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
var _pad_y := 0.1
var _pad_v := 0.0


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
	# Hazard-striped rim around the pad.
	_base.mesh = V3D.box_mesh(Vector3(size.x + 0.32, 0.06, size.y + 0.32))
	_base.position.y = 0.03
	_base.material_override = V3D.hazard_material()
	_pad.mesh = V3D.box_mesh(Vector3(size.x, 0.1, size.y))
	_paint()
	_pad.position.y = _pad_y


func _paint() -> void:
	var c := V3D.C_GOAL if pressed else Color("d9a43a")
	_pad.material_override = V3D.glow_material(c, 0.9 if pressed else 0.35, 0.0)


## Pad eases down when pressed (with a little give) and springs back up when released.
func _process(delta: float) -> void:
	if _pad == null:
		return
	var want := 0.035 if pressed else 0.1
	_pad_v += ((want - _pad_y) * 900.0 - _pad_v * 38.0) * minf(delta, 0.05)
	_pad_y = clampf(_pad_y + _pad_v * minf(delta, 0.05), 0.02, 0.12)
	_pad.position.y = _pad_y


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
