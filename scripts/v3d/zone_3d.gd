@tool
class_name Zone3D
extends Area3D
## 3D trigger volume: a box of `size` metres CENTRED on the origin. "Up" is the
## node's local +Y, so rotate the node to point spikes/fans another way.
##  SPIKES  kill WATER and STEAM (ICE is safe). Spikes sit on the local bottom face.
##  HEAT    forces STEAM while inside (vent grill at the bottom, haze rising)
##  FREEZE  forces ICE while inside (emitter at the top, snow falling)
##  FAN     pushes STEAM (and a little WATER) along local +Y (housing at the bottom)
##  GOAL    finishes the level

enum Kind { SPIKES, HEAT, FREEZE, FAN, GOAL }

const TEX_EMBER := preload("res://assets/env/e5c_ember.png")
const TEX_SNOW := preload("res://assets/env/e6c_snowflake_1.png")
const TEX_GOAL_SWIRL := preload("res://assets/env/e8a_goal_swirl.png")
const TEX_GOAL_GLOW := preload("res://assets/env/e8b_goal_glow.png")
const TEX_SPARKLE := preload("res://assets/env/e8c_sparkle_1.png")
const SH_HAZE := preload("res://shaders/v3d/haze_column.gdshader")

@export var kind: Kind = Kind.SPIKES:
	set(v):
		kind = v
		_refresh()
@export var size := Vector3(2, 1, 2):
	set(v):
		size = v.max(Vector3(0.1, 0.1, 0.1))
		_refresh()
## FAN: local push direction (default along the node's +Y).
@export var push_direction := Vector3.UP
## FAN: acceleration in m/s^2 (2D 1500 px/s^2 = 47).
@export var push_strength := 47.0
## Adds a small coloured light (heat/freeze/goal). Off to save lights.
@export var with_light := true:
	set(v):
		with_light = v
		_refresh()

var _t := 0.0
var _spin_goal := 0.0
var _vis: Node3D
var _shape: CollisionShape3D
var _blades: Node3D
var _swirl: Sprite3D
var _glow: Sprite3D
var _goal_light: OmniLight3D
var _absorb := 0.0
var _player: Node3D


func _ready() -> void:
	collision_layer = V3D.L_ZONES
	collision_mask = 0
	monitoring = false
	monitorable = true
	_refresh()


func push_vector() -> Vector3:
	return (global_basis * push_direction).normalized() * push_strength


func _process(delta: float) -> void:
	_t += delta
	if _blades:
		_blades.rotate_y(delta * 14.0)
	if _swirl:
		_animate_goal(delta)


func _refresh() -> void:
	if not is_inside_tree():
		return
	if _shape == null:
		_shape = V3D.add_internal(self, CollisionShape3D.new())
	var bs := BoxShape3D.new()
	var s := size
	if kind == Kind.SPIKES:
		s.y = maxf(size.y - 0.3, 0.15) # forgiving hitbox (like the 2D one)
		s.x = maxf(size.x - 0.1, 0.1)
		s.z = maxf(size.z - 0.1, 0.1)
		_shape.position = Vector3(0, -size.y / 2.0 + s.y / 2.0, 0)
	else:
		_shape.position = Vector3.ZERO
	bs.size = s
	_shape.shape = bs
	if _vis:
		_vis.queue_free()
	_blades = null
	_swirl = null
	_glow = null
	_goal_light = null
	_vis = V3D.add_internal(self, Node3D.new())
	var theme := EnvTheme.find_theme(self)
	match kind:
		Kind.SPIKES: _build_spikes(theme)
		Kind.HEAT: _build_heat(theme)
		Kind.FREEZE: _build_freeze(theme)
		Kind.FAN: _build_fan(theme)
		Kind.GOAL: _build_goal()


func _box(sz: Vector3, pos: Vector3, mat: Material, shadow := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = V3D.box_mesh(sz)
	mi.material_override = mat
	mi.position = pos
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_vis.add_child(mi)
	return mi


func _light(color: Color, energy: float, rng: float, pos: Vector3) -> void:
	if not with_light:
		return
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = rng
	l.position = pos
	_vis.add_child(l)


## Two crossed glowing planes filling the volume.
func _haze(color: Color, direction: float) -> void:
	var m := ShaderMaterial.new()
	m.shader = SH_HAZE
	m.set_shader_parameter("color", color)
	m.set_shader_parameter("direction", direction)
	for i in 2:
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(size.x if i == 0 else size.z, size.y)
		mi.mesh = q
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if i == 1:
			mi.rotation.y = PI / 2.0
		_vis.add_child(mi)


func _particles(tex: Texture2D, amount: int, life: float, vel: Vector3, grav: Vector3, scale_px: float, additive: bool, color := Color.WHITE) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.local_coords = true
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.direction = vel.normalized() if vel.length() > 0.0 else Vector3.UP
	p.spread = 8.0
	p.initial_velocity_min = vel.length() * 0.7
	p.initial_velocity_max = vel.length() * 1.2
	p.gravity = grav
	var q := QuadMesh.new()
	q.size = Vector2(scale_px, scale_px) * V3D.PX * (tex.get_width() if tex else 4)
	q.material = V3D.sprite_material(tex, additive, BaseMaterial3D.BILLBOARD_PARTICLES, color)
	p.mesh = q
	p.preprocess = life
	_vis.add_child(p)
	return p


func _build_spikes(theme: String) -> void:
	var pal := V3D.palette(theme)
	var plate_h := 0.12
	_box(Vector3(size.x, plate_h, size.z), Vector3(0, -size.y / 2.0 + plate_h / 2.0, 0), V3D.metal_material(Color(pal.metal) * 0.7, 0.6))
	var h := clampf(size.y - plate_h, 0.2, 0.75)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.2
	cone.height = h
	cone.radial_segments = 4
	cone.rings = 1
	cone.material = V3D.metal_material(Color("c9d3dc"), 0.85)
	var nx := maxi(1, int(round(size.x / 0.5)))
	var nz := maxi(1, int(round(size.z / 0.5)))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = cone
	mm.instance_count = nx * nz
	var i := 0
	for ix in nx:
		for iz in nz:
			var x := -size.x / 2.0 + (ix + 0.5) * size.x / nx
			var z := -size.z / 2.0 + (iz + 0.5) * size.z / nz
			var hh := h * (0.85 + 0.15 * sin(ix * 2.3 + iz * 1.7))
			var tr := Transform3D(Basis().rotated(Vector3.UP, PI / 4.0).scaled(Vector3(1, hh / h, 1)), Vector3(x, -size.y / 2.0 + plate_h + hh / 2.0, z))
			mm.set_instance_transform(i, tr)
			i += 1
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	_vis.add_child(mmi)


func _build_heat(theme: String) -> void:
	var tex := EnvTheme.textures(theme)
	var grill := StandardMaterial3D.new()
	grill.albedo_texture = tex.heat_vent
	grill.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	grill.uv1_triplanar = true
	grill.uv1_world_triplanar = true
	grill.uv1_scale = Vector3(1, 1, 1) * 32.0 / 32.0
	grill.emission_enabled = true
	grill.emission = Color(1.0, 0.35, 0.08)
	grill.emission_energy_multiplier = 0.6
	_box(Vector3(size.x, 0.16, size.z), Vector3(0, -size.y / 2.0 + 0.08, 0), grill)
	_haze(Color(1.0, 0.38, 0.08, 0.55), 1.0)
	var p := _particles(TEX_EMBER, int(clampf(size.x * size.z * 3.0, 8, 40)), size.y / 2.5, Vector3(0, 2.5, 0), Vector3(0, 0.3, 0), 1.6, true, Color(1, 0.7, 0.3))
	p.emission_box_extents = Vector3(size.x / 2.0, 0.05, size.z / 2.0)
	p.position.y = -size.y / 2.0 + 0.2
	_light(Color(1.0, 0.45, 0.15), 1.4, maxf(size.x, size.z) + 2.5, Vector3(0, -size.y / 2.0 + 0.8, 0))


func _build_freeze(theme: String) -> void:
	var tex := EnvTheme.textures(theme)
	var em := StandardMaterial3D.new()
	em.albedo_texture = tex.freeze_emitter
	em.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	em.uv1_triplanar = true
	em.uv1_world_triplanar = true
	em.emission_enabled = true
	em.emission = Color(0.5, 0.85, 1.0)
	em.emission_energy_multiplier = 0.5
	_box(Vector3(size.x, 0.2, size.z), Vector3(0, size.y / 2.0 - 0.1, 0), em)
	_haze(Color(0.45, 0.85, 1.0, 0.45), -1.0)
	var p := _particles(TEX_SNOW, int(clampf(size.x * size.z * 3.0, 8, 40)), size.y / 1.2, Vector3(0, -1.2, 0), Vector3(0, -0.2, 0), 1.5, false)
	p.emission_box_extents = Vector3(size.x / 2.0, 0.05, size.z / 2.0)
	p.position.y = size.y / 2.0 - 0.25
	_light(Color(0.5, 0.85, 1.0), 1.1, maxf(size.x, size.z) + 2.5, Vector3(0, size.y / 2.0 - 0.6, 0))


func _build_fan(theme: String) -> void:
	var pal := V3D.palette(theme)
	var base_y := -size.y / 2.0
	var hous := V3D.world_material(theme, "dark")
	var rim := V3D.metal_material(Color(pal.metal), 0.6)
	# Housing ring (4 bars) around the fan opening.
	var t := 0.18
	var hh := 0.5
	_box(Vector3(size.x, hh, t), Vector3(0, base_y + hh / 2.0, -size.z / 2.0 + t / 2.0), hous)
	_box(Vector3(size.x, hh, t), Vector3(0, base_y + hh / 2.0, size.z / 2.0 - t / 2.0), hous)
	_box(Vector3(t, hh, size.z), Vector3(-size.x / 2.0 + t / 2.0, base_y + hh / 2.0, 0), hous)
	_box(Vector3(t, hh, size.z), Vector3(size.x / 2.0 - t / 2.0, base_y + hh / 2.0, 0), hous)
	_box(Vector3(size.x - 2 * t, 0.06, size.z - 2 * t), Vector3(0, base_y + 0.03, 0), V3D.metal_material(Color(0.12, 0.13, 0.15), 0.2), false)
	# Spinning blades.
	_blades = Node3D.new()
	_blades.position = Vector3(0, base_y + 0.25, 0)
	_vis.add_child(_blades)
	var r := minf(size.x, size.z) / 2.0 - t - 0.05
	var blade_mat := V3D.metal_material(Color(pal.metal) * 1.25, 0.7)
	for i in 4:
		var b := MeshInstance3D.new()
		b.mesh = V3D.box_mesh(Vector3(r, 0.04, 0.32))
		b.material_override = blade_mat
		b.position = Vector3(cos(i * PI / 2.0), 0, sin(i * PI / 2.0)) * r / 2.0
		b.rotation = Vector3(0.35, -i * PI / 2.0, 0)
		_blades.add_child(b)
	var hub := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.14
	cm.bottom_radius = 0.14
	cm.height = 0.12
	cm.radial_segments = 8
	hub.mesh = cm
	hub.material_override = rim
	_blades.add_child(hub)
	# Airflow streaks along +Y.
	var p := CPUParticles3D.new()
	p.amount = int(clampf(size.x * size.z * 2.0, 10, 40))
	var speed := 9.0
	p.lifetime = maxf((size.y - 0.4) / speed, 0.2)
	p.local_coords = true
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(size.x / 2.0 - t, 0.05, size.z / 2.0 - t)
	p.position.y = base_y + 0.45
	p.direction = Vector3.UP
	p.spread = 0.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = speed * 0.8
	p.initial_velocity_max = speed * 1.2
	var sm := BoxMesh.new()
	sm.size = Vector3(0.035, 0.7, 0.035)
	var smat := StandardMaterial3D.new()
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	smat.albedo_color = Color(0.75, 0.9, 1.0, 0.45)
	sm.material = smat
	p.mesh = sm
	p.preprocess = p.lifetime
	_vis.add_child(p)


func _build_goal() -> void:
	var glow := Sprite3D.new()
	glow.texture = TEX_GOAL_GLOW
	glow.pixel_size = V3D.PX
	glow.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	glow.shaded = false
	glow.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	glow.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	glow.modulate = Color(1, 1, 1, 0.8)
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_vis.add_child(glow)
	_glow = glow
	_swirl = Sprite3D.new()
	_swirl.texture = TEX_GOAL_SWIRL
	_swirl.pixel_size = V3D.PX * 1.1
	_swirl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_swirl.shaded = false
	_swirl.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_swirl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_swirl.render_priority = 1
	_vis.add_child(_swirl)
	var p := _particles(TEX_SPARKLE, 14, 1.4, Vector3(0, 0.8, 0), Vector3.ZERO, 1.6, true, Color(0.6, 1, 0.75))
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = minf(size.x, size.y) * 0.55
	p.spread = 180.0
	_light(V3D.C_GOAL, 1.6, 5.0, Vector3.ZERO)
	for c in _vis.get_children():
		if c is OmniLight3D:
			_goal_light = c


## Light pillar rising from the goal so "where next" reads from anywhere in the room
## (Level3D adds it in the isometric / third-person chapters). `through` draws it over
## walls (isometric).
func add_beacon(through: bool) -> void:
	if _vis == null or kind != Kind.GOAL:
		return
	var h := 14.0
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.55
	mesh.bottom_radius = 0.75
	mesh.height = h
	mesh.radial_segments = 16
	mesh.rings = 1
	mesh.cap_top = false
	mesh.cap_bottom = false
	var grad := Gradient.new()
	grad.set_color(0, Color(V3D.C_GOAL, 0.0))
	grad.set_color(1, Color(V3D.C_GOAL, 0.45 if through else 0.35))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	tex.width = 4
	tex.height = 64
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = through
	m.albedo_texture = tex
	m.disable_receive_shadows = true
	var beam := MeshInstance3D.new()
	beam.name = "Beacon"
	beam.mesh = mesh
	beam.material_override = m
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam.position = Vector3(0, h / 2.0 - size.y * 0.4, 0)
	_vis.add_child(beam)


## Goal swirl: idle spin + breathing bob; leans its pull toward a nearby blob; when
## the blob wins it spins up, flares and swallows it (scale pulse, light flash).
func _animate_goal(delta: float) -> void:
	if _player == null and not Engine.is_editor_hint():
		var lv := V3D.level_of(self)
		if lv:
			_player = lv.get_node_or_null("Player")
	var won: bool = _player != null and _player.get("won") == true
	_absorb = move_toward(_absorb, 1.0 if won else 0.0, delta * 1.6)
	var a := _absorb
	var near := 0.0
	if _player and not won:
		near = clampf(1.0 - global_position.distance_to(_player.global_position) / 4.0, 0.0, 1.0)
	_spin_goal += delta * (2.5 + near * 2.0 + a * 14.0)
	_swirl.rotation.z = -_spin_goal
	var breathe := 1.0 + sin(_t * 2.2) * 0.06
	var pulse := 1.0 + a * 0.6 * sin(minf(a, 1.0) * PI) + a * 0.25
	_swirl.scale = Vector3.ONE * breathe * pulse * (1.0 + near * 0.12)
	_swirl.position.y = sin(_t * 1.6) * 0.08
	_swirl.modulate.a = clampf(0.85 + sin(_t * 3.0) * 0.15 - maxf(a - 0.7, 0.0) * 2.0, 0.0, 1.0)
	if _glow:
		_glow.scale = Vector3.ONE * (1.0 + sin(_t * 2.2 + 0.6) * 0.08 + a * 0.9)
		_glow.modulate.a = clampf(0.8 + near * 0.2 - maxf(a - 0.75, 0.0) * 3.0, 0.0, 1.0)
	if _goal_light:
		_goal_light.light_energy = 1.6 + sin(_t * 2.2) * 0.25 + near * 0.6 + sin(minf(a, 1.0) * PI) * 3.0
