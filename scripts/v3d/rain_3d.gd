@tool
class_name Rain3D
extends CPUParticles3D
## Night rain: thin streaks falling in a box that follows the active camera
## (so it costs the same however big the level is). Decor only.

@export var area := Vector3(26, 1, 26):
	set(v):
		area = v
		_refresh()
@export var height_above := 12.0
@export var fall_speed := 22.0
@export var wind := Vector3(-2.0, 0, 1.0)


func _ready() -> void:
	_refresh()


func _refresh() -> void:
	if not is_inside_tree():
		return
	amount = 420
	lifetime = (height_above + 6.0) / fall_speed
	preprocess = lifetime
	local_coords = false
	emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	emission_box_extents = area / 2.0
	direction = (Vector3.DOWN * fall_speed + wind).normalized()
	spread = 2.0
	gravity = Vector3.ZERO
	initial_velocity_min = fall_speed * 0.9
	initial_velocity_max = fall_speed * 1.1
	particle_flag_align_y = true
	var m := BoxMesh.new()
	m.size = Vector3(0.025, 0.55, 0.025)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.7, 0.8, 1.0, 0.35)
	mat.disable_fog = true
	m.material = mat
	mesh = m
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visibility_aabb = AABB(-area / 2.0 - Vector3(0, height_above + 8, 0), area + Vector3(0, height_above + 16, 0))


func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or not is_inside_tree():
		return
	var cam := get_viewport().get_camera_3d()
	if cam:
		var f := -cam.global_basis.z
		f.y = 0.0
		global_position = cam.global_position + f.normalized() * area.x * 0.3 + Vector3.UP * height_above
