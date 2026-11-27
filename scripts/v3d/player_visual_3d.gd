@tool
class_name PlayerVisual3D
extends Node3D
## Looks of the 3D blob (child "Visual" of Player3D):
##  ICE   translucent chamfered cube (2D ice art on each face, glinting bevels, cracks,
##        frost rim when locked); tips on a spring when it speeds up / brakes / hits walls
##  WATER wobbly vertex-shader sphere that leans like jelly and stretches into a teardrop
##        along its motion + splash droplets on land/jump
##  STEAM a cloud of breathing lobes (one merged mesh) that sways, trails behind its
##        motion and sheds wisps
## Shifting morphs: the old form shrinks and fades while the new one grows in with an
## overshoot (MORPH_TIME), eyes blink through it, plus the shift burst / ring.
## At runtime this node is top_level and follows Player3D.render_position(), i.e. it is
## interpolated between physics ticks (no judder when physics runs slower than the screen).
## Eyes are billboard sprites from assets/player placed on the surface of the body facing
## the camera (leaning toward where the blob is heading), smoothed, with irregular blinks.
## A soft blob shadow is projected straight down. Body meshes live on render layer 2
## (hidden in first person).

const TEX_EYE_WHITE := preload("res://assets/player/p4a_eye_white.png")
const TEX_PUPIL := preload("res://assets/player/p4b_pupil.png")
const TEX_BLINK := [preload("res://assets/player/p4d_blink_1.png"), preload("res://assets/player/p4d_blink_2.png")]
const TEX_EYES := {
	"blocked": preload("res://assets/player/p4e_eyes_blocked.png"),
	"determined": preload("res://assets/player/p4e_eyes_determined.png"),
	"dizzy": preload("res://assets/player/p4e_eyes_dizzy.png"),
	"happy": preload("res://assets/player/p4e_eyes_happy.png"),
	"scared": preload("res://assets/player/p4e_eyes_scared.png"),
}
const TEX_CRACKS := [
	preload("res://assets/player/p1b_ice_crack_light.png"),
	preload("res://assets/player/p1b_ice_crack_medium.png"),
	preload("res://assets/player/p1b_ice_crack_heavy.png"),
]

const MORPH_TIME := 0.28
const ICE_CHAMFER := 0.075
## Steam cloud lobes: [centre, radius] (m). The core lobe dominates; extent ~0.42.
const CLOUD_LOBES := [
	[Vector3(0.0, 0.0, 0.0), 0.3],
	[Vector3(0.2, -0.06, 0.04), 0.22],
	[Vector3(-0.2, -0.05, -0.02), 0.23],
	[Vector3(0.05, 0.17, -0.06), 0.22],
	[Vector3(-0.09, 0.13, 0.12), 0.18],
	[Vector3(0.12, -0.12, -0.16), 0.17],
	[Vector3(-0.06, -0.13, 0.17), 0.17],
	[Vector3(0.19, 0.1, 0.13), 0.15],
]
## Water body: radius of the sphere mesh and how its base sits (see water_blob shader).
const WATER_MESH_R := 0.37
const WATER_BOTTOM := 0.30

static var _ice_mesh: ArrayMesh
static var _cloud_mesh: ArrayMesh

@onready var ice: MeshInstance3D = $Ice
@onready var water: MeshInstance3D = $Water
@onready var steam: Node3D = $Steam
@onready var puffs: CPUParticles3D = $Steam/Puffs
@onready var cloud: MeshInstance3D = $Steam/Cloud
@onready var eyes: Node3D = $Eyes
@onready var white_l: Sprite3D = $Eyes/WhiteL
@onready var white_r: Sprite3D = $Eyes/WhiteR
@onready var pupil_l: Sprite3D = $Eyes/PupilL
@onready var pupil_r: Sprite3D = $Eyes/PupilR
@onready var expr: Sprite3D = $Eyes/Expr
@onready var splash: CPUParticles3D = $Splash
@onready var burst: CPUParticles3D = $Burst
@onready var ring: Sprite3D = $Ring
@onready var shadow: MeshInstance3D = $Shadow
@onready var light: OmniLight3D = $Glow

var _t := 0.0
var _shown := -1
var _from := -1
var _morph := 1.0
var _end := 1.0
# Springs / smoothed values.
var _acc := Vector3.ZERO
var _prev_vel := Vector3.ZERO
var _tilt := Vector2.ZERO
var _tilt_v := Vector2.ZERO
var _lean := Vector3.ZERO
var _lean_v := Vector3.ZERO
var _stretch := 0.0
var _stretch_dir := Vector2(1, 0)
var _drag := Vector3.ZERO
var _drag_v := Vector3.ZERO
var _glint := 0.0
# Eyes.
var _eye_dir := Vector3.ZERO
var _pupil := Vector2.ZERO
var _blink_in := 2.5
var _blink := -1.0
var _double_blink := false


func _ready() -> void:
	if _ice_mesh == null:
		_ice_mesh = _build_chamfer_box(Player3D.ICE_HALF, ICE_CHAMFER)
	if _cloud_mesh == null:
		_cloud_mesh = _build_cloud(CLOUD_LOBES)
	ice.mesh = _ice_mesh
	cloud.mesh = _cloud_mesh
	if Engine.is_editor_hint():
		return
	top_level = true
	shadow.top_level = true
	ring.visible = false
	_blink_in = randf_range(1.5, 4.0)
	for n in [ice, water, steam, eyes, ring, splash, burst]:
		V3D.set_render_layer(n, V3D.RL_BLOB)


func _player() -> Player3D:
	return get_parent() as Player3D


func on_shift(heating: bool) -> void:
	var p := _player()
	if _shown != -1 and _shown != p.state:
		_from = _shown
		_morph = 0.0
	_show_state(p.state)
	var col: Color = V3D.STATE_COLORS[p.state]
	burst.color = col
	burst.restart()
	if p.state == Player3D.State.WATER or _from == Player3D.State.WATER:
		splash.amount = 8
		splash.restart()
	ring.modulate = col
	ring.frame = 0
	ring.visible = true
	ring.global_position = global_position
	var tw := ring.create_tween()
	tw.tween_property(ring, "frame", 4, 0.25)
	tw.tween_callback(func() -> void: ring.visible = false)
	if p.rig:
		p.rig.flash(col, 0.35 if heating else 0.3)


func on_jump() -> void:
	splash.amount = 10
	splash.restart()


func on_land(_speed: float) -> void:
	if _player().state == Player3D.State.WATER:
		splash.restart()


func on_die(_vel: Vector3) -> void:
	var p := _player()
	burst.color = Color(1.0, 0.45, 0.45)
	burst.restart()
	if p.state != Player3D.State.ICE:
		splash.amount = 24
		splash.restart()
	if p.rig:
		p.rig.flash(Color(1.0, 0.3, 0.3), 0.6)


func on_win() -> void:
	burst.color = Color(0.6, 1.0, 0.7)
	burst.restart()


func _show_state(st: int) -> void:
	_shown = st
	puffs.emitting = st == Player3D.State.STEAM
	if _morph >= 1.0:
		light.light_color = V3D.STATE_COLORS[st]


# --- Per frame -----------------------------------------------------------------

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var p := _player()
	if p == null:
		return
	delta = minf(delta, 0.1)
	_t += delta
	global_position = p.render_position()
	var st := p.state
	if st != _shown:
		# Changed without on_shift (spawn / scripted): no morph.
		_from = -1
		_morph = 1.0
		_show_state(st)
	if _morph < 1.0:
		_morph = minf(_morph + delta / MORPH_TIME, 1.0)
		light.light_color = (V3D.STATE_COLORS[_from] as Color).lerp(V3D.STATE_COLORS[st], _morph)
		if _morph >= 1.0:
			_from = -1
	if p.dead or p.won:
		_end = maxf(_end - delta * (4.0 if p.dead else 2.0), 0.0)
		var e := _end * _end * (3.0 - 2.0 * _end)
		scale = Vector3.ONE * maxf(e, 0.02)
		if p.won:
			rotate_y(delta * 12.0 * (1.0 - _end * 0.5))
		puffs.emitting = false
	# Smoothed acceleration (velocity changes only on physics ticks).
	var raw_acc := (p.velocity - _prev_vel) / maxf(delta, 0.001)
	_prev_vel = p.velocity
	_acc = _acc.lerp(raw_acc.limit_length(80.0), 1.0 - exp(-14.0 * delta))
	_springs(p, delta)
	# Which forms are drawn and how big: new one grows with an overshoot, old one
	# shrinks / fades over the first 60 % of the morph.
	var grow := _back_out(_morph)
	var shrink := clampf(_morph / 0.6, 0.0, 1.0)
	var show_end := _end > 0.0
	for s in [Player3D.State.ICE, Player3D.State.WATER, Player3D.State.STEAM]:
		var k := 0.0
		var fade := 0.0
		if s == st:
			k = lerpf(0.35, 1.0, grow)
			fade = clampf(_morph * 2.5, 0.0, 1.0)
		elif s == _from:
			k = lerpf(1.0, 0.25, shrink * shrink)
			fade = 1.0 - shrink
		var vis := show_end and fade > 0.0
		match s:
			Player3D.State.ICE:
				ice.visible = vis
				if vis: _pose_ice(p, k, fade)
			Player3D.State.WATER:
				water.visible = vis
				if vis: _pose_water(p, k, fade)
			Player3D.State.STEAM:
				steam.visible = vis
				if vis: _pose_steam(p, k, fade)
	eyes.visible = show_end and _end > 0.05
	if eyes.visible:
		_update_eyes(p, st, delta)
	_update_shadow(p, st)


## Ease-out with ~10 % overshoot.
static func _back_out(x: float) -> float:
	var c1 := 2.2
	var c3 := c1 + 1.0
	var t := x - 1.0
	return 1.0 + c3 * t * t * t + c1 * t * t


static func _spring(x, v, target, k: float, c: float, delta: float) -> Array:
	v += ((target - x) * k - v * c) * delta
	x += v * delta
	return [x, v]


func _springs(p: Player3D, delta: float) -> void:
	var hv := Vector2(p.velocity.x, p.velocity.z)
	var steps := ceili(delta * 120.0)
	var h := delta / maxf(steps, 1)
	# Ice tips toward where its inertia carries it (braking tips it forward).
	var tt := Vector2(-_acc.z, _acc.x) * 0.02
	if p.side_mode:
		tt.x = 0.0
	tt = tt.limit_length(0.15)
	# Water: jelly lean along the motion; the spring adds the lag / overshoot.
	var lt := Vector3(p.velocity.x, 0.0, p.velocity.z) * 0.02
	lt = lt.limit_length(0.13)
	# Steam: lobes trail behind the motion.
	var dt := (-p.velocity * 0.035).limit_length(0.16)
	for i in steps:
		var r := _spring(_tilt, _tilt_v, tt, 170.0, 9.0, h)
		_tilt = r[0]
		_tilt_v = r[1]
		r = _spring(_lean, _lean_v, lt, 110.0, 6.5, h)
		_lean = r[0]
		_lean_v = r[1]
		r = _spring(_drag, _drag_v, dt, 45.0, 6.0, h)
		_drag = r[0]
		_drag_v = r[1]
	var k := 1.0 - exp(-10.0 * delta)
	_stretch = lerpf(_stretch, clampf(hv.length() * 0.035, 0.0, 0.24), k)
	if hv.length() > 0.3:
		_stretch_dir = _stretch_dir.lerp(hv.normalized(), k).normalized()
	_glint += delta * (0.12 + hv.length() * 0.09)


func _pose_ice(p: Player3D, k: float, fade: float) -> void:
	var sq := Vector3.ONE.lerp(p.squash, 0.7) * k
	ice.rotation = Vector3(_tilt.x, 0.0, _tilt.y)
	ice.scale = sq
	# Keep the bottom on the floor while squashed or tipped.
	var hh := Player3D.ICE_HALF
	var lift := hh * (absf(sin(_tilt.x)) + cos(_tilt.x) - 1.0 + absf(sin(_tilt.y)) + cos(_tilt.y) - 1.0)
	ice.position = Vector3(0.0, hh * (sq.y - 1.0) + lift * sq.y, 0.0)
	var m := ice.material_override as ShaderMaterial
	if m:
		var c := p.crack
		if c > 0.05:
			var lvl := clampi(ceili(c) - 1, 0, 2)
			m.set_shader_parameter("crack_tex", TEX_CRACKS[lvl])
			m.set_shader_parameter("crack", clampf(c - lvl, 0.3, 1.0))
		else:
			m.set_shader_parameter("crack", 0.0)
		m.set_shader_parameter("frost", (0.7 + sin(_t * 6.0) * 0.3) if p.is_locked() else 0.0)
		m.set_shader_parameter("fade", fade)
		m.set_shader_parameter("glint", fmod(_glint, 4.0))


func _pose_water(p: Player3D, k: float, fade: float) -> void:
	var sq := p.squash * k
	var vstretch := clampf(absf(p.velocity.y) * 0.012, 0.0, 0.2)
	water.scale = Vector3(sq.x * (1.0 - vstretch * 0.5), sq.y * (1.0 + vstretch), sq.z * (1.0 - vstretch * 0.5))
	water.position = Vector3(0.0, -(Player3D.WATER_R) + WATER_BOTTOM * water.scale.y, 0.0)
	var m := water.material_override as ShaderMaterial
	if m:
		var hs := Vector2(p.velocity.x, p.velocity.z).length()
		m.set_shader_parameter("wobble", 1.0 + clampf(hs * 0.2, 0.0, 1.2) + absf(1.0 - p.squash.y) * 3.0 + _lean_v.length() * 0.6)
		m.set_shader_parameter("lean", _lean / maxf(k, 0.2))
		m.set_shader_parameter("stretch", _stretch)
		m.set_shader_parameter("stretch_dir", _stretch_dir)
		m.set_shader_parameter("fade", fade)


func _pose_steam(p: Player3D, k: float, fade: float) -> void:
	var sq := p.squash * k
	steam.scale = sq
	var lean_x := clampf(p.velocity.x * 0.03, -0.2, 0.2)
	var lean_z := 0.0 if p.side_mode else clampf(p.velocity.z * 0.03, -0.2, 0.2)
	steam.rotation = Vector3(cos(_t * 1.25) * 0.07 + lean_z, sin(_t * 0.7) * 0.15, sin(_t * 1.6) * 0.09 - lean_x)
	steam.position = Vector3(sin(_t * 0.9) * 0.025, sin(_t * 2.0) * 0.035, 0.0)
	var m := cloud.material_override as ShaderMaterial
	if m:
		m.set_shader_parameter("drag", _drag)
		m.set_shader_parameter("fade", fade)


func _cam() -> Camera3D:
	return get_viewport().get_camera_3d() if is_inside_tree() else null


## Distance from `origin` along unit `dir` to the visible surface of the current form.
func _surface(st: int, dir: Vector3) -> Array:
	match st:
		Player3D.State.ICE:
			var o := ice.global_position
			var d := ice.global_transform.affine_inverse().basis * dir
			var hh := Player3D.ICE_HALF
			var t := 10.0
			for i in 3:
				if absf(d[i]) > 0.0001:
					t = minf(t, hh / absf(d[i]))
			return [o, t]
		Player3D.State.WATER:
			var o := water.global_position + _lean * 0.35
			var s := water.scale
			var r := WATER_MESH_R * Vector3(dir.x * s.x, dir.y * s.y, dir.z * s.z).length()
			return [o, r * (1.0 + _stretch * 0.3)]
		_:
			var o := cloud.global_position + _drag * 0.7
			var inv := cloud.global_transform.affine_inverse()
			var d := (inv.basis * dir)
			var dl := d.length()
			d /= maxf(dl, 0.0001)
			var best := 0.25
			for lobe in CLOUD_LOBES:
				var c: Vector3 = lobe[0]
				var rr: float = lobe[1] * 1.08
				var b := c.dot(d)
				var disc := b * b - (c.length_squared() - rr * rr)
				if disc >= 0.0:
					best = maxf(best, b + sqrt(disc))
			return [o, best / maxf(dl, 0.0001)]


func _update_eyes(p: Player3D, st: int, delta: float) -> void:
	var cam := _cam()
	if cam == null:
		return
	var center := global_position
	var to_cam := cam.global_position - center
	if cam.projection == Camera3D.PROJECTION_ORTHOGONAL:
		to_cam = cam.global_basis.z
	if to_cam.length() < 0.01:
		return
	to_cam = to_cam.normalized()
	var look := p.look_dir()
	look.y = 0.0
	var want := (to_cam + look * 0.55).normalized()
	# Don't slide the face so far round that the outer eye hangs off the silhouette.
	var max_ang := 0.6 if st == Player3D.State.ICE else (0.42 if st == Player3D.State.WATER else 0.3)
	var ang := to_cam.angle_to(want)
	if ang > max_ang:
		want = to_cam.slerp(want, max_ang / ang).normalized()
	if _eye_dir == Vector3.ZERO or _eye_dir.angle_to(want) > 1.4:
		_eye_dir = want
	else:
		_eye_dir = _eye_dir.slerp(want, 1.0 - exp(-12.0 * delta)).normalized()
	var dir := _eye_dir
	var lift := 0.06
	match st:
		Player3D.State.ICE: lift = 0.05
		Player3D.State.WATER: lift = -0.03
		Player3D.State.STEAM: lift = 0.04
	var surf := _surface(st, dir)
	var grow := lerpf(0.35, 1.0, _back_out(_morph)) if _morph < 1.0 else 1.0
	var margin := 0.02 if st == Player3D.State.ICE else 0.05
	var base: Vector3 = (surf[0] as Vector3) + dir * ((surf[1] as float) + margin) + Vector3.UP * lift * grow
	base += to_cam * 0.02
	var right := cam.global_basis.x
	var up := cam.global_basis.y
	# Irregular blinks (sometimes a double blink); eyes also blink through a shift.
	_blink_in -= delta
	if _blink_in <= 0.0:
		_blink = 0.0
		if _double_blink:
			_double_blink = false
			_blink_in = randf_range(2.0, 5.5)
		else:
			_double_blink = randf() < 0.2
			_blink_in = 0.3 if _double_blink else randf_range(2.0, 5.5)
	var blink_tex := -1
	if _blink >= 0.0:
		_blink += delta
		blink_tex = 0 if _blink < 0.04 or _blink > 0.1 else 1
		if _blink > 0.14:
			_blink = -1.0
			blink_tex = -1
	if _morph < 1.0 and _morph > 0.1 and _morph < 0.75:
		blink_tex = 1 if _morph > 0.25 and _morph < 0.6 else 0
	var e := p.expression()
	var show_set := e != "" or blink_tex >= 0
	expr.visible = show_set
	for s in [white_l, white_r, pupil_l, pupil_r]:
		s.visible = not show_set
	# Pupils look where the blob is heading (in screen space) and up/down with speed.
	var lx := clampf(look.dot(right) * 1.4, -1.0, 1.0)
	var ly := clampf(p.velocity.y * 0.05, -1.0, 1.0)
	_pupil = _pupil.lerp(Vector2(lx, ly), 1.0 - exp(-9.0 * delta))
	if show_set:
		expr.texture = TEX_EYES[e] if e != "" else TEX_BLINK[blink_tex]
		expr.global_position = base
		return
	var ex := 5.0 * V3D.PX
	white_l.global_position = base - right * ex
	white_r.global_position = base + right * ex
	var po := (right * _pupil.x + up * _pupil.y) * V3D.PX
	pupil_l.global_position = white_l.global_position + po + to_cam * 0.005
	pupil_r.global_position = white_r.global_position + po + to_cam * 0.005


func _update_shadow(p: Player3D, st: int) -> void:
	if p.dead or p.won:
		shadow.visible = false
		return
	var space := p.get_world_3d().direct_space_state
	var from := global_position
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 25.0, V3D.L_WORLD | V3D.L_BREAKABLE | V3D.L_GLASS | V3D.L_GRATE, [p.get_rid()])
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		shadow.visible = false
		return
	shadow.visible = true
	var h := from.y - (hit.position as Vector3).y
	var base := 0.95 if st == Player3D.State.ICE else (0.75 if st == Player3D.State.WATER else 0.8)
	var s := base * clampf(1.2 - h * 0.06, 0.4, 1.2)
	shadow.global_position = (hit.position as Vector3) + (hit.normal as Vector3) * 0.02
	shadow.global_basis = Basis(Quaternion(Vector3.UP, hit.normal)).scaled(Vector3(s, 1, s))
	shadow.transparency = clampf(0.25 + h * 0.06 + (0.35 if st == Player3D.State.STEAM else 0.0), 0.0, 0.9)


# --- Meshes --------------------------------------------------------------------

## Adds triangle a,b,c facing `n` (Godot: clockwise front faces).
static func _tri(verts: PackedVector3Array, norms: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3, n: Vector3, na := Vector3.ZERO, nb := Vector3.ZERO, nc := Vector3.ZERO) -> void:
	if na == Vector3.ZERO:
		na = n
		nb = n
		nc = n
	if (b - a).cross(c - a).dot(n) > 0.0:
		verts.append_array([a, c, b])
		norms.append_array([na, nc, nb])
	else:
		verts.append_array([a, b, c])
		norms.append_array([na, nb, nc])


## Cube of half size `h` with every edge cut by a `c` chamfer: 6 faces, 12 bevel
## strips and 8 corner triangles, flat normals (faceted), one surface.
static func _build_chamfer_box(h: float, c: float) -> ArrayMesh:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var i := h - c
	var axes := [Vector3.RIGHT, Vector3.UP, Vector3.BACK]
	for ax in 3:
		var n: Vector3 = axes[ax]
		var u: Vector3 = axes[(ax + 1) % 3]
		var v: Vector3 = axes[(ax + 2) % 3]
		for sgn in [1.0, -1.0]:
			var nn: Vector3 = n * sgn
			var p0: Vector3 = nn * h - u * i - v * i
			var p1: Vector3 = nn * h + u * i - v * i
			var p2: Vector3 = nn * h + u * i + v * i
			var p3: Vector3 = nn * h - u * i + v * i
			_tri(verts, norms, p0, p1, p2, nn)
			_tri(verts, norms, p0, p2, p3, nn)
	# Edge strips: between face A (sign sa) and face B (sign sb), running along E.
	for ax in 3:
		var A: Vector3 = axes[ax]
		var B: Vector3 = axes[(ax + 1) % 3]
		var E: Vector3 = axes[(ax + 2) % 3]
		for sa in [1.0, -1.0]:
			for sb in [1.0, -1.0]:
				var n: Vector3 = (A * sa + B * sb).normalized()
				var q0: Vector3 = A * sa * h + B * sb * i - E * i
				var q1: Vector3 = A * sa * h + B * sb * i + E * i
				var q2: Vector3 = A * sa * i + B * sb * h + E * i
				var q3: Vector3 = A * sa * i + B * sb * h - E * i
				_tri(verts, norms, q0, q1, q2, n)
				_tri(verts, norms, q0, q2, q3, n)
	for sx in [1.0, -1.0]:
		for sy in [1.0, -1.0]:
			for sz in [1.0, -1.0]:
				var n := Vector3(sx, sy, sz).normalized()
				_tri(verts, norms, Vector3(sx * h, sy * i, sz * i), Vector3(sx * i, sy * h, sz * i), Vector3(sx * i, sy * i, sz * h), n)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh


## Low-poly spheres for each lobe merged into one surface. COLOR.rgb carries the lobe
## centre (*0.5 + 0.5) and COLOR.a its phase for the steam_cloud shader.
static func _build_cloud(lobes: Array) -> ArrayMesh:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var seg := 12
	var rings := 8
	var li := 0
	for lobe in lobes:
		var c: Vector3 = lobe[0]
		var r: float = lobe[1]
		var col := Color(c.x * 0.5 + 0.5, c.y * 0.5 + 0.5, c.z * 0.5 + 0.5, fmod(li * 0.618, 1.0))
		var grid := []
		for y in rings + 1:
			var phi := PI * float(y) / rings
			var row := []
			for x in seg + 1:
				var th := TAU * float(x) / seg + li * 0.7
				row.append(Vector3(sin(phi) * cos(th), cos(phi), sin(phi) * sin(th)))
			grid.append(row)
		for y in rings:
			for x in seg:
				var n00: Vector3 = grid[y][x]
				var n10: Vector3 = grid[y][x + 1]
				var n01: Vector3 = grid[y + 1][x]
				var n11: Vector3 = grid[y + 1][x + 1]
				var fn := (n00 + n10 + n01 + n11).normalized()
				if y > 0:
					_tri(verts, norms, c + n00 * r, c + n10 * r, c + n11 * r, fn, n00, n10, n11)
				if y < rings - 1:
					_tri(verts, norms, c + n00 * r, c + n11 * r, c + n01 * r, fn, n00, n11, n01)
		while cols.size() < verts.size():
			cols.append(col)
		li += 1
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh
