@tool
class_name PlayerVisual3D
extends Node3D
## Looks of the 3D blob (child "Visual" of Player3D):
##  ICE   translucent faceted cube (2D ice art on each face, cracks, frost rim when locked)
##  WATER wobbly vertex-shader sphere + splash droplets on land/jump
##  STEAM puffy particle cloud around a glowing core
## Eyes are billboard sprites from assets/player placed on the side of the body that
## faces the camera (leaning toward where the blob is heading). A soft blob shadow is
## projected straight down. Body meshes live on render layer 2 (hidden in first person).

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

@onready var ice: MeshInstance3D = $Ice
@onready var water: MeshInstance3D = $Water
@onready var steam: Node3D = $Steam
@onready var puffs: CPUParticles3D = $Steam/Puffs
@onready var core: Sprite3D = $Steam/Core
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
var _pop := 1.0
var _end_scale := 1.0
var _shown := -1


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	shadow.top_level = true
	ring.visible = false
	for n in [ice, water, steam, eyes, ring, splash, burst]:
		V3D.set_render_layer(n, V3D.RL_BLOB)


func _player() -> Player3D:
	return get_parent() as Player3D


func on_shift(heating: bool) -> void:
	var p := _player()
	_pop = 0.55
	burst.color = V3D.STATE_COLORS[p.state]
	burst.restart()
	ring.modulate = V3D.STATE_COLORS[p.state]
	ring.frame = 0
	ring.visible = true
	ring.global_position = p.global_position
	var tw := ring.create_tween()
	tw.tween_property(ring, "frame", 4, 0.25)
	tw.tween_callback(func() -> void: ring.visible = false)
	if p.rig:
		p.rig.flash(V3D.STATE_COLORS[p.state], 0.35 if heating else 0.3)


func on_jump() -> void:
	splash.amount = 10
	splash.restart()


func on_land(speed: float) -> void:
	if _player().state == Player3D.State.WATER:
		splash.restart()


func on_die(vel: Vector3) -> void:
	var p := _player()
	burst.color = Color(1.0, 0.45, 0.45)
	burst.restart()
	if p.state != Player3D.State.ICE:
		splash.amount = 24
		splash.restart()
	_end_scale = 0.0
	if p.rig:
		p.rig.flash(Color(1.0, 0.3, 0.3), 0.6)


func on_win() -> void:
	burst.color = Color(0.6, 1.0, 0.7)
	burst.restart()
	_end_scale = 0.0


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var p := _player()
	if p == null:
		return
	_t += delta
	_pop = move_toward(_pop, 1.0, delta * 4.0)
	var st := p.state
	if st != _shown:
		_shown = st
		ice.visible = st == Player3D.State.ICE
		water.visible = st == Player3D.State.WATER
		steam.visible = st == Player3D.State.STEAM
		puffs.emitting = st == Player3D.State.STEAM
		light.light_color = V3D.STATE_COLORS[st]
	var end := 1.0
	if p.dead or p.won:
		end = maxf(scale.x - delta * (5.0 if p.dead else 2.5), 0.0)
		scale = Vector3.ONE * end
		if p.won:
			rotate_y(delta * 12.0)
		puffs.emitting = false
	var sq := p.squash * _pop
	match st:
		Player3D.State.ICE:
			ice.scale = Vector3(sq.x, sq.y, sq.z)
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
			# Lean the cube along its slide a touch.
			var hv := Vector2(p.velocity.x, p.velocity.z)
			ice.rotation = Vector3(-hv.y * 0.004, 0, hv.x * 0.004) if not p.side_mode else Vector3(0, 0, -hv.x * 0.004)
		Player3D.State.WATER:
			var hs := Vector2(p.velocity.x, p.velocity.z).length()
			var stretch := clampf(absf(p.velocity.y) * 0.012, 0.0, 0.2)
			water.scale = Vector3(sq.x * (1.0 - stretch * 0.5), sq.y * (1.0 + stretch), sq.z * (1.0 - stretch * 0.5))
			water.position.y = -0.04 + (water.scale.y - 1.0) * 0.3
			var m := water.material_override as ShaderMaterial
			if m:
				m.set_shader_parameter("wobble", 1.0 + clampf(hs * 0.25, 0.0, 1.5) + (1.0 - sq.y) * 3.0)
		Player3D.State.STEAM:
			steam.scale = Vector3.ONE * sq.x
			core.modulate.a = 0.75 + sin(_t * 5.0) * 0.15
	_update_eyes(p, st)
	_update_shadow(p, st)


func _cam() -> Camera3D:
	return get_viewport().get_camera_3d() if is_inside_tree() else null


func _update_eyes(p: Player3D, st: int) -> void:
	var cam := _cam()
	if cam == null:
		return
	var center := p.global_position
	var to_cam := cam.global_position - center
	if to_cam.length() < 0.01:
		return
	to_cam = to_cam.normalized()
	var look := p.look_dir()
	look.y = 0.0
	var dir := (to_cam + look * 0.55).normalized()
	var radius := 0.36
	var lift := 0.06
	match st:
		Player3D.State.ICE:
			var m := maxf(maxf(absf(dir.x), absf(dir.z)), absf(dir.y))
			radius = Player3D.ICE_HALF / maxf(m, 0.01) * p.squash.x
			lift = 0.05
		Player3D.State.WATER:
			radius = 0.37 * p.squash.x
			lift = -0.03
		Player3D.State.STEAM:
			radius = 0.32
			lift = 0.04
	var base := center + dir * (radius + 0.02) + Vector3.UP * lift
	base += to_cam * 0.02
	var right := cam.global_basis.x
	var up := cam.global_basis.y
	var e := p.expression()
	var blink := fmod(_t, 3.7)
	var show_set := e != "" or blink < 0.14
	expr.visible = show_set
	for s in [white_l, white_r, pupil_l, pupil_r]:
		s.visible = not show_set
	if show_set:
		expr.texture = TEX_EYES[e] if e != "" else TEX_BLINK[0 if blink < 0.05 or blink > 0.10 else 1]
		expr.global_position = base
		return
	# Pupils look where the blob is heading (in screen space) and up/down with speed.
	var lx := clampf(look.dot(right) * 1.4, -1.0, 1.0)
	var ly := clampf(p.velocity.y * 0.05, -1.0, 1.0)
	var off := Vector2(roundf(lx), roundf(ly))
	var ex := 5.0 * V3D.PX
	white_l.global_position = base - right * ex
	white_r.global_position = base + right * ex
	var po := (right * off.x + up * off.y) * V3D.PX
	pupil_l.global_position = white_l.global_position + po + to_cam * 0.005
	pupil_r.global_position = white_r.global_position + po + to_cam * 0.005


func _update_shadow(p: Player3D, st: int) -> void:
	if p.dead or p.won:
		shadow.visible = false
		return
	var space := p.get_world_3d().direct_space_state
	var from := p.global_position
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
