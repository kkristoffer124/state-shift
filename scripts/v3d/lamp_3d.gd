@tool
class_name Lamp3D
extends OmniLight3D
## Light with a small glowing fitting so it has a visible source.
## BULB (sphere), TUBE (strip along X), NONE (light only).

enum Fitting { BULB, TUBE, NONE }

@export var fitting: Fitting = Fitting.BULB:
	set(v):
		fitting = v
		_refresh()
@export var tube_length := 1.6:
	set(v):
		tube_length = v
		_refresh()
## Gentle flicker amount (0 = steady).
@export var flicker := 0.0

var _mesh: MeshInstance3D
var _base_energy := 1.0
var _t := 0.0


func _ready() -> void:
	_base_energy = light_energy
	_refresh()


func _refresh() -> void:
	if not is_inside_tree():
		return
	if _mesh == null:
		_mesh = V3D.add_internal(self, MeshInstance3D.new())
	_mesh.visible = fitting != Fitting.NONE
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	match fitting:
		Fitting.BULB:
			var s := SphereMesh.new()
			s.radius = 0.12
			s.height = 0.24
			s.radial_segments = 8
			s.rings = 4
			_mesh.mesh = s
		Fitting.TUBE:
			var b := BoxMesh.new()
			b.size = Vector3(tube_length, 0.08, 0.14)
			_mesh.mesh = b
	_mesh.material_override = V3D.flat_material(light_color, 0.0, 0.5, light_color, 3.0)


func _process(delta: float) -> void:
	if flicker <= 0.0 or Engine.is_editor_hint():
		return
	_t += delta
	var f := 1.0 - flicker * (0.5 + 0.5 * sin(_t * 23.0) * sin(_t * 7.3))
	if fmod(_t, 4.3) < 0.08:
		f *= 0.4
	light_energy = _base_energy * f
