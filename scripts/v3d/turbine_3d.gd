@tool
class_name Turbine3D
extends Area3D
## Steam turbine. Drifting through it as STEAM spins the rotor; spin it up for
## `charge_time` seconds and it powers `channel` (latched). ORIGIN = rotor centre,
## the rotor axis is the node's local Y (rotate the node to mount it on a wall).

@export var channel := ""
@export var charge_time := 0.35
## Sensor radius (m). Bigger than the art so drifting steam reliably catches it.
@export var radius := 1.0:
	set(v):
		radius = v
		_refresh()
## Draws a mounting pole this many metres along local +Y (0 = none).
@export var pole_length := 0.0:
	set(v):
		pole_length = maxf(v, 0.0)
		_refresh()

var charged := false
var _charge := 0.0
var _spin := 0.0
var _vis_spin := 0.0
var _flash := 0.0
var _rotor: Node3D
var _ticks: Array[MeshInstance3D] = []
var _vis: Node3D
var _shape: CollisionShape3D
var _light: OmniLight3D


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
	var s := SphereShape3D.new()
	s.radius = radius
	_shape.shape = s
	if _vis:
		_vis.queue_free()
	_ticks.clear()
	_vis = V3D.add_internal(self, Node3D.new())
	var steel := V3D.metal_material(Color("5d7b93"), 0.7)
	var dark := V3D.metal_material(Color("2a3644"), 0.4)
	# Housing ring: 8 boxes in a circle.
	var rr := 0.62
	for i in 8:
		var a := i * TAU / 8.0
		var b := MeshInstance3D.new()
		b.mesh = V3D.box_mesh(Vector3(0.5, 0.22, 0.14))
		b.material_override = steel
		b.position = Vector3(cos(a), 0, sin(a)) * rr
		b.rotation.y = -a + PI / 2.0
		_vis.add_child(b)
	var hub := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.12
	cm.bottom_radius = 0.12
	cm.height = 0.3
	cm.radial_segments = 8
	hub.mesh = cm
	hub.material_override = dark
	_vis.add_child(hub)
	_rotor = Node3D.new()
	_vis.add_child(_rotor)
	var blade := V3D.metal_material(Color("b8d4ea"), 0.8)
	for i in 6:
		var b := MeshInstance3D.new()
		b.mesh = V3D.box_mesh(Vector3(0.46, 0.03, 0.16))
		b.material_override = blade
		var a := i * TAU / 6.0
		b.position = Vector3(cos(a), 0, sin(a)) * 0.3
		b.rotation = Vector3(0.5, -a, 0)
		_rotor.add_child(b)
	# Charge ticks around the rim.
	if channel != "":
		for i in 12:
			var a := i * TAU / 12.0
			var t := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.07, 0.26, 0.07)
			t.mesh = bm
			t.position = Vector3(cos(a), 0, sin(a)) * 0.76
			_vis.add_child(t)
			_ticks.append(t)
	if pole_length > 0.0:
		var pole := MeshInstance3D.new()
		pole.mesh = V3D.box_mesh(Vector3(0.12, pole_length, 0.12))
		pole.material_override = steel
		pole.position = Vector3(0, 0.15 + pole_length / 2.0, 0)
		_vis.add_child(pole)
	_light = OmniLight3D.new()
	_light.light_color = V3D.C_GOAL
	_light.light_energy = 0.0
	_light.omni_range = 3.5
	_vis.add_child(_light)
	_paint_ticks()


func _paint_ticks() -> void:
	var n := _ticks.size()
	var lit := n if charged else int(round(_charge / maxf(charge_time, 0.01) * n))
	for i in n:
		var c := Color("18222d")
		var e := 0.0
		if i < lit:
			c = V3D.C_GOAL if charged else V3D.C_HEAT
			e = 2.0
		if _flash > 0.0 and int(_flash * 16.0) % 2 == 0:
			c = Color.WHITE
			e = 3.0
		_ticks[i].material_override = V3D.flat_material(c, 0.0, 0.5, c, e)


## Rotor turns every rendered frame (smooth at any refresh rate); speed eases toward
## the physics-driven `_spin` so spin-up / spin-down never steps.
func _process(delta: float) -> void:
	if _rotor == null:
		return
	if Engine.is_editor_hint():
		_rotor.rotate_y(delta * 2.0)
		return
	_vis_spin = lerpf(_vis_spin, _spin, 1.0 - exp(-4.0 * delta))
	_rotor.rotate_y(_vis_spin * delta)
	# A slight hum-wobble of the whole housing while it's spinning hard.
	_vis.rotation.x = sin(Time.get_ticks_msec() * 0.031) * clampf(_vis_spin / 40.0, 0.0, 1.0) * 0.025


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var steam := false
	for b in get_overlapping_bodies():
		if V3D.state_of(b) == 2:
			steam = true
			_spin += b.velocity.length() * 2.5 * delta + 30.0 * delta
	# Inertia: steam drives the rotor up, it coasts down slowly; once charged it idles.
	var idle := 4.0 if charged else 0.0
	_spin = clampf(_spin - (_spin - idle) * 0.6 * delta, 0.0, 40.0)
	var before := int(round(_charge / maxf(charge_time, 0.01) * 12))
	if channel != "" and not charged:
		_charge = clampf(_charge + (delta if steam else -delta * 0.5), 0.0, charge_time)
		if _charge >= charge_time:
			charged = true
			_flash = 0.6
			V3D.emit(self, channel, true)
			Sfx.play("select", 0.0)
	var was_flash := _flash > 0.0
	_flash = maxf(_flash - delta, 0.0)
	if _light:
		_light.light_energy = lerpf(_light.light_energy, 1.5 if charged else 0.0, delta * 3.0)
	if was_flash or before != int(round(_charge / maxf(charge_time, 0.01) * 12)):
		_paint_ticks()
