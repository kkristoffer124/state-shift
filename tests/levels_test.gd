extends Node
## Headless solvability test for levels 1-12: plays a scripted solution for each
## level with real input actions and checks the goal is reached in time. Levels whose
## exit is behind a channel-driven IxGate must also have opened it on the way.
##   godot --headless --path . res://tests/levels_test.tscn [-- --only=7 --trace]

const ACTIONS := ["move_left", "move_right", "jump", "heat", "cool"]

var _fails := 0
var p: Player
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
	var solutions := {
		1: _solve_01, 2: _solve_02, 3: _solve_03, 4: _solve_04, 5: _solve_05,
		6: _solve_06, 7: _solve_07, 8: _solve_08, 9: _solve_09,
		10: _solve_10, 11: _solve_11, 12: _solve_12,
	}
	for n in solutions:
		if only != "" and str(n) != only:
			continue
		await _play(n, solutions[n])
	print("LEVELS TEST %s (%d failures)" % ["PASSED" if _fails == 0 else "FAILED", _fails])
	get_tree().quit(1 if _fails else 0)


func _play(n: int, solve: Callable) -> void:
	var path := "res://levels/level_%02d.tscn" % n
	for c in get_children():
		c.queue_free()
	await get_tree().physics_frame
	var level: Node = load(path).instantiate()
	add_child(level)
	p = level.get_node("Player")
	_frame = 0
	await _wait(30)
	await solve.call()
	# Let the scripted run finish into the goal.
	await _until(func() -> bool: return p.won or p.dead, 240)
	_release_all()
	var secs := _frame / 120.0
	var ok := p.won and not p.dead and secs < 90.0
	# Every gameplay gate in the level must have been opened by the run.
	var gates := []
	for g in level.find_children("*", "AnimatableBody2D", true, false):
		if g is IxGate and g.channel != "":
			gates.append("%s:%s" % [g.name, "open" if g.is_open else "SHUT"])
			if not g.is_open:
				ok = false
	print(("  ok   " if ok else "  FAIL ") + "%s (%s) won=%s dead=%s t=%.1fs pos=%s state=%d %s"
		% [path.get_file(), level.level_name, p.won, p.dead, secs, p.global_position.round(), p.state, " ".join(gates)])
	if not ok:
		_fails += 1


# --- Input helpers -----------------------------------------------------------

func _step() -> void:
	await get_tree().physics_frame
	_frame += 1
	if _trace and _frame % 30 == 0:
		print("    f%d pos=%s vel=%s st=%d" % [_frame, p.global_position.round(), p.velocity.round(), p.state])


func _wait(frames: int) -> void:
	for i in frames:
		if p.won or p.dead:
			return
		await _step()


func _release_all() -> void:
	for a in ACTIONS:
		Input.action_release(a)


func _hold(actions: Array, frames: int) -> void:
	for a in actions:
		Input.action_press(a)
	await _wait(frames)
	for a in actions:
		Input.action_release(a)


func _tap(action: String) -> void:
	Input.action_press(action)
	await _step()
	await _step()
	Input.action_release(action)
	await _step()


## Holds `actions` until cond() is true (or timeout). Returns whether cond was met.
func _until(cond: Callable, max_frames: int, actions: Array = []) -> bool:
	for a in actions:
		Input.action_press(a)
	var met := false
	for i in max_frames:
		if cond.call():
			met = true
			break
		if p.won or p.dead:
			break
		await _step()
	for a in actions:
		Input.action_release(a)
	if not met and not p.won and not p.dead and max_frames > 0:
		print("    (timeout waiting at pos=%s state=%d)" % [p.global_position.round(), p.state])
	return met


func _x_gt(x: float) -> Callable:
	return func() -> bool: return p.global_position.x > x


func _x_lt(x: float) -> Callable:
	return func() -> bool: return p.global_position.x < x


func _y_lt(y: float) -> Callable:
	return func() -> bool: return p.global_position.y < y


func _y_gt(y: float) -> Callable:
	return func() -> bool: return p.global_position.y > y


func _on_floor() -> Callable:
	return func() -> bool: return p.is_on_floor()


## Walks/drifts toward the goal's centre until the level is won.
func _seek_goal(max_frames := 600) -> void:
	var goal: Node2D = p.get_parent().get_node("Zones/Goal")
	var target: float = goal.global_position.x + goal.size.x / 2.0
	for i in max_frames:
		if p.won or p.dead:
			break
		var d := target - p.global_position.x
		Input.action_release("move_left")
		Input.action_release("move_right")
		if absf(d) > 6.0:
			Input.action_press("move_right" if d > 0 else "move_left")
		await _step()
	_release_all()


func _to_steam() -> void:
	for i in 4:
		if p.state == Player.State.STEAM or p.dead or p.won:
			return
		await _tap("heat")


func _to_ice() -> void:
	for i in 4:
		if p.state == Player.State.ICE or p.dead or p.won:
			return
		await _tap("cool")


## Holds `actions` + jump for `frames` (a full-height hop), then lets go of everything.
func _jump(actions: Array, frames := 45) -> void:
	Input.action_press("jump")
	await _hold(actions, frames)
	Input.action_release("jump")


## Walks right until x > `x`, then hops right.
func _jump_at(x: float, frames := 30) -> void:
	await _until(_x_gt(x), 400, ["move_right"])
	await _jump(["move_right"], frames)


func _stopped() -> bool:
	return absf(p.velocity.x) < 5.0 and p.is_on_floor()


# --- Solutions (rooms are 960x540 unless noted) --------------------------------

## 1: hop both crates, drip through the grate into the basin (opens the shutter),
## walk left off the tier and into the goal chamber.
func _solve_01() -> void:
	await _jump_at(190)
	await _jump_at(330)
	await _until(_y_gt(300), 400, ["move_right"])
	await _until(_on_floor(), 200, ["move_right"])
	await _wait(30)
	await _until(_y_gt(440), 600, ["move_left"])
	await _seek_goal()


## 2: freeze and slide over the floor spikes, melt, climb the steps and ledge,
## freeze on the walkway and slide left over the spikes and the plate into the goal.
func _solve_02() -> void:
	await _to_ice()
	await _until(func() -> bool: return p.global_position.x > 600 and _stopped(), 900, ["move_right"])
	await _tap("heat")
	await _wait(10)
	await _jump(["move_right"], 40)
	await _until(_on_floor(), 120)
	await _jump(["move_right"], 40)
	await _until(_on_floor(), 120)
	await _until(_x_gt(760), 120, ["move_right"])
	await _jump(["move_left"], 40)
	await _until(_on_floor(), 120)
	await _until(_x_lt(680), 200, ["move_left"])
	await _jump(["move_left"], 25)
	await _until(_on_floor(), 120)
	await _wait(10)
	await _to_ice()
	await _until(func() -> bool: return p.won, 900, ["move_left"])


## 3: steam up grate 1, slide left under the shelf to grate 2, rise, drift right past
## the turbine (opens the shutter), condense over the goal block.
func _solve_03() -> void:
	await _until(_x_gt(336), 300, ["move_right"])
	await _to_steam()
	await _until(_y_lt(300), 600)
	await _until(_y_lt(180), 600, ["move_left"])
	await _until(_y_lt(100), 300)
	await _until(_x_gt(820), 900, ["move_right"])
	await _tap("cool")
	await _until(_on_floor(), 300)
	await _seek_goal()


## 4: steam to the roof, freeze over the crack, smash through onto the spikes,
## slide over the plate (opens the shutter) into the goal.
func _solve_04() -> void:
	await _to_steam()
	await _until(_y_lt(90), 600)
	await _until(_x_gt(590), 600, ["move_right"])
	await _wait(20)
	await _to_ice()
	await _until(func() -> bool: return p.is_on_floor() and p.global_position.y > 440, 600)
	await _until(func() -> bool: return p.won, 900, ["move_right"])


## 5: heat zone lifts you, cold zone drops you as ICE through the crack onto the plate
## (opens the fan hatch); walk to the fan, steam up the shaft, condense on the shelf.
func _solve_05() -> void:
	await _until(func() -> bool: return p.state == Player.State.STEAM, 600, ["move_right"])
	await _until(func() -> bool: return p.state == Player.State.ICE, 900, ["move_right"])
	await _until(func() -> bool: return p.is_on_floor() and p.global_position.y > 400, 600)
	await _wait(20)
	await _tap("heat")
	await _until(_x_gt(744), 600, ["move_right"])
	await _to_steam()
	await _until(_y_lt(150), 900)
	await _until(_x_gt(860), 600, ["move_right"])
	await _tap("cool")
	await _until(_on_floor(), 300)
	await _seek_goal()


## 6: walk to the ledge edge, steam, let the side fan carry you under the baffle, condense over the far ledge.
func _solve_06() -> void:
	await _until(_x_gt(196), 300, ["move_right"])
	await _to_steam()
	await _until(_x_gt(880), 600, ["move_right"])
	await _tap("cool")
	await _until(_on_floor(), 200)
	await _seek_goal()


## 7: drip through grate 1, freeze mid-fall, slide to grate 2, melt, drip, freeze,
## slide to the grate wall, melt, walk through into the goal.
func _solve_07() -> void:
	await _until(_y_gt(230), 600, ["move_right"])
	await _to_ice()
	await _until(_on_floor(), 200)
	await _until(func() -> bool: return p.global_position.x < 80 and _stopped(), 900, ["move_left"])
	await _tap("heat")
	await _until(_y_gt(370), 200)
	await _to_ice()
	await _until(_on_floor(), 200)
	await _until(func() -> bool: return p.global_position.x > 680 and _stopped(), 900, ["move_right"])
	await _tap("heat")
	await _seek_goal()


## 8: walk into the shaft, steam up past the turbine (opens the attic shutter), drift over
## the column, freeze, smash both cracked floors and slide into the goal.
func _solve_08() -> void:
	await _until(_x_lt(100), 600, ["move_left"])
	await _to_steam()
	await _until(_y_lt(90), 900)
	await _until(_x_gt(730), 900, ["move_right"])
	await _to_ice()
	await _until(func() -> bool: return p.is_on_floor() and p.global_position.y > 440, 600)
	await _until(func() -> bool: return p.won, 600, ["move_right"])


## 9: hold right: vents lift you over the barriers, cold bands drop you; the plate opens the exit.
func _solve_09() -> void:
	await _until(func() -> bool: return p.won, 2400, ["move_right"])


## 10: hop up P1, P2 and the ledge, freeze at its back, build speed through the spike
## tunnel, fly the pit, slide over the plate (opens the shutter) into the goal.
func _solve_10() -> void:
	await _until(_x_gt(90), 200, ["move_right"])
	await _jump(["move_right"])
	await _until(_on_floor(), 120)
	await _until(_x_lt(142), 200, ["move_left"])
	await _jump(["move_left"])
	await _until(_on_floor(), 120)
	await _until(_x_lt(60), 120, ["move_left"])
	await _jump(["move_right"], 70)
	await _until(_on_floor(), 120)
	await _until(_x_lt(180), 200, ["move_left"])
	await _to_ice()
	await _until(func() -> bool: return p.won, 900, ["move_right"])


## 11 (960x1080): hop onto the crate and over the spikes, steam up grate 1 and veer left of the spikes, slide under
## the shelf to grate 2, freeze above it, ice over the spiked shelf, melt, steam up grate 3,
## drift left past the roof turbine (opens the shutter), condense over the goal.
func _solve_11() -> void:
	await _jump_at(320)
	await _until(_on_floor(), 120)
	await _jump_at(458, 20)
	await _until(_on_floor(), 120, ["move_right"])
	await _until(_x_gt(752), 600, ["move_right"])
	await _to_steam()
	await _until(_y_lt(796), 600)
	await _until(_y_lt(540), 900, ["move_left"])
	await _to_ice()
	await _until(_on_floor(), 200)
	await _until(func() -> bool: return p.global_position.x > 860 and _stopped(), 900, ["move_right"])
	await _tap("heat")
	await _until(_x_lt(816), 300, ["move_left"])
	await _to_steam()
	await _until(_y_lt(100), 900)
	await _until(_x_lt(100), 900, ["move_left"])
	await _tap("cool")
	await _until(_on_floor(), 200)
	await _seek_goal()


## 12 (1920x540): steam to the roof, drop as ice through the crack onto the spikes, slide over
## the plate (opens the shutter) to the grate wall, melt through it into the heat zone and
## ride the crosswind over the spike pit; condense on the goal ledge.
func _solve_12() -> void:
	await _until(_x_gt(200), 200, ["move_right"])
	await _to_steam()
	await _until(_y_lt(90), 600)
	await _until(_x_gt(560), 600, ["move_right"])
	await _wait(20)
	await _to_ice()
	await _until(func() -> bool: return p.is_on_floor() and p.global_position.y > 400, 600)
	await _until(func() -> bool: return p.global_position.x > 1000 and _stopped(), 900, ["move_right"])
	await _tap("heat")
	await _until(func() -> bool: return p.state == Player.State.STEAM, 600, ["move_right"])
	await _until(_x_gt(1780), 900, ["move_right"])
	await _tap("cool")
	await _until(_on_floor(), 300)
	await _seek_goal()
