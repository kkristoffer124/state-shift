extends Node
## Player options, persisted in the Save file's [settings] section. Autoload "Settings".
## Every option is a typed var below plus one row in DEFS (category, control type, range /
## choices, label, description); the settings panel is generated from DEFS.
## Read the vars directly (`Settings.reduce_motion`); listen to `changed(key)` to react to
## edits (`key` is "" after a bulk load / reset). The SettingsFx autoload
## (scenes/settings_fx.tscn) applies the engine-wide effects (post-process, info HUD,
## input map, 3D camera / lights, particles...).

signal changed(key: String)

const CATEGORIES: Array[String] = ["audio", "video", "gameplay", "camera", "controls", "access", "interface"]
const CATEGORY_NAMES := {
	"audio": "Audio", "video": "Video", "gameplay": "Gameplay", "camera": "Camera",
	"controls": "Controls", "access": "Access", "interface": "Interface",
}
## Legacy option (the levels always set their own room zoom); kept so old saves load.
const ZOOM_CHOICES: Array[float] = [1.5, 2.0, 3.0]
## Rebindable actions: setting key -> InputMap action(s). 0 = keep the default key.
const BINDS := {
	"bind_move_left": ["move_left"], "bind_move_right": ["move_right"],
	"bind_move_up": ["move_up"], "bind_move_down": ["move_down"],
	"bind_jump": ["jump", "jump_3d"], "bind_heat": ["heat"], "bind_cool": ["cool"],
	"bind_restart": ["restart"],
}
## Extra audio buses (created at startup, all sending to SFX): Sfx routes sounds by name.
const EXTRA_BUSES := {"UI": "ui_volume", "Cutscene": "cutscene_volume", "Movement": "movement_volume",
	"Shift": "shift_volume", "Jingles": "jingle_volume"}

# --- Audio ---
var master_volume := 1.0
var music_volume := 0.8
var sfx_volume := 0.8
var ui_volume := 0.8
var cutscene_volume := 0.9
var movement_volume := 1.0
var shift_volume := 1.0
var jingle_volume := 1.0
var mute_all := false
var mute_unfocused := false
var pitch_variation := 1.0
var pause_duck := 1.0
# --- Video ---
var fullscreen := false
var vsync := true
var max_fps := 0
var pixel_render := false
var integer_scaling := false
var brightness := 1.0
var contrast := 1.0
var saturation := 1.0
var gamma := 1.0
var scanlines := 0.0
var vignette := 0.0
var bloom := 0.0
var film_grain := 0.0
var chromatic_aberration := 0.0
var particle_density := 1.0
var backdrop_animation := true
var background_bubbles := true
var shadows_3d := true
var render_scale_3d := 1.0
var msaa_3d := 0
var fog_3d := true
var glow_3d := false
# --- Gameplay ---
var game_speed := 1.0
var coyote_time := 0.1
var jump_buffer := 0.12
var ice_grip := 1.0
var respawn_delay := 0.7
var skip_chapter_cards := false
var skip_cutscenes := false
var show_results := true
var restart_confirm := false
var auto_pause_unfocused := false
var show_hints := true
# --- Camera ---
var screen_shake := true
var shake_intensity := 1.0
var camera_zoom := 2.0
var room_zoom := 1.0
var camera_smoothing := 7.0
var tp_fov := 64.0
var fp_fov := 80.0
var tp_distance := 4.6
var mouse_sens_x := 1.0
var mouse_sens_y := 1.0
var invert_x := false
var invert_y := false
var turn_speed := 1.0
var iso_zoom := 1.0
var side_fov := 38.0
var side_lookahead := 2.2
# --- Controls ---
var bind_move_left := 0
var bind_move_right := 0
var bind_move_up := 0
var bind_move_down := 0
var bind_jump := 0
var bind_heat := 0
var bind_cool := 0
var bind_restart := 0
var gamepad_vibration := true
var gamepad_deadzone := 0.2
# --- Accessibility ---
var reduce_motion := false
var ui_animations := true
var colorblind_mode := 0
var player_locator := false
var state_label := false
var text_size := 1.0
var background_dim := 0.0
var cursor_size := 1
var skip_hold := 0.75
# --- Interface ---
var show_fps := false
var show_timer := false
var show_total_timer := false
var show_deaths := false
var show_perspective := false
var show_controls := false
var hud_opacity := 1.0
var show_state_bar := true
var info_corner := 1
var timer_precision := 1

## Metadata rows: [key, category, type, label, description, extra].
## type: "bool" | "range" (extra: min, max, step, fmt "pct"/"x"/"f1"/"f2"/"deg")
##       "choice" (extra: values, labels) | "key" (physical keycode, 0 = default key)
## extra may also hold "hidden": true (no row) and "desktop_only": true (no row on web).
const DEFS := [
	# Audio
	["master_volume", "audio", "range", "Master volume", "Overall loudness of everything.", {"min": 0.0, "max": 1.0, "step": 0.05, "fmt": "pct"}],
	["music_volume", "audio", "range", "Music", "Volume of the music bus.", {"min": 0.0, "max": 1.0, "step": 0.05, "fmt": "pct"}],
	["sfx_volume", "audio", "range", "Sound effects", "All game sounds (the groups below mix into this).", {"min": 0.0, "max": 1.0, "step": 0.05, "fmt": "pct"}],
	["ui_volume", "audio", "range", "Menu sounds", "Menu move / select blips.", {"min": 0.0, "max": 1.0, "step": 0.05, "fmt": "pct"}],
	["cutscene_volume", "audio", "range", "Cutscene & ambience", "Typewriter text, lab machinery, alarms and rain in the story scenes.", {"min": 0.0, "max": 1.0, "step": 0.05, "fmt": "pct"}],
	["movement_volume", "audio", "range", "Movement sounds", "Jumps, landings and splats.", {"min": 0.0, "max": 1.0, "step": 0.05, "fmt": "pct"}],
	["shift_volume", "audio", "range", "State-shift sounds", "Heat / cool whooshes and the 'blocked' buzz.", {"min": 0.0, "max": 1.0, "step": 0.05, "fmt": "pct"}],
	["jingle_volume", "audio", "range", "Jingles", "Chapter-clear fanfare, chimes and shattering ice.", {"min": 0.0, "max": 1.0, "step": 0.05, "fmt": "pct"}],
	["mute_all", "audio", "bool", "Mute all", "Silences the game without losing your volume levels.", {}],
	["mute_unfocused", "audio", "bool", "Mute in background", "Mute while the game window / browser tab is not focused.", {}],
	["pitch_variation", "audio", "choice", "Pitch variation", "How much repeated sounds vary in pitch.", {"values": [0.0, 0.5, 1.0, 2.0], "labels": ["Off", "Subtle", "Normal", "Wild"]}],
	["pause_duck", "audio", "choice", "Volume when paused", "Lowers the sound while the pause menu is open.", {"values": [1.0, 0.5, 0.25, 0.0], "labels": ["Full", "Half", "Quiet", "Silent"]}],
	# Video
	["fullscreen", "video", "bool", "Fullscreen", "Fill the screen (on web: browser fullscreen).", {}],
	["vsync", "video", "bool", "V-Sync", "Sync frames to the monitor to stop tearing.", {"desktop_only": true}],
	["max_fps", "video", "choice", "Frame rate cap", "Limit frames per second (saves battery).", {"values": [0, 30, 60, 120, 144], "labels": ["Unlimited", "30", "60", "120", "144"]}],
	["pixel_render", "video", "bool", "Pixel-exact rendering", "Render at 960x540 and scale up: chunkier text, true retro pixels.", {}],
	["integer_scaling", "video", "bool", "Integer scaling", "Only scale by whole numbers (sharp pixels, may add borders).", {}],
	["brightness", "video", "range", "Brightness", "Overall image brightness.", {"min": 0.5, "max": 1.5, "step": 0.05, "fmt": "pct"}],
	["contrast", "video", "range", "Contrast", "Difference between darks and lights.", {"min": 0.5, "max": 1.5, "step": 0.05, "fmt": "pct"}],
	["saturation", "video", "range", "Saturation", "Colour intensity (0% = black and white).", {"min": 0.0, "max": 2.0, "step": 0.05, "fmt": "pct"}],
	["gamma", "video", "range", "Gamma", "Lifts or deepens the mid-tones.", {"min": 0.6, "max": 1.6, "step": 0.05, "fmt": "f2"}],
	["scanlines", "video", "range", "CRT scanlines", "Old-TV horizontal lines over the picture.", {"min": 0.0, "max": 1.0, "step": 0.05, "fmt": "pct"}],
	["vignette", "video", "range", "Vignette", "Darkens the screen corners.", {"min": 0.0, "max": 1.0, "step": 0.05, "fmt": "pct"}],
	["bloom", "video", "range", "Bloom", "Soft glow around bright pixels.", {"min": 0.0, "max": 1.0, "step": 0.05, "fmt": "pct"}],
	["film_grain", "video", "range", "Film grain", "Subtle animated noise.", {"min": 0.0, "max": 1.0, "step": 0.05, "fmt": "pct"}],
	["chromatic_aberration", "video", "range", "Chromatic aberration", "Red/blue colour fringes towards the edges.", {"min": 0.0, "max": 1.0, "step": 0.05, "fmt": "pct"}],
	["particle_density", "video", "choice", "Particles", "Amount of sparks, drips and puffs.", {"values": [0.0, 0.33, 0.66, 1.0], "labels": ["Off", "Low", "Medium", "High"]}],
	["backdrop_animation", "video", "bool", "Animated backdrops", "Animate the lab machinery behind 2D rooms.", {}],
	["background_bubbles", "video", "bool", "Background bubbles", "Rising bubbles in the 2D backdrops.", {}],
	["shadows_3d", "video", "bool", "3D shadows", "Real-time shadows in the 3D chapters.", {}],
	["render_scale_3d", "video", "range", "3D render scale", "Resolution of the 3D chapters (lower = faster, blurrier).", {"min": 0.5, "max": 1.0, "step": 0.05, "fmt": "pct"}],
	["msaa_3d", "video", "choice", "3D anti-aliasing", "Smooths jagged 3D edges (MSAA).", {"values": [0, 1, 2], "labels": ["Off", "2x", "4x"]}],
	["fog_3d", "video", "bool", "3D fog", "Atmospheric distance fog in the 3D chapters.", {}],
	["glow_3d", "video", "bool", "3D glow", "Lamps and steam glow in the 3D chapters.", {}],
	# Gameplay
	["game_speed", "gameplay", "range", "Game speed", "Assist: slow the whole game down.", {"min": 0.5, "max": 1.0, "step": 0.05, "fmt": "pct"}],
	["coyote_time", "gameplay", "choice", "Coyote time", "Grace time to still jump after leaving a ledge.", {"values": [0.0, 0.1, 0.18, 0.28], "labels": ["Off", "Normal", "Generous", "Huge"]}],
	["jump_buffer", "gameplay", "choice", "Jump buffer", "Jumps pressed just before landing still count.", {"values": [0.0, 0.12, 0.2, 0.3], "labels": ["Off", "Normal", "Generous", "Huge"]}],
	["ice_grip", "gameplay", "choice", "Ice grip", "How quickly the ice cube stops sliding (2D and 3D).", {"values": [0.5, 1.0, 2.0, 4.0], "labels": ["Slippery", "Normal", "Grippy", "Sticky"]}],
	["respawn_delay", "gameplay", "choice", "Respawn delay", "Pause before the room resets after losing the puddle.", {"values": [0.2, 0.7, 1.5], "labels": ["Quick", "Normal", "Slow"]}],
	["skip_chapter_cards", "gameplay", "bool", "Skip chapter titles", "Don't show the title card when a chapter starts.", {}],
	["skip_cutscenes", "gameplay", "bool", "Skip cutscenes", "Jump straight past the intro and ending scenes.", {}],
	["show_results", "gameplay", "bool", "Chapter results", "Show time / puddles lost after clearing a chapter.", {}],
	["restart_confirm", "gameplay", "bool", "Double-press restart", "Press restart twice to reset the room (no accidents).", {}],
	["auto_pause_unfocused", "gameplay", "bool", "Pause in background", "Open the pause menu when the window loses focus.", {}],
	["show_hints", "gameplay", "bool", "Tutorial hints", "Show the hint text painted in the rooms.", {}],
	# Camera
	["screen_shake", "camera", "bool", "Screen shake", "Shake the camera on impacts and shifts.", {}],
	["shake_intensity", "camera", "range", "Shake strength", "How hard the screen shakes.", {"min": 0.25, "max": 2.0, "step": 0.05, "fmt": "pct"}],
	["camera_zoom", "camera", "choice", "Camera zoom (legacy)", "", {"values": [1.5, 2.0, 3.0], "labels": ["1.5x", "2x", "3x"], "hidden": true}],
	["room_zoom", "camera", "choice", "2D room zoom", "Zoom into 2D rooms; the camera then follows the blob.", {"values": [1.0, 1.25, 1.5, 2.0], "labels": ["1x", "1.25x", "1.5x", "2x"]}],
	["camera_smoothing", "camera", "choice", "2D camera smoothing", "How softly the zoomed 2D camera follows.", {"values": [0.0, 14.0, 7.0, 3.5], "labels": ["Off", "Snappy", "Normal", "Floaty"]}],
	["tp_fov", "camera", "range", "Third-person FOV", "Field of view behind the blob.", {"min": 50.0, "max": 100.0, "step": 1.0, "fmt": "deg"}],
	["fp_fov", "camera", "range", "First-person FOV", "Field of view through the blob's eyes.", {"min": 60.0, "max": 110.0, "step": 1.0, "fmt": "deg"}],
	["tp_distance", "camera", "range", "Third-person distance", "How far the camera sits behind the blob.", {"min": 3.0, "max": 8.0, "step": 0.1, "fmt": "f1"}],
	["mouse_sens_x", "camera", "range", "Mouse sensitivity X", "Horizontal mouse look speed (3D).", {"min": 0.25, "max": 3.0, "step": 0.05, "fmt": "x"}],
	["mouse_sens_y", "camera", "range", "Mouse sensitivity Y", "Vertical mouse look speed (3D).", {"min": 0.25, "max": 3.0, "step": 0.05, "fmt": "x"}],
	["invert_x", "camera", "bool", "Invert mouse X", "Mouse left/right turns the other way.", {}],
	["invert_y", "camera", "bool", "Invert mouse Y", "Mouse up looks down (flight style).", {}],
	["turn_speed", "camera", "range", "Keyboard turn speed", "Arrow-key turning speed in 1st / 3rd person.", {"min": 0.5, "max": 2.0, "step": 0.05, "fmt": "x"}],
	["iso_zoom", "camera", "range", "Isometric zoom", "Zoom of the isometric chapters.", {"min": 0.7, "max": 1.5, "step": 0.05, "fmt": "x"}],
	["side_fov", "camera", "range", "2.5D view angle", "Lower = flatter, closer side view.", {"min": 25.0, "max": 55.0, "step": 1.0, "fmt": "deg"}],
	["side_lookahead", "camera", "choice", "2.5D look-ahead", "How far the side camera leads in the running direction.", {"values": [0.0, 1.1, 2.2, 3.5], "labels": ["Off", "Low", "Normal", "High"]}],
	# Controls
	["bind_move_left", "controls", "key", "Move left", "Main key (arrow keys keep working). Backspace = default.", {}],
	["bind_move_right", "controls", "key", "Move right", "Main key (arrow keys keep working). Backspace = default.", {}],
	["bind_move_up", "controls", "key", "Move up / forward", "Top-down and 3D chapters. Backspace = default.", {}],
	["bind_move_down", "controls", "key", "Move down / back", "Top-down and 3D chapters. Backspace = default.", {}],
	["bind_jump", "controls", "key", "Jump", "Jump as water, in every perspective. Backspace = default.", {}],
	["bind_heat", "controls", "key", "Heat up", "Ice -> water -> steam. Backspace = default.", {}],
	["bind_cool", "controls", "key", "Cool down", "Steam -> water -> ice. Backspace = default.", {}],
	["bind_restart", "controls", "key", "Restart room", "Reset the current room. Backspace = default.", {}],
	["gamepad_vibration", "controls", "bool", "Gamepad vibration", "Rumble on state shifts and when the puddle is lost.", {}],
	["gamepad_deadzone", "controls", "range", "Stick deadzone", "Ignore small stick movements (drifting sticks).", {"min": 0.05, "max": 0.6, "step": 0.05, "fmt": "pct"}],
	# Accessibility
	["reduce_motion", "access", "bool", "Reduce motion", "Calms menus, stops screen shake, backdrop animation and grain.", {}],
	["ui_animations", "access", "bool", "UI animations", "Animated menu transitions and pop-ins.", {}],
	["colorblind_mode", "access", "choice", "Colour-blind mode", "Shifts colours so ice / water / steam stay distinct.", {"values": [0, 1, 2, 3, 4], "labels": ["Off", "Protanopia", "Deuteranopia", "Tritanopia", "Greyscale"]}],
	["player_locator", "access", "bool", "Player locator", "Draws a ring around the blob so it never gets lost.", {}],
	["state_label", "access", "bool", "State name", "Writes ICE / WATER / STEAM next to the blob.", {}],
	["text_size", "access", "choice", "Text size", "Size of menu and HUD text.", {"values": [0.9, 1.0, 1.15, 1.3], "labels": ["Small", "Normal", "Large", "Huge"]}],
	["background_dim", "access", "range", "Dim backgrounds", "Darkens 2D backdrops so the room stands out.", {"min": 0.0, "max": 0.8, "step": 0.05, "fmt": "pct"}],
	["cursor_size", "access", "choice", "Mouse cursor", "A bigger, high-contrast pointer.", {"values": [1, 2, 3], "labels": ["System", "Large", "Huge"]}],
	["skip_hold", "access", "choice", "Cutscene skip hold", "How long to hold SPACE / ESC to skip a cutscene.", {"values": [0.25, 0.75, 1.5], "labels": ["Short", "Normal", "Long"]}],
	# Interface
	["show_fps", "interface", "bool", "FPS counter", "Frames per second in the corner.", {}],
	["show_timer", "interface", "bool", "Chapter timer", "Time spent on the current chapter.", {}],
	["show_total_timer", "interface", "bool", "Speedrun timer", "Total time for this play session.", {}],
	["show_deaths", "interface", "bool", "Puddle counter", "Keep 'puddles lost' visible all the time.", {}],
	["show_perspective", "interface", "bool", "Perspective label", "Shows the chapter's camera style (top-down, 3D...).", {}],
	["show_controls", "interface", "bool", "Control hints", "A strip with your current keys at the bottom.", {}],
	["hud_opacity", "interface", "range", "HUD opacity", "Transparency of the in-game HUD.", {"min": 0.2, "max": 1.0, "step": 0.05, "fmt": "pct"}],
	["show_state_bar", "interface", "bool", "State bar", "The ice / water / steam icons at the bottom.", {}],
	["info_corner", "interface", "choice", "Info position", "Corner for the timers / counters.", {"values": [0, 1, 2, 3], "labels": ["Top left", "Top right", "Bottom left", "Bottom right"]}],
	["timer_precision", "interface", "choice", "Timer precision", "Decimals shown on the timers.", {"values": [1, 2], "labels": ["0.1 s", "0.01 s"]}],
]

## All setting keys in panel order.
var KEYS: Array[String] = []
## Extra multiplier on the master bus (pause ducking / unfocused mute), set by SettingsFx.
var master_duck := 1.0

var _defaults := {}
var _meta := {} # key -> DEFS row as a Dictionary


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for row in DEFS:
		var m := {"key": row[0], "category": row[1], "type": row[2], "label": row[3], "description": row[4]}
		m.merge(row[5])
		_meta[row[0]] = m
		KEYS.append(row[0])
		_defaults[row[0]] = get(row[0])
	_make_buses()
	load_settings()
	_apply_window(true)


# --- Metadata ---------------------------------------------------------------------

func meta(key: String) -> Dictionary:
	return _meta.get(key, {})


func default_of(key: String) -> Variant:
	return _defaults.get(key)


## Keys of one category in panel order (hidden / unsupported rows left out if `visible_only`).
func keys_in(category: String, visible_only := false) -> Array[String]:
	var out: Array[String] = []
	for k in KEYS:
		if _meta[k].category != category:
			continue
		if visible_only and not is_row_visible(k):
			continue
		out.append(k)
	return out


func is_row_visible(key: String) -> bool:
	var m := meta(key)
	if m.get("hidden", false):
		return false
	if m.get("desktop_only", false) and OS.has_feature("web"):
		return false
	return true


## Human-readable value ("80%", "Generous", "K"...).
func format_value(key: String, value: Variant = null) -> String:
	var m := meta(key)
	var v: Variant = get(key) if value == null else value
	match m.get("type", ""):
		"bool":
			return "On" if v else "Off"
		"choice":
			var i: int = choice_index(key, v)
			return m.labels[i] if i >= 0 else str(v)
		"key":
			return key_name(key, int(v))
		"range":
			match m.get("fmt", ""):
				"pct": return "%d%%" % roundi(float(v) * 100.0)
				"x": return "%.2fx" % float(v)
				"deg": return "%d°" % roundi(float(v))
				"f1": return "%.1f" % float(v)
				"f2": return "%.2f" % float(v)
	return str(v)


func choice_index(key: String, value: Variant) -> int:
	var vals: Array = meta(key).get("values", [])
	for i in vals.size():
		if typeof(value) in [TYPE_FLOAT, TYPE_INT] and absf(float(vals[i]) - float(value)) < 0.0001:
			return i
	return -1


## Name of the key bound by a "bind_*" setting (its default key when 0).
func key_name(key: String, code: int) -> String:
	if code == 0:
		code = default_key(key)
	return OS.get_keycode_string(code) if code != 0 else "-"


## Default physical key of a "bind_*" setting (first key event of its action).
func default_key(key: String) -> int:
	var fx := get_node_or_null("/root/SettingsFx")
	if fx and BINDS.has(key):
		return fx.default_key_for(BINDS[key][0])
	return 0


# --- Values -------------------------------------------------------------------------

## Re-reads all settings from Save (call after Save.use_path()). Missing / invalid entries
## (older saves, hand edits) fall back to the defaults.
func load_settings() -> void:
	for k in KEYS:
		set(k, _coerce(k, Save.get_setting(k, _defaults[k])))
	_apply_audio()
	changed.emit("")


## Changes one setting, applies it, saves and emits `changed(key)`.
func set_value(key: String, value: Variant) -> void:
	if not _meta.has(key):
		push_error("Settings: unknown key %s" % key)
		return
	value = _coerce(key, value)
	if get(key) == value:
		return
	set(key, value)
	Save.set_setting(key, value)
	_apply_audio()
	if key == "fullscreen":
		_apply_window(false)
	changed.emit(key)


func reset_category(category: String) -> void:
	_reset(keys_in(category))


func reset_defaults() -> void:
	_reset(KEYS)


func _reset(keys: Array) -> void:
	for k in keys:
		set(k, _defaults[k])
		Save.set_setting(k, _defaults[k], false)
	Save.flush()
	_apply_audio()
	_apply_window(false)
	changed.emit("")


## Converts / clamps a stored or edited value to the setting's type and range.
func _coerce(key: String, v: Variant) -> Variant:
	var m: Dictionary = _meta[key]
	var d: Variant = _defaults[key]
	if not typeof(v) in [TYPE_BOOL, TYPE_INT, TYPE_FLOAT]:
		return d
	match m.type:
		"bool":
			return bool(v)
		"range":
			return clampf(float(v), m.min, m.max)
		"key":
			return maxi(int(v), 0)
		"choice":
			var i := choice_index(key, v)
			if i < 0:
				return d
			return float(m.values[i]) if typeof(d) == TYPE_FLOAT else int(m.values[i])
	return d


## Camera shake multiplier for all perspectives (0 when off or with reduce motion).
func shake_scale() -> float:
	return 0.0 if (not screen_shake or reduce_motion) else shake_intensity


# --- Audio / window -------------------------------------------------------------------

## Fullscreen works on desktop and on web (from a click/key press = user gesture).
func can_fullscreen() -> bool:
	return DisplayServer.get_name() != "headless"


func _make_buses() -> void:
	for bus in EXTRA_BUSES:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus)
			AudioServer.set_bus_send(i, &"SFX")


func apply_audio() -> void:
	_apply_audio()


func _apply_audio() -> void:
	_set_bus("Master", master_volume * master_duck)
	_set_bus("Music", music_volume)
	_set_bus("SFX", sfx_volume)
	for bus in EXTRA_BUSES:
		_set_bus(bus, float(get(EXTRA_BUSES[bus])))
	# Tests / background windows keep the master bus muted (Game does that for --bg-test).
	if not "--bg-test" in OS.get_cmdline_user_args():
		AudioServer.set_bus_mute(0, mute_all)


func _set_bus(bus: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))


func _apply_window(at_startup: bool) -> void:
	if not can_fullscreen() or "--bg-test" in OS.get_cmdline_user_args():
		return
	# Browsers only allow fullscreen from a user gesture, so don't force it on load.
	if at_startup and OS.has_feature("web"):
		return
	var mode := DisplayServer.window_get_mode()
	var is_full := mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if fullscreen and not is_full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif not fullscreen and is_full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
