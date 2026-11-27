@tool
class_name Player3D
extends CharacterBody3D
## The blob in 3D. Same three states and rules as the 2D Player (scripts/player.gd),
## with the 2D tuning converted at 32 px = 1 m (V3D.PX):
##  ICE    heavy, slippery, can't jump, ignores spikes, blocked by grates, shatters cracked floors
##  WATER  nimble, jumps (jump_3d = Space), drips through grates, dies on spikes
##  STEAM  floats upward, drifts, pushed by fans, passes grates, can't press plates
## Moves relative to the CameraRig3D (camera-relative in 3rd/1st person and isometric,
## locked to the X/Y plane in SIDE_25D). The origin is the centre of the body.

signal state_changed(new_state: int)

enum State { ICE, WATER, STEAM }

const PX := V3D.PX
const ICE_HALF := 0.47     # 30 px cube
const WATER_R := 0.34      # 11 px
const STEAM_R := 0.4       # 13 px

@export var state: State = State.WATER

@export_group("Ice")
@export var ice_gravity := 1900.0 * PX
@export var ice_max_speed := 320.0 * PX
@export var ice_accel := 520.0 * PX
@export var ice_friction := 140.0 * PX
@export var ice_max_fall := 1100.0 * PX
## Impact speed (into the surface) needed to shatter a BREAKABLE block (750 px/s).
@export var shatter_speed := 750.0 * PX
@export_group("Water")
@export var water_gravity := 1300.0 * PX
@export var water_speed := 210.0 * PX
@export var water_accel := 1800.0 * PX
@export var water_jump := 440.0 * PX
@export var water_max_fall := 700.0 * PX
@export_group("Steam")
@export var steam_rise := 170.0 * PX
@export var steam_speed := 170.0 * PX
@export var steam_accel := 700.0 * PX

@onready var shape_node: CollisionShape3D = $CollisionShape3D
@onready var sensor: Area3D = $ZoneSensor
@onready var visual: PlayerVisual3D = $Visual

var dead := false
var won := false
## Set by Level3D.
var rig: CameraRig3D
var side_mode := false
var kill_y := -30.0
## Outdoors: the blob can't float above this (rising steam is capped here).
var max_y := 1000.0

var _shapes := {}
var _t := 0.0
var _coyote := 0.0
var _jump_buffer := 0.0
var _was_on_floor := false
var _locked := false
var _look := Vector3.FORWARD
## Body scale (1 = rest). Kicked by jumps / landings / shifts, then a damped spring
## (`_squash_v`) brings it back with a jelly overshoot. The FP camera reads squash.y.
var squash := Vector3.ONE
var _squash_v := Vector3.ZERO
## Position at the start of the last physics tick (for render_position()).
var _prev_phys_pos := Vector3.ZERO
var _prev_phys_valid := false
var shake := 0.0
var crack := 0.0
var blocked_flash := 0.0
var last_landing := 0.0


func _ready() -> void:
	var ice := BoxShape3D.new()
	ice.size = Vector3.ONE * ICE_HALF * 2.0
	var water := SphereShape3D.new()
	water.radius = WATER_R
	var steam := SphereShape3D.new()
	steam.radius = STEAM_R
	_shapes = { State.ICE: ice, State.WATER: water, State.STEAM: steam }
	if Engine.is_editor_hint():
		return
	collision_layer = V3D.L_PLAYER
	floor_snap_length = 0.12
	floor_max_angle = deg_to_rad(50.0)
	_apply_state_physics()


func setup(level: Node, camera_rig: CameraRig3D, side: bool, plane_z: float, kill_height: float) -> void:
	rig = camera_rig
	side_mode = side
	kill_y = kill_height
	axis_lock_linear_z = side
	if side:
		global_position.z = plane_z
	if rig:
		_look = rig.forward()


func _apply_state_physics() -> void:
	shape_node.shape = _shapes[state]
	collision_mask = V3D.MASK_ICE if state == State.ICE else V3D.MASK_FLUID
	state_changed.emit(state)


func is_locked() -> bool:
	return _locked


func look_dir() -> Vector3:
	return _look


## Smooth position for visuals / camera: interpolated between the last two physics
## ticks (physics runs at 60 Hz on web, slower than the display). Teleports (> 1 m in
## one tick: restarts, test staging) snap instead of smearing.
func render_position() -> Vector3:
	var cur := global_position
	if not _prev_phys_valid or _prev_phys_pos.distance_squared_to(cur) > 1.0:
		return cur
	return _prev_phys_pos.lerp(cur, clampf(Engine.get_physics_interpolation_fraction(), 0.0, 1.0))


# --- State shifting -----------------------------------------------------------

func try_shift(target: int, forced := false) -> bool:
	if target == state or target < State.ICE or target > State.STEAM:
		return false
	var offset = _find_fit(target)
	if offset == null:
		if not forced:
			_on_blocked()
			return false
		offset = Vector3.ZERO
	var heating := target > state
	global_position += offset
	state = target as State
	_apply_state_physics()
	if state == State.STEAM:
		velocity.y = maxf(velocity.y, 80.0 * PX)
	squash = Vector3(1.4, 0.62, 1.4) if heating else Vector3(0.68, 1.4, 0.68)
	shake = maxf(shake, 3.0)
	visual.on_shift(heating)
	Sfx.play("heat" if heating else "cool")
	return true


## A small nudge (metres) that lets the new shape fit, or null if it can't.
func _find_fit(target: int):
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = _shapes[target]
	q.collision_mask = V3D.MASK_ICE if target == State.ICE else V3D.MASK_FLUID
	q.exclude = [get_rid()]
	q.margin = 0.0
	var space := get_world_3d().direct_space_state
	var side := [0.0, 3.0, -3.0, 6.0, -6.0]
	for dy in [0.0, 2.0, 4.0, 6.0, 8.0, -2.0, -4.0, 10.0, 12.0, 16.0]:
		for dx in side:
			for dz in ([0.0] if side_mode else side):
				var off := Vector3(dx, dy, dz) * PX
				q.transform = Transform3D(Basis(), global_position + off)
				if space.intersect_shape(q, 1).is_empty():
					return off
	return null


func _on_blocked() -> void:
	blocked_flash = 0.25
	Sfx.play("blocked", 0.0)


func _handle_shift_input() -> void:
	var want: int
	if Input.is_action_just_pressed("heat"):
		want = state + 1
	elif Input.is_action_just_pressed("cool"):
		want = state - 1
	else:
		return
	if _locked or want < State.ICE or want > State.STEAM:
		_on_blocked()
		return
	try_shift(want)


# --- Physics -------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_prev_phys_pos = global_position
	_prev_phys_valid = true
	if dead or won:
		return
	_handle_zones(delta)
	if dead or won:
		return
	_handle_shift_input()
	var dir := rig.move_input() if rig else Vector3(Input.get_axis("move_left", "move_right"), 0, Input.get_axis("move_up", "move_down"))
	if side_mode:
		dir = Vector3(dir.x, 0, 0)
	if dir.length() > 0.1:
		_look = dir.normalized()
	if state != State.WATER:
		_coyote = 0.0
	match state:
		State.ICE: _move_ice(dir, delta)
		State.WATER: _move_water(dir, delta)
		State.STEAM: _move_steam(dir, delta)
	if side_mode:
		velocity.z = 0.0
	var pre := velocity
	move_and_slide()
	_after_move(pre)
	if global_position.y > max_y:
		global_position.y = max_y
		velocity.y = minf(velocity.y, 0.0)
	if global_position.y < kill_y:
		die()


func _handle_zones(delta: float) -> void:
	var forced := -1
	for area in sensor.get_overlapping_areas():
		var z := area as Zone3D
		if z == null:
			continue
		match z.kind:
			Zone3D.Kind.SPIKES:
				if state != State.ICE:
					die()
					return
			Zone3D.Kind.HEAT:
				forced = State.STEAM
			Zone3D.Kind.FREEZE:
				forced = State.ICE
			Zone3D.Kind.FAN:
				var push := z.push_vector()
				if side_mode:
					push.z = 0.0
				if state == State.STEAM:
					velocity += push * delta
				elif state == State.WATER:
					velocity += push * delta * 0.3
			Zone3D.Kind.GOAL:
				win()
				return
	var was_locked := _locked
	_locked = forced != -1
	if was_locked != _locked and Hud.has_method("set_locked"):
		Hud.call("set_locked", _locked)
	if _locked and state != forced:
		try_shift(forced, true)


func _hvel() -> Vector2:
	return Vector2(velocity.x, velocity.z)


func _set_hvel(h: Vector2) -> void:
	velocity.x = h.x
	velocity.z = h.y


func _move_ice(dir: Vector3, delta: float) -> void:
	velocity.y = maxf(velocity.y - ice_gravity * delta, -ice_max_fall)
	var acc := ice_accel if is_on_floor() else ice_accel * 0.5
	var h := _hvel()
	var d := Vector2(dir.x, dir.z)
	if d.length() > 0.05:
		h = h.move_toward(d * ice_max_speed, acc * delta)
	elif is_on_floor():
		h = h.move_toward(Vector2.ZERO, ice_friction * delta)
	_set_hvel(h)


func _jump_pressed() -> bool:
	return Input.is_action_just_pressed("jump_3d") or (side_mode and Input.is_action_just_pressed("move_up"))


func _jump_released() -> bool:
	if side_mode:
		return (Input.is_action_just_released("jump_3d") or Input.is_action_just_released("move_up")) \
			and not Input.is_action_pressed("jump_3d") and not Input.is_action_pressed("move_up")
	return Input.is_action_just_released("jump_3d")


func _move_water(dir: Vector3, delta: float) -> void:
	_coyote = maxf(Settings.coyote_time, 0.001) if is_on_floor() else maxf(_coyote - delta, 0.0)
	if _jump_pressed():
		_jump_buffer = maxf(Settings.jump_buffer, 0.001)
	else:
		_jump_buffer = maxf(_jump_buffer - delta, 0.0)
	velocity.y = maxf(velocity.y - water_gravity * delta, -water_max_fall)
	var h := _hvel().move_toward(Vector2(dir.x, dir.z) * water_speed, water_accel * delta)
	_set_hvel(h)
	if _jump_buffer > 0.0 and _coyote > 0.0:
		velocity.y = water_jump
		_jump_buffer = 0.0
		_coyote = 0.0
		squash = Vector3(0.72, 1.35, 0.72)
		visual.on_jump()
		Sfx.play("jump")
	if _jump_released() and velocity.y > 0.0:
		velocity.y *= 0.5


func _move_steam(dir: Vector3, delta: float) -> void:
	velocity.y = move_toward(velocity.y, steam_rise, 600.0 * PX * delta)
	velocity.y = minf(velocity.y, 650.0 * PX)
	var h := _hvel().move_toward(Vector2(dir.x, dir.z) * steam_speed, steam_accel * delta)
	h += Vector2(sin(_t * 3.0), 0.0 if side_mode else cos(_t * 2.3)) * 25.0 * PX * delta
	_set_hvel(h)


func _after_move(pre: Vector3) -> void:
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var block := c.get_collider() as Block3D
		if state == State.ICE and block and block.kind == Block3D.Kind.BREAKABLE and not block.broken:
			var need := block.break_speed if block.break_speed > 0.0 else shatter_speed
			if -pre.dot(c.get_normal()) > need:
				block.shatter(pre)
				velocity = pre * 0.75
				shake = 12.0
				crack = 3.0
	var on_floor := is_on_floor()
	if on_floor and not _was_on_floor and pre.y < -200.0 * PX:
		last_landing = -pre.y
		if state == State.ICE:
			squash = Vector3(1.15, 0.85, 1.15)
			Sfx.play("land_ice")
			if pre.y < -600.0 * PX:
				shake = maxf(shake, 6.0)
				crack = maxf(crack, clampf((-pre.y - 500.0 * PX) / (200.0 * PX), 1.0, 3.0))
		else:
			squash = Vector3(1.3, 0.7, 1.3)
			Sfx.play("land")
		visual.on_land(-pre.y)
	_was_on_floor = on_floor


func die() -> void:
	if dead or won:
		return
	dead = true
	visual.on_die(velocity)
	velocity = Vector3.ZERO
	shake = 9.0
	Sfx.play("die")
	if rig:
		rig.on_player_end(false)
	Game.player_died()


func win() -> void:
	if dead or won:
		return
	won = true
	visual.on_win()
	Sfx.play("win", 0.0)
	if rig:
		rig.on_player_end(true)
	Game.level_complete()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_t += delta
	_step_squash(delta)
	shake = maxf(shake - 30.0 * delta, 0.0)
	blocked_flash = maxf(blocked_flash - delta, 0.0)
	crack = maxf(crack - delta * 1.5, 0.0)


## Damped spring (stiffness 260, ~0.4 damping ratio) pulling squash back to 1 with a
## wobble or two; sub-stepped so a long web frame can't blow it up.
func _step_squash(delta: float) -> void:
	var left := minf(delta, 0.1)
	while left > 0.0:
		var h := minf(left, 1.0 / 120.0)
		_squash_v += ((Vector3.ONE - squash) * 260.0 - _squash_v * 13.0) * h
		squash = (squash + _squash_v * h).clamp(Vector3.ONE * 0.4, Vector3.ONE * 1.8)
		left -= h


## Expression shown by the eyes: "" for the normal look-around eyes.
func expression() -> String:
	if won:
		return "happy"
	if blocked_flash > 0.0:
		return "blocked"
	if _locked:
		return "determined"
	if velocity.y < -650.0 * PX or _near_spikes():
		return "scared"
	return ""


func _near_spikes() -> bool:
	if state == State.ICE or sensor == null:
		return false
	for area in sensor.get_overlapping_areas():
		if area is Zone3D and area.kind == Zone3D.Kind.SPIKES:
			return true
	return false
