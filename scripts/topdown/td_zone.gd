@tool
class_name TdZone
extends Area2D
## Top-down trigger area (same meaning as Zone, drawn from above).
## ORIGIN = top-left corner; `size` in px (use multiples of 32 to match the grid).
##  HEAT    hot floor grill (t21 heat pads on the floor cells): forces STEAM while inside
##  FREEZE  cryo leak (t22 freeze pads, frost edge, drifting snow): forces ICE while inside
##  FAN     floor fan (t23 housing + spinning blades at the upwind end): pushes STEAM
##          (a little WATER) along push_direction
##  GOAL    the exit swirl (t24, turning over a glow)
## Pads are only laid on floor cells of Blocks/Terrain (not on walls / pits / sewage).

enum Kind { HEAT, FREEZE, FAN, GOAL }

const TEX_EMBER := preload("res://assets/env/e5c_ember.png")
const TEX_FROST_EDGE := preload("res://assets/env/e6d_frost_edge_9s16.png")
const TEX_SNOW: Array[Texture2D] = [
	preload("res://assets/env/e6c_snowflake_1.png"),
	preload("res://assets/env/e6c_snowflake_2.png"),
	preload("res://assets/env/e6c_snowflake_3.png"),
]
const TEX_AIRFLOW := preload("res://assets/env/e7c_airflow_streak.png")   # 4x32
const TEX_HEAT_PAD := preload("res://assets/topdown/tex/t21_heat_pad.png")     # 32x32
const TEX_FREEZE_PAD := preload("res://assets/topdown/tex/t22_freeze_pad.png") # 32x32
const TEX_FAN_HOUSING := preload("res://assets/topdown/tex/t23_fan_housing.png") # 64x64
const TEX_FAN_BLADES := preload("res://assets/topdown/tex/t23_fan_blades.png")   # 64x64, spun
const TEX_GOAL := preload("res://assets/topdown/tex/t24_goal.png")               # 64x64
const TEX_GOAL_GLOW := preload("res://assets/env/e8b_goal_glow.png")
const TEX_MIST := preload("res://assets/topdown/td_puff_m.png")
const TEX_SPARKLES: Array[Texture2D] = [
	preload("res://assets/env/e8c_sparkle_1.png"),
	preload("res://assets/env/e8c_sparkle_2.png"),
]

@export var kind: Kind = Kind.HEAT:
	set(v):
		kind = v
		_refresh()
@export var size := Vector2(64, 64):
	set(v):
		size = v
		_refresh()
@export var push_direction := Vector2.RIGHT:
	set(v):
		push_direction = v
		queue_redraw()
@export var push_strength := 700.0
## FAN only: draw the fan unit at the upwind end (off = just the airflow, e.g. a fan hidden in a wall).
@export var show_unit := true:
	set(v):
		show_unit = v
		queue_redraw()

var _t := 0.0
var _frost_box: StyleBoxTexture
## Local top-left corners of the zone's floor cells (where pads are laid).
var _pad_cells: Array[Vector2] = []


func _ready() -> void:
	collision_layer = 16
	collision_mask = 0
	monitoring = false
	monitorable = true
	_refresh()


func _refresh() -> void:
	if not is_inside_tree():
		return
	var cs := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs and cs.shape is RectangleShape2D:
		var s := size
		if kind == Kind.GOAL:
			s = size * 0.6
		(cs.shape as RectangleShape2D).size = s
		cs.position = size / 2.0
	_frost_box = Zone._nine(TEX_FROST_EDGE, 16.0, 16.0, size)
	z_index = 2 if kind == Kind.FAN else 1
	_find_pad_cells()
	queue_redraw()


func _find_pad_cells() -> void:
	_pad_cells.clear()
	var lvl := get_parent().get_parent() if get_parent() else null
	var terrain := lvl.get_node_or_null("Blocks/Terrain") as TdTerrain if lvl else null
	for y in int(ceilf(size.y / 32.0)):
		for x in int(ceilf(size.x / 32.0)):
			var c := Vector2(x, y) * 32.0
			if terrain:
				var ch := terrain.char_at(global_position + c + Vector2(16, 16))
				if ch == TdTerrain.WALL or terrain.is_hole(ch):
					continue
			_pad_cells.append(c)


func push_vector() -> Vector2:
	return push_direction.normalized() * push_strength


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	match kind:
		Kind.HEAT: _draw_heat()
		Kind.FREEZE: _draw_freeze()
		Kind.FAN: _draw_fan()
		Kind.GOAL: _draw_goal()


func _draw_heat() -> void:
	var pulse := 0.5 + 0.5 * sin(_t * 3.0)
	# grill pads; the slats glow brighter and dimmer
	var glow := Color(1.0, 0.9 + 0.1 * pulse, 0.85 + 0.15 * pulse).lerp(Color(1.25, 1.1, 0.9), pulse * 0.5)
	for c in _pad_cells:
		draw_texture(TEX_HEAT_PAD, c, glow)
	# heat glow + rising embers (rise = toward the top of the screen, fading)
	for c in _pad_cells:
		draw_rect(Rect2(c, Vector2(32, 32)), Color(1.0, 0.45, 0.15, 0.05 + 0.06 * pulse))
	for i in int(size.x * size.y / 500.0) + 3:
		var px := fmod(i * 37.7, size.x - 4.0) + 2.0
		var travel := fmod(_t * (22.0 + i % 5 * 7.0) + i * 53.0, 40.0)
		var py := fmod(i * 23.3, size.y) - travel * 0.6
		var a := clampf(1.0 - travel / 40.0, 0.0, 1.0)
		draw_texture(TEX_EMBER, Vector2(px + sin(_t * 3.0 + i) * 2.0, py).round() - Vector2(2, 2), Color(1, 1, 1, a))
	# heat shimmer: wavy pale dashes drifting up across the grill
	var rows := int(size.y / 6.0)
	for j in rows:
		var yy := fmod(j * 6.0 - _t * 14.0, size.y)
		if yy < 0.0:
			yy += size.y
		var wob := sin(_t * 5.0 + j * 1.7) * 3.0
		var x0 := fmod(j * 19.0 + wob + _t * 3.0, size.x * 0.5)
		var ha := 0.07 + 0.05 * sin(_t * 4.0 + j)
		draw_rect(Rect2(Vector2(x0 + 2.0, yy).round(), Vector2(size.x * 0.35, 1)), Color(1.0, 0.85, 0.6, ha))
	# quick bright sparks that flick upward
	for i in int(size.x * size.y / 900.0) + 2:
		var life := 0.7 + float(i % 3) * 0.2
		var ph := fmod(_t + i * 0.37, life) / life
		var sx := fmod(i * 29.0 + floorf((_t + i * 0.37) / life) * 13.0, size.x - 4.0) + 2.0
		var sy := size.y - 4.0 - ph * (size.y * 0.8 + 10.0)
		if sy < -6.0:
			continue
		var flick := 1.0 if int(_t * 30.0 + i) % 4 != 0 else 0.5
		draw_rect(Rect2(Vector2(sx + sin(ph * 9.0 + i) * 2.0, sy).round(), Vector2(1, 2)), Color(1.0, 0.92, 0.5, (1.0 - ph) * flick))


func _draw_freeze() -> void:
	var r := Rect2(Vector2.ZERO, size)
	# cryo pads on the floor cells; a big cold room gets a scatter of vents instead
	var big := _pad_cells.size() > 12
	for c in _pad_cells:
		var g := Vector2i((global_position + c) / 32.0)
		var h := (g.x * 73856093) ^ (g.y * 19349663) ^ 0x5bd1e995
		h = absi((h ^ (h >> 13)) * 1274126177)
		if not big or (h ^ (h >> 16)) % 8 == 0:
			draw_texture(TEX_FREEZE_PAD, c)
	draw_rect(r, Color(0.55, 0.85, 1.0, 0.08 + sin(_t * 1.7) * 0.03))
	if _frost_box:
		draw_style_box(_frost_box, r)
	# low cold mist rolling across the floor
	for i in int(size.x * size.y / 3000.0) + 2:
		var mx := fmod(i * 47.0 + _t * (5.0 + i % 3 * 2.0), size.x + 24.0) - 12.0
		var my := fmod(i * 31.0, maxf(size.y - 16.0, 1.0)) + 8.0 + sin(_t * 0.8 + i) * 3.0
		var ma := 0.18 * sin(clampf(mx / size.x, 0.0, 1.0) * PI)
		var ms := TEX_MIST.get_size() * (1.6 + 0.3 * sin(_t * 0.6 + i))
		var mr := Rect2((Vector2(mx, my) - ms * 0.5).round(), ms.round()).intersection(r)
		if mr.has_area():
			draw_texture_rect(TEX_MIST, Rect2((Vector2(mx, my) - ms * 0.5).round(), ms.round()), false, Color(0.75, 0.92, 1.0, ma))
	# twinkling frost glints
	for i in int(size.x * size.y / 700.0) + 2:
		var tw := fmod(_t * 0.9 + i * 0.61, 2.0)
		if tw > 0.35:
			continue
		var gp := Vector2(fmod(i * 71.3, size.x - 4.0) + 2.0, fmod(i * 43.9 + i * i * 0.21, size.y - 4.0) + 2.0).floor()
		var ga := sin(tw / 0.35 * PI)
		draw_rect(Rect2(gp - Vector2(1, 0), Vector2(3, 1)), Color(1, 1, 1, ga * 0.8))
		draw_rect(Rect2(gp - Vector2(0, 1), Vector2(1, 3)), Color(1, 1, 1, ga * 0.8))
	# drifting snow
	for i in int(size.x * size.y / 2200.0) + 4:
		var px := fmod(i * 41.3 + _t * (6.0 + i % 3 * 3.0), size.x)
		var py := fmod(i * 67.0 + _t * (12.0 + i % 4 * 5.0), size.y)
		var p := Vector2(px + sin(_t * 2.0 + i) * 4.0, py).round() - Vector2(2, 2)
		if r.has_point(p + Vector2(2, 2)):
			draw_texture(TEX_SNOW[i % TEX_SNOW.size()], p, Color(1, 1, 1, 0.85))


func _draw_fan() -> void:
	var d := push_direction.normalized() if push_direction.length() > 0.01 else Vector2.RIGHT
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Color(0.75, 0.9, 1.0, 0.05))
	# airflow streaks drawn in a frame rotated so +y of the streak = wind direction
	var along_len := size.x if absf(d.x) > absf(d.y) else size.y
	var across_len := size.y if absf(d.x) > absf(d.y) else size.x
	var lanes := maxi(2, int(across_len / 14.0))
	for i in lanes:
		var across := roundf((i + 0.5) * across_len / lanes) + float(i % 3) - 1.0
		var speed := 160.0 + float((i * 37) % 70)
		var pos := fmod(_t * speed + i * 57.0, along_len + 32.0) - 32.0
		var a := 0.35 + 0.35 * clampf(pos / along_len, 0.0, 1.0)
		across += roundf(sin(_t * 6.0 + i * 1.3 + pos * 0.05) * 1.5)
		# tapered streak: bright head, fading tail (tail = upwind)
		for k in 3:
			var seg_len: float = [12.0, 10.0, 10.0][k]
			var start: float = pos + 32.0 - float([12.0, 22.0, 32.0][k])
			var ka: float = [1.0, 0.55, 0.25][k]
			var seg := Rect2()
			if absf(d.x) > absf(d.y):
				var x := start if d.x > 0.0 else along_len - start - seg_len
				seg = Rect2(x, across, seg_len, 1 if k == 2 else 2)
			else:
				var y := start if d.y > 0.0 else along_len - start - seg_len
				seg = Rect2(across, y, 1 if k == 2 else 2, seg_len)
			seg = seg.intersection(r)
			if seg.has_area():
				draw_rect(seg, Color(0.85, 0.95, 1.0, a * 0.6 * ka))
	if not show_unit:
		return
	# fan unit just inside the upwind edge, centred across; the blades spin
	var c: Vector2
	if absf(d.x) > absf(d.y):
		c = Vector2(32.0 if d.x > 0.0 else size.x - 32.0, size.y / 2.0)
	else:
		c = Vector2(size.x / 2.0, 32.0 if d.y > 0.0 else size.y - 32.0)
	c = c.round()
	draw_texture(TEX_FAN_HOUSING, c - Vector2(32, 32))
	var ang := _t * 13.0
	# motion blur: the previous angle ghosted under the current one
	draw_set_transform(c, ang - 0.35)
	draw_texture(TEX_FAN_BLADES, Vector2(-32, -32), Color(1, 1, 1, 0.35))
	draw_set_transform(c, ang)
	draw_texture(TEX_FAN_BLADES, Vector2(-32, -32))
	draw_set_transform(Vector2.ZERO)
	draw_arc(c, 20.0, ang * 1.1, ang * 1.1 + 1.0, 6, Color(1, 1, 1, 0.25), 1.0)
	draw_arc(c, 20.0, ang * 1.1 + PI, ang * 1.1 + PI + 1.0, 6, Color(1, 1, 1, 0.25), 1.0)


func _draw_goal() -> void:
	var c := (size / 2.0).round()
	var glow_a := 0.7 + sin(_t * 3.0) * 0.25
	draw_texture(TEX_GOAL_GLOW, c - TEX_GOAL_GLOW.get_size() / 2.0, Color(1, 1, 1, glow_a))
	# pulse rings breathing outward
	for j in 2:
		var u := fmod(_t * 0.8 + j * 0.5, 1.0)
		draw_arc(c, 18.0 + u * 22.0, 0.0, TAU, 32, Color(0.6, 1.0, 0.7, 0.35 * (1.0 - u)), 1.0)
	# the swirl turns (quarter-turn steps would stutter; it is smooth but slow)
	draw_set_transform(c, -_t * 1.8, Vector2.ONE * (1.0 + sin(_t * 2.0) * 0.03))
	draw_texture(TEX_GOAL, -TEX_GOAL.get_size() / 2.0)
	draw_set_transform(Vector2.ZERO)
	for i in 4:
		var a := _t * 2.0 + i * TAU / 4.0
		var p := (c + Vector2(cos(a), sin(a) * 0.8) * 32.0).round() - Vector2(3, 3)
		draw_texture(TEX_SPARKLES[(i + int(_t * 6.0)) % 2], p)
