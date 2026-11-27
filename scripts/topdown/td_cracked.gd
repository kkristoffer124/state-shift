@tool
class_name TdCracked
extends StaticBody2D
## Top-down cracked block (collision layer 4 like Block.BREAKABLE). ORIGIN = top-left.
## Stops everything; an ICE cube sliding into it fast enough (TdPlayer.shatter_speed)
## smashes it and keeps sliding.

## 3 x 32x32 frames: intact, crack 1, crack 2. Cells show the cracked frames (it breaks
## in one hit, so it always reads as breakable).
const TEX_BLOCK := preload("res://assets/topdown/tex/t20_cracked_block_3f.png")
const TEX_SHARDS: Array[Texture2D] = [
	preload("res://assets/env/e3c_shard_1.png"),
	preload("res://assets/env/e3c_shard_2.png"),
	preload("res://assets/env/e3c_shard_3.png"),
	preload("res://assets/env/e3c_shard_4.png"),
	preload("res://assets/env/e3c_shard_5.png"),
	preload("res://assets/env/e3c_shard_6.png"),
]
const TEX_DUST := preload("res://assets/vfx/v4_dust_5f.png")

@export var size := Vector2(32, 32):
	set(v):
		size = v.max(Vector2(16, 16))
		_refresh()


func _ready() -> void:
	_refresh()


func _refresh() -> void:
	if not is_inside_tree():
		return
	collision_layer = 4
	collision_mask = 0
	z_index = 1
	var cs := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs and cs.shape is RectangleShape2D:
		(cs.shape as RectangleShape2D).size = size
		cs.position = size / 2.0
	queue_redraw()


func _draw() -> void:
	var nx := maxi(1, ceili(size.x / 32.0))
	var ny := maxi(1, ceili(size.y / 32.0))
	var base := int(global_position.x / 32.0) + int(global_position.y / 32.0)
	# contact shadow on the floor below / right of the block
	draw_rect(Rect2(2, size.y, size.x, 2), Color(0, 0, 0.03, 0.35))
	draw_rect(Rect2(size.x, 2, 2, size.y), Color(0, 0, 0.03, 0.25))
	for ty in ny:
		for tx in nx:
			var f := 1 + (base + tx + ty) % 2
			draw_texture_rect_region(TEX_BLOCK, Rect2(Vector2(tx, ty) * 32.0, Vector2(32, 32)), Rect2(f * 32, 0, 32, 32))


func shatter(impact_velocity: Vector2) -> void:
	collision_layer = 0
	var host := get_parent()
	var origin := global_position
	var dir := impact_velocity.normalized() if impact_velocity.length() > 1.0 else Vector2.DOWN
	if has_node("/root/Sfx"):
		get_node("/root/Sfx").play("shatter")
	for i in int(clampf(size.x * size.y / 60.0, 10, 30)):
		var s := Sprite2D.new()
		s.texture = TEX_SHARDS[randi() % TEX_SHARDS.size()]
		s.z_index = 5
		host.add_child(s)
		var p0 := origin + Vector2(randf() * size.x, randf() * size.y)
		s.global_position = p0
		var v := dir.rotated(randf_range(-1.0, 1.0)) * randf_range(90.0, 260.0)
		var life := randf_range(0.45, 0.8)
		var spin := randf_range(-10.0, 10.0)
		var tw := s.create_tween().set_parallel()
		# top-down: shards skid out along the floor with a little hop
		tw.tween_method(func(t: float) -> void:
			s.global_position = (p0 + v * (t - t * t / (2.0 * life)) + Vector2(0, -40.0 * sin(PI * t / life))).round()
			s.rotation = spin * t, 0.0, life, life)
		tw.tween_property(s, "modulate:a", 0.0, life * 0.4).set_delay(life * 0.6)
		tw.chain().tween_callback(s.queue_free)
	var d := Sprite2D.new()
	d.texture = TEX_DUST
	d.hframes = 5
	d.z_index = 5
	host.add_child(d)
	d.global_position = (origin + size / 2.0).round()
	var tw2 := d.create_tween()
	tw2.tween_property(d, "frame", 4, 0.4).from(0)
	tw2.tween_callback(d.queue_free)
	queue_free()
