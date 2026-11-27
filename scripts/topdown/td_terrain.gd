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
## Height (px) of the south-facing wall strip that gives walls their depth.
const FACE := 12
const WALL := "#"
const PIT := "o"
const SEWAGE := "~"
const SPIKES := "^"

const TEX_FLOOR := {
	"lab": preload("res://assets/topdown/td_floor_lab.png"),
	"sewer": preload("res://assets/topdown/td_floor_sewer.png"),
}
const TEX_FACE := {
	"lab": preload("res://assets/topdown/td_face_lab.png"),
	"sewer": preload("res://assets/topdown/td_face_sewer.png"),
}
const TEX_SPIKES := preload("res://assets/topdown/td_spikes.png")

## Per-theme palette for the procedurally drawn parts.
const PAL := {
	"lab": {
		"rim": Color("8fb0d2"), "rim_dark": Color("1a2330"), "pit": Color("06090e"),
		"pit_wall": Color("1d2734"), "hazard": Color("e0b43a"), "liquid": Color("1b5a6e"),
		"liquid_hi": Color("5fc2d8"), "liquid_deep": Color("0d2f3d"), "top_tint": Color(0.6, 0.66, 0.78),
	},
	"sewer": {
		"rim": Color("8fb3a0"), "rim_dark": Color("141c19"), "pit": Color("050807"),
		"pit_wall": Color("1d2925"), "hazard": Color("7a9a54"), "liquid": Color("1f5a46"),
		"liquid_hi": Color("79c79a"), "liquid_deep": Color("0f3126"), "top_tint": Color(0.55, 0.62, 0.58),
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
	return t if TEX_FLOOR.has(t) else "lab"


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
	var pal: Dictionary = PAL[_theme]
	var floor_tex: Texture2D = TEX_FLOOR[_theme]
	var face_tex: Texture2D = TEX_FACE[_theme]
	var wall_tex: Texture2D = EnvTheme.textures(_theme).wall
	var h := height()
	var w := width()
	# 1) floor everywhere that isn't a wall or a hole
	for y in h:
		for x in w:
			var ch := char_at_cell(Vector2i(x, y))
			if ch == WALL or is_hole(ch):
				continue
			var hv := _hash(x, y) % 100
			var v := 0
			if ch == ",":
				v = 3
			elif hv < 9:
				v = 1
			elif hv < 15:
				v = 2
			elif hv < 21:
				v = 3
			var p := Vector2(x, y) * CELL
			draw_texture_rect_region(floor_tex, Rect2(p, Vector2(CELL, CELL)), Rect2(v * CELL, 0, CELL, CELL))
			if ch == SPIKES:
				draw_texture(TEX_SPIKES, p)
	# 2) holes (pits / sewage beds)
	for y in h:
		for x in w:
			var ch := char_at_cell(Vector2i(x, y))
			if is_hole(ch):
				_draw_hole(x, y, ch, pal)
	# 3) shadows cast by walls on the floor (south and east of walls)
	for y in h:
		for x in w:
			if _is_wall(x, y):
				continue
			var p := Vector2(x, y) * CELL
			if _is_wall(x, y - 1):
				for i in 8:
					draw_rect(Rect2(p.x, p.y + i, CELL, 1), Color(0, 0, 0.03, 0.42 * (1.0 - i / 8.0)))
			if _is_wall(x - 1, y):
				for i in 5:
					draw_rect(Rect2(p.x + i, p.y, 1, CELL), Color(0, 0, 0.03, 0.3 * (1.0 - i / 5.0)))
	# 4) walls: top face (theme wall art sampled in world space), rims, south face
	var wtw := wall_tex.get_width()
	for y in h:
		for x in w:
			if not _is_wall(x, y):
				continue
			var p := Vector2(x, y) * CELL
			var south_open := not _is_wall(x, y + 1) and y + 1 < h
			var top_h := CELL - (FACE if south_open else 0)
			# Sample the interior (non-border) part of the 9-slice wall art.
			var sx := 32 + (x * CELL) % 32
			var sy := 32 + (y * CELL) % 32
			draw_texture_rect_region(wall_tex, Rect2(p, Vector2(CELL, top_h)), Rect2(sx, sy, CELL, top_h), pal.top_tint)
			# rims where the top meets open space (lit from the top-left)
			if not _is_wall(x, y - 1) and y > 0:
				draw_rect(Rect2(p.x, p.y, CELL, 2), pal.rim)
				draw_rect(Rect2(p.x, p.y + 2, CELL, 1), pal.rim.darkened(0.5))
			if not _is_wall(x - 1, y) and x > 0:
				draw_rect(Rect2(p.x, p.y, 2, top_h), pal.rim.darkened(0.1))
			if not _is_wall(x + 1, y) and x + 1 < w:
				draw_rect(Rect2(p.x + CELL - 2, p.y, 2, top_h), pal.rim.darkened(0.45))
			if south_open:
				draw_rect(Rect2(p.x, p.y + top_h - 2, CELL, 2), pal.rim.lightened(0.15))
				draw_texture_rect_region(face_tex, Rect2(p.x, p.y + top_h, CELL, FACE), Rect2((x * CELL) % 32, 0, CELL, FACE))
				# face ends darken next to open sides
				if not _is_wall(x - 1, y):
					draw_rect(Rect2(p.x, p.y + top_h, 1, FACE), pal.rim_dark)
				if not _is_wall(x + 1, y):
					draw_rect(Rect2(p.x + CELL - 1, p.y + top_h, 1, FACE), pal.rim_dark)
	if Engine.is_editor_hint():
		draw_rect(Rect2(Vector2.ZERO, Vector2(w, h) * CELL), Color(1, 1, 1, 0.15), false, 1.0)


func _draw_hole(x: int, y: int, ch: String, pal: Dictionary) -> void:
	var p := Vector2(x, y) * CELL
	var up_open := not is_hole(char_at_cell(Vector2i(x, y - 1)))
	if ch == PIT:
		draw_rect(Rect2(p, Vector2(CELL, CELL)), pal.pit)
		# far (north) inner wall fading into the dark: reads as a deep shaft
		if up_open:
			for i in 10:
				draw_rect(Rect2(p.x, p.y + i, CELL, 1), pal.pit_wall.lerp(pal.pit, i / 10.0))
			for bx in range(0, CELL, 8):
				draw_rect(Rect2(p.x + bx + (4 if (x + bx / 8) % 2 else 0), p.y + 2, 1, 3), pal.pit_wall.darkened(0.5))
		if not is_hole(char_at_cell(Vector2i(x - 1, y))):
			for i in 3:
				draw_rect(Rect2(p.x + i, p.y, 1, CELL), Color(pal.pit_wall, 0.5 - i * 0.15))
		# a faint glint far below
		if (x * 7 + y * 3) % 4 == 0:
			draw_rect(Rect2(p.x + 18, p.y + 22, 2, 1), Color(pal.liquid_hi, 0.25))
	else:
		draw_rect(Rect2(p, Vector2(CELL, CELL)), pal.liquid_deep)
		if up_open:
			draw_rect(Rect2(p, Vector2(CELL, 8)), pal.pit_wall)
			draw_rect(Rect2(p.x, p.y + 7, CELL, 1), pal.pit_wall.darkened(0.4))
	# lips where the floor ends
	var dirs := [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
	for d in dirs:
		var n := char_at_cell(Vector2i(x, y) + d)
		if is_hole(n) or n == WALL:
			continue
		var r: Rect2
		var hz: Rect2
		if d.y < 0:
			r = Rect2(p.x, p.y, CELL, 2)
			hz = Rect2(p.x, p.y - 3, CELL, 3)
		elif d.y > 0:
			r = Rect2(p.x, p.y + CELL - 2, CELL, 2)
			hz = Rect2(p.x, p.y + CELL, CELL, 3)
		elif d.x < 0:
			r = Rect2(p.x, p.y, 2, CELL)
			hz = Rect2(p.x - 3, p.y, 3, CELL)
		else:
			r = Rect2(p.x + CELL - 2, p.y, 2, CELL)
			hz = Rect2(p.x + CELL, p.y, 3, CELL)
		draw_rect(r, pal.rim.darkened(0.25))
		if ch == PIT and _theme == "lab":
			# hazard paint on the floor lip
			var horizontal: bool = d.y != 0
			var n_seg := 8
			for i in n_seg:
				if (i + x + y) % 2:
					continue
				var seg := hz
				if horizontal:
					seg = Rect2(hz.position.x + i * 4, hz.position.y, 4, hz.size.y)
				else:
					seg = Rect2(hz.position.x, hz.position.y + i * 4, hz.size.x, 4)
				draw_rect(seg, pal.hazard)


## Animated sewage surface (redrawn every frame on the internal Liquid child).
func _draw_liquid() -> void:
	var pal: Dictionary = PAL[_theme]
	var f := flow.normalized() if flow.length() > 0.01 else Vector2.RIGHT
	for y in height():
		for x in width():
			if char_at_cell(Vector2i(x, y)) != SEWAGE:
				continue
			var p := Vector2(x, y) * CELL
			var up_open := not is_hole(char_at_cell(Vector2i(x, y - 1)))
			var top := 8.0 if up_open else 0.0
			var body := Rect2(p.x, p.y + top, CELL, CELL - top)
			var deep := 0
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if char_at_cell(Vector2i(x, y) + d) == SEWAGE:
					deep += 1
			_liquid.draw_rect(body, pal.liquid.lerp(pal.liquid_deep, 0.12 * deep))
			# moving ripples: short light dashes travelling along the flow
			for i in 4:
				var sd := _hash(x * 7 + i, y * 3 + i)
				var lane := float(sd % 26) + 3.0
				var speed := 26.0 + float(sd % 17)
				var along := fmod(_t * speed + float(sd % 97), CELL + 12.0) - 6.0
				var q: Vector2
				if absf(f.x) >= absf(f.y):
					along = along if f.x > 0.0 else CELL - along
					q = Vector2(along, lane)
				else:
					along = along if f.y > 0.0 else CELL - along
					q = Vector2(lane, along)
				q = (p + q).floor()
				if q.y < body.position.y or q.y > body.end.y - 1:
					continue
				var dash := Rect2(q, Vector2(5, 1) if absf(f.x) >= absf(f.y) else Vector2(1, 4))
				dash = dash.intersection(body)
				if dash.has_area():
					_liquid.draw_rect(dash, Color(pal.liquid_hi, 0.55))
			# foam along the banks
			if up_open:
				for i in 6:
					var fx := fmod(float(_hash(x, y + i) % 32) + _t * 9.0 * (1 if i % 2 else -1), CELL)
					_liquid.draw_rect(Rect2((p + Vector2(fx, top + (i % 2))).floor(), Vector2(2, 1)), Color(pal.liquid_hi, 0.7))
			# drifting gunk
			if _hash(x, y) % 7 == 0:
				var gx := fmod(float(_hash(y, x) % 32) + _t * 14.0 * f.x, CELL)
				var gy := fmod(float(_hash(x + 3, y) % 20) + 10.0 + _t * 14.0 * f.y, CELL - top) + top
				if gx < 0: gx += CELL
				_liquid.draw_rect(Rect2((p + Vector2(gx, gy)).floor(), Vector2(3, 2)), pal.liquid_deep.lightened(0.15))
