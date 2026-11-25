class_name FluidBody
extends Node2D
## The player's WATER / STEAM body as pixel particles (Sandboxels-style).
## Each pixel is pulled towards a "home" slot around the player by a spring, but
## moves and collides on its own against the level's FluidWorld grid, so the
## body sloshes, squashes against floors and walls, and lags when you move.
## Hard landings and fast moves throw pixels off; they become free water in the
## FluidWorld (they pool, flow and drip through grates) and the blob soaks them
## back up when it passes. Steam pixels peel off as rising wisps.
## Gameplay collision still uses the Player's own shape.

@export_group("Water")
@export var water_pixels := 118
@export var water_spring := 900.0
@export var water_damping := 10.0
## How far (px) a pixel can be pulled from home before it breaks off.
@export var water_break_distance := 14.0
@export var absorb_radius := 15.0

@export_group("Steam")
@export var steam_pixels := 80
@export var steam_spring := 140.0
@export var steam_damping := 5.0
@export var steam_break_distance := 16.0

const CELL := 2
const PACK: Array[Vector2i] = [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1),
	Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1),
	Vector2i(0, -2), Vector2i(-2, 0), Vector2i(2, 0), Vector2i(0, 2)]
const C_SURFACE := Color("6fb0ff")
const C_BODY := Color("3f8cff")
const C_DEEP := Color("1f59cc")
const C_RIM := Color("1a4aad")
const C_FOAM := Color("cfe6ff")
const C_SHINE := Color("e8f3ff")
const C_STEAM := Color("f2f7ff")
const C_STEAM_EDGE := Color("c5d3e6")

var center := Vector2.ZERO
var center_velocity := Vector2.ZERO
## Where the face should be drawn (pinned to the body, nudged towards its mass).
var visual_center := Vector2.ZERO
var water_active := false
var steam_active := false
var alpha := 1.0

var _pos := PackedVector2Array()
var _vel := PackedVector2Array()
var _alive := PackedByteArray()
var _homes := PackedVector2Array()
var _steam_homes := PackedVector2Array()
var _squash := 0.0
var _squash_v := 0.0
var _regen := 0.0
var _fading := false
var _scale := 1.0
var _t := 0.0
var _world: FluidWorld
var _prev_vx := 0.0
var _spent := false # died/won: no more refilling


func _ready() -> void:
	top_level = true
	global_position = Vector2.ZERO
	_scale = (get_parent() as Node2D).global_scale.x
	center = get_parent().global_position
	visual_center = center
	_homes = _disc(water_pixels, 0.0)
	_steam_homes = _disc(steam_pixels, 1.6)


## Pixel slots on a 2 px lattice filling a disc, nearest-first.
func _disc(count: int, spread: float) -> PackedVector2Array:
	var cells: Array[Vector2] = []
	for y in range(-12, 13):
		for x in range(-12, 13):
			cells.append(Vector2(x, y) * CELL)
	cells.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.length_squared() < b.length_squared())
	var out := PackedVector2Array()
	for i in count:
		out.append(cells[i] * (1.0 + spread * (cells[i].length() / 24.0)))
	return out


func _get_world() -> FluidWorld:
	if _world == null or not is_instance_valid(_world):
		_world = get_tree().get_first_node_in_group("fluid_world") as FluidWorld
	return _world


# --- Public API (called by Player) ------------------------------------------

func set_state(state: int, from_points: PackedVector2Array) -> void:
	var was_fluid := water_active or steam_active
	var old := _pos.duplicate()
	var old_alive := _alive.duplicate()
	water_active = state == Player.State.WATER
	steam_active = state == Player.State.STEAM
	_squash = 0.0
	_squash_v = 3.0 if water_active else 0.0
	var n := water_pixels if water_active else steam_pixels if steam_active else 0
	_pos.resize(n)
	_vel.resize(n)
	_alive.resize(n)
	for i in n:
		var p := center + _home(i)
		if was_fluid and not old.is_empty():
			var j := (i * old.size()) / n
			if old_alive[j] == 1:
				p = old[j]
		elif not from_points.is_empty():
			# Melting from ice: start spread over the cube, then slump.
			p = center + Vector2(randf_range(-14, 14), randf_range(-14, 14)) * _scale
		_pos[i] = p
		_vel[i] = center_velocity * 0.6
		_alive[i] = 1
	if steam_active:
		for i in n:
			_vel[i] += Vector2(randf_range(-60, 60), randf_range(-90, 0))


func current_points() -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in _pos.size():
		if _alive[i] == 1:
			out.append(_pos[i])
	return out


func on_land(impact: float) -> void:
	if not water_active:
		return
	_squash_v += clampf(impact * 0.012, 0.0, 9.0)
	if impact < 240.0:
		return
	# Throw pixels from the bottom half outwards: a real splash.
	var budget := int(clampf((impact - 200.0) / 18.0, 2, water_pixels * 0.35))
	var order := range(_pos.size())
	order.shuffle()
	for i in order:
		if budget <= 0:
			break
		if _alive[i] == 1 and _homes[i].y > 2.0:
			var side := signf(_homes[i].x) if _homes[i].x != 0.0 else (1.0 if randf() < 0.5 else -1.0)
			var v := Vector2(side * randf_range(70, 240), -randf_range(80, 140 + impact * 0.45)) * _scale
			_release(i, v)
			budget -= 1


func on_jump() -> void:
	if not water_active:
		return
	_squash_v -= 7.0
	var n := 0
	for i in _pos.size():
		if n >= 5:
			break
		if _alive[i] == 1 and _homes[i].y > 6.0 and randf() < 0.4:
			_release(i, Vector2(randf_range(-120, 120), randf_range(-40, 60)) * _scale)
			n += 1


func splatter(impact: Vector2) -> void:
	for i in _pos.size():
		if _alive[i] == 1:
			var out := (_pos[i] - center).normalized()
			_release(i, impact * 0.3 + (out * randf_range(120, 320) + Vector2(0, -160)) * _scale)
	_fading = true
	_spent = true


func swirl_away() -> void:
	_fading = true
	_spent = true


func _release(i: int, v: Vector2) -> void:
	_alive[i] = 0
	var world := _get_world()
	if world == null:
		return
	if water_active:
		world.spawn_water(_pos[i], v)
	elif steam_active:
		world.spawn_steam(_pos[i], v)


func _home(i: int) -> Vector2:
	if water_active:
		var h := _homes[i]
		var sx := 1.0 + _squash
		var sy := 1.0 - _squash * 0.8
		var o := Vector2(h.x * sx, h.y * sy)
		if _squash > 0.0:
			o.y += _squash * 7.0 # flatten towards the floor
		# Stretch along fast motion.
		var sp := center_velocity.length()
		if sp > 60.0:
			var d := center_velocity / sp
			var st := clampf(sp / 2600.0, 0.0, 0.15)
			o = d * o.dot(d) * (1.0 + st) + d.orthogonal() * o.dot(d.orthogonal()) * (1.0 - st * 0.5)
		return o * _scale
	# Steam churns: homes rotate slowly and breathe.
	var h2 := _steam_homes[i % _steam_homes.size()]
	var a := _t * (0.8 + (i % 5) * 0.15) * (1.0 if i % 2 == 0 else -1.0)
	var breathe := 1.0 + sin(_t * 2.0 + i) * 0.12
	return h2.rotated(a * 0.6) * breathe * _scale


# --- Simulation ---------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_t += delta
	var body := get_parent() as Node2D
	var new_center := body.global_position
	center_velocity = (new_center - center) / delta
	center = new_center
	if _fading:
		alpha = maxf(alpha - delta * 2.0, 0.0)
	if water_active:
		_step(delta, water_spring, water_damping, 1300.0 * 0.25, water_break_distance)
		_refill(delta)
	elif steam_active:
		_step(delta, steam_spring, steam_damping, -90.0, steam_break_distance)
		_refill(delta)
	visual_center = center + (_mass_center() - center).limit_length(3.0 * _scale)
	_prev_vx = center_velocity.x
	queue_redraw()


func _step(delta: float, k: float, damp: float, grav: float, break_dist: float) -> void:
	_squash_v += (-260.0 * _squash - 9.0 * _squash_v) * delta
	_squash = clampf(_squash + _squash_v * delta, -0.5, 0.6)
	var dvx := center_velocity.x - _prev_vx
	if water_active and absf(dvx) > 150.0:
		_squash_v += absf(dvx) * 0.003
	var world := _get_world()
	for i in _pos.size():
		if _alive[i] == 0:
			continue
		var p := _pos[i]
		var v := _vel[i]
		var target := center + _home(i)
		v += ((target - p) * k + Vector2(0, grav)) * delta
		if steam_active:
			v += Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 400.0 * delta
		v *= exp(-damp * delta)
		var next := p + v * delta
		if world and world.is_blocked(next):
			if not world.is_blocked(Vector2(next.x, p.y)):
				next.y = p.y
				v.y = 0.0
			elif not world.is_blocked(Vector2(p.x, next.y)):
				next.x = p.x
				v.x = 0.0
			else:
				next = p
				v = Vector2.ZERO
		# Left behind (stuck on a ledge, flung by a fast move): break off.
		if next.distance_to(target) > break_dist * _scale * (2.5 if steam_active else 1.0):
			_pos[i] = next
			_release(i, v)
			continue
		if next.distance_to(center) > 70.0 * _scale:
			next = target
			v = center_velocity
		_pos[i] = next
		_vel[i] = v


func _refill(delta: float) -> void:
	if _spent:
		return
	var missing: Array[int] = []
	for i in _alive.size():
		if _alive[i] == 0:
			missing.append(i)
	if missing.is_empty():
		return
	var world := _get_world()
	var got := PackedVector2Array()
	if water_active and world:
		got = world.absorb_water(center, absorb_radius * _scale, missing.size())
	var k := 0
	for p in got:
		var i := missing[k]
		_pos[i] = p
		_vel[i] = (center - p) * 4.0
		_alive[i] = 1
		k += 1
	# The body slowly regenerates whatever it couldn't soak back up.
	_regen += delta * (40.0 if steam_active else 18.0)
	while _regen >= 1.0 and k < missing.size():
		_regen -= 1.0
		var i := missing[k]
		_pos[i] = center + _home(i) * 0.3
		_vel[i] = center_velocity
		_alive[i] = 1
		k += 1
	if k >= missing.size():
		_regen = 0.0


func _mass_center() -> Vector2:
	var s := Vector2.ZERO
	var n := 0
	for i in _pos.size():
		if _alive[i] == 1:
			s += _pos[i]
			n += 1
	return s / n if n > 0 else center


# --- Drawing (world space, pixel grid) -----------------------------------------

func _draw() -> void:
	if not (water_active or steam_active) or _pos.is_empty():
		return
	var cs := CELL * _scale
	# Pack pixels onto the grid: if a cell is taken, use the nearest free one,
	# so the body reads as solid liquid instead of a sieve.
	var grid := {}
	for i in _pos.size():
		if _alive[i] == 1:
			var k := Vector2i((_pos[i] / cs).floor())
			if grid.has(k):
				for o: Vector2i in PACK:
					if not grid.has(k + o):
						k += o
						break
			grid[k] = i
	# Close pinholes: an empty cell with 3+ filled neighbours is liquid too.
	var holes: Array[Vector2i] = []
	for key: Vector2i in grid:
		for o: Vector2i in [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1)]:
			var e: Vector2i = key + o
			if grid.has(e):
				continue
			var n := int(grid.has(e + Vector2i(0, -1))) + int(grid.has(e + Vector2i(0, 1))) 				+ int(grid.has(e + Vector2i(-1, 0))) + int(grid.has(e + Vector2i(1, 0)))
			if n >= 3:
				holes.append(e)
	for e in holes:
		grid[e] = grid.get(e + Vector2i(0, -1), grid.get(e + Vector2i(0, 1), grid.get(e + Vector2i(-1, 0), grid.get(e + Vector2i(1, 0), 0))))
	var sz := Vector2(cs, cs)
	for key: Vector2i in grid:
		var i: int = grid[key]
		var up := grid.has(key + Vector2i(0, -1))
		var down := grid.has(key + Vector2i(0, 1))
		var left := grid.has(key + Vector2i(-1, 0))
		var right := grid.has(key + Vector2i(1, 0))
		var col: Color
		if water_active:
			var rel := (_vel[i] - center_velocity).length()
			if not up:
				col = C_SURFACE
				if not left and grid.has(key + Vector2i(1, 1)):
					col = C_SHINE
			elif not down:
				col = C_RIM
			elif grid.has(key + Vector2i(0, -3)):
				col = C_DEEP
			else:
				col = C_BODY
			if rel > 420.0:
				col = C_FOAM
		else:
			col = C_STEAM if (up and down and left and right) else C_STEAM_EDGE
			col.a = 0.85 if (up and down) else 0.55
		col.a *= alpha
		draw_rect(Rect2(Vector2(key) * cs, sz), col)
	# A couple of shine pixels on the water's upper left.
	if water_active and alpha > 0.0:
		var top := (visual_center + Vector2(-6, -8) * _scale) / cs
		var tk := Vector2i(top.floor())
		if grid.has(tk):
			draw_rect(Rect2(Vector2(tk) * cs, sz), Color(1, 1, 1, 0.85 * alpha))
			if grid.has(tk + Vector2i(1, -1)):
				draw_rect(Rect2(Vector2(tk + Vector2i(1, -1)) * cs, sz), Color(1, 1, 1, 0.6 * alpha))
