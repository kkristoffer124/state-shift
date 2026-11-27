@tool
class_name Plate3D
extends Area3D
## Pressure plate on a floor. Only ICE is heavy enough to press it (unless
## `heavy_only` is off; STEAM never presses). ORIGIN = centre of the plate on the
## floor surface. Drives every receiver listening on `channel` while held.

@export var channel := "a"
@export var size := Vector2(1.4, 1.4):
	set(v):
		size = v
		_refresh()
@export var heavy_only := true
## Stays on once pressed.
@export var latch := false

var pressed := false
var _pad: MeshInstance3D
var _base: MeshInstance3D
var _shape: CollisionShape3D


func _ready() -> void:
	collision_layer = 0
	collision_mask = V3D.L_PLAYER
	monitoring = true
	monitorable = false
	_refresh()


func _refresh() -> void:
	if not is_inside_tree():
		return
	if _shape == null:
		_shape = V3D.add_internal(self, CollisionShape3D.new())
		_base = V3D.add_internal(self, MeshInstance3D.new())
		_pad = V3D.add_internal(self, MeshInstance3D.new())
	var bs := BoxShape3D.new()
	bs.size = Vector3(size.x, 0.6, size.y)
	_shape.shape = bs
	_shape.position.y = 0.3
	var bm := BoxMesh.new()
	bm.size = Vector3(size.x + 0.2, 0.06, size.y + 0.2)
	_base.mesh = bm
	_base.position.y = 0.03
	_base.material_override = V3D.flat_material(Color("2a3440"), 0.6, 0.5)
	var pm := BoxMesh.new()
	pm.size = Vector3(size.x, 0.1, size.y)
	_pad.mesh = pm
	_paint()


func _paint() -> void:
	var c := V3D.C_GOAL if pressed else Color("d9a43a")
	_pad.material_override = V3D.flat_material(c, 0.3, 0.5, c, 0.8 if pressed else 0.3)
	_pad.position.y = 0.04 if pressed else 0.1


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var on := false
	for b in get_overlapping_bodies():
		var s := V3D.state_of(b)
		if s == 0 or (s == 1 and not heavy_only):
			on = true
	if latch and pressed:
		on = true
	if on != pressed:
		pressed = on
		_paint()
		Sfx.play("blip" if on else "blip_low", 0.0)
		V3D.emit(self, channel, on)
