@tool
class_name Zone
extends Area2D
## Trigger area. Origin is the TOP-LEFT corner; set `size` in the inspector.
##  SPIKES  kill WATER and STEAM (ICE is safe)
##  HEAT    forces STEAM while inside
##  FREEZE  forces ICE while inside
##  FAN     pushes STEAM (and a little WATER) along push_direction
##  GOAL    finishes the level

enum Kind { SPIKES, HEAT, FREEZE, FAN, GOAL }

@export var kind: Kind = Kind.SPIKES:
	set(v):
		kind = v
		_refresh()
@export var size := Vector2(64, 32):
	set(v):
		size = v
		_refresh()
@export var push_direction := Vector2.UP
@export var push_strength := 1500.0

var _t := 0.0


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
		if kind == Kind.SPIKES:
			s.y = maxf(size.y - 8.0, 4.0) # forgiving hitbox
			cs.position = Vector2(size.x / 2.0, size.y - s.y / 2.0)
		else:
			cs.position = size / 2.0
		(cs.shape as RectangleShape2D).size = s
	queue_redraw()


func push_vector() -> Vector2:
	return push_direction.normalized() * push_strength


func _process(delta: float) -> void:
	if kind != Kind.SPIKES:
		_t += delta
		queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	match kind:
		Kind.SPIKES:
			var w := 16.0
			for i in int(size.x / w):
				var x := i * w
				var tri := PackedVector2Array([Vector2(x, size.y), Vector2(x + w / 2.0, 2), Vector2(x + w, size.y)])
				draw_colored_polygon(tri, Color("c9d2dc"))
				draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2]]), Color("4a5566"), 1.5)
		Kind.HEAT:
			draw_rect(r, Color(1.0, 0.35, 0.1, 0.16))
			draw_rect(Rect2(0, size.y - 6, size.x, 6), Color(1.0, 0.45, 0.15, 0.8))
			for i in int(size.x * size.y / 900.0) + 4:
				var px := fmod(i * 37.7, size.x)
				var py := size.y - fmod(_t * (40.0 + i % 5 * 12.0) + i * 53.0, size.y)
				draw_circle(Vector2(px + sin(_t * 3.0 + i) * 4.0, py), 2.0, Color(1.0, 0.7, 0.3, 0.75))
			draw_rect(r, Color(1.0, 0.5, 0.2, 0.5), false, 2.0)
		Kind.FREEZE:
			draw_rect(r, Color(0.5, 0.85, 1.0, 0.13))
			for i in int(size.x * size.y / 900.0) + 4:
				var px := fmod(i * 41.3, size.x)
				var py := fmod(_t * (20.0 + i % 4 * 8.0) + i * 47.0, size.y)
				draw_circle(Vector2(px + sin(_t * 2.0 + i) * 6.0, py), 2.0, Color(0.9, 0.97, 1.0, 0.8))
			draw_rect(r, Color(0.6, 0.9, 1.0, 0.5), false, 2.0)
		Kind.FAN:
			var base := Rect2(0, size.y - 16, size.x, 16)
			var flow := size.y - 16.0
			for i in 8:
				var x := (i + 0.5) * size.x / 8.0
				var y := flow - fmod(_t * 260.0 + i * 67.0, flow)
				draw_line(Vector2(x, y), Vector2(x, minf(y + 28.0, flow)), Color(1, 1, 1, 0.22), 2.0)
			draw_rect(base, Color("3d4f60"))
			var spin := fmod(_t * 8.0, 1.0)
			for i in 6:
				var x := (i + spin) * size.x / 6.0
				draw_line(Vector2(x, size.y - 14), Vector2(x, size.y - 2), Color("8fa6ba"), 3.0)
			draw_rect(base, Color("22303d"), false, 2.0)
		Kind.GOAL:
			var c := size / 2.0
			draw_circle(c, 16.0, Color(0.4, 1.0, 0.6, 0.25))
			draw_arc(c, 22.0 + sin(_t * 3.0) * 3.0, 0, TAU, 40, Color(0.55, 1.0, 0.7, 0.9), 3.0)
			for i in 4:
				var a := _t * 2.0 + i * TAU / 4.0
				draw_circle(c + Vector2(cos(a), sin(a)) * 28.0, 3.0, Color(0.75, 1.0, 0.85))
