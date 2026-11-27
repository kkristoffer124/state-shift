@tool
class_name Gate3D
extends AnimatableBody3D
## Solid shutter / hatch (layer 1) opened by a channel. A box of `size` CENTRED on
## the origin when closed; opening slides it by `open_offset` (parent space).
## A status lamp on top shows red (shut) / green (open). Never closes onto the player.

@export var channel := "a"
@export var size := Vector3(2, 3, 0.3):
	set(v):
		size = v.max(Vector3(0.05, 0.05, 0.05))
		_refresh()
@export var open_offset := Vector3(0, -3, 0)
@export var duration := 0.8
## Open when the channel is OFF instead.
@export var inverted := false
## Needs this many distinct sources on at once (e.g. two plates).
@export var sources_needed := 1

var is_open := false
var _open := 0.0
var _sources := {}
var _base := Vector3.ZERO
var _mesh: MeshInstance3D
var _shape: CollisionShape3D
var _lamp: MeshInstance3D


func _ready() -> void:
	_base = position
	collision_layer = V3D.L_WORLD
	collision_mask = 0
	sync_to_physics = true
	_refresh()
	if Engine.is_editor_hint():
		return
	add_to_group("v3d_receivers")
	if inverted:
		is_open = true
		_open = 1.0
		position = _base + open_offset
		_paint()


func _refresh() -> void:
	if not is_inside_tree():
		return
	if _mesh == null:
		_mesh = V3D.add_internal(self, MeshInstance3D.new())
		_shape = V3D.add_internal(self, CollisionShape3D.new())
		_lamp = V3D.add_internal(self, MeshInstance3D.new())
	var bm := BoxMesh.new()
	bm.size = size
	_mesh.mesh = bm
	_mesh.material_override = V3D.world_material(EnvTheme.find_theme(self), "gate")
	var bs := BoxShape3D.new()
	bs.size = size
	_shape.shape = bs
	var lm := BoxMesh.new()
	lm.size = Vector3(size.x + 0.04, 0.1, size.z + 0.04) if size.y > size.x * 0.5 else Vector3(0.3, size.y + 0.04, 0.3)
	_lamp.mesh = lm
	_lamp.position = Vector3(0, size.y / 2.0 - 0.12, 0) if size.y > size.x * 0.5 else Vector3.ZERO
	_lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_paint()


func _paint() -> void:
	if _lamp == null:
		return
	var c := V3D.C_GOAL if is_open else V3D.C_HEAT
	_lamp.material_override = V3D.flat_material(c, 0.0, 0.5, c, 2.5)


func _on_channel(source_id: int, on: bool) -> void:
	if on:
		_sources[source_id] = true
	else:
		_sources.erase(source_id)
	var want := (_sources.size() >= sources_needed) != inverted
	if want == is_open:
		return
	is_open = want
	_paint()
	Sfx.play("door", 0.0)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var goal := 1.0 if is_open else 0.0
	if goal == _open:
		return
	if goal < _open and _player_in_way():
		return
	_open = move_toward(_open, goal, delta / maxf(duration, 0.05))
	var e := _open * _open * (3.0 - 2.0 * _open)
	position = _base + open_offset * e


func _player_in_way() -> bool:
	var lv := V3D.level_of(self)
	var p: Node3D = lv.get_node_or_null("Player") if lv else null
	if p == null:
		return false
	var closed := AABB(get_parent().to_global(_base) - size / 2.0 - Vector3.ONE * 0.5, size + Vector3.ONE)
	return closed.has_point(p.global_position)
