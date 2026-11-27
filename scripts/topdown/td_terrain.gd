@tool
class_name TdTerrain
extends Node2D
## Top-down room terrain, painted from text `rows` (one character per 32 px cell,
## origin = top-left of cell (0, 0)). Edit the rows in the inspector; it redraws live.
##   #  wall: raised block (top face + south face + cast shadow), blocks everything
##   .  floor            ,  floor (grimy / alternate tile)
##   o  pit (open hatch): ICE and WATER fall in, STEAM floats over
##   ~  sewage channel: like a pit (ICE sinks, WATER is washed away), STEAM floats over
##   ^  floor spikes: kill WATER; ICE slides over them, STEAM floats over
## Gates, plates, drains, bars, zones and decor are their own nodes on top.

const CELL := 32
## Height (px) of the south-facing wall strip that gives walls their depth (t12 art).
const FACE := 16
const WALL := "#"
const PIT := "o"
const SEWAGE := "~"
const SPIKES := "^"
## Share (%) of floor cells that get a detail tile (crack / stain / bolts / vent).
const DETAIL_PCT := 11

const TEX_FLOOR_PLAIN := {
	"lab": [
		preload("res://assets/topdown/tex/t10_floor_plain_1_lab.png"),
		preload("res://assets/topdown/tex/t10_floor_plain_2_lab.png"),
		preload("res://assets/topdown/tex/t10_floor_plain_3_lab.png"),
		preload("res://assets/topdown/tex/t10_floor_plain_4_lab.png"),
	],
	"sewer": [
		preload("res://assets/topdown/tex/t10_floor_plain_1_sewer.png"),
		preload("res://assets/topdown/tex/t10_floor_plain_2_sewer.png"),
		preload("res://assets/topdown/tex/t10_floor_plain_3_sewer.png"),
		preload("res://assets/topdown/tex/t10_floor_plain_4_sewer.png"),
	],
}
const TEX_FLOOR_DETAIL := {
	"lab": [
		preload("res://assets/topdown/tex/t10_floor_detail_1_lab.png"),
		preload("res://assets/topdown/tex/t10_floor_detail_2_lab.png"),
		preload("res://assets/topdown/tex/t10_floor_detail_3_lab.png"),
		preload("res://assets/topdown/tex/t10_floor_detail_4_lab.png"),
	],
	"sewer": [
		preload("res://assets/topdown/tex/t10_floor_detail_1_sewer.png"),
		preload("res://assets/topdown/tex/t10_floor_detail_2_sewer.png"),
		preload("res://assets/topdown/tex/t10_floor_detail_3_sewer.png"),
		preload("res://assets/topdown/tex/t10_floor_detail_4_sewer.png"),
	],
}
## 96x96 9-slices (32 px cells), autotiled per quadrant.
const TEX_WALL_TOP := {
	"lab": preload("res://assets/topdown/tex/t11_wall_top_9s32_lab.png"),
	"sewer": preload("res://assets/topdown/tex/t11_wall_top_9s32_sewer.png"),
}
const TEX_PIT := {
	"lab": preload("res://assets/topdown/tex/t13_pit_9s32_lab.png"),
	"sewer": preload("res://assets/topdown/tex/t13_pit_9s32_sewer.png"),
}
## 32x16 south faces; a / b alternate along a wall run.
const TEX_WALL_FRONT := {
	"lab": [
		preload("res://assets/topdown/tex/t12_wall_front_a_lab.png"),
		preload("res://assets/topdown/tex/t12_wall_front_b_lab.png"),
	],
	"sewer": [
		preload("res://assets/topdown/tex/t12_wall_front_a_sewer.png"),
		preload("res://assets/topdown/tex/t12_wall_front_b_sewer.png"),
	],
}
## 8 x 32x32 frames scrolling toward +x; rotated / reversed to match `flow`.
const TEX_SEWAGE := preload("res://assets/topdown/tex/t14_sewage_8f_sewer.png")
const SEWAGE_FPS := 8.0
const TEX_SPIKES := preload("res://assets/topdown/td_spikes.png")

## Per-theme palette for the procedural touches (face ends, motes, foam, bubbles).
const PAL := {
	"lab": {
		"rim": Color("8fb0d2"), "rim_dark": Color("1a2330"), "liquid_hi": Color("5fc2d8"),
		"liquid_deep": Color("0d2f3d"),
	},
	"sewer": {
		"rim": Color("8fb3a0"), "rim_dark": Color("141c19"), "liquid_hi": Color("a8d89a"),
		"liquid_deep": Color("0f3126"),
	},
}

@export var rows: PackedStringArray = PackedStringArray(["##########", "#........#", "##########"]):
	set(v):
		rows = v
		_dirty = true
		queue_redraw()
## Direction the sewage flows (animation only).
@export var flow := Vector2(1, 0)

var _theme := "lab"
var _dirty := true
var _body: StaticBody2D
var _liquid: Node2D
var _t := 0.0


func _ready() -> void:
	_theme = _find_theme()
	_liquid = Node2D.new()
	_liquid.name = "Liquid"
	add_child(_liquid, false, Node.INTERNAL_MODE_FRONT)
	_liquid.draw.connect(_draw_liquid)
	_build_collision()


func _find_theme() -> String:
	var t := EnvTheme.find_theme(self)
	return t if TEX_FLOOR_PLAIN.has(t) else "lab"


func _process(delta: float) -> void:
	_t += delta
	if Engine.is_editor_hint():
		var t := _find_theme()
		if t != _theme:
			_theme = t
			queue_redraw()
		if _dirty:
			_build_collision()
	if _liquid:
		_liquid.queue_redraw()


# --- Queries --------------------------------------------------------------------------

func width() -> int:
	var w := 0
	for r in rows:
		w = maxi(w, r.length())
	return w


func height() -> int:
	return rows.size()


func char_at_cell(c: Vector2i) -> String:
	if c.y < 0 or c.y >= rows.size():
		return WALL
	var r := rows[c.y]
	if c.x < 0 or c.x >= r.length():
		return WALL
	return r[c.x]


func cell_of(global_point: Vector2) -> Vector2i:
	var p := to_local(global_point)
	return Vector2i(floori(p.x / CELL), floori(p.y / CELL))


func char_at(global_point: Vector2) -> String:
	return char_at_cell(cell_of(global_point))


## Global centre of the cell containing `global_point`.
func cell_center(global_point: Vector2) -> Vector2:
	var c := cell_of(global_point)
	return to_global(Vector2(c) * CELL + Vector2(CELL, CELL) * 0.5)


func is_hole(ch: String) -> bool:
	return ch == PIT or ch == SEWAGE


func bounds() -> Rect2:
	return Rect2(global_position, Vector2(width(), height()) * CELL)


func _is_wall(x: int, y: int) -> bool:
	return char_at_cell(Vector2i(x, y)) == WALL


# --- Collision ----------------------------------------------------------------------

## One static body; one rectangle per horizontal run of wall cells (layer 1 like Blocks).
func _build_collision() -> void:
	_dirty = false
	if _body:
		_body.queue_free()
		_body = null
	_body = StaticBody2D.new()
	_body.name = "Solid"
	_body.collision_layer = 1
	_body.collision_mask = 0
	add_child(_body, false, Node.INTERNAL_MODE_FRONT)
	for y in rows.size():
		var r := rows[y]
		var x := 0
		while x < r.length():
			if r[x] != WALL:
				x += 1
				continue
			var x0 := x
			while x < r.length() and r[x] == WALL:
				x += 1
			var cs := CollisionShape2D.new()
			var sh := RectangleShape2D.new()
			sh.size = Vector2((x - x0) * CELL, CELL)
			cs.shape = sh
			cs.position = Vector2(x0 * CELL + sh.size.x * 0.5, y * CELL + CELL * 0.5)
			_body.add_child(cs)


# --- Drawing ----------------------------------------------------------------------------

func _hash(x: int, y: int) -> int:
	var h := (x * 73856093) ^ (y * 19349663) ^ 0x5bd1e995
	h = (h ^ (h >> 13)) * 1274126177
	return absi(h ^ (h >> 16))


func _draw() -> void:
	var h := height()
	var w := width()
	var plain: Array = TEX_FLOOR_PLAIN[_theme]
	var detail: Array = TEX_FLOOR_DETAIL[_theme]
	# 1) floor: plain tiles with a deterministic sprinkle of detail tiles (`,` = always grimy)
	for y in h:
		for x in w:
			var ch := char_at_cell(Vector2i(x, y))
			if ch == WALL or is_hole(ch):
				continue
			var hv := _hash(x, y)
			var p := Vector2(x, y) * CELL
			var tex: Texture2D
			if ch == ",":
				tex = detail[1]
			elif hv % 100 < DETAIL_PCT:
				tex = detail[(hv >> 8) % detail.size()]
			else:
				tex = plain[(hv >> 4) % plain.size()]
			draw_texture(tex, p)
			if ch == SPIKES:
				draw_texture(TEX_SPIKES, p)
	# 2) pits: 9-slice autotile (sewage beds are drawn animated on the Liquid child)
	var pit_tex: Texture2D = TEX_PIT[_theme]
	for y in h:
		for x in w:
			if char_at_cell(Vector2i(x, y)) == PIT:
				_autotile(pit_tex, x, y, Rect2(Vector2(x, y) * CELL, Vector2(CELL, CELL)), _is_hole_xy)
	# 3) shadows cast by walls on the floor (south and east of walls)
	for y in h:
		for x in w:
			if _is_wall(x, y) or char_at_cell(Vector2i(x, y)) == SEWAGE:
				continue
			_draw_cast_shadow(self, x, y)
	# 4) walls: 9-slice top face, south face strip under south-facing walls
	var top_tex: Texture2D = TEX_WALL_TOP[_theme]
	var fronts: Array = TEX_WALL_FRONT[_theme]
	var pal: Dictionary = PAL[_theme]
	for y in h:
		for x in w:
			if not _is_wall(x, y):
				continue
			var p := Vector2(x, y) * CELL
			var south_open := not _is_wall(x, y + 1) and y + 1 < h
			var top_h := CELL - (FACE if south_open else 0)
			_autotile(top_tex, x, y, Rect2(p, Vector2(CELL, top_h)), _is_wall)
			if south_open:
				var fp := Vector2(p.x, p.y + top_h)
				draw_texture(fronts[x % fronts.size()], fp)
				# face ends darken next to open sides
				if not _is_wall(x - 1, y):
					draw_rect(Rect2(fp, Vector2(1, FACE)), pal.rim_dark)
				if not _is_wall(x + 1, y):
					draw_rect(Rect2(fp.x + CELL - 1, fp.y, 1, FACE), pal.rim_dark)
	if Engine.is_editor_hint():
		draw_rect(Rect2(Vector2.ZERO, Vector2(w, h) * CELL), Color(1, 1, 1, 0.15), false, 1.0)


func _is_hole_xy(x: int, y: int) -> bool:
	return is_hole(char_at_cell(Vector2i(x, y)))


## Draws cell (x, y) from a 96x96 9-slice into `dst` (a full cell, or the shortened top
## of a south-facing wall), one 16 px wide x half-height quadrant at a time: each
## quadrant picks edge / corner / centre art from its two neighbours, so 1-wide runs and
## odd shapes work. Concave (inner) corners get the two rims joined by hand.
func _autotile(tex: Texture2D, x: int, y: int, dst: Rect2, same: Callable, ci: CanvasItem = null) -> void:
	if ci == null:
		ci = self
	var qw := 16.0
	var qh := dst.size.y * 0.5
	for qy in 2:
		for qx in 2:
			var hx := x - 1 if qx == 0 else x + 1
			var vy := y - 1 if qy == 0 else y + 1
			var h_same: bool = same.call(hx, y)
			var v_same: bool = same.call(x, vy)
			var col := 1 if h_same else (0 if qx == 0 else 2)
			var row := 1 if v_same else (0 if qy == 0 else 2)
			var sx := col * 32.0 + qx * 16.0
			var sy := row * 32.0 + (0.0 if qy == 0 else 32.0 - qh)
			var d := Rect2(dst.position + Vector2(qx * qw, qy * qh), Vector2(qw, qh))
			ci.draw_texture_rect_region(tex, d, Rect2(sx, sy, qw, qh))
			if h_same and v_same and not same.call(hx, vy):
				# inner corner: run the horizontal rim into the corner, then the vertical one
				var cx := d.position.x if qx == 0 else d.end.x - 3.0
				var cy := d.position.y if qy == 0 else d.end.y - 3.0
				var ry := 0.0 if qy == 0 else 93.0
				var rx := 0.0 if qx == 0 else 93.0
				ci.draw_texture_rect_region(tex, Rect2(cx, cy, 3, 3), Rect2(40, ry, 3, 3))
				ci.draw_texture_rect_region(tex, Rect2(cx, cy, 3, 3), Rect2(rx, 40, 3, 3))


func _draw_cast_shadow(ci: CanvasItem, x: int, y: int) -> void:
	var p := Vector2(x, y) * CELL
	if _is_wall(x, y - 1):
		for i in 7:
			ci.draw_rect(Rect2(p.x, p.y + i, CELL, 1), Color(0, 0, 0.03, 0.4 * (1.0 - i / 7.0)))
	if _is_wall(x - 1, y):
		for i in 5:
			ci.draw_rect(Rect2(p.x + i, p.y, 1, CELL), Color(0, 0, 0.03, 0.28 * (1.0 - i / 5.0)))


## Animated sewage (redrawn every frame on the internal Liquid child): scrolling t14
## frames along `flow`, channel banks cut from the pit 9-slice, foam, gunk and bubbles.
func _draw_liquid() -> void:
	var pal: Dictionary = PAL[_theme]
	var pit_tex: Texture2D = TEX_PIT[_theme]
	var f := flow.normalized() if flow.length() > 0.01 else Vector2.RIGHT
	var horizontal := absf(f.x) >= absf(f.y)
	var fi := int(_t * SEWAGE_FPS) % 8
	# the frames scroll toward +x; play them backwards for -x / -y flow
	if (horizontal and f.x < 0.0) or (not horizontal and f.y < 0.0):
		fi = (8 - fi) % 8
	var src := Rect2(fi * CELL, 0, CELL, CELL)
	for y in height():
		for x in width():
			var cc := char_at_cell(Vector2i(x, y))
			if cc == PIT:
				_draw_pit_motes(x, y, pal)
				continue
			if cc != SEWAGE:
				continue
			var p := Vector2(x, y) * CELL
			if horizontal:
				_liquid.draw_texture_rect_region(TEX_SEWAGE, Rect2(p, Vector2(CELL, CELL)), src)
			else:
				# a quarter turn so the scroll runs down the screen
				_liquid.draw_set_transform(p + Vector2(CELL, 0), PI / 2.0)
				_liquid.draw_texture_rect_region(TEX_SEWAGE, Rect2(0, 0, CELL, CELL), src)
				_liquid.draw_set_transform(Vector2.ZERO)
			_draw_banks(pit_tex, x, y)
			_draw_cast_shadow(_liquid, x, y)
			var up_open := not _is_hole_xy(x, y - 1)
			var top := 12.0 if up_open else 0.0
			# foam along the far bank
			if up_open:
				for i in 5:
					var fx := fmod(float(_hash(x, y + i) % 32) + _t * 9.0 * (1 if i % 2 else -1), CELL)
					if fx < 0.0:
						fx += CELL
					_liquid.draw_rect(Rect2((p + Vector2(fx, top + (i % 2))).floor(), Vector2(2, 1)), Color(pal.liquid_hi, 0.6))
			# drifting gunk
			if _hash(x, y) % 7 == 0:
				var gx := fmod(float(_hash(y, x) % 32) + _t * 14.0 * f.x, CELL)
				var gy := fmod(float(_hash(x + 3, y) % 16) + _t * 14.0 * f.y, CELL - top - 4.0)
				if gx < 0.0:
					gx += CELL
				if gy < 0.0:
					gy += CELL - top - 4.0
				_liquid.draw_rect(Rect2((p + Vector2(minf(gx, CELL - 3.0), top + 2.0 + gy)).floor(), Vector2(3, 2)), pal.liquid_deep.lightened(0.1))
			# a bubble swells and pops now and then
			var hb := _hash(x * 5 + 1, y * 11 + 2)
			var period := 2.2 + float(hb % 17) * 0.1
			var bu := fmod(_t + float(hb % 100) * 0.031, period) / period
			var bc := p + Vector2(6 + hb % 20, top + 4.0 + float((hb >> 5) % maxi(int(CELL - top - 8.0), 1))).floor()
			if bu < 0.7:
				var br := 1.0 + bu / 0.7 * 2.0
				_liquid.draw_rect(Rect2(bc - Vector2(br, br * 0.7).floor(), Vector2(br * 2.0, br * 1.4).floor()), Color(pal.liquid_hi, 0.35))
				_liquid.draw_rect(Rect2(bc - Vector2(br - 1.0, br * 0.7).floor(), Vector2(1, 1)), Color(1, 1, 1, 0.5))
			elif bu < 0.85:
				var pr := 3.0 + (bu - 0.7) / 0.15 * 4.0
				_liquid.draw_arc(bc, pr, 0.0, TAU, 10, Color(pal.liquid_hi, 0.5 * (1.0 - (bu - 0.7) / 0.15)), 1.0)


## Sewage channel banks: the pit 9-slice's edge bands where the channel meets floor.
func _draw_banks(tex: Texture2D, x: int, y: int) -> void:
	var p := Vector2(x, y) * CELL
	var n := not _is_hole_xy(x, y - 1)
	var s := not _is_hole_xy(x, y + 1)
	var wv := not _is_hole_xy(x - 1, y)
	var e := not _is_hole_xy(x + 1, y)
	if n:
		# far bank: rim + inner wall (top 12 px of the top-edge art; corners at open sides)
		var c0 := 0.0 if wv else 32.0
		var c1 := 80.0 if e else 48.0
		_liquid.draw_texture_rect_region(tex, Rect2(p, Vector2(16, 12)), Rect2(c0, 0, 16, 12))
		_liquid.draw_texture_rect_region(tex, Rect2(p + Vector2(16, 0), Vector2(16, 12)), Rect2(c1, 0, 16, 12))
	if s:
		_liquid.draw_texture_rect_region(tex, Rect2(p.x, p.y + CELL - 3, CELL, 3), Rect2(32, 93, 32, 3))
	var y0 := 12.0 if n else 0.0
	if wv:
		_liquid.draw_texture_rect_region(tex, Rect2(p.x, p.y + y0, 3, CELL - y0), Rect2(0, 32 + y0, 3, CELL - y0))
	if e:
		_liquid.draw_texture_rect_region(tex, Rect2(p.x + CELL - 3, p.y + y0, 3, CELL - y0), Rect2(93, 32 + y0, 3, CELL - y0))


## Pits: dust motes drifting down into the dark and a slow glint far below.
func _draw_pit_motes(x: int, y: int, pal: Dictionary) -> void:
	var p := Vector2(x, y) * CELL
	var hb := _hash(x * 3 + 7, y * 13 + 1)
	for i in 2:
		var period := 3.0 + float((hb >> i) % 13) * 0.15
		var u := fmod(_t + float((hb >> (i * 4)) % 100) * 0.05, period) / period
		var start := Vector2(5 + (hb >> (i * 3)) % 22, 13.0)
		var q := start.lerp(Vector2(16, 25), u) + Vector2(sin(u * 6.0 + i) * 2.0, 0)
		_liquid.draw_rect(Rect2((p + q).floor(), Vector2.ONE), Color(pal.rim, 0.5 * (1.0 - u)))
	if (x * 7 + y * 3) % 4 == 0:
		var ga := 0.15 + 0.15 * sin(_t * 1.3 + x)
		_liquid.draw_rect(Rect2(p.x + 18, p.y + 22, 2, 1), Color(pal.liquid_hi, ga))

