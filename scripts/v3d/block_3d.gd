@tool
class_name Block3D
extends StaticBody3D
## Solid 3D level piece: a box of `size` metres CENTRED on the node origin.
##  WALL      blocks everything (layer 1)
##  GRATE     blocks only ICE (layer 2) - see-through bars
##  BREAKABLE blocks everything; ICE hitting it fast shatters it (layer 4)
##  GLASS     lab glass, blocks the blob but not the camera probe (layer 32)
##  DECOR     no collision (furniture, trims, background shapes)
## Texture art comes from the level theme (EnvTheme) and maps 32 px per metre.

enum Kind { WALL, GRATE, BREAKABLE, GLASS, DECOR }
enum Look { AUTO, WALL, FILL, DARK, METAL, GLOW }

const SHARD_TEX: Array[Texture2D] = [
	preload("res://assets/env/e3c_shard_1.png"),
	preload("res://assets/env/e3c_shard_2.png"),
	preload("res://assets/env/e3c_shard_3.png"),
]

@export var kind: Kind = Kind.WALL:
	set(v):
		kind = v
		_refresh()
@export var size := Vector3(4, 1, 4):
	set(v):
		size = v.max(Vector3(0.05, 0.05, 0.05))
		_refresh()
## Art override: AUTO picks from `kind`; METAL/GLOW are plain colour boxes (`tint`).
@export var look: Look = Look.AUTO:
	set(v):
		look = v
		_refresh()
@export var tint := Color.WHITE:
	set(v):
		tint = v
		_refresh()
## BREAKABLE only: impact speed (m/s) that shatters it. 0 = the blob's default
## (23 m/s, a long ICE fall). ~9 makes a thin cracked wall an ICE slide can smash.
@export var break_speed := 0.0
## Casts shadows (turn off for thin trims to save draw calls).
@export var cast_shadow := true:
	set(v):
		cast_shadow = v
		_refresh()

var broken := false
var _mesh: MeshInstance3D
var _shape: CollisionShape3D


func _ready() -> void:
	_refresh()


func _refresh() -> void:
	if not is_inside_tree():
		return
	if _mesh == null:
		_mesh = V3D.add_internal(self, MeshInstance3D.new())
		_shape = V3D.add_internal(self, CollisionShape3D.new())
	var bm := BoxMesh.new()
	bm.size = size
	_mesh.mesh = bm
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadow and kind != Kind.GLASS else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh.material_override = _material()
	var bs := BoxShape3D.new()
	bs.size = size
	_shape.shape = bs
	_shape.disabled = kind == Kind.DECOR or broken
	collision_mask = 0
	match kind:
		Kind.WALL: collision_layer = V3D.L_WORLD
		Kind.GRATE: collision_layer = V3D.L_GRATE
		Kind.BREAKABLE: collision_layer = V3D.L_BREAKABLE
		Kind.GLASS: collision_layer = V3D.L_GLASS
		Kind.DECOR: collision_layer = 0


func _material() -> Material:
	var theme := EnvTheme.find_theme(self)
	if kind == Kind.GLASS:
		return V3D.glass_material()
	match look:
		Look.FILL: return V3D.world_material(theme, "fill", tint)
		Look.DARK: return V3D.world_material(theme, "dark", tint)
		Look.METAL: return V3D.flat_material(tint, 0.55, 0.45)
		Look.GLOW: return V3D.flat_material(tint, 0.0, 0.5, tint, 2.0)
		Look.WALL: return V3D.world_material(theme, "wall", tint)
	match kind:
		Kind.GRATE: return V3D.world_material(theme, "grate", tint)
		Kind.BREAKABLE: return V3D.world_material(theme, "cracked", tint)
	return V3D.world_material(theme, "wall", tint)


## World-space bounds of the box.
func get_aabb() -> AABB:
	return AABB(global_position - size / 2.0, size)


## ICE smashed into it. Drops collision at once, bursts into shards.
func shatter(impact := Vector3.ZERO) -> void:
	if broken:
		return
	broken = true
	collision_layer = 0
	_shape.set_deferred("disabled", true)
	_mesh.visible = false
	Sfx.play("shatter")
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = clampi(int(size.x * size.z * 6.0), 16, 64)
	p.lifetime = 1.4
	p.explosiveness = 0.95
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = size / 2.0
	p.direction = Vector3(0, 1, 0)
	p.spread = 70.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 6.0
	p.gravity = Vector3(0, -22, 0)
	p.angular_velocity_min = -360
	p.angular_velocity_max = 360
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	var m := BoxMesh.new()
	m.size = Vector3(0.18, 0.12, 0.16)
	m.material = V3D.world_material(EnvTheme.find_theme(self), "cracked", tint)
	p.mesh = m
	var dir := impact.normalized() if impact.length() > 0.1 else Vector3.DOWN
	p.direction = (-dir * 0.4 + Vector3.UP).normalized() if dir.y > -0.5 else Vector3(0, -0.2, 0)
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.6, false).timeout.connect(p.queue_free)
