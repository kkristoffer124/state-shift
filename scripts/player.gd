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
const TEX_ICE := preload("res://assets/player/p1a_ice_body.png")
const TEX_ICE_CRACKS := [
	preload("res://assets/player/p1b_ice_crack_light.png"),
	preload("res://assets/player/p1b_ice_crack_medium.png"),
	preload("res://assets/player/p1b_ice_crack_heavy.png"),
]
const TEX_FROST_RIM := preload("res://assets/player/p1c_ice_frost_rim.png")
const TEX_CORE_GLOW := preload("res://assets/player/p3d_core_glow.png")
const TEX_EYE_WHITE := preload("res://assets/player/p4a_eye_white.png")
const TEX_PUPIL := preload("res://assets/player/p4b_pupil.png")
const TEX_CATCHLIGHT := preload("res://assets/player/p4c_catchlight.png")
const TEX_BLINK := [preload("res://assets/player/p4d_blink_1.png"), preload("res://assets/player/p4d_blink_2.png")]
const TEX_EYES := {
	"blocked": preload("res://assets/player/p4e_eyes_blocked.png"),
	"determined": preload("res://assets/player/p4e_eyes_determined.png"),
	"dizzy": preload("res://assets/player/p4e_eyes_dizzy.png"),
	"happy": preload("res://assets/player/p4e_eyes_happy.png"),
	"scared": preload("res://assets/player/p4e_eyes_scared.png"),
}
const TEX_BURST := preload("res://assets/vfx/v1_shift_burst_5f.png")

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
@onready var fluid: FluidBody = $FluidBody

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
var _crack := 0.0 # ice crack overlay strength, 0..3
var _death_face := Vector2.ZERO


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
		fluid.set_state(state, PackedVector2Array())
		return
	_apply_state_physics()
	fluid.set_state(state, PackedVector2Array())
	_apply_settings()
	var settings := get_node_or_null("/root/Settings")
	if settings and settings.has_signal("changed"):
		settings.connect("changed", _apply_settings)


## Camera zoom / screen shake come from the Settings autoload when it exists.
func _apply_settings() -> void:
	var settings := get_node_or_null("/root/Settings")
	if settings == null:
		return
	var z = settings.get("camera_zoom")
	if z != null:
		camera.zoom = Vector2(z, z)


func _apply_state_physics() -> void:
	shape_node.shape = _shapes[state]
	collision_mask = MASK_ICE if state == State.ICE else MASK_FLUID
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
	var seed_points := _ice_outline() if state == State.ICE else fluid.current_points()
	global_position += offset
	state = target as State
	_apply_state_physics()
	fluid.set_state(state, seed_points)
	if state == State.STEAM:
		velocity.y = minf(velocity.y, -80.0)
	burst.color = STATE_COLORS[state]
	burst.restart()
	_spawn_burst_ring(STATE_COLORS[state])
	_squash = Vector2(1.45, 0.6) if heating else Vector2(0.65, 1.4)
	_shake = maxf(_shake, 3.0)
	Sfx.play("heat" if heating else "cool")
	return true


## Points around the ice cube's edge, used to seed droplets/puffs when melting.
func _ice_outline() -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		var d := Vector2(cos(a), sin(a))
		pts.append(global_position + d / maxf(absf(d.x), absf(d.y)) * 14.0 * global_scale.x)
	return pts


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
	if state != State.WATER:
		_coyote = 0.0 # no mid-air jump after melting
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
	var was_locked := _locked
	_locked = forced != -1
	if was_locked != _locked and Hud.has_method("set_locked"):
		Hud.call("set_locked", _locked)
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
		fluid.on_jump()
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
				_crack = 3.0
	var on_floor := is_on_floor()
	if on_floor and not _was_on_floor and pre.y > 200.0:
		if state == State.ICE:
			_squash = Vector2(1.15, 0.85)
			Sfx.play("land_ice")
			if pre.y > 600.0:
				_shake = maxf(_shake, 6.0)
				_crack = maxf(_crack, clampf((pre.y - 500.0) / 200.0, 1.0, 3.0))
		else:
			fluid.on_land(pre.y)
			Sfx.play("land")
	_was_on_floor = on_floor


func die() -> void:
	if dead or won:
		return
	dead = true
	_death_face = fluid.visual_center - global_position if state != State.ICE else Vector2.ZERO
	fluid.splatter(velocity)
	velocity = Vector2.ZERO
	burst.color = Color(1.0, 0.45, 0.45)
	burst.restart()
	_shake = 9.0
	Sfx.play("die")
	Game.player_died()


func win() -> void:
	if dead or won:
		return
	won = true
	fluid.swirl_away()
	burst.color = Color(0.6, 1.0, 0.7)
	burst.restart()
	Sfx.play("win", 0.0)
	Game.level_complete()


# --- Visuals ----------------------------------------------------------------

func _spawn_burst_ring(col: Color) -> void:
	var ring := Sprite2D.new()
	ring.texture = TEX_BURST
	ring.hframes = 5
	ring.modulate = col
	ring.z_index = 3
	get_parent().add_child(ring)
	ring.global_position = fluid.visual_center if state != State.ICE else global_position
	var tw := ring.create_tween()
	tw.tween_property(ring, "frame", 4, 0.25)
	tw.tween_callback(ring.queue_free)


func _process(delta: float) -> void:
	_t += delta
	if not Engine.is_editor_hint():
		_squash = _squash.lerp(Vector2.ONE, minf(12.0 * delta, 1.0))
		_shake = maxf(_shake - 30.0 * delta, 0.0)
		var shake_on = true
		var settings := get_node_or_null("/root/Settings")
		if settings and settings.get("screen_shake") != null:
			shake_on = settings.get("screen_shake")
		camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake * (0.5 if shake_on else 0.0)
		_blocked_flash = maxf(_blocked_flash - delta, 0.0)
		_crack = maxf(_crack - delta * 1.5, 0.0)
		if won:
			scale = scale.lerp(Vector2.ZERO, minf(6.0 * delta, 1.0))
	queue_redraw()


func _draw() -> void:
	if dead:
		# Dizzy eyes hang where the body burst, then the level reloads.
		draw_set_transform(_death_face + Vector2(0, sin(_t * 8.0) * 1.5))
		_draw_eye_set(TEX_EYES.dizzy)
		draw_set_transform(Vector2.ZERO)
		return
	var jitter := sin(_t * 70.0) * 2.0 if _blocked_flash > 0.0 else 0.0
	var tilt := clampf(velocity.x * 0.0005, -0.15, 0.15) if state == State.ICE else 0.0
	var live_fluid := not Engine.is_editor_hint() and state != State.ICE
	# Water/steam bodies are simulated by FluidBody; the face rides on their centre.
	var face := Vector2.ZERO
	if live_fluid:
		face = (fluid.visual_center - global_position) / maxf(global_scale.x, 0.001)
	var squash := _squash if state == State.ICE else Vector2.ONE
	draw_set_transform(face + Vector2(jitter, 0), tilt, squash)
	match state:
		State.ICE: _draw_ice()
		State.WATER:
			if not live_fluid: _draw_water()
		State.STEAM:
			if live_fluid: _draw_steam_core()
			else: _draw_steam()
	_draw_eyes()
	draw_set_transform(Vector2.ZERO)


func _draw_steam_core() -> void:
	draw_texture(TEX_CORE_GLOW, -TEX_CORE_GLOW.get_size() * 0.5, Color(1, 1, 1, 0.8))


func _draw_ice() -> void:
	draw_texture(TEX_ICE, Vector2(-15, -15))
	if _crack > 0.05:
		var level := clampi(ceili(_crack) - 1, 0, 2)
		draw_texture(TEX_ICE_CRACKS[level], Vector2(-15, -15), Color(1, 1, 1, clampf(_crack - level, 0.3, 1.0)))
	if _locked:
		draw_texture(TEX_FROST_RIM, Vector2(-15, -15), Color(1, 1, 1, 0.7 + sin(_t * 6.0) * 0.3))


## Editor-only preview shapes (in game the FluidBody simulation draws these).
func _draw_water() -> void:
	var pts := PackedVector2Array()
	var n := 28
	for i in n:
		var a := TAU * i / n
		var p := Vector2(cos(a), sin(a)) * 12.0
		if p.y > 10.0:
			p.y = 10.0 + (p.y - 10.0) * 0.3
		pts.append(p)
	draw_colored_polygon(pts, Color(0.25, 0.55, 1.0, 0.95))


func _draw_steam() -> void:
	for i in 6:
		var a := i * TAU / 6.0
		draw_circle(Vector2(cos(a) * 8.0, sin(a * 1.3) * 5.0), 8.0, Color(0.92, 0.95, 1.0, 0.5))
	draw_circle(Vector2.ZERO, 9.0, Color(1, 1, 1, 0.75))


func _expression() -> String:
	if won:
		return "happy"
	if _blocked_flash > 0.0:
		return "blocked"
	if _locked:
		return "determined"
	if velocity.y > 650.0 or _near_spikes():
		return "scared"
	return ""


func _near_spikes() -> bool:
	if Engine.is_editor_hint() or state == State.ICE:
		return false
	for area in sensor.get_overlapping_areas():
		if area is Zone and area.kind == Zone.Kind.SPIKES:
			return true
	return false


func _draw_eye_set(tex: Texture2D) -> void:
	draw_texture(tex, (-tex.get_size() * 0.5 + Vector2(0, -2)).round())


func _draw_eyes() -> void:
	var expr := _expression()
	if expr != "":
		_draw_eye_set(TEX_EYES[expr])
		return
	var cycle := fmod(_t, 3.7)
	if cycle < 0.14:
		_draw_eye_set(TEX_BLINK[0 if cycle < 0.05 or cycle > 0.10 else 1])
		return
	var look := Vector2(_look, clampf(velocity.y * 0.003, -1.0, 1.0)).round()
	for ex in [-5.0, 5.0]:
		var e := Vector2(ex + _look, -2.0)
		draw_texture(TEX_EYE_WHITE, (e - Vector2(3.5, 3.5)).round())
		var pupil := (e - Vector2(1.5, 1.5) + look).round()
		draw_texture(TEX_PUPIL, pupil)
		draw_texture(TEX_CATCHLIGHT, pupil + Vector2(1, 0))
