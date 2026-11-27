@tool
class_name CameraRig3D
extends Node3D
## Camera for the 3D chapters. One rig, four styles (Level3D.camera_mode):
##  THIRD_PERSON  orbit camera behind the blob; mouse (click to capture) or <- -> to turn,
##                a sphere probe keeps it out of walls (glass/grates don't count)
##  FIRST_PERSON  through the blob's eyes; the body is hidden (render layer 2) and a
##                ScreenFX overlay shows frost / droplets / haze for the current state
##  SIDE_25D      side view with slight perspective; movement is locked to the X/Y plane
##  ISOMETRIC     orthographic 45 deg yaw / 35.264 deg pitch, follows the blob
## Movement input is camera relative; `move_input()` returns the world direction.
## In 1st/3rd person the arrow keys left/right TURN (WASD strafes); up/down move.

const Mode := V3D.CameraMode

@export var mode: V3D.CameraMode = V3D.CameraMode.THIRD_PERSON
@export_group("Third person")
@export var distance := 4.6
@export var pitch_deg := -18.0
@export var tp_fov := 64.0
@export var focus_height := 0.55
@export_group("First person")
@export var fp_fov := 80.0
@export_group("Side 2.5D")
@export var side_distance := 15.0
@export var side_height := 1.2
@export var side_pitch_deg := -5.0
@export var side_fov := 38.0
@export var side_lookahead := 2.2
@export_group("Isometric")
@export var iso_size := 15.0
@export var iso_distance := 40.0
@export var iso_yaw_deg := 45.0
@export var iso_pitch_deg := -35.264
## Cutaway: everything higher than this above the blob is hidden.
@export var iso_cut_height := 1.4
@export_group("Input")
## Starting view direction (degrees around Y; 0 looks along -Z).
@export var yaw_deg := 0.0
@export var mouse_sensitivity := 0.0025
@export var turn_speed := 2.4

@onready var camera: Camera3D = $Camera3D
@onready var screen_fx: CanvasLayer = $ScreenFX
@onready var fx_rect: ColorRect = $ScreenFX/Rect

var target: Player3D
var level: Node
var yaw := 0.0
var pitch := 0.0
var bounds := AABB()
var plane_z := 0.0

var _focus := Vector3.ZERO
var _look_ahead := 0.0
var _mix := Vector3(0, 1, 0)
var _flash := 0.0
var _flash_col := Color.WHITE
var _ended := false
var _snap := true
var _tp_pitch := 0.0
var _tp_dist := 0.0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	top_level = true
	screen_fx.visible = false


func setup(lvl: Node, player: Player3D, camera_mode: int, level_bounds: AABB, side_plane_z: float) -> void:
	level = lvl
	target = player
	mode = camera_mode as V3D.CameraMode
	bounds = level_bounds
	plane_z = side_plane_z
	yaw = deg_to_rad(yaw_deg)
	pitch = deg_to_rad(pitch_deg) if mode == Mode.THIRD_PERSON else 0.0
	camera.current = true
	camera.near = 0.05
	camera.far = 200.0
	match mode:
		Mode.THIRD_PERSON:
			camera.fov = tp_fov
		Mode.FIRST_PERSON:
			camera.fov = fp_fov
			camera.cull_mask = 0xFFFFF & ~V3D.RL_BLOB
		Mode.SIDE_25D:
			camera.fov = side_fov
			yaw = 0.0
		Mode.ISOMETRIC:
			camera.projection = Camera3D.PROJECTION_ORTHOGONAL
			camera.size = iso_size
			yaw = deg_to_rad(iso_yaw_deg)
	screen_fx.visible = mode == Mode.FIRST_PERSON
	_snap = true
	_update(0.0)


## Horizontal forward of the view (for camera-relative movement).
func forward() -> Vector3:
	if mode == Mode.SIDE_25D:
		return Vector3.RIGHT
	return Vector3(-sin(yaw), 0, -cos(yaw))


func _uses_mouse() -> bool:
	return mode == Mode.THIRD_PERSON or mode == Mode.FIRST_PERSON


## Arrow key held without its WASD twin: in 1st/3rd person that turns instead of strafing.
func _arrow_only(arrow: Key, letter: Key) -> bool:
	return Input.is_physical_key_pressed(arrow) and not Input.is_physical_key_pressed(letter)


## World-space movement wish (length <= 1) from the move_* actions.
func move_input() -> Vector3:
	var right := Input.get_action_strength("move_right")
	var left := Input.get_action_strength("move_left")
	var fwd := Input.get_action_strength("move_up")
	var back := Input.get_action_strength("move_down")
	match mode:
		Mode.SIDE_25D:
			return Vector3(right - left, 0, 0)
		Mode.THIRD_PERSON, Mode.FIRST_PERSON:
			if _arrow_only(KEY_LEFT, KEY_A):
				left = 0.0
			if _arrow_only(KEY_RIGHT, KEY_D):
				right = 0.0
	var v := Vector2(right - left, back - fwd).limit_length(1.0)
	var b := Basis(Vector3.UP, yaw)
	return b * Vector3(v.x, 0, v.y)


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not _uses_mouse() or _ended:
		return
	if event is InputEventMouseButton and event.pressed and not get_tree().paused:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var rel: Vector2 = event.relative
		yaw -= rel.x * mouse_sensitivity
		pitch = clampf(pitch - rel.y * mouse_sensitivity, deg_to_rad(-75.0), deg_to_rad(60.0 if mode == Mode.THIRD_PERSON else 80.0))


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_EXIT_TREE:
		_release_mouse()


func _release_mouse() -> void:
	if not Engine.is_editor_hint() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func on_player_end(_won: bool) -> void:
	_ended = true
	_release_mouse()


## Coloured full-screen flash (first person only; shift / death feedback).
func flash(col: Color, amount: float) -> void:
	_flash_col = col
	_flash = maxf(_flash, amount)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or target == null:
		return
	if _uses_mouse() and not _ended:
		var turn := 0.0
		if _arrow_only(KEY_LEFT, KEY_A):
			turn += 1.0
		if _arrow_only(KEY_RIGHT, KEY_D):
			turn -= 1.0
		yaw += turn * turn_speed * delta
	_update(delta)


func _smooth(rate: float, delta: float) -> float:
	return 1.0 if _snap else 1.0 - exp(-rate * delta)


func _update(delta: float) -> void:
	if target == null:
		return
	var p := target.global_position
	var shake_on := true
	var settings := get_node_or_null("/root/Settings")
	if settings and settings.get("screen_shake") != null:
		shake_on = settings.get("screen_shake")
	var sh := target.shake * (0.012 if shake_on else 0.0)
	camera.h_offset = randf_range(-1, 1) * sh
	camera.v_offset = randf_range(-1, 1) * sh
	match mode:
		Mode.THIRD_PERSON: _update_tp(p, delta)
		Mode.FIRST_PERSON: _update_fp(p, delta)
		Mode.SIDE_25D: _update_side(p, delta)
		Mode.ISOMETRIC: _update_iso(p, delta)
	_snap = false
	if mode == Mode.FIRST_PERSON:
		_update_fx(delta)


func _update_tp(p: Vector3, delta: float) -> void:
	var want := p + Vector3.UP * focus_height
	# Keep the focus under low ceilings so the probe never starts inside a slab.
	var space := get_world_3d().direct_space_state
	var up := PhysicsRayQueryParameters3D.create(p, want + Vector3.UP * 0.35, V3D.MASK_CAMERA, [target.get_rid()])
	var hit := space.intersect_ray(up)
	if not hit.is_empty():
		want.y = minf(want.y, (hit.position as Vector3).y - 0.35)
	var k := _smooth(14.0, delta)
	var kv := _smooth(7.0, delta)
	_focus = Vector3(lerpf(_focus.x, want.x, k), lerpf(_focus.y, want.y, kv), lerpf(_focus.z, want.z, k))
	# Sphere probe from the focus back to the camera. Under a low ceiling (or with a
	# wall behind) try flatter / lower angles before pulling the camera in close.
	var best_pitch := pitch
	var best := _probe(pitch)
	if best < distance * 0.75:
		for alt in [pitch * 0.5, 0.0, 0.2, -0.6]:
			var d := _probe(alt)
			if d > best + 0.3:
				best = d
				best_pitch = alt
	_tp_pitch = lerp_angle(_tp_pitch, best_pitch, _smooth(6.0, delta))
	var b := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, _tp_pitch)
	var dir := b * Vector3(0, 0, 1)
	var dist := minf(_probe(_tp_pitch), distance)
	_tp_dist = dist if dist < _tp_dist or _snap else lerpf(_tp_dist, dist, _smooth(4.0, delta))
	global_transform = Transform3D(b, _focus + dir * _tp_dist)
	camera.transform = Transform3D.IDENTITY


## Free distance (m) from the focus along the camera arm at `p_angle`.
func _probe(p_angle: float) -> float:
	var dir := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, p_angle) * Vector3(0, 0, 1)
	var q := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.25
	q.shape = sphere
	q.transform = Transform3D(Basis(), _focus)
	q.motion = dir * distance
	q.collision_mask = V3D.MASK_CAMERA
	q.exclude = [target.get_rid()]
	var res := get_world_3d().direct_space_state.cast_motion(q)
	if res.size() == 2 and res[0] < 1.0:
		return maxf(distance * res[0], 0.4)
	return distance


func _update_fp(p: Vector3, delta: float) -> void:
	var eye := 0.12
	var bob := 0.0
	match target.state:
		Player3D.State.ICE: eye = 0.2
		Player3D.State.WATER:
			eye = 0.08
			var hs := Vector2(target.velocity.x, target.velocity.z).length()
			if target.is_on_floor():
				bob = sin(Time.get_ticks_msec() * 0.018) * 0.03 * clampf(hs / 6.0, 0.0, 1.0)
		Player3D.State.STEAM:
			eye = 0.1
			bob = sin(Time.get_ticks_msec() * 0.004) * 0.04
	var want := p + Vector3.UP * (eye + bob)
	var k := _smooth(30.0, delta)
	_focus = _focus.lerp(want, k)
	var sq := target.squash.y
	global_transform = Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch), _focus + Vector3.UP * (sq - 1.0) * 0.25)
	camera.transform = Transform3D.IDENTITY


func _update_side(p: Vector3, delta: float) -> void:
	var la := clampf(target.velocity.x * 0.3, -side_lookahead, side_lookahead)
	_look_ahead = lerpf(_look_ahead, la, _smooth(2.5, delta))
	var want := Vector3(p.x + _look_ahead, p.y + side_height, plane_z)
	var half_h := tan(deg_to_rad(side_fov) / 2.0) * side_distance
	var vp := get_viewport().get_visible_rect().size
	var half_w := half_h * (vp.x / maxf(vp.y, 1.0))
	if bounds.size.x > 0.0:
		var lo := bounds.position.x + half_w - 0.5
		var hi := bounds.end.x - half_w + 0.5
		want.x = clampf(want.x, lo, hi) if lo < hi else bounds.get_center().x
		var blo := bounds.position.y + half_h - 1.0
		var bhi := bounds.end.y - half_h + 0.5
		want.y = clampf(want.y, blo, bhi) if blo < bhi else bounds.get_center().y
	var k := _smooth(6.0, delta)
	_focus = _focus.lerp(want, k)
	var b := Basis(Vector3.RIGHT, deg_to_rad(side_pitch_deg))
	global_transform = Transform3D(b, _focus + b * Vector3(0, 0, side_distance))
	camera.transform = Transform3D.IDENTITY


func _update_iso(p: Vector3, delta: float) -> void:
	_focus = _focus.lerp(p, _smooth(6.0, delta))
	var b := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, deg_to_rad(iso_pitch_deg))
	global_transform = Transform3D(b, _focus + b * Vector3(0, 0, iso_distance))
	if level and level.has_method("apply_cut"):
		# Cut at head height, or just under the ceiling right above the blob.
		var cut := _focus.y + iso_cut_height
		var q := PhysicsRayQueryParameters3D.create(p, p + Vector3.UP * iso_cut_height, V3D.MASK_CAMERA | V3D.L_GRATE, [target.get_rid()])
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty():
			cut = minf(cut, (hit.position as Vector3).y - 0.02)
		level.apply_cut(snappedf(cut, 0.05))
	camera.transform = Transform3D.IDENTITY


func _update_fx(delta: float) -> void:
	var want := Vector3(1 if target.state == 0 else 0, 1 if target.state == 1 else 0, 1 if target.state == 2 else 0)
	if target.dead:
		want = Vector3.ZERO
	_mix = _mix.lerp(want, minf(delta * 5.0, 1.0)) if delta > 0.0 else want
	_flash = maxf(_flash - delta * 2.0, 0.0)
	var m := fx_rect.material as ShaderMaterial
	if m == null:
		return
	m.set_shader_parameter("mix_ice", _mix.x)
	m.set_shader_parameter("mix_water", _mix.y)
	m.set_shader_parameter("mix_steam", _mix.z)
	m.set_shader_parameter("flash", _flash)
	m.set_shader_parameter("flash_color", Color(_flash_col.r, _flash_col.g, _flash_col.b, 0.6))
