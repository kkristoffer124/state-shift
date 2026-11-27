@tool
class_name TdZone
extends Area2D
## Top-down trigger area (same meaning as Zone, drawn from above).
## ORIGIN = top-left corner; `size` in px (use multiples of 32 to match the grid).
##  HEAT    hot floor grill: forces STEAM while inside
##  FREEZE  cryo leak: forces ICE while inside (frosted floor, drifting snow)
##  FAN     floor/wall fan: pushes STEAM (a little WATER) along push_direction
##  GOAL    the exit swirl

enum Kind { HEAT, FREEZE, FAN, GOAL }

const TEX_EMBER := preload("res://assets/env/e5c_ember.png")
const TEX_FROST_EDGE := preload("res://assets/env/e6d_frost_edge_9s16.png")
const TEX_SNOW: Array[Texture2D] = [
	preload("res://assets/env/e6c_snowflake_1.png"),
	preload("res://assets/env/e6c_snowflake_2.png"),
	preload("res://assets/env/e6c_snowflake_3.png"),
]
const TEX_AIRFLOW := preload("res://assets/env/e7c_airflow_streak.png")   # 4x32
const TEX_FAN_HOUSING := preload("res://assets/interactive/ix_turbine_housing.png") # 40x40
const TEX_FAN_ROTOR := preload("res://assets/interactive/ix_turbine_rotor_4f.png")  # 4 x 32x32
const TEX_GOAL_SWIRL := preload("res://assets/env/e8a_goal_swirl.png")
const TEX_GOAL_GLOW := preload("res://assets/env/e8b_goal_glow.png")
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
	queue_redraw()


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
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Color("2a1410"))
	draw_rect(r.grow(-2), Color("3a1a12"))
	# glowing slats
	var y := 5.0
	while y < size.y - 4.0:
		var hot := Color("ff5a1a").lerp(Color("ffb347"), pulse * 0.6)
		draw_rect(Rect2(4, y, size.x - 8, 3), hot)
		draw_rect(Rect2(4, y + 3, size.x - 8, 1), Color("6b2a14"))
		y += 7.0
	# frame
	draw_rect(Rect2(0, 0, size.x, 2), Color("8a5a48"))
	draw_rect(Rect2(0, size.y - 2, size.x, 2), Color("1a0c08"))
	draw_rect(Rect2(0, 0, 2, size.y), Color("6a4234"))
	draw_rect(Rect2(size.x - 2, 0, 2, size.y), Color("1a0c08"))
	# heat glow + rising embers (rise = toward the top of the screen, fading)
	draw_rect(r, Color(1.0, 0.45, 0.15, 0.10 + 0.08 * pulse))
	for i in int(size.x * size.y / 500.0) + 3:
		var px := fmod(i * 37.7, size.x - 4.0) + 2.0
		var travel := fmod(_t * (22.0 + i % 5 * 7.0) + i * 53.0, 40.0)
		var py := fmod(i * 23.3, size.y) - travel * 0.6
		var a := clampf(1.0 - travel / 40.0, 0.0, 1.0)
		draw_texture(TEX_EMBER, Vector2(px + sin(_t * 3.0 + i) * 2.0, py).round() - Vector2(2, 2), Color(1, 1, 1, a))


func _draw_freeze() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Color(0.55, 0.85, 1.0, 0.16 + sin(_t * 1.7) * 0.03))
	# frosty floor speckle
	for i in int(size.x * size.y / 160.0):
		var p := Vector2(fmod(i * 53.1, size.x), fmod(i * 29.7 + i * i * 0.37, size.y)).floor()
		draw_rect(Rect2(p, Vector2(1, 1)), Color(0.85, 0.96, 1.0, 0.35))
	if _frost_box:
		draw_style_box(_frost_box, r)
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
		var seg := Rect2()
		var src := Rect2(0, 0, 4, 32)
		if absf(d.x) > absf(d.y):
			var x := pos if d.x > 0.0 else along_len - pos - 32.0
			seg = Rect2(x, across, 32, 2)
		else:
			var y := pos if d.y > 0.0 else along_len - pos - 32.0
			seg = Rect2(across, y, 2, 32)
		seg = seg.intersection(r)
		if seg.has_area():
			draw_rect(seg, Color(0.85, 0.95, 1.0, a * 0.55))
	if not show_unit:
		return
	# fan unit at the upwind edge, centred across
	var c: Vector2
	if absf(d.x) > absf(d.y):
		c = Vector2(0.0 if d.x > 0.0 else size.x, size.y / 2.0)
	else:
		c = Vector2(size.x / 2.0, 0.0 if d.y > 0.0 else size.y)
	c = c.round()
	draw_texture(TEX_FAN_HOUSING, c - Vector2(20, 20))
	var frame := int(_t * 24.0) % 4
	draw_texture_rect_region(TEX_FAN_ROTOR, Rect2(c - Vector2(16, 16), Vector2(32, 32)), Rect2(frame * 32, 0, 32, 32))


func _draw_goal() -> void:
	var c := (size / 2.0).round()
	var glow_a := 0.7 + sin(_t * 3.0) * 0.25
	draw_texture(TEX_GOAL_GLOW, c - TEX_GOAL_GLOW.get_size() / 2.0, Color(1, 1, 1, glow_a))
	draw_set_transform(c, -_t * 2.5)
	draw_texture(TEX_GOAL_SWIRL, -TEX_GOAL_SWIRL.get_size() / 2.0)
	draw_set_transform(Vector2.ZERO)
	for i in 4:
		var a := _t * 2.0 + i * TAU / 4.0
		var p := (c + Vector2(cos(a), sin(a) * 0.8) * 30.0).round() - Vector2(3, 3)
		draw_texture(TEX_SPARKLES[(i + int(_t * 6.0)) % 2], p)
