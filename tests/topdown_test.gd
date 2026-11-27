extends Node
## Headless test for the top-down chapters (2 "Freeze", 7 "Sieve"): plays a scripted
## solution with real input actions and checks the goal is reached in time and every
## channel gate was opened, then checks the core state rules one by one.
##   godot --headless --path . res://tests/topdown_test.tscn --fixed-fps 120 [-- --only=7 --trace]

const ACTIONS := ["move_left", "move_right", "move_up", "move_down", "heat", "cool"]
const C := 32.0

var _fails := 0
var p: TdPlayer
var level: Node
var _frame := 0
var _trace := false


func _ready() -> void:
	Game.testing = true
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7)
		elif a == "--trace":
			_trace = true
	var solutions := {2: _solve_02, 7: _solve_07}
	for n in solutions:
		if only != "" and str(n) != only:
			continue
		await _play(n, solutions[n])
	if only == "" or only == "rules":
		await _rules()
	print("TOPDOWN TEST %s (%d failures)" % ["PASSED" if _fails == 0 else "FAILED", _fails])
	get_tree().quit(1 if _fails else 0)


func _check(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + msg)
	if not cond:
		_fails += 1


func _load(n: int) -> void:
	for c in get_children():
		c.queue_free()
	await get_tree().physics_frame
	level = load("res://levels/level_%02d_topdown.tscn" % n).instantiate()
	add_child(level)
	p = level.get_node("Player") as TdPlayer
	if p == null:
		print("  FAIL could not load level %d" % n)
		get_tree().quit(1)
		return
	_frame = 0
	await _wait(20)


func _play(n: int, solve: Callable) -> void:
	await _load(n)
	await solve.call()
	await _until(func() -> bool: return p.won or p.dead, 240)
	_release_all()
	var secs := _frame / 120.0
	var ok := p.won and not p.dead and secs < 90.0
	var gates := []
	for g in level.find_children("*", "StaticBody2D", true, false):
		if g is TdGate and g.channel != "":
			gates.append("%s:%s" % [g.name, "open" if g.is_open else "SHUT"])
			if not g.is_open:
				ok = false
	print(("  ok   " if ok else "  FAIL ") + "level_%02d_topdown (%s) won=%s dead=%s t=%.1fs pos=%s state=%d %s"
		% [n, level.level_name, p.won, p.dead, secs, p.global_position.round(), p.state, " ".join(gates)])
	if not ok:
		_fails += 1


# --- Input helpers ------------------------------------------------------------------

func _step() -> void:
	await get_tree().physics_frame
	_frame += 1
	if _trace and _frame % 30 == 0:
		print("    f%d pos=%s vel=%s st=%d busy=%s" % [_frame, p.global_position.round(), p.velocity.round(), p.state, p.busy])


func _wait(frames: int) -> void:
	for i in frames:
		if p.won or p.dead:
			return
		await _step()


func _release_all() -> void:
	for a in ACTIONS:
		Input.action_release(a)


func _tap(action: String) -> void:
	Input.action_press(action)
	await _step()
	await _step()
	Input.action_release(action)
	await _step()


func _until(cond: Callable, max_frames: int) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		if p.won or p.dead:
			return false
		await _step()
	print("    (timeout at pos=%s state=%d)" % [p.global_position.round(), p.state])
	return false


static func cell(x: float, y: float) -> Vector2:
	return Vector2(x * C + 16.0, y * C + 16.0)


## Steers WATER/STEAM towards `target` with the arrow actions until within `tol` px.
## Stops early when the blob goes down a drain (busy).
func _go(target: Vector2, tol := 5.0, max_frames := 900) -> bool:
	var ok := false
	for i in max_frames:
		if p.won or p.dead or p.busy:
			break
		var d := target - p.global_position
		if d.length() < tol:
			ok = true
			break
		_hold_if("move_right", d.x > 2.0)
		_hold_if("move_left", d.x < -2.0)
		_hold_if("move_down", d.y > 2.0)
		_hold_if("move_up", d.y < -2.0)
		await _step()
	_release_all()
	if not ok and not p.busy and not p.won and not p.dead:
		print("    (could not reach %s, at %s)" % [target, p.global_position.round()])
	return ok


func _hold_if(action: String, on: bool) -> void:
	if on and not Input.is_action_pressed(action):
		Input.action_press(action)
	elif not on and Input.is_action_pressed(action):
		Input.action_release(action)


## Pushes the ICE cube one way and waits until it has stopped.
func _push(action: String) -> void:
	await _until(func() -> bool: return p.is_resting(), 240)
	Input.action_press(action)
	await _step()
	await _step()
	Input.action_release(action)
	await _step()
	await _until(func() -> bool: return p.is_resting() or p.dead, 400)
	await _wait(4)
	if _trace:
		print("    pushed %s -> %s" % [action, p.global_position.round()])


func _drain_done() -> void:
	await _until(func() -> bool: return not p.busy, 240)
	await _wait(6)


# --- Solutions ----------------------------------------------------------------------

## Chapter 2: freeze at the start, slide over the spikes into the cold room,
## R D R onto the plate (opens the gate), U R out through the gate to the bars,
## melt and slip through the bars into the goal.
func _solve_02() -> void:
	await _tap("cool")
	await _push("move_right")   # over the spikes -> (17,6)
	await _push("move_down")    # -> (17,10)
	await _push("move_right")   # -> plate (22,10)
	await _until(func() -> bool: return level.get_node("Blocks/ExitGate").is_open, 120)
	await _push("move_up")      # -> (22,7)
	await _push("move_right")   # through the gate -> (25,7), stopped by the bars
	var stop_ok := p.global_position.distance_to(cell(25, 7)) < 2.0
	_check(stop_ok, "ch2: ice stopped by the bars at (25,7) [%s]" % p.global_position.round())
	await _wait(20)
	await _tap("heat")
	await _go(cell(27.5, 6.5))


## Chapter 7: through the bars, over the bridge, down drain A, onto the hot grate
## (steam), through the vent mesh, across the sewage against the updraft fan, cool
## to water on the far bank, down drain B into the goal room.
func _solve_07() -> void:
	await _go(cell(4, 3))
	await _go(cell(6.2, 3))     # between the bars
	await _go(cell(9, 3))
	await _go(cell(9, 6))       # over the bridge
	await _go(cell(10, 7), 2.0) # drain A
	await _drain_done()
	_check(p.global_position.distance_to(cell(1, 9)) < 4.0, "ch7: drain A -> A2 (%s)" % p.global_position.round())
	await _go(cell(2, 10))
	await _go(cell(9, 10))
	await _go(cell(10, 12))     # hot grate forces steam
	await _until(func() -> bool: return p.state == TdPlayer.State.STEAM, 120)
	_check(p.state == TdPlayer.State.STEAM, "ch7: hot grate -> steam")
	await _go(cell(16, 12), 8.0)  # through the mesh, over the sewage and the island pit
	await _go(cell(25, 12), 6.0)  # across the updraft
	await _wait(30)
	await _tap("cool")
	_check(p.state == TdPlayer.State.WATER, "ch7: cooled to water on the far bank")
	await _go(cell(26, 11), 2.0)  # drain B
	await _drain_done()
	_check(p.global_position.distance_to(cell(26, 7)) < 4.0, "ch7: drain B -> goal room (%s)" % p.global_position.round())
	await _go(cell(26, 3.5))


# --- Single rules -------------------------------------------------------------------

func _place(at: Vector2, st: int) -> void:
	p.global_position = at
	if p.state != st:
		p.try_shift(st, true)
	p.global_position = at
	p.velocity = Vector2.ZERO
	await _wait(2)


func _rules() -> void:
	# water on spikes dies, ice and steam don't
	await _load(2)
	await _place(cell(7, 5), TdPlayer.State.WATER)
	await _wait(10)
	_check(p.dead, "water dies on spikes")
	await _load(2)
	await _place(cell(5, 5), TdPlayer.State.ICE)
	await _push("move_right") # stops on the spikes against the wall
	_check(not p.dead and p.global_position.distance_to(cell(8, 5)) < 2.0, "ice slides over spikes and stops at the wall (%s)" % p.global_position.round())
	await _load(2)
	await _place(cell(7, 9), TdPlayer.State.STEAM)
	await _wait(30)
	_check(not p.dead, "steam floats over spikes")
	# pits: ice slides in and falls, steam floats
	await _load(2)
	await _place(cell(11, 2), TdPlayer.State.ICE)
	await _wait(5)
	_check(p.is_resting(), "ice rests in the cold room")
	await _push("move_down") # (11,3) is a pit
	await _wait(60)
	_check(p.dead, "ice slides into a pit and falls")
	await _load(2)
	await _place(cell(13, 10), TdPlayer.State.STEAM)
	await _wait(4)
	_check(p.state == TdPlayer.State.ICE, "freeze zone forces ice")
	await _wait(80)
	_check(p.dead, "...and ice over a pit falls in")
	# bars: water passes, ice doesn't (ch2 exit)
	await _load(2)
	await _place(cell(25, 7), TdPlayer.State.WATER)
	await _go(cell(27, 7))
	_check(p.global_position.x > 26.5 * C, "water slips through the bars")
	await _load(7)
	await _place(cell(4, 4), TdPlayer.State.ICE)
	await _push("move_right")
	_check(p.global_position.distance_to(cell(4, 4)) < 2.0, "bars stop ice (%s)" % p.global_position.round())
	# mesh: steam passes, water doesn't; water dies in sewage
	await _load(7)
	# (the hot grate in front of the mesh would flip water to steam: probe the same frame)
	p.global_position = cell(11, 12)
	var water_blocked := p.test_move(p.global_transform, Vector2(40, 0))
	p.try_shift(TdPlayer.State.STEAM, true)
	var steam_blocked := p.test_move(p.global_transform, Vector2(40, 0))
	_check(water_blocked and not steam_blocked, "mesh stops water, lets steam through")
	await _load(7)
	await _place(cell(13, 10), TdPlayer.State.WATER)
	await _wait(80)
	_check(p.dead, "water is washed away in sewage")
	await _load(7)
	await _place(cell(14, 11), TdPlayer.State.STEAM)
	await _wait(60)
	_check(not p.dead and p.state == TdPlayer.State.STEAM, "steam floats over sewage")
	# fan pushes steam
	await _load(7)
	await _place(cell(20, 13), TdPlayer.State.STEAM)
	var y0 := p.global_position.y
	await _wait(70)
	_check(p.global_position.y < y0 - 30.0, "updraft fan pushes steam (%d px)" % int(y0 - p.global_position.y))
	_release_all()
