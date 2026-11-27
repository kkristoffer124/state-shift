@tool
class_name SteamJet3D
extends CPUParticles3D
## Ambient steam puffs from a vent or valve (decor only), along local +Y.
## Puffs for `burst_time` seconds every `period` seconds (period 0 = continuous).

const TEX_PUFF := preload("res://assets/player/p3a_puff_2.png")

@export var height := 2.5:
	set(v):
		height = v
		_refresh()
@export var period := 3.0
@export var burst_time := 1.0
@export var phase := 0.0

var _t := 0.0


func _ready() -> void:
	_t = phase
	_refresh()


func _refresh() -> void:
	if not is_inside_tree():
		return
	amount = 14
	lifetime = 1.3
	local_coords = false
	direction = Vector3.UP
	spread = 12.0
	initial_velocity_min = height / lifetime * 1.2
	initial_velocity_max = height / lifetime * 1.6
	damping_min = 1.0
	damping_max = 2.0
	gravity = Vector3(0, 0.5, 0)
	emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	emission_sphere_radius = 0.12
	scale_amount_min = 0.6
	scale_amount_max = 1.0
	var c := Curve.new()
	c.add_point(Vector2(0, 0.35))
	c.add_point(Vector2(0.5, 1.0))
	c.add_point(Vector2(1, 1.4))
	c.max_value = 1.5
	scale_amount_curve = c
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.5))
	g.set_color(1, Color(1, 1, 1, 0.0))
	color_ramp = g
	var q := QuadMesh.new()
	q.size = Vector2(0.9, 0.9)
	q.material = V3D.sprite_material(TEX_PUFF, false, BaseMaterial3D.BILLBOARD_PARTICLES)
	mesh = q


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or period <= 0.0:
		return
	_t += delta
	emitting = fmod(_t, period) < burst_time
