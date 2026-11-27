extends Node
## Applies the Settings that act engine-wide or on nodes owned by other systems.
## Autoload "SettingsFx" (scenes/settings_fx.tscn):
##   PostFX  full-screen shader (brightness, contrast, saturation, gamma, colour-blind
##           filter, scanlines, vignette, bloom, grain, aberration); hidden at defaults
##   Info    timers / FPS / puddle counter / perspective, control hints, toast messages,
##           player locator ring and state name tag
## It also owns the input map (rebinds, gamepad bindings, deadzone), window / viewport
## options, time scale, pause ducking, focus handling, vibration, cursor and text size,
## and adjusts nodes as scenes load (particles, 3D lights / fog / glow, the 3D camera rig,
## 2D cameras, backdrops, hints, ice friction, cutscene skip time).
## `apply(key)` runs the hook for one setting (the settings test calls it for every key).

const STATE_NAMES := ["ICE", "WATER", "STEAM"]
const STATE_COLORS := [Color(0.72, 0.9, 1.0), Color(0.35, 0.65, 1.0), Color(0.95, 0.97, 1.0)]
const INPUT_ACTIONS := ["move_left", "move_right", "move_up", "move_down", "jump", "jump_3d", "heat", "cool", "restart"]
const MOVE_ACTIONS := ["move_left", "move_right", "move_up", "move_down"]
const POST_KEYS := ["brightness", "contrast", "saturation", "gamma", "scanlines", "vignette", "bloom",
	"film_grain", "chromatic_aberration", "colorblind_mode"]
## Keys handled by walking the scene tree (nodes of other systems).
const NODE_KEYS := ["particle_density", "backdrop_animation", "background_bubbles", "background_dim",
	"shadows_3d", "fog_3d", "glow_3d", "show_hints", "ice_grip", "skip_hold", "room_zoom",
	"camera_smoothing", "tp_fov", "fp_fov", "tp_distance", "turn_speed", "iso_zoom", "side_fov",
	"side_lookahead", "reduce_motion"]
const INFO_KEYS := ["show_fps", "show_timer", "show_total_timer", "show_deaths", "show_perspective",
	"show_controls", "info_corner", "timer_precision", "player_locator", "state_label"]
const THEME_PATH := "res://scenes/ui/theme.tres"
## Classic arrow pointer: X = outline, o = fill.
const CURSOR := [
	"X", "XX", "XoX", "XooX", "XoooX", "XooooX", "XoooooX", "XooooooX", "XoooooooX",
	"XooooooooX", "XoooooXXXXX", "XooXooX", "XoX XooX", "XX  XooX", "X    XooX", "     XooX", "      XX",
]

@onready var post_rect: ColorRect = $PostFX/Rect
@onready var info_root: Control = $Info/Root
@onready var corner: VBoxContainer = $Info/Root/Corner
@onready var fps_label: Label = $Info/Root/Corner/Fps
@onready var timer_label: Label = $Info/Root/Corner/Timer
@onready var total_label: Label = $Info/Root/Corner/Total
@onready var deaths_label: Label = $Info/Root/Corner/Deaths
@onready var view_label: Label = $Info/Root/Corner/View
@onready var controls_label: Label = $Info/Root/Controls
@onready var toast_label: Label = $Info/Root/Toast
@onready var locator: Node2D = $Info/Root/Locator
@onready var state_tag: Label = $Info/Root/StateTag

var _default_events := {}
var _theme_sizes := {}
var _theme: Theme
var _focused := true
var _state := 1
var _deaths := 0
var _toast_tween: Tween
var _loc_pos := Vector2.ZERO
var _loc_radius := 0.0
var _loc_on := false
var _bg_test := false
var _speed_owned := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bg_test = "--bg-test" in OS.get_cmdline_user_args()
	for a in INPUT_ACTIONS:
		if InputMap.has_action(a):
			_default_events[a] = InputMap.action_get_events(a)
	_add_gamepad_defaults()
	_theme = load(THEME_PATH) as Theme
	if _theme:
		_theme_sizes["__default"] = _theme.default_font_size
		for t in _theme.get_font_size_type_list():
			for n in _theme.get_font_size_list(t):
				_theme_sizes[[n, t]] = _theme.get_font_size(n, t)
	locator.draw.connect(_draw_locator)
	Settings.changed.connect(_on_changed)
	get_tree().node_added.connect(_on_node_added)
	Game.state_changed.connect(_on_state_changed)
	Game.deaths_changed.connect(_on_deaths_changed)
	Game.level_changed.connect(func(_n: String, _i: int, _t: int) -> void:
		_refresh_controls()
		_apply_hud())
	apply_all()


# --- Dispatch ---------------------------------------------------------------------------

func _on_changed(key: String) -> void:
	if key == "":
		apply_all()
	else:
		apply(key)


func apply_all() -> void:
	_apply_post()
	_apply_window()
	_apply_viewport_3d()
	_apply_input()
	_apply_text_size()
	_apply_cursor()
	_apply_hud()
	_apply_scene_nodes()
	_refresh_controls()
	Settings.apply_audio()


## Runs the apply hook of one setting. Returns false for keys with no hook here
## (those are read directly by Settings / Sfx / Game / the players / the panel).
func apply(key: String) -> bool:
	var handled := true
	if key in POST_KEYS:
		_apply_post()
	elif key in ["vsync", "max_fps", "pixel_render", "integer_scaling"]:
		_apply_window()
	elif key in ["render_scale_3d", "msaa_3d"]:
		_apply_viewport_3d()
	elif key in Settings.BINDS or key == "gamepad_deadzone":
		_apply_input()
		_refresh_controls()
	elif key == "text_size":
		_apply_text_size()
	elif key == "cursor_size":
		_apply_cursor()
	elif key in ["hud_opacity", "show_state_bar"]:
		_apply_hud()
	elif key in INFO_KEYS:
		_refresh_controls()
	else:
		handled = false
	if key in NODE_KEYS:
		_apply_scene_nodes()
		handled = true
	if key == "reduce_motion":
		_apply_post()
	return handled


# --- Per-frame ------------------------------------------------------------------------------

func _process(_delta: float) -> void:
	var in_level := Game.in_level and not Game.testing
	# Assist game speed (only while playing, so menus and fades keep their pace).
	# Only touches Engine.time_scale while the assist is active (tests may fast-forward).
	if in_level and Settings.game_speed < 0.999:
		if not is_equal_approx(Engine.time_scale, Settings.game_speed):
			Engine.time_scale = Settings.game_speed
		_speed_owned = true
	elif _speed_owned:
		Engine.time_scale = 1.0
		_speed_owned = false
	# Pause ducking / background mute.
	var duck := Settings.pause_duck if (in_level and get_tree().paused) else 1.0
	if Settings.mute_unfocused and not _focused:
		duck = 0.0
	if not is_equal_approx(duck, Settings.master_duck):
		Settings.master_duck = duck
		Settings.apply_audio()
	_update_info(in_level)


func _update_info(in_level: bool) -> void:
	fps_label.visible = Settings.show_fps
	timer_label.visible = in_level and Settings.show_timer
	total_label.visible = in_level and Settings.show_total_timer
	deaths_label.visible = in_level and Settings.show_deaths
	view_label.visible = in_level and Settings.show_perspective
	controls_label.visible = in_level and Settings.show_controls
	if fps_label.visible:
		fps_label.text = "%d FPS" % Engine.get_frames_per_second()
	if timer_label.visible:
		timer_label.text = "Chapter  " + format_time(Game.chapter_time)
	if total_label.visible:
		total_label.text = "Run  " + format_time(Game.run_time)
	if deaths_label.visible:
		deaths_label.text = "Puddles lost: %d" % Game.chapter_deaths
	if view_label.visible:
		view_label.text = Game.chapter_view(Game.level_index)
	var any := false
	for l in corner.get_children():
		any = any or (l as Control).visible
	corner.visible = any
	if any:
		_place_corner()
	_update_locator(in_level)


func _place_corner() -> void:
	var right := Settings.info_corner % 2 == 1
	var bottom := Settings.info_corner >= 2
	for l in corner.get_children():
		(l as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if right else HORIZONTAL_ALIGNMENT_LEFT
	var size := corner.get_combined_minimum_size()
	corner.size = size
	var vp := info_root.size
	# Keep clear of the HUD: chapter label top-left, puddles top-right, state bar bottom-centre.
	var x := vp.x - size.x - 16.0 if right else 16.0
	var y := vp.y - size.y - 12.0 if bottom else (64.0 if not right else 44.0)
	corner.position = Vector2(x, y).round()


## "1:02.3" / "1:02.34"
func format_time(t: float) -> String:
	var s := int(t)
	if Settings.timer_precision >= 2:
		return "%d:%02d.%02d" % [s / 60, s % 60, int((t - s) * 100.0)]
	return "%d:%02d.%d" % [s / 60, s % 60, int((t - s) * 10.0)]


# --- Player locator / state name ---------------------------------------------------------------

func _find_player() -> Node:
	var scene := get_tree().current_scene
	return scene.get_node_or_null("Player") if scene else null


func _update_locator(in_level: bool) -> void:
	var want := in_level and (Settings.player_locator or Settings.state_label)
	var p := _find_player() if want else null
	var on := false
	if p is Node2D:
		var xf := (p as Node2D).get_global_transform_with_canvas()
		_loc_pos = xf.origin
		_loc_radius = 24.0 * xf.get_scale().x
		on = not p.get("dead")
	elif p is Node3D:
		var cam := get_viewport().get_camera_3d()
		var pos := (p as Node3D).global_position + Vector3.UP * 0.3
		if cam and not cam.is_position_behind(pos) and cam.global_position.distance_to(pos) > 1.0:
			_loc_pos = cam.unproject_position(pos)
			var edge := cam.unproject_position(pos + cam.global_basis.x * 0.6)
			_loc_radius = clampf(_loc_pos.distance_to(edge), 14.0, 90.0)
			on = not p.get("dead")
	_loc_on = on and Settings.player_locator
	state_tag.visible = on and Settings.state_label
	if state_tag.visible:
		state_tag.text = STATE_NAMES[clampi(_state, 0, 2)]
		state_tag.add_theme_color_override("font_color", STATE_COLORS[clampi(_state, 0, 2)])
		state_tag.size = state_tag.get_combined_minimum_size()
		state_tag.position = (_loc_pos - Vector2(state_tag.size.x * 0.5, _loc_radius + state_tag.size.y + 2.0)).round()
	locator.queue_redraw()


func _draw_locator() -> void:
	if not _loc_on:
		return
	var col: Color = STATE_COLORS[clampi(_state, 0, 2)]
	var pulse := 0.0 if Settings.reduce_motion else sin(Time.get_ticks_msec() * 0.006) * 3.0
	var r := _loc_radius + 4.0 + pulse
	locator.draw_arc(_loc_pos, r, 0.0, TAU, 40, Color(0.02, 0.04, 0.08, 0.8), 5.0)
	locator.draw_arc(_loc_pos, r, 0.0, TAU, 40, col, 2.0)
	for i in 4:
		var d := Vector2.from_angle(i * TAU / 4.0 + PI / 4.0)
		locator.draw_line(_loc_pos + d * (r + 3.0), _loc_pos + d * (r + 9.0), col, 2.0)


# --- Game events -------------------------------------------------------------------------------

func _on_state_changed(s: int) -> void:
	_state = s
	if Game.in_level:
		_vibrate(0.25, 0.0, 0.08)


func _on_deaths_changed(d: int) -> void:
	if d > _deaths and Game.in_level:
		_vibrate(0.7, 0.9, 0.3)
	_deaths = d


func _vibrate(weak: float, strong: float, secs: float) -> void:
	if not Settings.gamepad_vibration:
		return
	for dev in Input.get_connected_joypads():
		Input.start_joy_vibration(dev, weak, strong, secs)


## Short message in the top centre (e.g. "Press R again to restart").
func toast(text: String, secs := 1.6) -> void:
	toast_label.text = text
	toast_label.show()
	toast_label.modulate.a = 1.0
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(secs)
	if Settings.ui_animations and not Settings.reduce_motion:
		_toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.3)
	_toast_tween.tween_callback(toast_label.hide)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and not _bg_test:
		_focused = false
		if Settings.auto_pause_unfocused and Game.in_level and not Game.testing and not get_tree().paused:
			Overlay.open_pause()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_focused = true


## Mouse look sensitivity / inversion for the 3D camera rig (captured mouse only).
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mm := event as InputEventMouseMotion
		var sx := Settings.mouse_sens_x * (-1.0 if Settings.invert_x else 1.0)
		var sy := Settings.mouse_sens_y * (-1.0 if Settings.invert_y else 1.0)
		mm.relative = Vector2(mm.relative.x * sx, mm.relative.y * sy)


# --- Post-process -------------------------------------------------------------------------------

func _apply_post() -> void:
	var m := post_rect.material as ShaderMaterial
	m.set_shader_parameter("brightness", Settings.brightness)
	m.set_shader_parameter("contrast", Settings.contrast)
	m.set_shader_parameter("saturation", Settings.saturation)
	m.set_shader_parameter("gamma", Settings.gamma)
	m.set_shader_parameter("scanlines", Settings.scanlines)
	m.set_shader_parameter("vignette", Settings.vignette)
	m.set_shader_parameter("bloom", Settings.bloom)
	m.set_shader_parameter("grain", Settings.film_grain)
	m.set_shader_parameter("aberration", Settings.chromatic_aberration)
	m.set_shader_parameter("cb_mode", Settings.colorblind_mode)
	m.set_shader_parameter("motion", 0.0 if Settings.reduce_motion else 1.0)
	# Only pay for the full-screen pass when something is changed from the defaults.
	var active := false
	for k in POST_KEYS:
		if Settings.get(k) != Settings.default_of(k):
			active = true
	post_rect.visible = active


func post_active() -> bool:
	return post_rect.visible


# --- Window / viewport ------------------------------------------------------------------------

func _apply_window() -> void:
	Engine.max_fps = Settings.max_fps
	var root := get_tree().root
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT if Settings.pixel_render else Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_INTEGER if Settings.integer_scaling else Window.CONTENT_SCALE_STRETCH_FRACTIONAL
	if DisplayServer.get_name() != "headless" and not OS.has_feature("web"):
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if Settings.vsync else DisplayServer.VSYNC_DISABLED)


func _apply_viewport_3d() -> void:
	var root := get_tree().root
	root.scaling_3d_scale = Settings.render_scale_3d
	root.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][clampi(Settings.msaa_3d, 0, 2)]


# --- Input map ----------------------------------------------------------------------------------

func _add_gamepad_defaults() -> void:
	var pads := {
		"move_left": [[JOY_AXIS_LEFT_X, -1.0], JOY_BUTTON_DPAD_LEFT],
		"move_right": [[JOY_AXIS_LEFT_X, 1.0], JOY_BUTTON_DPAD_RIGHT],
		"move_up": [[JOY_AXIS_LEFT_Y, -1.0], JOY_BUTTON_DPAD_UP],
		"move_down": [[JOY_AXIS_LEFT_Y, 1.0], JOY_BUTTON_DPAD_DOWN],
		"jump": [JOY_BUTTON_A], "jump_3d": [JOY_BUTTON_A],
		"heat": [JOY_BUTTON_RIGHT_SHOULDER], "cool": [JOY_BUTTON_LEFT_SHOULDER], "restart": [JOY_BUTTON_Y],
	}
	for a in pads:
		if not _default_events.has(a):
			continue
		var evs: Array = _default_events[a]
		if evs.any(func(e: InputEvent) -> bool: return e is InputEventJoypadButton or e is InputEventJoypadMotion):
			continue
		for p in pads[a]:
			if p is Array:
				var m := InputEventJoypadMotion.new()
				m.axis = p[0]
				m.axis_value = p[1]
				evs.append(m)
			else:
				var b := InputEventJoypadButton.new()
				b.button_index = p
				evs.append(b)


## First key of an action's default binding (physical keycode).
func default_key_for(action: String) -> int:
	for e in _default_events.get(action, []):
		if e is InputEventKey:
			var k := e as InputEventKey
			return k.physical_keycode if k.physical_keycode != 0 else k.keycode
	return 0


func _apply_input() -> void:
	var custom := {}
	for key in Settings.BINDS:
		var code := int(Settings.get(key))
		if code != 0:
			for a in Settings.BINDS[key]:
				custom[a] = code
	for a in _default_events:
		var evs: Array = []
		var replaced := false
		for e in _default_events[a]:
			if e is InputEventKey and not replaced and custom.has(a):
				var k := InputEventKey.new()
				k.physical_keycode = custom[a]
				evs.append(k)
				replaced = true
			else:
				evs.append(e)
		InputMap.action_erase_events(a)
		for e in evs:
			InputMap.action_add_event(a, e)
		if a in MOVE_ACTIONS:
			InputMap.action_set_deadzone(a, Settings.gamepad_deadzone)


func key_label(action: String) -> String:
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			var k := e as InputEventKey
			return OS.get_keycode_string(k.physical_keycode if k.physical_keycode != 0 else k.keycode)
	return "?"


func _refresh_controls() -> void:
	var view := Game.chapter_view(Game.level_index)
	var move := "%s/%s move" % [key_label("move_left"), key_label("move_right")]
	if view != "Side-scroller" and view != "2.5D side view":
		move = "%s%s%s%s move" % [key_label("move_up"), key_label("move_left"), key_label("move_down"), key_label("move_right")]
	var parts := [move]
	if view != "Top-down":
		parts.append("%s jump" % key_label("jump_3d" if view.contains("person") or view == "Isometric" or view.begins_with("2.5D") else "jump"))
	parts.append("%s heat" % key_label("heat"))
	parts.append("%s cool" % key_label("cool"))
	parts.append("%s restart" % key_label("restart"))
	parts.append("Esc pause")
	controls_label.text = "   ".join(parts)


# --- Text size / cursor / HUD --------------------------------------------------------------------

func _apply_text_size() -> void:
	if _theme == null:
		return
	var s := Settings.text_size
	for k in _theme_sizes:
		var v := maxi(8, roundi(_theme_sizes[k] * s))
		if k is String:
			if _theme.default_font_size != v:
				_theme.default_font_size = v
		elif _theme.get_font_size(k[0], k[1]) != v:
			_theme.set_font_size(k[0], k[1], v)


func _apply_cursor() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var n := Settings.cursor_size
	if n <= 1:
		Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
		Input.set_custom_mouse_cursor(null, Input.CURSOR_POINTING_HAND)
		return
	var tex := cursor_texture(n)
	Input.set_custom_mouse_cursor(tex, Input.CURSOR_ARROW, Vector2.ZERO)
	Input.set_custom_mouse_cursor(tex, Input.CURSOR_POINTING_HAND, Vector2.ZERO)


## Big pixel arrow, `scale` x 12x17 (white fill, black outline).
static func cursor_texture(scale: int) -> ImageTexture:
	var s := scale * 2
	var img := Image.create(12 * s, 17 * s, false, Image.FORMAT_RGBA8)
	for y in CURSOR.size():
		var row: String = CURSOR[y]
		for x in row.length():
			var ch := row[x]
			if ch == " ":
				continue
			img.fill_rect(Rect2i(x * s, y * s, s, s), Color.BLACK if ch == "X" else Color.WHITE)
	return ImageTexture.create_from_image(img)


func _apply_hud() -> void:
	var hud := get_node_or_null("/root/Hud")
	if hud == null:
		return
	var a := Settings.hud_opacity
	for c in hud.find_children("*", "CanvasItem", true, false):
		var ci := c as CanvasItem
		ci.self_modulate.a = a
	var bar := hud.get_node_or_null("StateBar") as CanvasItem
	if bar:
		bar.visible = Settings.show_state_bar
	info_root.modulate.a = a


# --- Scene nodes ---------------------------------------------------------------------------------

func _on_node_added(n: Node) -> void:
	if _interesting(n):
		_apply_node.call_deferred(n)


func _interesting(n: Node) -> bool:
	return n is CPUParticles2D or n is GPUParticles2D or n is CPUParticles3D or n is GPUParticles3D \
		or n is Light3D or n is WorldEnvironment or n is CameraRig3D or n is Player or n is Player3D \
		or n is TdPlayer or n.name == &"Hints" or (n is CanvasLayer and n.get_script() != null) \
		or (n.get_script() != null and "hold_to_skip" in n)


func _apply_scene_nodes() -> void:
	for n in get_tree().root.find_children("*", "", true, false):
		if _interesting(n):
			_apply_node(n)


func _base(n: Object, key: String, current: Variant) -> Variant:
	var m := "_ss_" + key
	if not n.has_meta(m):
		n.set_meta(m, current)
	return n.get_meta(m)


func _apply_node(n: Node) -> void:
	if not is_instance_valid(n) or not n.is_inside_tree():
		return
	if n is CPUParticles2D or n is GPUParticles2D or n is CPUParticles3D or n is GPUParticles3D:
		_apply_particles(n)
	elif n is Light3D:
		var l := n as Light3D
		l.shadow_enabled = bool(_base(l, "shadow", l.shadow_enabled)) and Settings.shadows_3d
	elif n is WorldEnvironment:
		_apply_environment(n as WorldEnvironment)
	elif n is CameraRig3D:
		_apply_rig(n as CameraRig3D)
	elif n.name == &"Hints" and n.get_parent() and n.get_parent().has_method("get_bounds"):
		if n is CanvasItem or n is Node3D:
			n.visible = Settings.show_hints
	elif n is CanvasLayer and "bubble_count" in n and "fps" in n:
		_apply_backdrop(n)
	elif "hold_to_skip" in n:
		n.hold_to_skip = float(_base(n, "hold", n.hold_to_skip)) * Settings.skip_hold / 0.75
	if n is Player or n is Player3D:
		n.ice_friction = float(_base(n, "ice_friction", n.ice_friction)) * Settings.ice_grip
	if (n is Player or n is TdPlayer) and not ("demo" in n and n.demo):
		_apply_cam2d(n)


func _apply_particles(p: Node) -> void:
	var base := int(_base(p, "amount", p.amount))
	var d := Settings.particle_density
	var hidden := d <= 0.0
	var vis := bool(_base(p, "visible", p.visible))
	if hidden:
		p.visible = false
	elif p.has_meta("_ss_hidden"):
		p.visible = vis
	if hidden:
		p.set_meta("_ss_hidden", true)
	else:
		p.remove_meta("_ss_hidden")
		var want := maxi(1, roundi(base * d))
		if p.amount != want:
			p.amount = want


func _apply_environment(we: WorldEnvironment) -> void:
	var env := we.environment
	if env == null:
		return
	env.fog_enabled = bool(_base(we, "fog", env.fog_enabled)) and Settings.fog_3d
	var glow_base := bool(_base(we, "glow", env.glow_enabled))
	if Settings.glow_3d and not glow_base:
		env.glow_intensity = 1.1
		env.glow_bloom = 0.12
		env.glow_hdr_threshold = 0.75
		env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.glow_enabled = glow_base or Settings.glow_3d


func _apply_rig(rig: CameraRig3D) -> void:
	rig.tp_fov = float(_base(rig, "tp_fov", rig.tp_fov)) * Settings.tp_fov / 64.0
	rig.fp_fov = float(_base(rig, "fp_fov", rig.fp_fov)) * Settings.fp_fov / 80.0
	rig.side_fov = float(_base(rig, "side_fov", rig.side_fov)) * Settings.side_fov / 38.0
	rig.distance = float(_base(rig, "distance", rig.distance)) * Settings.tp_distance / 4.6
	rig.turn_speed = float(_base(rig, "turn_speed", rig.turn_speed)) * Settings.turn_speed
	rig.iso_size = float(_base(rig, "iso_size", rig.iso_size)) / Settings.iso_zoom
	rig.side_lookahead = float(_base(rig, "side_lookahead", rig.side_lookahead)) * Settings.side_lookahead / 2.2
	var cam := rig.camera
	if cam == null or rig.target == null:
		return # setup() reads the values above
	match rig.mode:
		CameraRig3D.Mode.THIRD_PERSON: cam.fov = rig.tp_fov
		CameraRig3D.Mode.FIRST_PERSON: cam.fov = rig.fp_fov
		CameraRig3D.Mode.SIDE_25D: cam.fov = rig.side_fov
		CameraRig3D.Mode.ISOMETRIC: cam.size = rig.iso_size


func _apply_cam2d(p: Node) -> void:
	var cam := p.get("camera") as Camera2D
	if cam == null or not cam.enabled:
		return
	var base := float(p.zoom_override) if float(p.zoom_override) > 0.0 else 1.0
	cam.zoom = Vector2.ONE * base * Settings.room_zoom
	var smooth: Array = _base(cam, "smooth", [cam.position_smoothing_enabled, cam.position_smoothing_speed])
	if Settings.room_zoom > 1.0:
		cam.position_smoothing_enabled = Settings.camera_smoothing > 0.0
		cam.position_smoothing_speed = maxf(Settings.camera_smoothing, 0.1)
	else:
		cam.position_smoothing_enabled = smooth[0]
		cam.position_smoothing_speed = smooth[1]


func _apply_backdrop(bg: CanvasLayer) -> void:
	var animate := Settings.backdrop_animation and not Settings.reduce_motion
	bg.fps = float(_base(bg, "fps", bg.fps)) if animate else 0.0
	var bubbles := bg.get("bubbles") as CanvasItem
	if bubbles:
		var mod: Color = bg.get("_bubble_mod") if bg.get("_bubble_mod") != null else Color.WHITE
		bubbles.visible = Settings.background_bubbles and mod.a > 0.0
	var k := 1.0 - Settings.background_dim
	for c in bg.get_children():
		if c is CanvasItem:
			(c as CanvasItem).modulate = Color(k, k, k, (c as CanvasItem).modulate.a)
