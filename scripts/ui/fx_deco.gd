extends Control
## Per-control decoration added by the UiFx autoload (internal child, ignores the mouse).
##   button / tile : focus = glossy meniscus sweep + water beads forming on the bottom edge
##                   that drip off; disabled / locked = frozen ice crust (cracks when thawed)
##   toggle / cycle / slider / tab / plain : focus = frost creeping in from the corners
##   slider        : the filled track is water with a moving wavy surface that sloshes on change
##   tab           : a liquid underline that flows (stretches) between tabs

const WATER := Color(0.36, 0.66, 1.0)
const WATER_LIGHT := Color(0.72, 0.89, 1.0)
const ICE := Color(0.8, 0.95, 1.0)

var target: Control
var kind := "button"

var _focused := false
var _focus_t := 0.0
var _shine := -1.0
var _time := 0.0
var _beads: Array = []  # [x, grow 0..1, rate]
var _bead_wait := 0.4
var _ice := 0.0
var _ice_glint := 2.0
var _slosh := 0.0
var _ul := Vector2(-1, -1)  # tab underline left / right x
var _ul_target := Vector2(-1, -1)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ice = 1.0 if _frozen() else 0.0
	if kind == "tab":
		move_underline((target as TabBar).current_tab)
		_ul = _ul_target


func _fx() -> Node:
	return get_node_or_null("/root/UiFx")


func set_focused(on: bool) -> void:
	_focused = on
	if on and kind in ["button", "tile"]:
		var fx := _fx()
		if fx and fx.full():
			_shine = 0.0
			_bead_wait = randf_range(0.25, 0.5)


func on_toggled(_on: bool) -> void:
	queue_redraw()


func slosh() -> void:
	_slosh = minf(_slosh + 0.6, 1.6)


## Centre of the toggle knob (local coords) for the given state.
func knob_point(on: bool) -> Vector2:
	var r := _icon_rect()
	var k := r.size.x / 40.0
	return Vector2(r.position.x + (r.size.x - 10.0 * k if on else 10.0 * k), r.get_center().y)


func _icon_rect() -> Rect2:
	var tex: Texture2D = target.get_theme_icon("checked") if target is CheckButton else target.get_theme_icon("checked", "CheckBox")
	var ts := tex.get_size() if tex else Vector2(16, 16)
	if target is CheckButton:
		var sb := target.get_theme_stylebox("normal")
		var right := sb.get_margin(SIDE_RIGHT) if sb else 0.0
		return Rect2(Vector2(size.x - right - ts.x, (size.y - ts.y) / 2.0).round(), ts)
	return Rect2(Vector2(0, (size.y - ts.y) / 2.0).round(), ts)


## Slider grabber centre (local coords).
func grabber_point() -> Vector2:
	var s := target as Range
	var ratio := 0.0 if s.max_value <= s.min_value else (s.value - s.min_value) / (s.max_value - s.min_value)
	return Vector2(roundf(ratio * size.x), roundf(size.y / 2.0))


func move_underline(idx: int) -> void:
	var bar := target as TabBar
	if idx < 0 or idx >= bar.tab_count:
		return
	var r := bar.get_tab_rect(idx)
	_ul_target = Vector2(r.position.x + 6, r.end.x - 6)
	if _ul.x < 0.0:
		_ul = _ul_target
	var fx := _fx()
	if fx and fx.motion() == 0:
		_ul = _ul_target


func _frozen() -> bool:
	if target.get("locked") == true:
		return true
	if target is BaseButton and (target as BaseButton).disabled:
		# Buttons that override "disabled" to look normal are only briefly locked (scene change).
		return not target.has_theme_stylebox_override("disabled")
	return false


func _process(delta: float) -> void:
	if not target or not target.is_visible_in_tree():
		return
	var fx := _fx()
	var full: bool = fx.full() if fx else true
	delta /= maxf(Engine.time_scale, 0.01)
	_time += delta
	var dirty := false
	# Focus ramp.
	var ft := 1.0 if _focused else 0.0
	if _focus_t != ft:
		_focus_t = move_toward(_focus_t, ft, delta / (0.22 if full else 0.08))
		dirty = true
	if _shine >= 0.0:
		_shine += delta / 0.5
		if _shine > 1.0:
			_shine = -1.0
		dirty = true
	# Ice crust (disabled / locked).
	var it := 1.0 if _frozen() else 0.0
	if _ice != it:
		if it == 0.0 and _ice > 0.9 and fx and full:
			var r := get_global_rect()
			fx.frost_burst(self, r.get_center(), 14)
			fx.glint(self, r.position + Vector2(r.size.x * 0.3, 8), 4.0)
		_ice = move_toward(_ice, it, delta / (0.35 if it > 0.0 else 0.15))
		dirty = true
	if _ice > 0.5 and full and kind == "tile":
		_ice_glint -= delta
		if _ice_glint <= 0.0:
			_ice_glint = randf_range(1.8, 4.0)
			var r := get_global_rect()
			fx.glint(self, r.position + Vector2(randf_range(10, r.size.x - 10), randf_range(6, r.size.y - 8)).round(), 2.0, 0.6)
	# Water beads on focused buttons.
	if kind in ["button", "tile"]:
		dirty = _update_beads(delta, full, fx) or dirty
	if kind == "slider":
		_slosh = move_toward(_slosh, 0.0, delta * 1.4)
		dirty = true
	if kind == "tab" and _ul != _ul_target:
		var lead := 22.0 * delta
		var trail := 9.0 * delta
		var right := _ul_target.y > _ul.y
		_ul.x = lerpf(_ul.x, _ul_target.x, trail if right else lead)
		_ul.y = lerpf(_ul.y, _ul_target.y, lead if right else trail)
		if _ul.distance_to(_ul_target) < 0.5:
			_ul = _ul_target
		dirty = true
	if dirty:
		queue_redraw()


func _update_beads(delta: float, full: bool, fx: Node) -> bool:
	if _beads.is_empty() and not (_focused and full and _ice < 0.5):
		return false
	if _focused and full and _ice < 0.5:
		_bead_wait -= delta
		if _bead_wait <= 0.0 and _beads.size() < 2 and size.x > 40.0:
			_bead_wait = randf_range(0.5, 1.2)
			_beads.append([roundf(randf_range(18.0, size.x - 18.0)), 0.0, randf_range(1.1, 1.7)])
	for i in range(_beads.size() - 1, -1, -1):
		var b: Array = _beads[i]
		if _focused:
			b[1] += delta * b[2]
			if b[1] >= 1.0:
				if fx:
					fx.drip(self, get_global_transform() * Vector2(b[0] + 1.0, size.y + 2.0), 1)
				_beads.remove_at(i)
		else:
			b[1] -= delta * 4.0
			if b[1] <= 0.0:
				_beads.remove_at(i)
	return true


func _draw() -> void:
	if not target:
		return
	match kind:
		"button", "tile":
			_draw_button()
		"slider":
			_draw_slider()
			_draw_frost_corners(Rect2(Vector2(-4, -3), size + Vector2(8, 6)))
		"tab":
			_draw_underline()
		"toggle":
			_draw_frost_corners(_icon_rect().grow(4))
		_:
			_draw_frost_corners(Rect2(Vector2(-3, -2), size + Vector2(6, 4)))
	if _ice > 0.0:
		_draw_ice()


func _draw_button() -> void:
	var w := size.x
	var top := 5.0 if kind == "button" else 6.0
	# Glossy sweep across the upper half (the "meniscus" catching light).
	if _shine >= 0.0:
		var x0 := lerpf(-16.0, w + 16.0, _shine)
		var rows := int(size.y * 0.42)
		for y in range(int(top), rows):
			var x := roundf(x0 - (y - top) * 0.7)
			var a := 0.0
			for seg: Vector3 in [Vector3(0.0, 3.0, 0.32), Vector3(5.0, 1.0, 0.2)]:
				var sx: float = x + seg.x
				var ex: float = minf(sx + seg.y, w - 12.0)
				sx = maxf(sx, 12.0)
				if ex > sx:
					draw_rect(Rect2(sx, y, ex - sx, 1), Color(1, 1, 1, seg.z))
	# Rippling meniscus line along the top inner edge while focused.
	if _focus_t > 0.0:
		var c := Color(WATER_LIGHT, 0.45 * _focus_t)
		var y0 := top - 1.0
		var x := 14.0
		while x < w - 14.0:
			var up := 1.0 if sin(x * 0.21 - _time * 6.0) > 0.55 else 0.0
			draw_rect(Rect2(x, y0 + 1.0 - up, 2, 1), c)
			x += 2.0
	# Beads of water forming on the bottom edge: a neck that swells into a round drop.
	var by := size.y - (6.0 if kind == "button" else 5.0)
	for b in _beads:
		var g: float = clampf(b[1], 0.0, 1.0)
		if g <= 0.05:
			continue
		var bx: float = b[0]
		var neck := roundf(g * 4.0)
		var bulb := 1.0 + roundf(g * 2.0)
		draw_rect(Rect2(bx, by, 2, neck + 1.0), WATER)
		var cy := by + neck + 1.0
		draw_rect(Rect2(bx - bulb + 1.0, cy, bulb * 2.0, bulb), WATER)
		draw_rect(Rect2(bx - bulb + 2.0, cy + bulb, maxf(bulb * 2.0 - 2.0, 1.0), 1), WATER)
		draw_rect(Rect2(bx - bulb + 1.0, cy, 1, 1), Color(1, 1, 1, 0.85))


func _draw_frost_corners(r: Rect2) -> void:
	if _focus_t <= 0.0:
		return
	r = Rect2(r.position.round(), r.size.round())
	var arm := roundf(_focus_t * 7.0)
	var c := Color(ICE, 0.9 * _focus_t)
	var nub := Color(ICE, 0.55 * _focus_t)
	var corners := [
		[r.position, Vector2(1, 1)],
		[Vector2(r.end.x - 1, r.position.y), Vector2(-1, 1)],
		[Vector2(r.position.x, r.end.y - 1), Vector2(1, -1)],
		[r.end - Vector2.ONE, Vector2(-1, -1)],
	]
	for cr in corners:
		var p: Vector2 = cr[0]
		var d: Vector2 = cr[1]
		for i in int(arm):
			draw_rect(Rect2(p + Vector2(d.x * i, 0), Vector2.ONE), c)
			draw_rect(Rect2(p + Vector2(0, d.y * i), Vector2.ONE), c)
			# Crystal nubs growing outward every few pixels.
			if i in [2, 5]:
				draw_rect(Rect2(p + Vector2(d.x * i, -d.y), Vector2.ONE), nub)
				draw_rect(Rect2(p + Vector2(-d.x, d.y * i), Vector2.ONE), nub)
			if i == 3:
				draw_rect(Rect2(p + Vector2(d.x * (i + 1), d.y), Vector2.ONE), nub)
				draw_rect(Rect2(p + Vector2(d.x, d.y * (i + 1)), Vector2.ONE), nub)
		draw_rect(Rect2(p, Vector2.ONE), Color(1, 1, 1, _focus_t))


func _draw_slider() -> void:
	var gp := grabber_point()
	var fill_end := gp.x - 7.0
	if fill_end <= 6.0:
		return
	var cy := gp.y
	# Moving wave crest on the water surface (top inner row of the fill).
	var amp := 0.6 + _slosh
	var x := 4.0
	while x < fill_end:
		var s := sin(x * 0.32 - _time * 5.0) + 0.5 * sin(x * 0.11 + _time * 2.3)
		var off := roundf(s * amp * 0.6)
		var a := 0.55 if s > 0.4 else 0.22
		draw_rect(Rect2(x, cy - 3.0 - maxf(off, 0.0), 2, 1), Color(WATER_LIGHT, a))
		x += 2.0
	# Tiny bubbles rising through the water.
	for i in 3:
		var bx := fmod(i * 61.7 + _time * (9.0 + i * 3.0), maxf(fill_end - 8.0, 1.0)) + 4.0
		var by := cy + 3.0 - fmod(_time * (5.0 + i * 2.0) + i * 2.3, 6.0)
		if bx < fill_end - 2.0:
			draw_rect(Rect2(roundf(bx), roundf(by), 1, 1), Color(1, 1, 1, 0.55))


func _draw_underline() -> void:
	if _ul.x < 0.0 or _ul.y <= _ul.x:
		return
	var bar := target as TabBar
	var y := size.y - 3.0
	var l := roundf(_ul.x)
	var r := roundf(_ul.y)
	draw_rect(Rect2(l, y, r - l, 2), WATER)
	draw_rect(Rect2(l + 1, y, r - l - 2, 1), WATER_LIGHT)
	# Little wave crest travelling along the line.
	var cx := l + fmod(_time * 30.0, maxf(r - l, 1.0))
	draw_rect(Rect2(roundf(cx), y - 1, 2, 1), Color(1, 1, 1, 0.6))
	if bar.tab_count <= 0:
		return


func _draw_ice() -> void:
	var inset := 4.0 if kind in ["button", "tile"] else 1.0
	var r := Rect2(Vector2(inset, inset), size - Vector2(inset, inset) * 2.0)
	if kind == "toggle":
		r = _icon_rect().grow(-2)
	if r.size.x <= 6.0 or r.size.y <= 6.0:
		return
	r = Rect2(r.position.round(), r.size.round())
	var a := _ice
	# Frozen tint, a little stronger toward the top.
	draw_rect(r, Color(ICE, 0.06 * a))
	draw_rect(Rect2(r.position, Vector2(r.size.x, roundf(r.size.y * 0.35))), Color(ICE, 0.05 * a))
	# Rim of frost just inside the edge.
	var rim := Color(ICE, 0.35 * a)
	draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), Color(ICE, 0.55 * a))
	draw_rect(Rect2(r.position + Vector2(0, 1), Vector2(1, r.size.y - 2)), rim)
	draw_rect(Rect2(Vector2(r.end.x - 1, r.position.y + 1), Vector2(1, r.size.y - 2)), rim)
	# Icicles of uneven length hanging off the top rim (deterministic per control size).
	var c := Color(ICE, 0.6 * a)
	var x := r.position.x + 3.0
	var i := 0
	while x < r.end.x - 3.0:
		var h := float([2, 0, 4, 1, 3, 0, 1, 5, 2, 0][(i + int(r.size.x)) % 10])
		if h > 0.0:
			draw_rect(Rect2(x, r.position.y + 1.0, 1, h), c)
			draw_rect(Rect2(x, r.position.y + h, 1, 1), Color(1, 1, 1, 0.5 * a))
		x += 4.0 if i % 3 else 5.0
		i += 1
	# Frost clusters in the bottom corners.
	for sx in [r.position.x + 1.0, r.end.x - 4.0]:
		draw_rect(Rect2(sx, r.end.y - 2.0, 3, 1), rim)
		draw_rect(Rect2(sx + 1.0, r.end.y - 3.0, 1, 1), rim)
	# Diagonal sheen streaks (glassy ice surface).
	var sh := Color(1, 1, 1, 0.2 * a)
	for k in 2:
		var sx := r.position.x + 10.0 + k * 6.0
		var n := 9 - k * 4
		for j in n:
			draw_rect(Rect2(sx + j, r.position.y + 4.0 + n - j, 1, 1), sh)
