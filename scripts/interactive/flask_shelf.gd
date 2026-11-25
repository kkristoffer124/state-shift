@tool
class_name IxFlaskShelf
extends Node2D
## Wall shelf with lab glassware. ICE rushing past (inside the "Sensor" area) knocks the
## flasks off; they tumble, smash on the floor and spill (a few FluidWorld water pixels).
## WATER/STEAM brushing by only makes them rattle. A cracked floor shattering within
## `quake_radius` shakes them off too. Visual only: no collision with the player.
## ORIGIN = left end of the plank's top surface.

const TEX_PLANK := preload("res://assets/interactive/ix_shelf_plank.png")
const TEX_BRACKET := preload("res://assets/interactive/ix_shelf_bracket.png")
const TEX_FLASKS: Array[Texture2D] = [
	preload("res://assets/interactive/ix_flask_1.png"),
	preload("res://assets/interactive/ix_flask_2.png"),
	preload("res://assets/interactive/ix_flask_3.png"),
]
const LIQUID := [Color("66ff99"), Color("ff5a1a"), Color("80d9ff")]
const TEX_SHARDS: Array[Texture2D] = [
	preload("res://assets/env/e3c_shard_6.png"),
	preload("res://assets/env/e3c_shard_5.png"),
	preload("res://assets/env/e3c_shard_4.png"),
]

@export var width := 48.0:
	set(v):
		width = maxf(v, 16.0)
		_layout()
@export var count := 3:
	set(v):
		count = clampi(v, 0, 8)
		_layout()
@export var seed_value := 0:
	set(v):
		seed_value = v
		_layout()
## Minimum ICE speed that knocks the glassware off.
@export var knock_speed := 60.0
@export var quake_radius := 420.0
## How far below the plank the knock sensor reaches (down to the floor).
@export var sense_depth := 48.0:
	set(v):
		sense_depth = maxf(v, 8.0)
		_layout()

var _items: Array = []    # [x, tex_idx, state(0 shelf,1 falling,2 gone), wobble]
var _falling: Array = []  # [gpos, vel, rot, spin, tex_idx]
var _bits: Array = []     # [gpos, vel, life, color, shard_tex or -1]
var _t := 0.0
var _rng := RandomNumberGenerator.new()
@onready var _sensor: Area2D = get_node_or_null("Sensor")


func _ready() -> void:
	_rng.randomize()
	_layout()
	if _sensor:
		_sensor.collision_layer = 0
		_sensor.collision_mask = Ix.PLAYER_MASK
		_sensor.monitorable = false
	if Engine.is_editor_hint():
		return
	_watch_breakables.call_deferred()


func _watch_breakables() -> void:
	if not is_inside_tree():
		return
	for b in get_tree().get_nodes_in_group("breakable"):
		if b is Node2D and Ix.level_of(b) == Ix.level_of(self):
			var c: Vector2 = (b as Node2D).global_position + b.size / 2.0
			if c.distance_to(global_position) < quake_radius:
				b.tree_exiting.connect(_on_quake.bind(b))


func _on_quake(b: Node) -> void:
	# Block.shatter() zeroes the layer before freeing; a level unload doesn't.
	if b.collision_layer != 0 or not is_inside_tree() or is_queued_for_deletion():
		return
	knock_all(Vector2(_rng.randf_range(-60, 60), -40))


func _layout() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 104729 + 17
	_items.clear()
	if count > 0:
		var step := (width - 8.0) / count
		for i in count:
			_items.append([4.0 + step * (i + 0.5) + rng.randf_range(-2, 2), rng.randi() % 3, 0, 0.0])
	var cs := get_node_or_null("Sensor/CollisionShape2D") as CollisionShape2D
	if cs and cs.shape is RectangleShape2D:
		(cs.shape as RectangleShape2D).size = Vector2(width + 24.0, sense_depth + 16.0)
		cs.position = Vector2(width / 2.0, (sense_depth - 16.0) / 2.0)
	queue_redraw()


func knock_all(push: Vector2) -> void:
	var delay := 0.0
	for it in _items:
		if it[2] == 0:
			it[2] = 1
			var tex: Texture2D = TEX_FLASKS[it[1]]
			var gp := global_position + Vector2(it[0], -tex.get_height() / 2.0)
			var v := push + Vector2(_rng.randf_range(-30, 30), _rng.randf_range(-80, -30) - delay * 200.0)
			_falling.append([gp, v, 0.0, _rng.randf_range(-10, 10) * signf(push.x + 0.01), it[1]])
			delay += 0.05


func _physics_process(delta: float) -> void:
	_t += delta
	if Engine.is_editor_hint():
		return
	if _sensor:
		for b in _sensor.get_overlapping_bodies():
			var s := Ix.state_of(b)
			if s == 0 and (b.velocity as Vector2).length() > knock_speed:
				knock_all(Vector2(b.velocity.x * 0.5, -60))
				if has_node("/root/Sfx"):
					get_node("/root/Sfx").play("land_ice")
			elif s >= 1:
				for it in _items:
					it[3] = maxf(it[3], 0.6)
	for it in _items:
		it[3] = maxf(it[3] - delta, 0.0)
	var space := get_world_2d().direct_space_state
	for i in range(_falling.size() - 1, -1, -1):
		var f: Array = _falling[i]
		var p0: Vector2 = f[0]
		f[1].y += 1100.0 * delta
		var p1: Vector2 = p0 + f[1] * delta
		f[2] += f[3] * delta
		var hit := space.intersect_ray(PhysicsRayQueryParameters2D.create(p0, p1 + Vector2(0, 5), Ix.SOLID_MASK))
		if hit:
			_smash(hit.position, f[4], f[1])
			_falling.remove_at(i)
		elif p1.y > global_position.y + 3000.0:
			_falling.remove_at(i)
		else:
			f[0] = p1
	for i in range(_bits.size() - 1, -1, -1):
		var b2: Array = _bits[i]
		b2[1].y += 900.0 * delta
		b2[0] += b2[1] * delta
		b2[2] -= delta
		if b2[2] <= 0.0:
			_bits.remove_at(i)
	queue_redraw()


func _smash(at: Vector2, idx: int, vel: Vector2) -> void:
	if has_node("/root/Sfx"):
		get_node("/root/Sfx").play("shatter", 0.3)
	for i in 6:
		_bits.append([at + Vector2(0, -3), Vector2(_rng.randf_range(-110, 110) + vel.x * 0.2, _rng.randf_range(-200, -60)),
				_rng.randf_range(0.4, 0.8), Color(0.85, 0.93, 1.0), _rng.randi() % 3])
	for i in 8:
		_bits.append([at + Vector2(0, -2), Vector2(_rng.randf_range(-70, 70), _rng.randf_range(-120, -30)),
				_rng.randf_range(0.3, 0.6), LIQUID[idx], -1])
	# The blue flask holds plain water: it joins the level's fluid.
	if idx == 2:
		for i in 6:
			Ix.spawn_water(self, at + Vector2(_rng.randf_range(-4, 4), -4), Vector2(_rng.randf_range(-60, 60), -40))


func _draw() -> void:
	# Brackets + plank.
	draw_texture(TEX_BRACKET, Vector2(2, 5))
	draw_texture_rect_region(TEX_BRACKET, Rect2(width - 8, 5, -6, 8), Rect2(0, 0, 6, 8))
	Ix.htile(self, TEX_PLANK, Vector2(0, 0), width)
	for it in _items:
		if it[2] != 0:
			continue
		var tex: Texture2D = TEX_FLASKS[it[1]]
		var wob: float = sin(_t * 40.0 + it[0]) * 0.12 * it[3]
		draw_set_transform(Vector2(it[0], 0), wob)
		draw_texture(tex, Vector2(-floorf(tex.get_width() / 2.0), -tex.get_height()))
		draw_set_transform(Vector2.ZERO)
	var inv := get_global_transform().affine_inverse()
	for f in _falling:
		var tex2: Texture2D = TEX_FLASKS[f[4]]
		draw_set_transform((inv * (f[0] as Vector2)).round(), f[2])
		draw_texture(tex2, -tex2.get_size() / 2.0)
		draw_set_transform(Vector2.ZERO)
	for b in _bits:
		var lp := (inv * (b[0] as Vector2)).round()
		var a := clampf(b[2] * 3.0, 0.0, 1.0)
		if b[4] >= 0:
			var c: Color = b[3]
			c.a = a
			draw_texture(TEX_SHARDS[b[4]], lp - Vector2(2, 2), c)
		else:
			var c2: Color = b[3]
			c2.a = a
			draw_rect(Rect2(lp, Vector2(1, 1)), c2)
