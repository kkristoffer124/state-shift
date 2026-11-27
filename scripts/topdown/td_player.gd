@tool
class_name TdPlayer
extends CharacterBody2D
## The blob seen from above (scenes/topdown/td_player.tscn). Same contract as Player:
## `state` (0 ICE, 1 WATER, 2 STEAM), state_changed, dead, won, Game.player_died /
## Game.level_complete, Hud.set_locked.
##  ICE    frictionless: a push slides it along the grid until it hits something.
##         Heavy (holds plates), shatters cracked blocks at speed, ignores spikes,
##         stopped by bars and mesh. Falls into pits and sinks in sewage.
##  WATER  free 8-way movement, slips between bars, squeezes down linked floor
##         drains, leaves a wet trail. Spikes, pits and sewage are deadly.
##  STEAM  floats: free but drifty movement over pits, sewage and spikes, through
##         bars and vent mesh; pushed hard by fans.
## Zones: HEAT forces STEAM, FREEZE forces ICE (and snaps it to the grid).

signal state_changed(new_state: int)

enum State { ICE, WATER, STEAM }

const STATE_COLORS := [Color(0.72, 0.9, 1.0), Color(0.25, 0.58, 1.0), Color(0.95, 0.97, 1.0)]
const CELL := 32.0
## Collision masks per state: 1 walls/gates, 2 bars, 4 cracked, 64 vent mesh.
const MASKS := [1 | 2 | 4 | 64, 1 | 4 | 64, 1 | 4]
## Fans: drift speed (px/s) per unit of push_strength. STEAM rides it fully, WATER a little.
const WIND_DRIFT := 0.14

@export var state: State = State.WATER:
	set(v):
		state = v
		if is_node_ready():
			$Visual.queue_redraw()

@export_group("Ice")
@export var ice_start_speed := 220.0
@export var ice_max_speed := 540.0
@export var ice_accel := 2200.0
## Slide speed needed to smash a TdCracked block.
@export var shatter_speed := 430.0
@export_group("Water")
@export var water_speed := 150.0
@export var water_accel := 1500.0
@export_group("Steam")
@export var steam_speed := 125.0
@export var steam_accel := 520.0

@onready var shape_node: CollisionShape2D = $CollisionShape2D
@onready var sensor: Area2D = $ZoneSensor
@onready var camera: Camera2D = $Camera2D
@onready var burst: CPUParticles2D = $ShiftBurst
@onready var splash: CPUParticles2D = $Splash
@onready var visual: Node2D = $Visual

var dead := false
var won := false
## Unused here (the room camera is fixed) but kept for parity with Player.
var zoom_override := 1.0

var terrain: TdTerrain
var level: Node
## Ice: current slide direction (zero = resting) and speed.
var slide_dir := Vector2.ZERO
var slide_speed := 0.0
## Visual-only offset that eases back to zero after a snap (grid snap, drain pop).
var vis_offset := Vector2.ZERO
var squash := Vector2.ONE
var look := Vector2.RIGHT
var blocked_flash := 0.0
var locked := false
var crack := 0.0
var busy := false        # drain squeeze / falling / winning: no control
var in_pipe := false      # inside a pipe
var fall_t := -1.0       # >= 0 while falling into a hole
var win_t := 0.0         # 0..1 swirl into the goal
var t := 0.0
## Fan drift at the blob this frame.
var wind := Vector2.ZERO

var _shapes := {}
var _shake := 0.0
var _bumped := Vector2.ZERO
var _drain_exit: TdDrain


func _ready() -> void:
	var ice := RectangleShape2D.new()
	ice.size = Vector2(28, 28)
	var water := CircleShape2D.new()
	water.radius = 10.0
	var steam := CircleShape2D.new()
	steam.radius = 11.0
	_shapes = { State.ICE: ice, State.WATER: water, State.STEAM: steam }
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	if Engine.is_editor_hint():
		return
	level = get_parent()
	terrain = level.get_node_or_null("Blocks/Terrain") as TdTerrain
	_apply_state_physics(false)
	if state == State.ICE and terrain:
		global_position = terrain.cell_center(global_position)


func _apply_state_physics(emit := true) -> void:
	shape_node.shape = _shapes[state]
	collision_mask = MASKS[state]
	if emit:
		state_changed.emit(state)


func is_resting() -> bool:
	return state == State.ICE and slide_dir == Vector2.ZERO and not busy and not dead


func is_sliding() -> bool:
	return state == State.ICE and slide_dir != Vector2.ZERO


func _shake_on() -> bool:
	var settings := get_node_or_null("/root/Settings")
	if settings and settings.get("screen_shake") != null:
		return settings.get("screen_shake")
	return true


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


# --- State shifting ---------------------------------------------------------------

func try_shift(target: int, forced := false) -> bool:
	if target == state or target < State.ICE or target > State.STEAM or busy:
		return false
	var fit = _find_fit(target)
	if fit == null:
		if not forced:
			_on_blocked()
			return false
		fit = global_position
	var heating := target > state
	var old := global_position
	global_position = fit
	vis_offset += old - global_position
	state = target as State
	slide_dir = Vector2.ZERO
	slide_speed = 0.0
	if state == State.STEAM:
		velocity *= 0.4
	elif state == State.ICE:
		velocity = Vector2.ZERO
	_apply_state_physics()
	burst.color = STATE_COLORS[state]
	burst.restart()
	visual.on_shift(heating)
	squash = Vector2(1.4, 0.65) if heating else Vector2(0.7, 1.35)
	shake(3.0)
	Sfx.play("heat" if heating else "cool")
	return true


## Where the new shape fits (ICE snaps onto the grid), or null.
func _find_fit(target: int):
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = _shapes[target]
	q.collision_mask = MASKS[target]
	q.exclude = [get_rid()]
	var space := get_world_2d().direct_space_state
	var cands: Array[Vector2] = []
	if target == State.ICE and terrain:
		var c := terrain.cell_center(global_position)
		for d in [Vector2.ZERO, Vector2(CELL, 0), Vector2(-CELL, 0), Vector2(0, CELL), Vector2(0, -CELL)]:
			var p: Vector2 = c + d
			if p.distance_to(global_position) <= 26.0:
				cands.append(p)
		cands.sort_custom(func(a: Vector2, b: Vector2) -> bool:
			return a.distance_squared_to(global_position) < b.distance_squared_to(global_position))
	else:
		for d in [Vector2.ZERO, Vector2(0, -3), Vector2(3, 0), Vector2(-3, 0), Vector2(0, 3), Vector2(0, -6), Vector2(6, 0), Vector2(-6, 0), Vector2(0, 6)]:
			cands.append(global_position + d)
	for p in cands:
		q.transform = Transform2D(0.0, p)
		if space.intersect_shape(q, 1).is_empty():
			return p
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
	if locked or want < State.ICE or want > State.STEAM:
		_on_blocked()
		return
	try_shift(want)


# --- Physics -------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or dead or won or busy:
		return
	_handle_zones(delta)
	if dead or won or busy:
		return
	_handle_shift_input()
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if dir.length() > 0.1:
		look = dir.normalized()
	match state:
		State.ICE: _move_ice(delta)
		State.WATER: _move_free(dir, water_speed, water_accel, delta)
		State.STEAM: _move_steam(dir, delta)
	_check_floor()


func _handle_zones(_delta: float) -> void:
	var forced := -1
	wind = Vector2.ZERO
	for area in sensor.get_overlapping_areas():
		var z := area as TdZone
		if z == null:
			continue
		match z.kind:
			TdZone.Kind.HEAT:
				forced = State.STEAM
			TdZone.Kind.FREEZE:
				forced = State.ICE
			TdZone.Kind.FAN:
				wind += z.push_vector() * WIND_DRIFT
			TdZone.Kind.GOAL:
				win(z.global_position + z.size / 2.0)
				return
	var was_locked := locked
	locked = forced != -1
	if was_locked != locked and Hud.has_method("set_locked"):
		Hud.call("set_locked", locked)
	if locked and state != forced:
		try_shift(forced, true)


## Strongest cardinal direction held (ice only moves along the grid).
func _cardinal_input() -> Vector2:
	var x := Input.get_axis("move_left", "move_right")
	var y := Input.get_axis("move_up", "move_down")
	if absf(x) < 0.3 and absf(y) < 0.3:
		return Vector2.ZERO
	if absf(x) >= absf(y):
		return Vector2(signf(x), 0)
	return Vector2(0, signf(y))


func _move_ice(delta: float) -> void:
	velocity = Vector2.ZERO
	if slide_dir == Vector2.ZERO:
		var c := terrain.cell_center(global_position) if terrain else global_position
		global_position = global_position.move_toward(c, 90.0 * delta)
		var d := _cardinal_input()
		if d == Vector2.ZERO:
			_bumped = Vector2.ZERO
			return
		if test_move(global_transform, d * 3.0):
			if _bumped != d:
				_bumped = d
				squash = Vector2(0.85, 1.12) if d.x != 0.0 else Vector2(1.12, 0.85)
				vis_offset += d * 2.0
				Sfx.play("blocked", 0.0)
			return
		_bumped = Vector2.ZERO
		global_position = c
		slide_dir = d
		slide_speed = ice_start_speed
		look = d
		squash = Vector2(1.2, 0.85) if d.x != 0.0 else Vector2(0.85, 1.2)
		visual.on_push()
		return
	slide_speed = minf(slide_speed + ice_accel * delta, ice_max_speed)
	velocity = slide_dir * slide_speed
	# keep the cube on its lane
	if terrain:
		var c := terrain.cell_center(global_position)
		if slide_dir.x != 0.0:
			global_position.y = c.y
		else:
			global_position.x = c.x
	var remaining := slide_dir * slide_speed * delta
	for i in 3:
		var col := move_and_collide(remaining)
		if col == null:
			return
		var other := col.get_collider()
		if other is TdCracked and slide_speed >= shatter_speed:
			other.shatter(velocity)
			slide_speed *= 0.75
			crack = 3.0
			shake(10.0)
			remaining = col.get_remainder()
			continue
		_stop_ice()
		return


func _stop_ice() -> void:
	var impact := slide_speed
	slide_dir = Vector2.ZERO
	slide_speed = 0.0
	velocity = Vector2.ZERO
	if terrain:
		var c := terrain.cell_center(global_position)
		vis_offset += global_position - c
		global_position = c
	squash = Vector2(0.8, 1.2) if absf(look.x) > 0.0 else Vector2(1.2, 0.8)
	shake(clampf(impact / 120.0, 1.0, 5.0))
	crack = maxf(crack, clampf((impact - 380.0) / 100.0, 0.0, 1.5))
	visual.on_ice_stop(impact)
	Sfx.play("land_ice")


func _move_free(dir: Vector2, speed: float, accel: float, delta: float) -> void:
	velocity = velocity.move_toward(dir * speed + wind * 0.25, accel * delta)
	move_and_slide()


func _move_steam(dir: Vector2, delta: float) -> void:
	velocity = velocity.move_toward(dir * steam_speed + wind, steam_accel * delta)
	velocity += Vector2(sin(t * 2.3), cos(t * 1.7)) * 18.0 * delta
	velocity = velocity.limit_length(420.0)
	move_and_slide()


## Holes, spikes and drains under the blob's centre.
func _check_floor() -> void:
	if terrain == null:
		return
	var ch := terrain.char_at(global_position)
	if state != State.STEAM and terrain.is_hole(ch):
		_fall_in(ch)
		return
	if state == State.WATER and ch == TdTerrain.SPIKES:
		die(true)
		return
	if state == State.WATER:
		_check_drains()


func _check_drains() -> void:
	if _drain_exit and is_instance_valid(_drain_exit):
		if global_position.distance_to(_drain_exit.center()) > 22.0:
			_drain_exit = null
	for d in get_tree().get_nodes_in_group("td_drain"):
		var drain := d as TdDrain
		if drain == null or drain == _drain_exit or not level.is_ancestor_of(drain):
			continue
		var to := drain.target_drain()
		if to and global_position.distance_to(drain.center()) < TdDrain.RADIUS:
			_squeeze(drain, to)
			return


## Down one drain, along the pipe, up the other.
func _squeeze(from: TdDrain, to: TdDrain) -> void:
	busy = true
	velocity = Vector2.ZERO
	from.gulp()
	visual.on_drain_in(from.center())
	Sfx.play("land")
	splash.global_position = from.center()
	splash.restart()
	var tw := create_tween()
	tw.tween_property(self, "global_position", from.center(), 0.12)
	tw.parallel().tween_property(self, "squash", Vector2(1.5, 0.3), 0.12)
	tw.tween_property(self, "squash", Vector2(0.05, 0.05), 0.16)
	tw.tween_callback(func() -> void: in_pipe = true)
	tw.tween_interval(0.35)
	tw.tween_callback(func() -> void:
		global_position = to.center()
		vis_offset = Vector2.ZERO
		in_pipe = false
		squash = Vector2(0.3, 1.6)
		to.gulp()
		visual.on_drain_out(to.center())
		splash.global_position = to.center()
		splash.restart()
		Sfx.play("jump")
		_drain_exit = to)
	tw.tween_property(self, "squash", Vector2.ONE, 0.2)
	tw.tween_callback(func() -> void: busy = false)


func _fall_in(ch: String) -> void:
	busy = true
	fall_t = 0.0
	velocity = Vector2.ZERO
	var c := terrain.cell_center(global_position)
	var target := global_position.lerp(c, 0.6) + Vector2(0, 6)
	if ch == TdTerrain.SEWAGE:
		splash.global_position = global_position
		splash.restart()
		Sfx.play("land")
	var tw := create_tween()
	tw.tween_property(self, "global_position", target, 0.35).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(self, "fall_t", 1.0, 0.35)
	tw.tween_callback(func() -> void: die(false))


func die(splatter := true) -> void:
	if dead or won:
		return
	dead = true
	busy = false
	velocity = Vector2.ZERO
	if splatter:
		splash.global_position = global_position
		splash.restart()
		visual.on_splat()
	burst.color = Color(1.0, 0.45, 0.45)
	burst.restart()
	shake(9.0)
	Sfx.play("die")
	Game.player_died()


func win(at: Vector2) -> void:
	if dead or won:
		return
	won = true
	slide_dir = Vector2.ZERO
	velocity = Vector2.ZERO
	burst.color = Color(0.6, 1.0, 0.7)
	burst.restart()
	Sfx.play("win", 0.0)
	var tw := create_tween()
	tw.tween_property(self, "global_position", at, 0.45).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(self, "win_t", 1.0, 0.6)
	Game.level_complete()


# --- Per frame ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	t += delta
	if Engine.is_editor_hint():
		return
	squash = squash.lerp(Vector2.ONE, minf(12.0 * delta, 1.0)) if not busy else squash
	vis_offset = vis_offset.lerp(Vector2.ZERO, minf(11.0 * delta, 1.0)) # visual-only ease after snaps
	_shake = maxf(_shake - 30.0 * delta, 0.0)
	camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake * 0.5 * Settings.shake_scale()
	blocked_flash = maxf(blocked_flash - delta, 0.0)
	crack = maxf(crack - delta * 1.2, 0.0)

