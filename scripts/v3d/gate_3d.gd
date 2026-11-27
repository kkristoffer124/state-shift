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
var _lamp_pos := Vector3.ZERO
## Physics-tick positions for smooth rendering between ticks (60 Hz web physics).
var _prev_pos := Vector3.ZERO
var _cur_pos := Vector3.ZERO
var _jolt := 0.0


func _ready() -> void:
	_base = position
	_prev_pos = position
	_cur_pos = position
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
		_prev_pos = position
		_cur_pos = position
		_paint()


func _refresh() -> void:
	if not is_inside_tree():
		return
	if _mesh == null:
		_mesh = V3D.add_internal(self, MeshInstance3D.new())
		_shape = V3D.add_internal(self, CollisionShape3D.new())
		_lamp = V3D.add_internal(self, MeshInstance3D.new())
	_mesh.mesh = V3D.box_mesh(size)
	_mesh.material_override = V3D.world_material(EnvTheme.find_theme(self), "gate")
	var bs := BoxShape3D.new()
	bs.size = size
	_shape.shape = bs
	var lm := BoxMesh.new()
	lm.size = Vector3(size.x + 0.04, 0.1, size.z + 0.04) if size.y > size.x * 0.5 else Vector3(0.3, size.y + 0.04, 0.3)
	_lamp.mesh = lm
	_lamp_pos = Vector3(0, size.y / 2.0 - 0.12, 0) if size.y > size.x * 0.5 else Vector3.ZERO
	_lamp.position = _lamp_pos
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
	_jolt = 1.0
	Sfx.play("door", 0.0)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_prev_pos = _cur_pos
	var goal := 1.0 if is_open else 0.0
	if goal == _open or (goal < _open and _player_in_way()):
		_cur_pos = position
		return
	_open = move_toward(_open, goal, delta / maxf(duration, 0.05))
	if _open == goal:
		_jolt = 1.0
	var e := _open * _open * (3.0 - 2.0 * _open)
	position = _base + open_offset * e
	_cur_pos = position


## Visuals: interpolate between physics ticks, a small unlatch jolt before the slide
## and a settle bounce when it arrives.
func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _mesh == null:
		return
	var f := clampf(Engine.get_physics_interpolation_fraction(), 0.0, 1.0)
	var vis := _prev_pos.lerp(_cur_pos, f) if _prev_pos.distance_to(_cur_pos) < 1.0 else _cur_pos
	_jolt = maxf(_jolt - delta * 3.0, 0.0)
	var settle := 0.0
	if _open <= 0.0 or _open >= 1.0:
		settle = sin(_jolt * 14.0) * _jolt * 0.04 * (1.0 if _open >= 1.0 else -1.0)
	var off := vis - position
	if open_offset.length() > 0.0:
		off += open_offset.normalized() * settle
	_mesh.position = off
	_lamp.position = _lamp_pos + off


func _player_in_way() -> bool:
	var lv := V3D.level_of(self)
	var p: Node3D = lv.get_node_or_null("Player") if lv else null
	if p == null:
		return false
	var closed := AABB(get_parent().to_global(_base) - size / 2.0 - Vector3.ONE * 0.5, size + Vector3.ONE)
	return closed.has_point(p.global_position)
