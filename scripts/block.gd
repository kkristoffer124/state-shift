@tool
class_name Block
extends StaticBody2D
## Solid level piece. Origin is the TOP-LEFT corner; set `size` in the inspector.
##  WALL      blocks everything
##  GRATE     blocks only ICE (water & steam pass through)
##  BREAKABLE blocks everything, shatters when ICE hits it fast

enum Kind { WALL, GRATE, BREAKABLE }

const LAYERS := { Kind.WALL: 1, Kind.GRATE: 2, Kind.BREAKABLE: 4 }

@export var kind: Kind = Kind.WALL:
	set(v):
		kind = v
		_refresh()
@export var size := Vector2(64, 64):
	set(v):
		size = v
		_refresh()
@export var color := Color("2a3a4c"):
	set(v):
		color = v
		queue_redraw()


func _ready() -> void:
	_refresh()
	if kind == Kind.BREAKABLE and not Engine.is_editor_hint():
		add_to_group("breakable")


func _refresh() -> void:
	if not is_inside_tree():
		return
	collision_layer = LAYERS[kind]
	collision_mask = 0
	var cs := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs and cs.shape is RectangleShape2D:
		(cs.shape as RectangleShape2D).size = size
		cs.position = size / 2.0
	queue_redraw()


func shatter(impact_velocity: Vector2) -> void:
	collision_layer = 0
	Sfx.play("shatter")
	var fx := CPUParticles2D.new()
	fx.position = size / 2.0
	fx.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	fx.emission_rect_extents = size / 2.0
	fx.amount = int(clampf(size.x * size.y / 120.0, 16, 80))
	fx.one_shot = true
	fx.explosiveness = 1.0
	fx.lifetime = 0.9
	fx.direction = impact_velocity.normalized()
	fx.spread = 70.0
	fx.initial_velocity_min = 120.0
	fx.initial_velocity_max = 380.0
	fx.gravity = Vector2(0, 900)
	fx.angular_velocity_min = -400.0
	fx.angular_velocity_max = 400.0
	fx.scale_amount_min = 3.0
	fx.scale_amount_max = 7.0
	fx.color = Color("8d7a62")
	get_parent().add_child(fx)
	fx.global_position = global_position + size / 2.0
	fx.emitting = true
	fx.finished.connect(fx.queue_free)
	queue_free()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	match kind:
		Kind.WALL:
			draw_rect(r, color)
			draw_rect(Rect2(0, 0, size.x, 4), color.lightened(0.35))
			var dots := color.darkened(0.25)
			for x in range(16, int(size.x), 32):
				for y in range(16, int(size.y), 32):
					draw_circle(Vector2(x, y), 1.5, dots)
			draw_rect(r, color.darkened(0.4), false, 2.0)
		Kind.GRATE:
			draw_rect(r, Color(0.55, 0.7, 0.85, 0.12))
			var bar := Color(0.62, 0.74, 0.86, 0.8)
			for x in range(4, int(size.x), 10):
				draw_line(Vector2(x, 0), Vector2(x, size.y), bar, 2.0)
			draw_rect(r, Color(0.7, 0.8, 0.9, 0.9), false, 3.0)
		Kind.BREAKABLE:
			var base := Color("6e5c48")
			draw_rect(r, base)
			draw_rect(Rect2(0, 0, size.x, 4), base.lightened(0.3))
			var rng := RandomNumberGenerator.new()
			rng.seed = int(size.x * 13 + size.y * 7)
			var crack := base.darkened(0.5)
			for i in maxi(2, int(size.x / 48)):
				var p := Vector2(rng.randf_range(8, size.x - 8), 0)
				var pts := PackedVector2Array([p])
				while p.y < size.y:
					p += Vector2(rng.randf_range(-10, 10), rng.randf_range(6, 12))
					pts.append(Vector2(clampf(p.x, 0, size.x), minf(p.y, size.y)))
				draw_polyline(pts, crack, 2.0)
			draw_rect(r, base.darkened(0.45), false, 2.0)
