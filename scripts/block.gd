@tool
class_name Block
extends StaticBody2D
## Solid level piece. Origin is the TOP-LEFT corner; set `size` in the inspector.
##  WALL      blocks everything
##  GRATE     blocks only ICE (water & steam pass through)
##  BREAKABLE blocks everything, shatters when ICE hits it fast

enum Kind { WALL, GRATE, BREAKABLE }

const LAYERS := { Kind.WALL: 1, Kind.GRATE: 2, Kind.BREAKABLE: 4 }

const TEX_WALL := preload("res://assets/env/e1a_wall_9s32.png")
const TEX_GRATE := preload("res://assets/env/e2a_grate_9s3.png")
const TEX_CRACKED := preload("res://assets/env/e3a_cracked_block_9s8.png")
const TEX_CRACKS: Array[Texture2D] = [
	preload("res://assets/env/e3b_crack_1.png"),
	preload("res://assets/env/e3b_crack_2.png"),
	preload("res://assets/env/e3b_crack_3.png"),
]
const TEX_DECALS: Array[Texture2D] = [
	preload("res://assets/env/e1c_decal_cable_bundle.png"),
	preload("res://assets/env/e1c_decal_number_plate.png"),
	preload("res://assets/env/e1c_decal_pipe_elbow.png"),
	preload("res://assets/env/e1c_decal_vent_slit.png"),
	preload("res://assets/env/e1c_decal_warning_stripe.png"),
]  # e1c_decal_frost_patch is left out: it reads as static noise on plain walls.
const TEX_SHARDS: Array[Texture2D] = [
	preload("res://assets/env/e3c_shard_1.png"),
	preload("res://assets/env/e3c_shard_2.png"),
	preload("res://assets/env/e3c_shard_3.png"),
	preload("res://assets/env/e3c_shard_4.png"),
	preload("res://assets/env/e3c_shard_5.png"),
	preload("res://assets/env/e3c_shard_6.png"),
]
const TEX_DUST := preload("res://assets/vfx/v4_dust_5f.png")          # 5 frames of 96x64
const TEX_FLASH := preload("res://assets/vfx/v4_impact_flash_2f.png") # 2 frames of 64x32

## Wall area (px^2) per decal; lower = more decals, 0 disables them.
const DECAL_AREA := 45000.0

@export var kind: Kind = Kind.WALL:
	set(v):
		kind = v
		_refresh()
@export var size := Vector2(64, 64):
	set(v):
		size = v
		_refresh()
## Tint multiplied over the art (white = untinted).
@export var color := Color.WHITE:
	set(v):
		color = v
		queue_redraw()

var _box: StyleBoxTexture


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
	_box = _make_box()
	queue_redraw()


func _make_box() -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	var m := 0.0
	match kind:
		Kind.WALL:
			box.texture = TEX_WALL
			m = 32.0
		Kind.GRATE:
			box.texture = TEX_GRATE
			m = 3.0
		Kind.BREAKABLE:
			box.texture = TEX_CRACKED
			m = 8.0
	# Never let the borders overlap on thin pieces.
	var mx := minf(m, floorf(size.x / 2.0))
	var my := minf(m, floorf(size.y / 2.0))
	box.texture_margin_left = mx
	box.texture_margin_right = mx
	box.texture_margin_top = my
	box.texture_margin_bottom = my
	# TILE (not stretch / tile-fit) keeps every texel 1:1 so pixel art stays crisp.
	box.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	box.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	return box


func shatter(impact_velocity: Vector2) -> void:
	collision_layer = 0
	Sfx.play("shatter")
	var host := get_parent()
	var origin := global_position
	var dir := impact_velocity.normalized() if impact_velocity.length() > 1.0 else Vector2.DOWN
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	# Shards: sprites thrown along the impact with simple ballistic motion.
	var count := int(clampf(size.x * size.y / 300.0, 10, 48))
	for i in count:
		var s := Sprite2D.new()
		s.texture = TEX_SHARDS[rng.randi() % TEX_SHARDS.size()]
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.flip_h = rng.randf() < 0.5
		host.add_child(s)
		var p0 := origin + Vector2(rng.randf() * size.x, rng.randf() * size.y)
		s.global_position = p0
		var v := dir.rotated(rng.randf_range(-1.1, 1.1)) * rng.randf_range(120.0, 360.0)
		v.y -= rng.randf_range(60.0, 220.0)
		var life := rng.randf_range(0.6, 1.0)
		var r0 := rng.randf() * TAU
		var spin := rng.randf_range(-12.0, 12.0)
		var tw := s.create_tween().set_parallel()
		tw.tween_method(func(t: float) -> void:
			s.global_position = (p0 + v * t + Vector2(0, 900.0) * t * t * 0.5).round()
			s.rotation = r0 + spin * t, 0.0, life, life)
		tw.tween_property(s, "modulate:a", 0.0, life * 0.35).set_delay(life * 0.65)
		tw.chain().tween_callback(s.queue_free)

	# Dust puffs along the slab.
	var puffs := maxi(1, int(round(size.x / 96.0)))
	for i in puffs:
		var x := (i + 0.5) * size.x / puffs
		_spawn_flipbook(host, TEX_DUST, 5, origin + Vector2(x, size.y / 2.0 - 8.0), 0.45)

	# Impact flash at the centre.
	_spawn_flipbook(host, TEX_FLASH, 2, origin + size / 2.0, 0.14)
	queue_free()


## Plays a horizontal flipbook strip once at `at`, then frees it.
func _spawn_flipbook(host: Node, tex: Texture2D, frames: int, at: Vector2, duration: float) -> void:
	var s := Sprite2D.new()
	s.texture = tex
	s.hframes = frames
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	host.add_child(s)
	s.global_position = at.round()
	var tw := s.create_tween()
	tw.tween_property(s, "frame", frames - 1, duration).from(0)
	tw.tween_interval(duration / frames)
	tw.tween_callback(s.queue_free)


func _draw() -> void:
	if _box == null:
		_box = _make_box()
	_box.modulate_color = color
	draw_style_box(_box, Rect2(Vector2.ZERO, size))
	match kind:
		Kind.WALL:
			_draw_decals()
		Kind.BREAKABLE:
			_draw_cracks()


func _seed() -> int:
	return (int(position.x) * 73856093) ^ (int(position.y) * 19349663) ^ (int(size.x) * 83492791) ^ int(size.y)


func _draw_cracks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed()
	var cw := 64.0
	var ch := 32.0
	var cols := maxi(1, int(size.x / cw))
	var rows := maxi(1, int(size.y / ch))
	# Centre the crack grid inside the slab so leftover space is split evenly.
	var off := ((size - Vector2(cols * cw, rows * ch)) / 2.0).floor()
	for row in rows:
		for col in cols:
			if rng.randf() < 0.25:
				continue
			var tex := TEX_CRACKS[rng.randi() % TEX_CRACKS.size()]
			var p := off + Vector2(col * cw, row * ch)
			if rng.randf() < 0.5:
				# Mirrored copy for variety.
				draw_set_transform(p + Vector2(cw, 0), 0.0, Vector2(-1, 1))
				draw_texture(tex, Vector2.ZERO, color)
				draw_set_transform(Vector2.ZERO)
			else:
				draw_texture(tex, p, color)


func _draw_decals() -> void:
	if DECAL_AREA <= 0.0 or size.x < 64 or size.y < 64:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed()
	var n := int(size.x * size.y / DECAL_AREA)
	for i in n:
		var tex := TEX_DECALS[rng.randi() % TEX_DECALS.size()]
		var room := size - tex.get_size() - Vector2(16, 16)
		if room.x < 0 or room.y < 0:
			continue
		var p := (Vector2(8, 8) + Vector2(rng.randf() * room.x, rng.randf() * room.y)).floor()
		draw_texture(tex, p, color)
