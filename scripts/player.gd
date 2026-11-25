@tool
class_name Player
extends CharacterBody2D
## The blob. Shift between three states of matter:
##  ICE    heavy, slippery, can't jump, ignores spikes, blocked by grates, shatters cracked floors
##  WATER  small and nimble, jumps, drips through grates
##  STEAM  floats upward, drifts, passes grates

signal state_changed(new_state: int)

enum State { ICE, WATER, STEAM }

const STATE_COLORS := [Color(0.72, 0.9, 1.0), Color(0.25, 0.58, 1.0), Color(0.95, 0.97, 1.0)]
const MASK_ICE := 1 | 2 | 4   # world + grates + breakables
const MASK_FLUID := 1 | 4     # world + breakables

@export var state: State = State.WATER:
	set(v):
		state = v
		queue_redraw()

## Display-only (menus): no physics, no input, no camera.
@export var demo := false

@export_group("Ice")
@export var ice_gravity := 1900.0
@export var ice_max_speed := 320.0
@export var ice_accel := 520.0
@export var ice_friction := 140.0
@export var ice_max_fall := 1100.0
## Impact speed (into the surface) needed to shatter a BREAKABLE block.
@export var shatter_speed := 750.0
@export_group("Water")
@export var water_gravity := 1300.0
@export var water_speed := 210.0
@export var water_accel := 1800.0
@export var water_jump := 440.0
@export var water_max_fall := 700.0
@export_group("Steam")
@export var steam_rise := 170.0
@export var steam_speed := 170.0
@export var steam_accel := 700.0

@onready var shape_node: CollisionShape2D = $CollisionShape2D
@onready var sensor: Area2D = $ZoneSensor
@onready var camera: Camera2D = $Camera2D
@onready var burst: CPUParticles2D = $ShiftBurst
@onready var trail: CPUParticles2D = $SteamTrail

var dead := false
var won := false

var _shapes := {}
var _t := 0.0
var _coyote := 0.0
var _jump_buffer := 0.0
var _squash := Vector2.ONE
var _look := 1.0
var _shake := 0.0
var _was_on_floor := false
var _blocked_flash := 0.0
var _locked := false


func _ready() -> void:
	var ice := RectangleShape2D.new()
	ice.size = Vector2(30, 30)
	var water := CircleShape2D.new()
	water.radius = 11.0
	var steam := CircleShape2D.new()
	steam.radius = 13.0
	_shapes = { State.ICE: ice, State.WATER: water, State.STEAM: steam }
	if Engine.is_editor_hint():
		return
	if demo:
		camera.enabled = false
		set_physics_process(false)
		trail.emitting = state == State.STEAM
		return
	_apply_state_physics()


func _apply_state_physics() -> void:
	shape_node.shape = _shapes[state]
	collision_mask = MASK_ICE if state == State.ICE else MASK_FLUID
	trail.emitting = state == State.STEAM
	state_changed.emit(state)


# --- State shifting ---------------------------------------------------------

func try_shift(target: int, forced := false) -> bool:
	if target == state or target < State.ICE or target > State.STEAM:
		return false
	var offset = _find_fit(target)
	if offset == null:
		if not forced:
			_on_blocked()
			return false
		offset = Vector2.ZERO
	var heating := target > state
	global_position += offset
	state = target as State
	_apply_state_physics()
	if state == State.STEAM:
		velocity.y = minf(velocity.y, -80.0)
	burst.color = STATE_COLORS[state]
	burst.restart()
	_squash = Vector2(1.45, 0.6) if heating else Vector2(0.65, 1.4)
	_shake = maxf(_shake, 3.0)
	Sfx.play("heat" if heating else "cool")
	return true


## Returns a small nudge that lets the new shape fit, or null if it can't.
func _find_fit(target: int):
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = _shapes[target]
	q.collision_mask = MASK_ICE if target == State.ICE else MASK_FLUID
	q.exclude = [get_rid()]
	var space := get_world_2d().direct_space_state
	for dy in [0, -2, -4, -6, -8, 2, 4, -10, -12, -16]:
		for dx in [0, 3, -3, 6, -6]:
			q.transform = Transform2D(0.0, global_position + Vector2(dx, dy))
			if space.intersect_shape(q, 1).is_empty():
				return Vector2(dx, dy)
	return null


func _on_blocked() -> void:
	_blocked_flash = 0.25
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


# --- Physics ----------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or dead or won:
		return
	_handle_zones(delta)
	if dead or won:
		return
	_handle_shift_input()
	var dir := Input.get_axis("move_left", "move_right")
	if dir != 0.0:
		_look = signf(dir)
	match state:
		State.ICE: _move_ice(dir, delta)
		State.WATER: _move_water(dir, delta)
		State.STEAM: _move_steam(dir, delta)
	var pre := velocity
	move_and_slide()
	_after_move(pre)


func _handle_zones(delta: float) -> void:
	var forced := -1
	for area in sensor.get_overlapping_areas():
		var z := area as Zone
		if z == null:
			continue
		match z.kind:
			Zone.Kind.SPIKES:
				if state != State.ICE:
					die()
					return
			Zone.Kind.HEAT:
				forced = State.STEAM
			Zone.Kind.FREEZE:
				forced = State.ICE
			Zone.Kind.FAN:
				if state == State.STEAM:
					velocity += z.push_vector() * delta
				elif state == State.WATER:
					velocity += z.push_vector() * delta * 0.3
			Zone.Kind.GOAL:
				win()
				return
	_locked = forced != -1
	if _locked and state != forced:
		try_shift(forced, true)


func _move_ice(dir: float, delta: float) -> void:
	velocity.y = minf(velocity.y + ice_gravity * delta, ice_max_fall)
	var acc := ice_accel if is_on_floor() else ice_accel * 0.5
	if dir != 0.0:
		velocity.x = move_toward(velocity.x, dir * ice_max_speed, acc * delta)
	elif is_on_floor():
		velocity.x = move_toward(velocity.x, 0.0, ice_friction * delta)


func _move_water(dir: float, delta: float) -> void:
	_coyote = 0.1 if is_on_floor() else maxf(_coyote - delta, 0.0)
	if Input.is_action_just_pressed("jump"):
		_jump_buffer = 0.12
	else:
		_jump_buffer = maxf(_jump_buffer - delta, 0.0)
	velocity.y = minf(velocity.y + water_gravity * delta, water_max_fall)
	velocity.x = move_toward(velocity.x, dir * water_speed, water_accel * delta)
	if _jump_buffer > 0.0 and _coyote > 0.0:
		velocity.y = -water_jump
		_jump_buffer = 0.0
		_coyote = 0.0
		_squash = Vector2(0.7, 1.35)
		Sfx.play("jump")
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= 0.5


func _move_steam(dir: float, delta: float) -> void:
	velocity.y = move_toward(velocity.y, -steam_rise, 600.0 * delta)
	velocity.y = maxf(velocity.y, -650.0)
	velocity.x = move_toward(velocity.x, dir * steam_speed, steam_accel * delta)
	velocity.x += sin(_t * 3.0) * 25.0 * delta


func _after_move(pre: Vector2) -> void:
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var block := c.get_collider() as Block
		if state == State.ICE and block and block.kind == Block.Kind.BREAKABLE:
			if -pre.dot(c.get_normal()) > shatter_speed:
				block.shatter(pre)
				velocity = pre * 0.75
				_shake = 12.0
	var on_floor := is_on_floor()
	if on_floor and not _was_on_floor and pre.y > 200.0:
		if state == State.ICE:
			_squash = Vector2(1.15, 0.85)
			Sfx.play("land_ice")
			if pre.y > 600.0:
				_shake = maxf(_shake, 6.0)
		else:
			_squash = Vector2(1.35, 0.7)
			Sfx.play("land")
	_was_on_floor = on_floor


func die() -> void:
	if dead or won:
		return
	dead = true
	velocity = Vector2.ZERO
	trail.emitting = false
	burst.color = Color(1.0, 0.45, 0.45)
	burst.restart()
	_shake = 9.0
	Sfx.play("die")
	Game.player_died()


func win() -> void:
	if dead or won:
		return
	won = true
	burst.color = Color(0.6, 1.0, 0.7)
	burst.restart()
	Sfx.play("win", 0.0)
	Game.level_complete()


# --- Visuals ----------------------------------------------------------------

func _process(delta: float) -> void:
	_t += delta
	if not Engine.is_editor_hint():
		_squash = _squash.lerp(Vector2.ONE, minf(12.0 * delta, 1.0))
		_shake = maxf(_shake - 30.0 * delta, 0.0)
		camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
		_blocked_flash = maxf(_blocked_flash - delta, 0.0)
		if won:
			scale = scale.lerp(Vector2.ZERO, minf(6.0 * delta, 1.0))
	queue_redraw()


func _draw() -> void:
	if dead:
		return
	var jitter := sin(_t * 70.0) * 3.0 if _blocked_flash > 0.0 else 0.0
	var tilt := clampf(velocity.x * 0.0005, -0.15, 0.15) if state == State.ICE else 0.0
	draw_set_transform(Vector2(jitter, 0), tilt, _squash)
	match state:
		State.ICE: _draw_ice()
		State.WATER: _draw_water()
		State.STEAM: _draw_steam()
	_draw_eyes()
	if _locked:
		draw_arc(Vector2.ZERO, 20.0, 0, TAU, 24, Color(1, 1, 1, 0.35 + sin(_t * 10.0) * 0.2), 1.5)
	draw_set_transform(Vector2.ZERO)


func _draw_ice() -> void:
	var r := Rect2(-15, -15, 30, 30)
	draw_rect(r, Color(0.72, 0.9, 1.0, 0.95))
	draw_rect(Rect2(-15, -15, 30, 7), Color(0.9, 0.98, 1.0, 0.9))
	draw_line(Vector2(-10, -8), Vector2(-3, -11), Color.WHITE, 2.0)
	draw_polyline(PackedVector2Array([Vector2(5, -15), Vector2(8, -6), Vector2(4, 1), Vector2(9, 8)]), Color(0.5, 0.75, 0.95), 1.0)
	draw_rect(r, Color(0.35, 0.62, 0.88), false, 2.0)


func _draw_water() -> void:
	var pts := PackedVector2Array()
	var n := 28
	for i in n:
		var a := TAU * i / n
		var rr := 12.0 + sin(_t * 7.0 + i * 1.3) * 0.8 + sin(_t * 4.3 + i * 2.1) * 0.6
		var p := Vector2(cos(a), sin(a)) * rr
		if p.y > 10.0:
			p.y = 10.0 + (p.y - 10.0) * 0.3
		pts.append(p)
	draw_colored_polygon(pts, Color(0.22, 0.55, 1.0, 0.92))
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, Color(0.12, 0.35, 0.8), 2.0)
	draw_circle(Vector2(-5, -6), 3.0, Color(1, 1, 1, 0.7))


func _draw_steam() -> void:
	for i in 6:
		var a := _t * 1.5 + i * TAU / 6.0
		var p := Vector2(cos(a) * 8.0, sin(a * 1.3) * 5.0)
		draw_circle(p, 8.0 + sin(_t * 3.0 + i) * 1.5, Color(0.92, 0.95, 1.0, 0.5))
	draw_circle(Vector2.ZERO, 9.0, Color(1, 1, 1, 0.75))


func _draw_eyes() -> void:
	var blink := fmod(_t, 3.7) < 0.12
	var look_y := clampf(velocity.y * 0.004, -1.5, 1.5)
	for ex in [-5.0, 5.0]:
		var e := Vector2(ex + _look * 2.0, -2.0)
		if blink:
			draw_line(e - Vector2(3, 0), e + Vector2(3, 0), Color(0.05, 0.08, 0.15), 1.5)
		else:
			draw_circle(e, 3.2, Color.WHITE)
			draw_circle(e + Vector2(_look * 1.2, 0.5 + look_y), 1.7, Color(0.05, 0.08, 0.15))
