@tool
class_name Skyline3D
extends MultiMeshInstance3D
## Night city around the rooftops: a ring of tower blocks (one MultiMesh, one draw
## call) with procedural lit windows, plus a far sky band (stars + moon art) and the
## moon itself. Decor only; seeded so it looks the same every run.

const SH_CITY := preload("res://shaders/v3d/skyline.gdshader")
const SH_SKY := preload("res://shaders/v3d/far_sky.gdshader")
const TEX_SKY := preload("res://assets/cutscenes/sky_tall.png")
const TEX_MOON := preload("res://assets/cutscenes/glow_moon.png")

@export var radius_min := 45.0:
	set(v):
		radius_min = v
		_refresh()
@export var radius_max := 90.0:
	set(v):
		radius_max = v
		_refresh()
@export var count := 90:
	set(v):
		count = v
		_refresh()
## Rooftop height of the player's buildings; towers poke above and below it.
@export var base_y := -30.0
@export var seed_value := 47:
	set(v):
		seed_value = v
		_refresh()
## Direction (from the centre) where the moon hangs in the sky.
@export var moon_dir := Vector3(-0.6, 0.35, -0.7)

var _sky: MeshInstance3D
var _moon: Sprite3D


func _ready() -> void:
	_refresh()


func _refresh() -> void:
	if not is_inside_tree():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	var mat := ShaderMaterial.new()
	mat.shader = SH_CITY
	box.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = false
	mm.mesh = box
	mm.instance_count = count
	for i in count:
		var a := rng.randf() * TAU
		var r := rng.randf_range(radius_min, radius_max)
		var w := rng.randf_range(6.0, 14.0)
		var d := rng.randf_range(6.0, 14.0)
		var top := rng.randf_range(-6.0, 22.0) * (0.6 + r / radius_max * 0.6)
		var h := top - base_y
		var pos := Vector3(cos(a) * r, base_y + h / 2.0, sin(a) * r)
		var b := Basis(Vector3.UP, rng.randf() * 0.4).scaled(Vector3(w, h, d))
		mm.set_instance_transform(i, Transform3D(b, pos))
	multimesh = mm
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if _sky == null:
		_sky = V3D.add_internal(self, MeshInstance3D.new())
		_moon = V3D.add_internal(self, Sprite3D.new())
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius_max * 1.6
	cyl.bottom_radius = radius_max * 1.6
	cyl.height = 160.0
	cyl.radial_segments = 24
	cyl.rings = 1
	cyl.cap_top = false
	cyl.cap_bottom = false
	var sm := ShaderMaterial.new()
	sm.shader = SH_SKY
	sm.set_shader_parameter("sky_tex", TEX_SKY)
	cyl.material = sm
	_sky.mesh = cyl
	_sky.position = Vector3(0, 40, 0)
	_sky.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_moon.texture = TEX_MOON
	_moon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_moon.shaded = false
	_moon.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_moon.pixel_size = 0.22
	_moon.fixed_size = false
	_moon.position = moon_dir.normalized() * radius_max * 1.3
	_moon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_moon.render_priority = -1


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	# The sky band and moon travel with the camera so they stay "infinitely" far.
	var cam := get_viewport().get_camera_3d()
	if cam and _sky:
		var c := cam.global_position
		_sky.global_position = Vector3(c.x, 40.0, c.z)
		_moon.global_position = Vector3(c.x, 0, c.z) + moon_dir.normalized() * radius_max * 1.3
