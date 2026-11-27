extends Control
## Temporary overlay (added by UiFx.drip_text) that draws a single-line Label letter by
## letter: each glyph falls stretched like a droplet, squashes on landing, tints from water
## blue to its real colour, then the real Label takes over again.

const FALL := 0.2
const LAND := 0.22
const DROP_H := 16.0
const WATER := Color(0.45, 0.75, 1.0)

var label: Label
var delay := 0.0
var per_char := 0.045
var splashes := true

var _t := 0.0
var _xs: PackedFloat32Array = []
var _ws: PackedFloat32Array = []
var _landed: PackedByteArray = []
var _font: Font
var _fs := 16
var _origin := Vector2.ZERO
var _total := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.self_modulate.a = 0.0
	_layout.call_deferred()


func _layout() -> void:
	if not is_instance_valid(label):
		return
	_font = label.get_theme_font("font")
	_fs = label.get_theme_font_size("font_size")
	var text := label.text
	var total := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, _fs).x
	_xs.resize(text.length())
	_ws.resize(text.length())
	_landed.resize(text.length())
	_landed.fill(0)
	for i in text.length():
		_xs[i] = _font.get_string_size(text.substr(0, i), HORIZONTAL_ALIGNMENT_LEFT, -1, _fs).x
		_ws[i] = _font.get_string_size(text.substr(i, 1), HORIZONTAL_ALIGNMENT_LEFT, -1, _fs).x
	_total = total
	_update_origin()


## Recomputed every frame: the label may still be resized by its container (cards that
## were hidden have stale sizes on the first frame).
func _update_origin() -> void:
	var x0 := 0.0
	match label.horizontal_alignment:
		HORIZONTAL_ALIGNMENT_CENTER: x0 = (label.size.x - _total) / 2.0
		HORIZONTAL_ALIGNMENT_RIGHT: x0 = label.size.x - _total
	var line_h := _font.get_height(_fs)
	var y0 := 0.0
	match label.vertical_alignment:
		VERTICAL_ALIGNMENT_CENTER: y0 = (label.size.y - line_h) / 2.0
		VERTICAL_ALIGNMENT_BOTTOM: y0 = label.size.y - line_h
	_origin = Vector2(roundf(x0), roundf(y0 + _font.get_ascent(_fs)))


func finish() -> void:
	if is_instance_valid(label):
		label.self_modulate.a = 1.0
	queue_free()


func _process(delta: float) -> void:
	if not is_instance_valid(label) or _font == null:
		return
	_t += delta / maxf(Engine.time_scale, 0.01)
	_update_origin()
	var n := _xs.size()
	var fx := get_node_or_null("/root/UiFx")
	for i in n:
		if _landed[i] == 0 and _t - delay - i * per_char >= FALL:
			_landed[i] = 1
			if splashes and fx and label.text[i] != " " and i % 2 == 0:
				var p := label.get_global_transform() * (_origin + Vector2(_xs[i] + _ws[i] / 2.0, 0))
				fx.splash(label, p, 0.25)
	if _t >= delay + n * per_char + FALL + LAND:
		finish()
		return
	queue_redraw()


func _draw() -> void:
	if _font == null:
		return
	var text := label.text
	var col := label.get_theme_color("font_color")
	var ocol := label.get_theme_color("font_outline_color")
	var osize := label.get_theme_constant("outline_size")
	var scol := label.get_theme_color("font_shadow_color")
	var soff := Vector2(label.get_theme_constant("shadow_offset_x"), label.get_theme_constant("shadow_offset_y"))
	for i in _xs.size():
		var ch := text[i]
		if ch == " ":
			continue
		var t := _t - delay - i * per_char
		if t <= 0.0:
			continue
		var y := 0.0
		var sc := Vector2.ONE
		var tint := 1.0
		var a := 1.0
		if t < FALL:
			var k := t / FALL
			y = -DROP_H * (1.0 - k * k)
			sc = Vector2(0.8, 1.25)
			tint = 0.0
			a = clampf(k * 3.0, 0.0, 1.0)
		elif t < FALL + LAND:
			var u := (t - FALL) / LAND
			var s := sin(u * PI) * (1.0 - u * 0.4)
			sc = Vector2(1.0 + 0.28 * s, 1.0 - 0.24 * s)
			tint = u
		var c := WATER.lerp(col, tint)
		c.a *= a
		var w := _ws[i]
		var base := (_origin + Vector2(_xs[i] + w / 2.0, y)).round()
		draw_set_transform(base, 0.0, sc)
		var p := Vector2(-w / 2.0, 0)
		if scol.a > 0.0:
			draw_string(_font, p + soff, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, _fs, Color(scol, scol.a * a))
		if osize > 0 and ocol.a > 0.0:
			draw_string_outline(_font, p, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, _fs, osize, Color(ocol, ocol.a * a))
		draw_string(_font, p, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, _fs, c)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
