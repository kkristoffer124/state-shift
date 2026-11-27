@tool
class_name CameraRig3D
extends Node3D
## Camera for the 3D chapters. One rig, four styles (Level3D.camera_mode):
##  THIRD_PERSON  platformer orbit camera behind the blob:
##                - spring arm: sphere cast (thin props, small glass, grates ignored), pulls in
##                  fast, eases back out slowly (with hysteresis, so no in/out pumping)
##                - low ceilings / floors tilt the arm (continuously) instead of crushing it
##                - follows behind the movement direction with a lazy lag when you aren't
##                  steering it; drifts away from walls that crowd it
##                - pitch looks up while steam rises, down while falling, else settles
##                - frames slightly ahead of the movement
##                - move keys stay mapped to the view they were pressed in while the camera
##                  swings on its own (until released); manual turning re-maps at once
##                - CameraZone3D volumes can override distance / pitch / yaw in tricky spots
##  FIRST_PERSON  through the blob's eyes; the body is hidden (render layer 2) and a
##                ScreenFX overlay shows frost / droplets / haze for the current state
##  SIDE_25D      side view with slight perspective; movement is locked to the X/Y plane
##  ISOMETRIC     orthographic 35.264 deg pitch, follows (and leads) the blob; Z / X turn
##                the view in 90 deg steps; the camera-side walls are hidden; eased cutaway
## Look: mouse (click to capture, or drag with a button held), <- -> or Z / X turn, C recentres.
## Movement input is camera relative; `move_input()` returns the world direction.
## In 1st/3rd person the arrow keys left/right TURN (WASD strafes); up/down move.

const Mode := V3D.CameraMode
## The third-person arm stays on this side of walls and big glass panes (small glass
## and thin props are excluded per body; grates are see-through, the blob passes them).
const ARM_MASK := V3D.MASK_CAMERA | V3D.L_GLASS
const SH_MARKER := preload("res://shaders/v3d/landing_marker.gdshader")

@export var mode: V3D.CameraMode = V3D.CameraMode.THIRD_PERSON
@export_group("Third person")
@export var distance := 5.2
@export var pitch_deg := -20.0
@export var tp_fov := 64.0
@export var focus_height := 0.55
## Seconds after a manual look before the camera starts following / re-levelling itself.
@export var follow_delay := 1.0
## How eagerly the camera swings behind the movement direction (0 = never).
@export var follow_rate := 1.4
## Pitch while steam rises (deg, + looks up) and while falling.
@export var rise_pitch_deg := 8.0
@export var fall_pitch_deg := -38.0
@export_group("First person")
@export var fp_fov := 80.0
@export_group("Side 2.5D")
@export var side_distance := 15.0
@export var side_height := 1.2
@export var side_pitch_deg := -5.0
@export var side_fov := 38.0
@export var side_lookahead := 2.2
@export_group("Isometric")
@export var iso_size := 11.0
@export var iso_distance := 40.0
@export var iso_yaw_deg := 45.0
@export var iso_pitch_deg := -35.264
## Cutaway: everything higher than this above the blob is hidden.
@export var iso_cut_height := 3.4
@export_group("Input")
## Starting view direction (degrees around Y; 0 looks along -Z).
@export var yaw_deg := 0.0
@export var mouse_sensitivity := 0.0025
@export var turn_speed := 2.4

@onready var camera: Camera3D = $Camera3D
@onready var screen_fx: CanvasLayer = $ScreenFX
@onready var fx_rect: ColorRect = $ScreenFX/Rect
@onready var marker: Node3D = $Marker
@onready var marker_disc: MeshInstance3D = $Marker/Disc
@onready var marker_line: MeshInstance3D = $Marker/Line

var target: Player3D
var level: Node
var yaw := 0.0
var pitch := 0.0
var bounds := AABB()
var plane_z := 0.0

var _focus := Vector3.ZERO
var _look_ahead := 0.0
var _lead := Vector3.ZERO
var _mix := Vector3(0, 1, 0)
var _flash := 0.0
var _flash_col := Color.WHITE
var _ended := false
var _snap := true
var _tp_pitch := 0.0
var _arm := 0.0
var _arm_out_t := 0.0
var _dist := 0.0
## Seconds since the player last turned / pitched the camera by hand.
var _manual_t := 100.0
var _pitch_manual_t := 100.0
var _turn_v := 0.0
var _recenter := false
## Yaw the move keys are mapped with (see move_input()).
var _input_yaw := 0.0
var _iso_yaw := 0.0
var _iso_cut := INF
var _view_key := INF
var _marker_on := false
## Bodies the third-person arm ignores (thin / small props: pipes, cables, flasks...).
var _arm_exclude: Array[RID] = []
var _zones: Array = []


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	top_level = true
	screen_fx.visible = false
	marker.visible = false


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
			_collect_arm_excludes()
			if level:
				_zones = level.find_children("*", "CameraZone3D", true, false)
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
			_iso_yaw = yaw
	_input_yaw = yaw
	_tp_pitch = pitch
	_dist = distance
	_arm = distance
	screen_fx.visible = mode == Mode.FIRST_PERSON
	_setup_marker()
	_snap = true
	_update(0.0)


## Horizontal forward of the view (for camera-relative movement).
func forward() -> Vector3:
	if mode == Mode.SIDE_25D:
		return Vector3.RIGHT
	return Vector3(-sin(yaw), 0, -cos(yaw))


## Yaw the movement keys are currently mapped with. Equals `yaw` except while the
## third-person camera swings by itself with a move key held, or mid isometric turn.
func input_yaw() -> float:
	return _input_yaw


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
	var b := Basis(Vector3.UP, _input_yaw)
	return b * Vector3(v.x, 0, v.y)


func _move_held() -> bool:
	for a in ["move_left", "move_right", "move_up", "move_down"]:
		if Input.is_action_pressed(a):
			return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or _ended or target == null:
		return
	if mode == Mode.ISOMETRIC:
		if event.is_action_pressed("cam_left"):
			_iso_yaw -= PI / 2.0
		elif event.is_action_pressed("cam_right"):
			_iso_yaw += PI / 2.0
		return
	if not _uses_mouse():
		return
	if event.is_action_pressed("cam_center"):
		_recenter = true
		return
	if event is InputEventMouseButton and event.pressed and not get_tree().paused:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		var rel := mm.relative
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			# Drag look (e.g. when the browser refused the pointer lock).
			if mm.button_mask == 0:
				return
			rel = Vector2(rel.x * Settings.mouse_sens_x * (-1.0 if Settings.invert_x else 1.0),
				rel.y * Settings.mouse_sens_y * (-1.0 if Settings.invert_y else 1.0))
		yaw -= rel.x * mouse_sensitivity
		pitch = clampf(pitch - rel.y * mouse_sensitivity, deg_to_rad(-75.0), deg_to_rad(60.0 if mode == Mode.THIRD_PERSON else 80.0))
		if absf(rel.x) > 0.01:
			_manual_turn()
		if absf(rel.y) > 0.01:
			_pitch_manual_t = 0.0


func _manual_turn() -> void:
	_manual_t = 0.0
	_recenter = false
	_input_yaw = yaw


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
	_manual_t += delta
	_pitch_manual_t += delta
	if _uses_mouse() and not _ended:
		var turn := 0.0
		if _arrow_only(KEY_LEFT, KEY_A) or Input.is_action_pressed("cam_left"):
			turn += 1.0
		if _arrow_only(KEY_RIGHT, KEY_D) or Input.is_action_pressed("cam_right"):
			turn -= 1.0
		# Eased keyboard turning (no instant full-speed spin).
		_turn_v = lerpf(_turn_v, turn * turn_speed, 1.0 - exp(-12.0 * delta))
		if absf(_turn_v) > 0.01:
			yaw += _turn_v * delta
			if turn != 0.0:
				_manual_turn()
		if mode == Mode.FIRST_PERSON or not _move_held():
			_input_yaw = yaw
	_update(delta)


func _smooth(rate: float, delta: float) -> float:
	return 1.0 if _snap else 1.0 - exp(-rate * delta)


func _update(delta: float) -> void:
	if target == null:
		return
	var p := target.render_position()  # interpolated between physics ticks (no 60 Hz judder)
	var sh := target.shake * 0.012 * Settings.shake_scale()
	camera.h_offset = randf_range(-1, 1) * sh
	camera.v_offset = randf_range(-1, 1) * sh
	match mode:
		Mode.THIRD_PERSON: _update_tp(p, delta)
		Mode.FIRST_PERSON: _update_fp(p, delta)
		Mode.SIDE_25D: _update_side(p, delta)
		Mode.ISOMETRIC: _update_iso(p, delta)
	_update_marker(p)
	_snap = false
	if mode == Mode.FIRST_PERSON:
		_update_fx(delta)


# --- Third person -----------------------------------------------------------------

## Thin or small props never push the arm in (they'd make it twitch): pipes, cables,
## rails, flasks, monitors, crates...
func _collect_arm_excludes() -> void:
	_arm_exclude = [target.get_rid()]
	if level == null:
		return
	for n in level.find_children("*", "CollisionObject3D", true, false):
		if n == target or not (n is StaticBody3D or n is AnimatableBody3D):
			continue
		if n.get_parent() is Pipe3D:
			_arm_exclude.append((n as CollisionObject3D).get_rid())
			continue
		var box := AABB()
		if n is Block3D:
			box = (n as Block3D).get_aabb()
		else:
			continue
		var e := [box.size.x, box.size.y, box.size.z]
		e.sort()
		# Thinner than 0.35 m in two directions (pipes, rails, cables) or a small box.
		if e[1] < 0.35 or box.size.x * box.size.y * box.size.z < 0.6:
			_arm_exclude.append((n as CollisionObject3D).get_rid())


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to, ARM_MASK, _arm_exclude)
	return get_world_3d().direct_space_state.intersect_ray(q)


func _zone_at(p: Vector3) -> CameraZone3D:
	for z in _zones:
		if is_instance_valid(z) and z.contains(p):
			return z
	return null


func _update_tp(p: Vector3, delta: float) -> void:
	var vel := target.velocity
	var speed := Vector2(vel.x, vel.z).length()
	var steam := target.state == Player3D.State.STEAM
	var airborne := not target.is_on_floor()
	var zone: CameraZone3D = _zone_at(p)
	var free_cam := _manual_t > follow_delay and not _ended
	if _snap:
		_input_yaw = yaw

	# --- Yaw: recentre / zone hint / lazy follow behind the movement.
	if _recenter and not _ended:
		var ld := target.look_dir()
		var d := wrapf(atan2(-ld.x, -ld.z) - yaw, -PI, PI)
		yaw += _auto_step(d * _smooth(9.0, delta), delta, 5.0)
		if absf(d) < 0.02:
			_recenter = false
			_input_yaw = yaw
	elif free_cam and zone and zone.use_yaw:
		yaw += _auto_step(wrapf(deg_to_rad(zone.yaw_deg) - yaw, -PI, PI) * _smooth(zone.blend, delta), delta)
	elif free_cam and speed > 0.6 and follow_rate > 0.0:
		var d := wrapf(atan2(-vel.x, -vel.z) - yaw, -PI, PI)
		# Walking toward the camera doesn't spin it round (you'd lose your bearings).
		if absf(d) < deg_to_rad(125.0):
			var rate := follow_rate * clampf(speed / 4.0, 0.35, 1.0) * clampf(_manual_t - follow_delay, 0.0, 1.0)
			yaw += _auto_step(d * _smooth(rate, delta), delta)

	# --- Focus: blob + lead in the movement direction; lazy vertical (jumps don't bob
	# the view) but leads upward while rising so you can see where you're going.
	var lead := (Vector3(vel.x, 0, vel.z) * 0.16).limit_length(1.0)
	var lift := 0.0
	if steam and vel.y > 0.3:
		lift = clampf(vel.y * 0.12, 0.0, 0.5)
	elif airborne and vel.y < -2.0:
		lift = clampf(vel.y * 0.08, -0.8, 0.0)
	_lead = _lead.lerp(lead, _smooth(3.0, delta))
	var want := p + Vector3.UP * (focus_height + lift) + _lead
	# Keep the focus under low ceilings so the arm never starts inside a slab.
	var up := _ray(p, want + Vector3.UP * 0.4)
	if not up.is_empty():
		want.y = minf(want.y, (up.position as Vector3).y - 0.4)
	var k := _smooth(10.0, delta)
	var kv := _smooth(2.6 if (airborne and not steam) else 6.0, delta)
	_focus = Vector3(lerpf(_focus.x, want.x, k), lerpf(_focus.y, want.y, kv), lerpf(_focus.z, want.z, k))
	# Never let the lazy vertical lose the blob.
	_focus.y = clampf(_focus.y, p.y - 0.6, p.y + 1.1)

	# --- Distance (zones can pull it in / push it out).
	var dist_want: float = distance * (zone.distance_scale if zone else 1.0)
	_dist = lerpf(_dist, dist_want, _smooth(2.0, delta))

	# --- Pitch: manual pitch for a while, then settle to the situation's pitch.
	var auto: float = deg_to_rad(zone.pitch_deg if zone and zone.use_pitch else pitch_deg)
	if steam and vel.y > 0.5:
		auto = deg_to_rad(rise_pitch_deg)
	elif airborne and vel.y < -4.0:
		auto = deg_to_rad(fall_pitch_deg)
	if _pitch_manual_t > follow_delay * 1.5 and not _ended:
		var moving := speed > 0.4 or absf(vel.y) > 0.5
		pitch = lerp_angle(pitch, auto, _smooth(2.2 if moving else 0.6, delta))

	# --- Arm: tilt under ceilings / over floors (continuously), then sphere cast.
	var want_pitch := pitch
	var hdir := Vector3(sin(yaw), 0, cos(yaw))
	var ceil_y := INF
	for from in [_focus, _focus + hdir * _dist * 0.7]:
		var hit := _ray(from, from + Vector3.UP * 6.0)
		if not hit.is_empty():
			ceil_y = minf(ceil_y, (hit.position as Vector3).y)
	if ceil_y < INF:
		var room := (ceil_y - 0.45) - _focus.y
		want_pitch = maxf(want_pitch, -asin(clampf(room / _dist, -0.9, 0.9)))
	var down := _ray(_focus, _focus + Vector3.DOWN * 6.0)
	if not down.is_empty():
		var below := _focus.y - ((down.position as Vector3).y + 0.45)
		want_pitch = minf(want_pitch, asin(clampf(below / _dist, -0.9, 0.9)))
	# Wall right behind: look over it from higher up if that frees the arm.
	var free_now := _probe(want_pitch, yaw)
	if free_now < _dist * 0.6 and want_pitch > deg_to_rad(-45.0):
		var steep := deg_to_rad(-48.0)
		if ceil_y == INF or (ceil_y - 0.45 - _focus.y) > sin(-steep) * _dist * 0.8:
			var free_steep := _probe(steep, yaw)
			if free_steep > free_now + 1.0:
				want_pitch = lerpf(want_pitch, steep, clampf((free_steep - free_now) / _dist, 0.0, 1.0))
	_tp_pitch = lerp_angle(_tp_pitch, want_pitch, _smooth(5.0, delta))

	# Crowded by a wall at the side: drift (slowly) toward the freer side.
	if free_cam and _arm < _dist * 0.65 and not (zone and zone.use_yaw):
		var l := _probe(_tp_pitch, yaw + 0.45)
		var r := _probe(_tp_pitch, yaw - 0.45)
		if absf(l - r) > 0.8:
			yaw += signf(l - r) * 0.7 * delta

	var b := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, _tp_pitch)
	var dir := b * Vector3(0, 0, 1)
	var free := _probe(_tp_pitch, yaw)
	# Spring arm: in quickly (never through a wall), out slowly once it stays free.
	if _snap:
		_arm = free
	elif free < _arm:
		_arm = minf(lerpf(_arm, free, _smooth(30.0, delta)), free + 0.1)
		_arm_out_t = 0.0
	elif free > _arm + 0.15:
		_arm_out_t += delta
		if _arm_out_t > 0.12:
			_arm = lerpf(_arm, free, _smooth(3.5, delta))
	else:
		_arm_out_t = 0.0
	global_transform = Transform3D(b, _focus + dir * _arm)
	camera.transform = Transform3D.IDENTITY
	if not _move_held():
		_input_yaw = yaw


## Caps a camera-driven yaw step at `max_rate` rad/s (no whip pans).
func _auto_step(step: float, delta: float, max_rate := 1.6) -> float:
	if _snap or delta <= 0.0:
		return step
	return clampf(step, -max_rate * delta, max_rate * delta)


## Free distance (m) from the focus along the camera arm at `p_angle` / `y_angle`.
func _probe(p_angle: float, y_angle: float) -> float:
	var dir := Basis(Vector3.UP, y_angle) * Basis(Vector3.RIGHT, p_angle) * Vector3(0, 0, 1)
	var q := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.28
	q.shape = sphere
	q.transform = Transform3D(Basis(), _focus)
	q.motion = dir * _dist
	q.collision_mask = ARM_MASK
	q.exclude = _arm_exclude
	var res := get_world_3d().direct_space_state.cast_motion(q)
	if res.size() == 2 and res[0] < 1.0:
		return maxf(_dist * res[0], 0.6)
	return _dist


# --- First person / side ------------------------------------------------------------

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


# --- Isometric ----------------------------------------------------------------------

func _update_iso(p: Vector3, delta: float) -> void:
	# 90 deg view turns (Z / X): ease there; the keys map to the new view at once.
	yaw = lerp_angle(yaw, _iso_yaw, _smooth(9.0, delta))
	_input_yaw = _iso_yaw
	# Follow with a little lead in the movement direction.
	var vel := target.velocity
	var lead := (Vector3(vel.x, 0, vel.z) * 0.22).limit_length(1.6)
	_lead = _lead.lerp(lead, _smooth(2.5, delta))
	_focus = _focus.lerp(p + _lead, _smooth(5.0, delta))
	var b := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, deg_to_rad(iso_pitch_deg))
	global_transform = Transform3D(b, _focus + b * Vector3(0, 0, iso_distance))
	if level and level.has_method("apply_view"):
		var key := snappedf(wrapf(yaw, 0.0, TAU), 0.1)
		if key != _view_key:
			_view_key = key
			level.apply_view(forward())
	if level and level.has_method("apply_cut"):
		# Cut at head height, or just under the ceiling right above the blob. Eased, so
		# floors slide in / out over a moment instead of popping.
		var cut := p.y + iso_cut_height
		var q := PhysicsRayQueryParameters3D.create(p, p + Vector3.UP * iso_cut_height, V3D.MASK_CAMERA | V3D.L_GRATE, [target.get_rid()])
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty():
			cut = minf(cut, (hit.position as Vector3).y - 0.02)
		_iso_cut = cut if _iso_cut == INF or _snap else lerpf(_iso_cut, cut, _smooth(7.0, delta))
		level.apply_cut(snappedf(_iso_cut, 0.05))
	if level and level.has_method("update_occluders"):
		level.update_occluders(p, global_basis.z, delta)
	camera.transform = Transform3D.IDENTITY


# --- Landing marker -----------------------------------------------------------------

## Ground ring under the blob (+ a dashed drop line in isometric) so heights and
## landing spots read at a glance. Third person shows it only while airborne.
func _setup_marker() -> void:
	_marker_on = mode == Mode.ISOMETRIC or mode == Mode.THIRD_PERSON
	marker.visible = false
	if not _marker_on:
		return
	marker.top_level = true
	for mi in [marker_disc, marker_line]:
		var m := ShaderMaterial.new()
		m.shader = SH_MARKER
		m.set_shader_parameter("line", mi == marker_line)
		mi.material_override = m


func _update_marker(p: Vector3) -> void:
	if not _marker_on:
		return
	var mask := V3D.MASK_ICE if target.state == Player3D.State.ICE else V3D.MASK_FLUID
	var q := PhysicsRayQueryParameters3D.create(p, p + Vector3.DOWN * 40.0, mask, [target.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty() or target.dead or target.won:
		marker.visible = false
		return
	var g: Vector3 = hit.position
	var h := p.y - g.y
	if mode != Mode.ISOMETRIC and (target.is_on_floor() or h < 0.8):
		marker.visible = false
		return
	marker.visible = true
	marker.global_transform = Transform3D(Basis(), g + Vector3.UP * 0.03)
	var r := 0.5 + clampf(h * 0.03, 0.0, 0.3)
	marker_disc.scale = Vector3(r * 2.0, 1, r * 2.0)
	var line_len := h - 0.45
	marker_line.visible = mode == Mode.ISOMETRIC and line_len > 0.4
	if marker_line.visible:
		marker_line.scale = Vector3(1, line_len, 1)
		marker_line.position = Vector3(0, line_len / 2.0, 0)
		(marker_line.material_override as ShaderMaterial).set_shader_parameter("line_length", line_len)
	(marker_disc.material_override as ShaderMaterial).set_shader_parameter("strength", clampf(1.2 - h * 0.05, 0.6, 1.0))


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
