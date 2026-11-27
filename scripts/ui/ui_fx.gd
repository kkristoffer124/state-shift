extends Node
## Autoload "UiFx": water / ice / steam flavoured UI animation for every menu control.
##
## * Hooks every BaseButton, Slider, TabBar and TabContainer that enters the tree
##   (SceneTree.node_added) and gives it an FxDeco child + press / focus / toggle reactions.
##   Opt out with `set_meta("no_uifx", true)` on the control or any ancestor.
## * Helpers for screens: register_panel() (condense from steam on show, evaporate on hide),
##   stagger_in(), drip_text(), card_in(), and particle bursts (splash / frost / puff / drip).
## * Honours Settings.ui_animations (false = no motion) and Settings.reduce_motion
##   (fades only, no particles / wobble) when those settings exist.

const Particles := preload("res://scripts/ui/fx_particles.gd")
const Deco := preload("res://scripts/ui/fx_deco.gd")
const DripText := preload("res://scripts/ui/fx_drip_text.gd")

const WATER := Color(0.36, 0.66, 1.0)
const WATER_LIGHT := Color(0.72, 0.89, 1.0)
const ICE := Color(0.8, 0.95, 1.0)
const STEAM := Color(0.86, 0.92, 1.0, 0.34)

enum { OFF, REDUCED, FULL }

var _drawers := {}
var _last_input_mouse := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)
	_scan.call_deferred()


func _scan() -> void:
	for c in get_tree().root.find_children("*", "Control", true, false):
		_on_node_added(c)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_last_input_mouse = true
	elif event is InputEventKey or event is InputEventJoypadButton:
		_last_input_mouse = false


# --- Motion level -----------------------------------------------------------------

## FULL normally; REDUCED with Settings.reduce_motion; OFF when Settings.ui_animations is false.
func motion() -> int:
	var s := get_node_or_null("/root/Settings")
	if s:
		var a: Variant = s.get("ui_animations")
		if a != null and typeof(a) in [TYPE_BOOL, TYPE_INT, TYPE_FLOAT] and not bool(a):
			return OFF
		var r: Variant = s.get("reduce_motion")
		if r != null and typeof(r) in [TYPE_BOOL, TYPE_INT, TYPE_FLOAT] and bool(r):
			return REDUCED
	return FULL


func full() -> bool:
	return motion() == FULL


## Scales a duration for the motion level (0 when animations are off).
func dur(t: float) -> float:
	match motion():
		OFF: return 0.0
		REDUCED: return t * 0.6
	return t


## Kills the previous tween stored under `key` on `n` and returns a fresh one bound to `n`.
func tw(n: Node, key := "main") -> Tween:
	var meta := StringName("_uifx_tw_" + key)
	if n.has_meta(meta):
		var old: Variant = n.get_meta(meta)
		if old is Tween and (old as Tween).is_valid():
			(old as Tween).kill()
	var t := n.create_tween()
	t.set_ignore_time_scale(true)  # menus keep their pace with the game-speed assist
	n.set_meta(meta, t)
	return t


# --- Auto hooks ---------------------------------------------------------------------

func _on_node_added(n: Node) -> void:
	if n is BaseButton or n is Slider or n is TabBar or n is TabContainer:
		_hook.call_deferred(n)


func _opted_out(n: Node) -> bool:
	var p := n
	while p:
		if p.has_meta("no_uifx"):
			return true
		p = p.get_parent()
	return false


func _hook(c: Control) -> void:
	if not is_instance_valid(c) or not c.is_inside_tree() or c.has_meta("_uifx"):
		return
	if Engine.is_editor_hint() or _opted_out(c):
		return
	c.set_meta("_uifx", true)
	if c is TabContainer:
		(c as TabContainer).tab_changed.connect(_on_tab_page.bind(c))
		return
	var deco: Control = Deco.new()
	deco.target = c
	deco.kind = _kind_of(c)
	c.add_child(deco, false, Node.INTERNAL_MODE_FRONT)
	c.set_meta("_uifx_deco", deco)
	c.focus_entered.connect(_on_focus.bind(c, true))
	c.focus_exited.connect(_on_focus.bind(c, false))
	c.mouse_entered.connect(func() -> void:
		if c.focus_mode == Control.FOCUS_NONE and not _is_disabled(c):
			_on_focus(c, true))
	c.mouse_exited.connect(func() -> void:
		if c.focus_mode == Control.FOCUS_NONE:
			_on_focus(c, false))
	if c is Slider:
		(c as Slider).value_changed.connect(_on_slider.bind(c))
		return
	if c is TabBar:
		(c as TabBar).tab_changed.connect(_on_tab.bind(c))
		return
	var b := c as BaseButton
	b.button_down.connect(_on_down.bind(b))
	b.button_up.connect(_on_up.bind(b))
	if deco.kind == "toggle":
		b.toggled.connect(_on_toggled.bind(b))
	elif deco.kind == "cycle":
		if b.has_signal("value_changed"):
			b.connect("value_changed", _on_cycle.bind(b).unbind(1))
		if b is OptionButton:
			(b as OptionButton).item_selected.connect(_on_cycle.bind(b).unbind(1))
	else:
		b.pressed.connect(_on_pressed.bind(b))


func _kind_of(c: Control) -> String:
	if c is Slider:
		return "slider"
	if c is TabBar:
		return "tab"
	if c is CheckButton or c is CheckBox:
		return "toggle"
	if c.has_signal("value_changed") or c is OptionButton:
		return "cycle"
	if c.get("locked") != null or c.theme_type_variation in [&"ChapterTile", &"LockedTile"]:
		return "tile"
	if c is Button and not (c as Button).flat and not (c.get_theme_stylebox("normal") is StyleBoxEmpty):
		return "button"
	return "plain"


func _is_disabled(c: Control) -> bool:
	return c is BaseButton and (c as BaseButton).disabled


func deco_of(c: Control) -> Control:
	var d: Variant = c.get_meta("_uifx_deco", null)
	return d if is_instance_valid(d) else null


func _on_focus(c: Control, on: bool) -> void:
	var d := deco_of(c)
	if d:
		d.set_focused(on)
	if on and d and d.kind in ["button", "tile"]:
		wobble(c, 0.55 if d.kind == "tile" else 1.0)


func _on_down(b: BaseButton) -> void:
	if not full():
		return
	b.pivot_offset = (b.size / 2.0).round()
	var t := tw(b, "wobble")
	t.tween_property(b, "scale", Vector2(1.07, 0.9), 0.06).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _on_up(b: BaseButton) -> void:
	if not full() or not is_instance_valid(b):
		return
	var t := tw(b, "wobble")
	t.tween_property(b, "scale", Vector2(0.97, 1.05), 0.07).set_trans(Tween.TRANS_SINE)
	t.tween_property(b, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _on_pressed(b: BaseButton) -> void:
	if not full() or not b.is_inside_tree():
		return
	var p := _press_point(b)
	if b.get("locked") == true:
		frost_burst(b, p, 10)
		return
	splash(b, p, 1.0)
	if b.scale == Vector2.ONE:
		_on_up(b)  # keyboard / signal presses never got a button_down


## Where a press happened, in the control's canvas-layer coordinates.
func _press_point(c: Control) -> Vector2:
	var local := c.get_local_mouse_position()
	if not _last_input_mouse or not Rect2(Vector2.ZERO, c.size).has_point(local):
		local = c.size * Vector2(0.5, 0.62)
	return c.get_global_transform() * local


func wobble(c: Control, amount := 1.0) -> void:
	if not full() or not c.is_inside_tree():
		return
	c.pivot_offset = (c.size / 2.0).round()
	var t := tw(c, "wobble")
	t.tween_property(c, "scale", Vector2(1.0 + 0.06 * amount, 1.0 - 0.07 * amount), 0.07).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(c, "scale", Vector2(1.0 - 0.025 * amount, 1.0 + 0.04 * amount), 0.09).set_trans(Tween.TRANS_SINE)
	t.tween_property(c, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _on_toggled(on: bool, b: BaseButton) -> void:
	var d := deco_of(b)
	if d == null or not full() or not b.is_visible_in_tree():
		return
	var knob: Vector2 = b.get_global_transform() * d.knob_point(on)
	b.pivot_offset = (b.size / 2.0).round()
	var t := tw(b, "wobble")
	if on:
		# Ice cube snaps into place: rigid pop + frost shards.
		frost_burst(b, knob, 9)
		b.scale = Vector2(1.18, 1.18)
		t.tween_property(b, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		# Melts into a puddle: soft squash + drips.
		drip(b, knob + Vector2(-2, 5), 3)
		ripple(b, knob + Vector2(0, 9), 9.0)
		b.scale = Vector2(1.1, 0.86)
		t.tween_property(b, "scale", Vector2.ONE, 0.34).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	d.on_toggled(on)


func _on_cycle(b: BaseButton) -> void:
	if not full() or not b.is_visible_in_tree():
		return
	b.pivot_offset = (b.size / 2.0).round()
	var t := tw(b, "wobble")
	b.scale = Vector2(1.12, 0.92)
	t.tween_property(b, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	var r := b.get_global_rect()
	var y := r.position.y + r.size.y * 0.55
	_spray(b, Vector2(r.position.x + 4, y), -1.0)
	_spray(b, Vector2(r.end.x - 4, y), 1.0)


func _spray(c: CanvasItem, p: Vector2, dir: float) -> void:
	var d := drawer_for(c)
	for i in 4:
		d.add(Particles.DROP, p, Vector2(dir * randf_range(50, 130), randf_range(-140, -60)), randf_range(0.35, 0.5), randf_range(1.6, 3.0), WATER_LIGHT, 0.8)


func _on_slider(_v: float, s: Slider) -> void:
	var d := deco_of(s)
	if d:
		d.slosh()
	if not full() or not s.is_visible_in_tree():
		return
	var now := Time.get_ticks_msec()
	if now - int(s.get_meta("_uifx_drop_t", 0)) < 70:
		return
	s.set_meta("_uifx_drop_t", now)
	var p: Vector2 = s.get_global_transform() * d.grabber_point() if d else s.get_global_rect().get_center()
	var dr := drawer_for(s)
	for i in 2:
		dr.add(Particles.DROP, p + Vector2(randf_range(-3, 3), -4), Vector2(randf_range(-60, 60), randf_range(-140, -70)), 0.4, randf_range(1.6, 2.8), WATER_LIGHT, 0.9)


func _on_tab(idx: int, bar: TabBar) -> void:
	var d := deco_of(bar)
	if d:
		d.move_underline(idx)
	if not full() or not bar.is_visible_in_tree() or idx < 0:
		return
	var r := bar.get_tab_rect(idx)
	var p := bar.get_global_transform() * Vector2(r.get_center().x, r.end.y - 2)
	ripple(bar, p, r.size.x * 0.45)
	splash(bar, p, 0.5)


func _on_tab_page(idx: int, tc: TabContainer) -> void:
	var page := tc.get_tab_control(idx)
	if page == null or motion() == OFF:
		return
	page.modulate.a = 0.0
	var t := tw(page, "page")
	t.tween_property(page, "modulate:a", 1.0, dur(0.22))
	if full():
		var r := page.get_global_rect()
		for i in 5:
			puff_at(tc, Vector2(randf_range(r.position.x, r.end.x), r.position.y + randf_range(4, 30)), Vector2(0, -12), 0.45, 4.0)


# --- Particles ----------------------------------------------------------------------

## The particle layer drawing in the same CanvasLayer as `c` (created lazily).
func drawer_for(c: CanvasItem) -> Node2D:
	var layer := c.get_canvas_layer_node() if c and c.is_inside_tree() else null
	var host: Node = layer
	if host == null:
		host = get_tree().current_scene if get_tree().current_scene else get_tree().root
	var key := host.get_instance_id()
	var d: Variant = _drawers.get(key)
	if d != null and is_instance_valid(d):
		return d
	var nd: Node2D = Particles.new()
	nd.name = "UiFxParticles"
	if layer == null:
		nd.top_level = true
	_drawers[key] = nd
	_attach.call_deferred(host, nd)
	return nd


func _attach(host: Node, d: Node2D) -> void:
	if is_instance_valid(host) and host.is_inside_tree():
		host.add_child(d, false, Node.INTERNAL_MODE_BACK)
	else:
		d.free()


## Water splash: droplets fly up and fall, plus a flat ripple ring.
func splash(c: CanvasItem, p: Vector2, strength := 1.0) -> void:
	if not full():
		return
	var d := drawer_for(c)
	var n := int(round(12 * strength)) + 3
	for i in n:
		var col := WATER if i % 3 else WATER_LIGHT
		var a := lerpf(-PI * 0.92, -PI * 0.08, (i + randf()) / n)
		var spd := randf_range(110.0, 230.0) * sqrt(strength)
		d.add(Particles.DROP, p + Vector2(randf_range(-4, 4), 0), Vector2(cos(a) * spd * 0.8, sin(a) * spd), randf_range(0.42, 0.65), randf_range(1.6, 3.4), col)
	d.add(Particles.RING, p, Vector2.ZERO, 0.45, 18.0 * strength + 6.0, WATER_LIGHT, 0.32)
	if strength >= 0.5:
		d.add(Particles.RING, p, Vector2.ZERO, 0.6, 10.0 * strength + 4.0, WATER, 0.32)


func ripple(c: CanvasItem, p: Vector2, radius := 12.0) -> void:
	if full():
		drawer_for(c).add(Particles.RING, p, Vector2.ZERO, 0.5, radius, WATER_LIGHT, 0.3)


## Ice: shards scatter and glints twinkle.
func frost_burst(c: CanvasItem, p: Vector2, n := 10) -> void:
	if not full():
		return
	var d := drawer_for(c)
	for i in n:
		var a := randf() * TAU
		d.add(Particles.SHARD, p, Vector2(cos(a), sin(a) - 0.4) * randf_range(60, 170), randf_range(0.4, 0.65), randf_range(2, 4.4), ICE if i % 3 else Color.WHITE)
	for i in 3:
		d.add(Particles.GLINT, p + Vector2(randf_range(-10, 10), randf_range(-8, 8)), Vector2.ZERO, 0.4 + i * 0.1, 4.0, Color.WHITE)


func glint(c: CanvasItem, p: Vector2, size := 3.0, life := 0.5) -> void:
	if full():
		drawer_for(c).add(Particles.GLINT, p, Vector2.ZERO, life, size, Color.WHITE)


## Puffs blown outward in a ring (steam bursting), drifting up as they slow.
func puff_ring(c: CanvasItem, p: Vector2, n := 8, speed := 80.0, size := 5.0) -> void:
	if not full():
		return
	for i in n:
		var a := TAU * (i + randf() * 0.6) / n
		puff_at(c, p + Vector2(cos(a), sin(a) * 0.7) * 6.0, Vector2(cos(a), sin(a) * 0.7 - 0.3) * speed * randf_range(0.8, 1.2), randf_range(0.6, 0.85), size * randf_range(0.8, 1.2))


## Steam puffs rising from `p`.
func puff(c: CanvasItem, p: Vector2, n := 4, spread := 10.0, size := 5.0) -> void:
	if not full():
		return
	for i in n:
		puff_at(c, p + Vector2(randf_range(-spread, spread), randf_range(-3, 3)), Vector2(randf_range(-10, 10), randf_range(-45, -22)), randf_range(0.55, 0.85), size * randf_range(0.7, 1.2))


func puff_at(c: CanvasItem, p: Vector2, vel: Vector2, life: float, size: float) -> void:
	if full():
		drawer_for(c).add(Particles.PUFF, p, vel, life, size, STEAM)


## A few droplets dripping off `p`.
func drip(c: CanvasItem, p: Vector2, n := 1) -> void:
	if not full():
		return
	var d := drawer_for(c)
	for i in n:
		d.add(Particles.DROP, p + Vector2(randf_range(-3, 3), 0), Vector2(randf_range(-8, 8), randf_range(0, 30) + i * 18.0), randf_range(0.45, 0.6), 3.0, WATER, 0.7)


## Steam puffs rising off the top of a rect (a panel evaporating).
func evaporate_rect(c: CanvasItem, r: Rect2) -> void:
	if not full() or r.size.x < 4.0:
		return
	var n := clampi(int(r.size.x / 22.0), 6, 26)
	for i in n:
		var x := lerpf(r.position.x + 8, r.end.x - 8, (i + randf()) / n)
		var y := r.position.y + randf_range(0, r.size.y * 0.7)
		puff_at(c, Vector2(x, y), Vector2(randf_range(-8, 8), randf_range(-70, -35)), randf_range(0.5, 0.75), randf_range(5, 8))


## Steam wisps converging on a rect (a panel condensing).
func condense_rect(c: CanvasItem, r: Rect2) -> void:
	if not full() or r.size.x < 4.0:
		return
	var ctr := r.get_center()
	var n := clampi(int(r.size.x / 30.0), 6, 18)
	for i in n:
		var a := TAU * (i + randf() * 0.5) / n
		var p := ctr + Vector2(cos(a) * r.size.x * 0.55, sin(a) * r.size.y * 0.58)
		puff_at(c, p, (ctr - p) * 0.9, 0.34, randf_range(4, 7))


# --- Screens ----------------------------------------------------------------------

## Animates `root` whenever it is shown (condenses out of steam) or hidden (evaporates).
## `inner` is the visible box (default: first PanelContainer below root, else root).
func register_panel(root: Control, inner: Control = null) -> void:
	if root.has_meta("_uifx_panel"):
		return
	root.set_meta("_uifx_panel", true)
	root.visibility_changed.connect(func() -> void:
		if not is_instance_valid(root):
			return
		if root.visible:
			panel_in(root, inner)
		elif root.get_meta("_uifx_open", false):
			root.set_meta("_uifx_open", false)
			var box := inner if inner else _inner_of(root)
			if box and box.visible and box.is_inside_tree():
				evaporate_rect(box, box.get_global_rect()))


func _inner_of(root: Control) -> Control:
	if root is PanelContainer:
		return root
	var found := root.find_children("*", "PanelContainer", true, false)
	return found[0] if not found.is_empty() else root


func panel_in(root: Control, inner: Control = null) -> void:
	root.set_meta("_uifx_open", true)
	var m := motion()
	if m == OFF:
		root.modulate.a = 1.0
		return
	var box := inner if inner else _inner_of(root)
	root.modulate.a = 0.0
	var t := tw(root, "panel")
	t.tween_property(root, "modulate:a", 1.0, dur(0.2)).set_trans(Tween.TRANS_SINE)
	if m != FULL or box == null:
		return
	# Wait a frame so containers have sorted and sizes are real.
	await get_tree().process_frame
	if not is_instance_valid(box) or not box.is_visible_in_tree():
		return
	box.pivot_offset = (box.size / 2.0).round()
	box.scale = Vector2(1.06, 1.1)
	var tb := tw(box, "panel_box")
	tb.tween_property(box, "scale", Vector2(0.985, 0.98), 0.17).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tb.tween_property(box, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	condense_rect(box, box.get_global_rect())


## Children rise in one after another (menu buttons, tiles, stat rows).
func stagger_in(items: Array, step := 0.04, rise := 12.0, delay := 0.0) -> void:
	var m := motion()
	var list: Array[Control] = []
	for it in items:
		var c := it as Control
		if c != null and c.visible:
			c.modulate.a = 1.0 if m == OFF else 0.0
			list.append(c)
	if m == OFF:
		return
	# Let containers sort first so the resting positions are final.
	await get_tree().process_frame
	var i := 0
	for c in list:
		if not is_instance_valid(c):
			continue
		var t := tw(c, "stagger")
		t.tween_interval(delay + i * step * (1.0 if m == FULL else 0.4))
		t.tween_property(c, "modulate:a", 1.0, dur(0.18))
		if m == FULL:
			var base_y := c.position.y
			c.position.y = base_y + rise
			t.parallel().tween_property(c, "position:y", base_y, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		i += 1


## Letters drip in one by one: fall stretched like droplets, squash on landing, then settle.
func drip_text(label: Label, delay := 0.0, per_char := 0.045, splashes := true) -> void:
	for c in label.get_children(true):
		if c.get_script() == DripText:
			c.finish()
	if motion() != FULL or label.text.is_empty():
		label.self_modulate.a = 1.0
		return
	var dt: Control = DripText.new()
	dt.label = label
	dt.delay = delay
	dt.per_char = per_char
	dt.splashes = splashes
	label.add_child(dt, false, Node.INTERNAL_MODE_BACK)


## Title / results card intro: mist band condenses, water lines run out from the middle.
func card_in(card: Control, delay := 0.0) -> void:
	if motion() != FULL:
		return
	var band := card.get_node_or_null("Band") as Control
	if band:
		band.pivot_offset = (band.size / 2.0).round()
		band.scale = Vector2(1.0, 0.25)
		tw(band, "card").tween_property(band, "scale", Vector2.ONE, 0.4).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var i := 0
	for n in ["LineTop", "LineBottom"]:
		var l := card.get_node_or_null(n) as Control
		if l:
			l.pivot_offset = (l.size / 2.0).round()
			l.scale = Vector2(0.0, 1.0)
			tw(l, "card").tween_property(l, "scale", Vector2.ONE, 0.45).set_delay(delay + 0.08 + i * 0.06).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		i += 1


## Puffs off the card's text box as it fades out.
func card_out(card: Control) -> void:
	var box := card.get_node_or_null("Box") as Control
	if box and card.visible:
		var r := box.get_global_rect()
		evaporate_rect(card, Rect2(r.position + Vector2(r.size.x * 0.25, 10), Vector2(r.size.x * 0.5, r.size.y - 20)))


## Typewriter reveal for secondary lines.
func type_in(label: Label, delay := 0.0, cps := 60.0) -> void:
	if motion() == OFF or label.text.is_empty():
		label.visible_ratio = 1.0
		return
	label.visible_ratio = 0.0
	var t := tw(label, "type")
	t.tween_interval(delay)
	t.tween_property(label, "visible_ratio", 1.0, label.text.length() / cps)
