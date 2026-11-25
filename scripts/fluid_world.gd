class_name FluidWorld
extends Node2D
## Level-wide pixel fluid, Sandboxels-style. Every level gets one (level.gd adds it,
## group "fluid_world"). Free WATER pixels fall, spread sideways, pool, drip through
## grates and get re-absorbed by the player's water blob. Free STEAM pixels rise,
## drift and fade. Heat zones boil water into steam, freeze zones freeze it, cold
## air condenses steam back into water.
##
## Public API (also used by interactive props):
##   spawn_water(pos, vel := Vector2.ZERO)   spawn_steam(pos, vel := Vector2.ZERO)
##   set_solid_rect(rect: Rect2, solid: bool)   water_count_in(rect: Rect2) -> int
##   is_blocked(pos) -> bool   absorb_water(center, radius, max_count) -> PackedVector2Array

const CELL := 2
const MAX_WATER := 600
const MAX_STEAM := 220
const GRAVITY := 1300.0
const WATER_LIFE := 30.0
const TICK := 1.0 / 60.0

const C_SURFACE := Color("6fb0ff")
const C_BODY := Color("3f8cff")
const C_DEEP := Color("1f59cc")
const C_FOAM := Color("cfe6ff")
const C_ICE := Color("b8e6ff")
const C_ICE_DARK := Color("7fc0ee")

var origin := Vector2.ZERO
var w := 0
var h := 0
## 0 empty, 1 solid, 2 grate (fluids pass, ice doesn't)
var solid := PackedByteArray()
## dynamic solids (gates, moving blocks): a counter per cell on top of `solid`
var dyn := PackedByteArray()
## free-water occupancy: particle index + 1, 0 = empty
var occ := PackedInt32Array()

# Free water: cell coords, sub-cell velocity, state 0 flow / 1 air / 2 frozen, age
var wcell: Array[Vector2i] = []
var wpos := PackedVector2Array()
var wvel := PackedVector2Array()
var wstate := PackedByteArray()
var wage := PackedFloat32Array()
var wdir := PackedByteArray() # preferred sideways direction 0 = left, 1 = right
var wsleep := PackedByteArray() # ticks a resting pixel hasn't moved (sleepers update rarely)

# Free steam (no occupancy; gas overlaps)
var spos := PackedVector2Array()
var svel := PackedVector2Array()
var sage := PackedFloat32Array()
var slife := PackedFloat32Array()

var _heat: Array[Rect2] = []
var _freeze: Array[Rect2] = []
var _acc := 0.0
var _tick := 0


func build(bounds: Rect2, blocks: Array, zones: Array) -> void:
	add_to_group("fluid_world")
	origin = bounds.position
	w = int(ceil(bounds.size.x / CELL))
	h = int(ceil(bounds.size.y / CELL))
	solid.resize(w * h)
	solid.fill(0)
	occ.resize(w * h)
	occ.fill(0)
	dyn.resize(w * h)
	dyn.fill(0)
	for b in blocks:
		if b is Block:
			var r := Rect2(b.global_position, b.size)
			_fill_rect(r, 2 if b.kind == Block.Kind.GRATE else 1)
	for z in zones:
		if z is Zone:
			var r := Rect2(z.global_position, z.size)
			if z.kind == Zone.Kind.HEAT:
				_heat.append(r)
			elif z.kind == Zone.Kind.FREEZE:
				_freeze.append(r)


# --- Public API -------------------------------------------------------------

func spawn_water(pos: Vector2, vel := Vector2.ZERO) -> void:
	if w == 0:
		return
	if wpos.size() >= MAX_WATER:
		_remove_water(0) # oldest goes
	var c := _cell(pos)
	c = _free_cell_near(c)
	if c.x < 0:
		return
	var i := wpos.size()
	wcell.append(c)
	wpos.append(pos)
	wvel.append(vel)
	wstate.append(1 if vel.length() > 20.0 else 0)
	wage.append(0.0)
	wdir.append(randi() % 2)
	wsleep.append(0)
	occ[c.y * w + c.x] = i + 1


func spawn_steam(pos: Vector2, vel := Vector2.ZERO) -> void:
	if spos.size() >= MAX_STEAM:
		_remove_steam(0)
	spos.append(pos)
	svel.append(vel)
	sage.append(0.0)
	slife.append(randf_range(1.0, 2.2))


## Dynamic pieces (gates) add/remove a solid layer without touching the level's
## own geometry; when no dynamic layer covers a cell, clearing it removes the base
## solid (used when a cracked block shatters).
func set_solid_rect(rect: Rect2, is_solid: bool) -> void:
	var a := _cell(rect.position)
	var b := _cell(rect.end - Vector2(0.01, 0.01))
	for y in range(maxi(a.y, 0), mini(b.y + 1, h)):
		for x in range(maxi(a.x, 0), mini(b.x + 1, w)):
			var k := y * w + x
			if is_solid:
				dyn[k] = mini(dyn[k] + 1, 250)
			elif dyn[k] > 0:
				dyn[k] -= 1
			else:
				solid[k] = 0
	if is_solid:
		# Push out any water caught inside.
		for i in range(wpos.size() - 1, -1, -1):
			if rect.has_point(wpos[i]):
				_remove_water(i)


func water_count_in(rect: Rect2) -> int:
	var n := 0
	for p in wpos:
		if rect.has_point(p):
			n += 1
	return n


## True if a world position is inside solid geometry (grates are open).
func is_blocked(pos: Vector2) -> bool:
	var c := _cell(pos)
	if c.x < 0 or c.y < 0 or c.x >= w or c.y >= h:
		return true
	var k := c.y * w + c.x
	return solid[k] == 1 or dyn[k] > 0


## Only the level's own geometry (ignores fluid-only walls like basins and gate
## layers). The player's pixel body uses this so it never snags on things the
## player itself walks through.
func is_blocked_static(pos: Vector2) -> bool:
	var c := _cell(pos)
	if c.x < 0 or c.y < 0 or c.x >= w or c.y >= h:
		return true
	return solid[c.y * w + c.x] == 1


## Top y of the first grate cell in the column at x between y0 and y1 (NAN if none).
func grate_top_near(x: float, y0: float, y1: float) -> float:
	var a := _cell(Vector2(x, y0))
	var b := _cell(Vector2(x, y1))
	if a.x < 0 or a.x >= w:
		return NAN
	for y in range(maxi(a.y, 0), mini(b.y + 1, h)):
		if solid[y * w + a.x] == 2:
			var top := y
			while top > 0 and solid[(top - 1) * w + a.x] == 2:
				top -= 1
			return origin.y + top * CELL
	return NAN


## Removes up to max_count free (non-frozen) water pixels within radius and returns
## their positions so the blob can take them back.
func absorb_water(center: Vector2, radius: float, max_count: int) -> PackedVector2Array:
	var got := PackedVector2Array()
	if max_count <= 0:
		return got
	var r2 := radius * radius
	var i := wpos.size() - 1
	while i >= 0 and got.size() < max_count:
		# Fresh splashes must land and spread a moment before being soaked up.
		if wstate[i] == 0 and wage[i] > 0.7 and wpos[i].distance_squared_to(center) < r2:
			got.append(wpos[i])
			_remove_water(i)
		i -= 1
	return got


# --- Simulation ---------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if w == 0:
		return
	_acc += delta
	var stepped := false
	while _acc >= TICK:
		_acc -= TICK
		_tick += 1
		_step_water(TICK)
		_step_steam(TICK)
		stepped = true
	if stepped:
		queue_redraw()


func _step_water(dt: float) -> void:
	var n := wpos.size()
	if n == 0:
		return
	# Alternate scan direction so flow isn't biased.
	var forward := _tick % 2 == 0
	var i := 0 if forward else n - 1
	var removals: Array[int] = []
	while (i < n) if forward else (i >= 0):
		wage[i] += dt
		var st := wstate[i]
		var c := wcell[i]
		if _tick % 6 == 0:
			var zone := _zone_at(wpos[i])
			if zone == 1:
				removals.append(i)
				spawn_steam(wpos[i], Vector2(randf_range(-20, 20), -60))
			elif zone == 2 and st != 2:
				wstate[i] = 2
				wvel[i] = Vector2.ZERO
				st = 2
			elif zone != 2 and st == 2 and wage[i] > 8.0:
				wstate[i] = 0
				st = 0
		if wage[i] > WATER_LIFE and st != 2:
			removals.append(i)
		elif st == 1:
			_step_air(i, dt)
		elif st == 0:
			# Resting pixels (inside pools) only re-check every 8th tick unless woken.
			if wsleep[i] < 6 or (i + _tick) % 8 == 0:
				if _step_flow(i, c):
					wsleep[i] = 0
				elif wsleep[i] < 255:
					wsleep[i] += 1
		i += 1 if forward else -1
	removals.sort()
	for k in range(removals.size() - 1, -1, -1):
		if removals[k] < wpos.size():
			_remove_water(removals[k])


func _step_air(i: int, dt: float) -> void:
	var v := wvel[i]
	v.y = minf(v.y + GRAVITY * dt, 900.0)
	v *= 0.995
	var target := wpos[i] + v * dt
	var c := wcell[i]
	var tc := _cell(target)
	var steps := maxi(absi(tc.x - c.x), absi(tc.y - c.y))
	var landed := false
	for s in steps:
		var nx := c.x + signi(tc.x - c.x) if c.x != tc.x else c.x
		var ny := c.y + signi(tc.y - c.y) if c.y != tc.y else c.y
		if _open(nx, ny):
			_move(i, c, Vector2i(nx, ny))
			c = Vector2i(nx, ny)
		elif _open(nx, c.y) and nx != c.x:
			_move(i, c, Vector2i(nx, c.y))
			c = Vector2i(nx, c.y)
			v.y *= 0.2
		elif _open(c.x, ny) and ny != c.y:
			_move(i, c, Vector2i(c.x, ny))
			c = Vector2i(c.x, ny)
			v.x *= -0.3
		else:
			landed = true
			break
	wpos[i] = target if not landed and steps > 0 and _cell(target) == c else _center(c)
	if steps == 0:
		wpos[i] = target
	if landed or (not _open(c.x, c.y + 1) and v.y >= 0.0):
		wstate[i] = 0
		wdir[i] = 1 if v.x > 0.0 else 0 if v.x < 0.0 else wdir[i]
		v = Vector2.ZERO
		wpos[i] = _center(c)
	wvel[i] = v


func _step_flow(i: int, c: Vector2i) -> bool:
	# Falling-sand rules: down, diagonal down, then spread sideways.
	if _open(c.x, c.y + 1):
		_move(i, c, Vector2i(c.x, c.y + 1))
		wstate[i] = 1
		wvel[i] = Vector2(0, 120)
		return true
	var d := 1 if wdir[i] == 1 else -1
	if _open(c.x + d, c.y + 1):
		_move(i, c, Vector2i(c.x + d, c.y + 1))
		return true
	if _open(c.x - d, c.y + 1):
		_move(i, c, Vector2i(c.x - d, c.y + 1))
		wdir[i] = 1 - wdir[i]
		return true
	# Spread up to 3 cells; settle when there's nowhere to go.
	var moved := 0
	var cc := c
	while moved < 3 and _open(cc.x + d, cc.y):
		var nc := Vector2i(cc.x + d, cc.y)
		_move(i, cc, nc)
		cc = nc
		moved += 1
		if _open(cc.x, cc.y + 1):
			break
	if moved == 0:
		wdir[i] = 1 - wdir[i]
	return moved > 0


func _step_steam(dt: float) -> void:
	var i := spos.size() - 1
	while i >= 0:
		sage[i] += dt
		if sage[i] > slife[i]:
			_remove_steam(i)
			i -= 1
			continue
		var v := svel[i]
		v.y = move_toward(v.y, -70.0, 180.0 * dt)
		v.x += randf_range(-260.0, 260.0) * dt
		v.x *= 0.96
		var p := spos[i] + v * dt
		if is_blocked(p):
			if not is_blocked(Vector2(p.x, spos[i].y)):
				p.y = spos[i].y
				v.y = 0.0
			elif not is_blocked(Vector2(spos[i].x, p.y)):
				p.x = spos[i].x
				v.x = -v.x * 0.5
			else:
				p = spos[i]
				v = Vector2.ZERO
		if _tick % 6 == 0 and _zone_at(p) == 2:
			spawn_water(p, Vector2(v.x, 0))
			_remove_steam(i)
			i -= 1
			continue
		spos[i] = p
		svel[i] = v
		i -= 1


# --- Grid helpers -------------------------------------------------------------

func _cell(p: Vector2) -> Vector2i:
	return Vector2i(floori((p.x - origin.x) / CELL), floori((p.y - origin.y) / CELL))


func _center(c: Vector2i) -> Vector2:
	return origin + Vector2(c.x * CELL + CELL * 0.5, c.y * CELL + CELL * 0.5)


func _open(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= w or y >= h:
		return false
	var k := y * w + x
	return solid[k] != 1 and dyn[k] == 0 and occ[k] == 0


func _move(i: int, from: Vector2i, to: Vector2i) -> void:
	occ[from.y * w + from.x] = 0
	_wake(from.x, from.y - 1)
	_wake(from.x - 1, from.y)
	_wake(from.x + 1, from.y)
	_wake(from.x - 1, from.y - 1)
	_wake(from.x + 1, from.y - 1)
	occ[to.y * w + to.x] = i + 1
	wcell[i] = to
	wpos[i] = _center(to)


func _wake(x: int, y: int) -> void:
	if x < 0 or y < 0 or x >= w or y >= h:
		return
	var j := occ[y * w + x]
	if j > 0:
		wsleep[j - 1] = 0


func _free_cell_near(c: Vector2i) -> Vector2i:
	for r in 4:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if _open(c.x + dx, c.y + dy):
					return Vector2i(c.x + dx, c.y + dy)
	return Vector2i(-1, -1)


func _fill_rect(r: Rect2, value: int) -> void:
	var a := _cell(r.position)
	var b := _cell(r.end - Vector2(0.01, 0.01))
	for y in range(maxi(a.y, 0), mini(b.y + 1, h)):
		for x in range(maxi(a.x, 0), mini(b.x + 1, w)):
			solid[y * w + x] = value


## 0 none, 1 heat, 2 freeze
func _zone_at(p: Vector2) -> int:
	for r in _heat:
		if r.has_point(p):
			return 1
	for r in _freeze:
		if r.has_point(p):
			return 2
	return 0


func _remove_water(i: int) -> void:
	var last := wpos.size() - 1
	var c := wcell[i]
	if occ[c.y * w + c.x] == i + 1:
		occ[c.y * w + c.x] = 0
	if i != last:
		wcell[i] = wcell[last]
		wpos[i] = wpos[last]
		wvel[i] = wvel[last]
		wstate[i] = wstate[last]
		wage[i] = wage[last]
		wdir[i] = wdir[last]
		wsleep[i] = wsleep[last]
		var lc := wcell[i]
		occ[lc.y * w + lc.x] = i + 1
	wcell.resize(last)
	wpos.resize(last)
	wvel.resize(last)
	wstate.resize(last)
	wage.resize(last)
	wdir.resize(last)
	wsleep.resize(last)


func _remove_steam(i: int) -> void:
	var last := spos.size() - 1
	if i != last:
		spos[i] = spos[last]
		svel[i] = svel[last]
		sage[i] = sage[last]
		slife[i] = slife[last]
	spos.resize(last)
	svel.resize(last)
	sage.resize(last)
	slife.resize(last)


# --- Drawing --------------------------------------------------------------------

func _draw() -> void:
	var sz := Vector2(CELL, CELL)
	for i in wpos.size():
		var c := wcell[i]
		var col: Color
		if wstate[i] == 2:
			col = C_ICE if not _occ_at(c.x, c.y - 1) else C_ICE_DARK
		elif wstate[i] == 1:
			col = C_FOAM if wvel[i].length() > 260.0 else C_SURFACE
		elif not _occ_at(c.x, c.y - 1):
			col = C_SURFACE
		elif _occ_at(c.x, c.y - 3):
			col = C_DEEP
		else:
			col = C_BODY
		var fade := clampf((WATER_LIFE - wage[i]) / 3.0, 0.0, 1.0)
		col.a = fade
		draw_rect(Rect2(origin + Vector2(c * CELL), sz), col)
	for i in spos.size():
		var k := sage[i] / slife[i]
		var a := (1.0 - k) * 0.7
		var p := (spos[i] / CELL).floor() * CELL
		draw_rect(Rect2(p, sz), Color(0.93, 0.96, 1.0, a))


func _occ_at(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= w or y >= h:
		return false
	return occ[y * w + x] != 0
