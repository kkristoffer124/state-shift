@tool
class_name Pipe3D
extends MeshInstance3D
## Decorative pipe run (no collision): a cylinder of `length` along `axis`,
## centred on the origin, with flange rings every `flange_every` metres.
## Colour from the theme palette unless `color` is set (alpha > 0).

enum Axis { X, Y, Z }

@export var length := 4.0:
	set(v):
		length = maxf(v, 0.1)
		_refresh()
@export var radius := 0.18:
	set(v):
		radius = v
		_refresh()
@export var axis: Axis = Axis.X:
	set(v):
		axis = v
		_refresh()
@export var flange_every := 1.5:
	set(v):
		flange_every = v
		_refresh()
@export var color := Color(0, 0, 0, 0):
	set(v):
		color = v
		_refresh()

var _flanges: MultiMeshInstance3D


func _ready() -> void:
	_refresh()


func _refresh() -> void:
	if not is_inside_tree():
		return
	var pal := V3D.palette(EnvTheme.find_theme(self))
	var c: Color = color if color.a > 0.0 else pal.metal
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = length
	cm.radial_segments = 8
	cm.rings = 1
	mesh = cm
	material_override = V3D.flat_material(c, 0.6, 0.45)
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	match axis:
		Axis.X: rotation = Vector3(0, 0, PI / 2.0)
		Axis.Y: rotation = Vector3.ZERO
		Axis.Z: rotation = Vector3(PI / 2.0, 0, 0)
	if _flanges == null:
		_flanges = V3D.add_internal(self, MultiMeshInstance3D.new())
	var fm := CylinderMesh.new()
	fm.top_radius = radius * 1.35
	fm.bottom_radius = radius * 1.35
	fm.height = 0.12
	fm.radial_segments = 8
	fm.rings = 1
	fm.material = V3D.flat_material(c * 0.75, 0.6, 0.5)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = fm
	var n := maxi(int(length / maxf(flange_every, 0.3)), 0) + 1
	mm.instance_count = n
	for i in n:
		var y := -length / 2.0 + 0.1 + (length - 0.2) * (float(i) / maxf(n - 1, 1))
		mm.set_instance_transform(i, Transform3D(Basis(), Vector3(0, y, 0)))
	_flanges.multimesh = mm
	_flanges.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
