extends Node
## Headless solvability test for the 3D chapters: plays a scripted solution with
## real input actions (analog move strengths, camera relative) and checks the goal
## is reached in time and every channel gate was opened on the way.
##   godot --headless --fixed-fps 120 --path . res://tests/v3d_test.tscn [-- --only=8 --trace]

const ACTIONS := ["move_left", "move_right", "move_up", "move_down", "jump_3d", "heat", "cool"]

var _fails := 0
var p: Player3D
var level: Level3D
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
	var solutions := { 3: _solve_03, 6: _solve_06, 8: _solve_08 }
	for n in solutions:
		if only != "" and str(n) != only:
			continue
		await _play(n, solutions[n])
	await _check_rules()
	print("V3D TEST %s (%d failures)" % ["PASSED" if _fails == 0 else "FAILED", _fails])
	get_tree().quit(1 if _fails else 0)


func _play(n: int, solve: Callable) -> void:
	var path := "res://levels/level_%02d_3d.tscn" % n
	for c in get_children():
		c.queue_free()
	await get_tree().physics_frame
	level = load(path).instantiate()
	add_child(level)
	p = level.get_node("Player")
	_frame = 0
	await _wait(30)
	await solve.call()
	await _until(func() -> bool: return p.won or p.dead, 300)
	_release_all()
	var secs := _frame / 120.0
	var ok := p.won and not p.dead and secs < 90.0
	var gates := []
	for g in level.find_children("*", "AnimatableBody3D", true, false):
		if g is Gate3D and g.channel != "":
			gates.append("%s:%s" % [g.name, "open" if g.is_open else "SHUT"])
			if not g.is_open:
				ok = false
	var mode: String = V3D.CameraMode.keys()[level.camera_mode]
	print(("  ok   " if ok else "  FAIL ") + "%s (%s, %s) won=%s dead=%s t=%.1fs pos=%s state=%d %s"
		% [path.get_file(), level.level_name, mode, p.won, p.dead, secs, _r(p.global_position), p.state, " ".join(gates)])
	if not ok:
		_fails += 1


# --- Input helpers -----------------------------------------------------------

func _r(v: Vector3) -> String:
	return "(%.1f, %.1f, %.1f)" % [v.x, v.y, v.z]


func _step() -> void:
	await get_tree().physics_frame
	_frame += 1
	if _trace and _frame % 30 == 0:
		print("    f%d pos=%s vel=%s st=%d floor=%s" % [_frame, _r(p.global_position), _r(p.velocity), p.state, p.is_on_floor()])


func _wait(frames: int) -> void:
	for i in frames:
		if p.won or p.dead:
			return
		await _step()


func _release_all() -> void:
	for a in ACTIONS:
		Input.action_release(a)


func _release_moves() -> void:
	for a in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(a)


func _tap(action: String) -> void:
	Input.action_press(action)
	await _step()
	await _step()
	Input.action_release(action)
	await _step()


## Presses the move actions (analog) so the camera-relative input points at `target`.
## Returns the remaining horizontal distance.
func _steer(target: Vector3) -> float:
	var d := target - p.global_position
	d.y = 0.0
	if p.side_mode:
		d.z = 0.0
	var dist := d.length()
	_release_moves()
	if dist < 0.12:
		return dist
	var local := Basis(Vector3.UP, p.rig.yaw).inverse() * (d / dist)
	var x := local.x
	var fwd := -local.z
	if p.side_mode:
		x = signf(d.x)
		fwd = 0.0
	if x > 0.01:
		Input.action_press("move_right", x)
	elif x < -0.01:
		Input.action_press("move_left", -x)
	if fwd > 0.01:
		Input.action_press("move_up", fwd)
	elif fwd < -0.01:
		Input.action_press("move_down", -fwd)
	return dist


## Steers toward `target` until within `tol` (or cond() is true / timeout).
func _go_to(target: Vector3, max_frames: int, tol := 0.25, cond := Callable()) -> bool:
	var met := false
	for i in max_frames:
		if p.won or p.dead:
			break
		if cond.is_valid() and cond.call():
			met = true
			break
		if _steer(target) < tol and not cond.is_valid():
			met = true
			break
		await _step()
	_release_moves()
	if not met and not p.won and not p.dead:
		print("    (timeout going to %s at pos=%s state=%d)" % [_r(target), _r(p.global_position), p.state])
	return met


## Holds `actions` until cond() is true (or timeout).
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
		print("    (timeout waiting at pos=%s state=%d)" % [_r(p.global_position), p.state])
	return met


## Jumps (jump_3d held `frames`) while steering at `target`, and keeps steering
## until the blob lands again.
func _jump_toward(target: Vector3, frames := 45) -> void:
	Input.action_press("jump_3d")
	var left_floor := false
	for i in 200:
		if p.won or p.dead:
			break
		if i == frames:
			Input.action_release("jump_3d")
		if not p.is_on_floor():
			left_floor = true
		elif left_floor and i > 4:
			break
		_steer(target)
		await _step()
	Input.action_release("jump_3d")
	_release_moves()


func _to_steam() -> void:
	for i in 4:
		if p.state == Player3D.State.STEAM or p.dead or p.won:
			return
		await _tap("heat")


func _to_ice() -> void:
	for i in 4:
		if p.state == Player3D.State.ICE or p.dead or p.won:
			return
		await _tap("cool")


func _y_gt(y: float) -> Callable:
	return func() -> bool: return p.global_position.y > y


func _x_gt(x: float) -> Callable:
	return func() -> bool: return p.global_position.x > x


func _on_floor() -> Callable:
	return func() -> bool: return p.is_on_floor()


func _gate_open(gate_name: String) -> Callable:
	var g: Gate3D = level.find_child(gate_name, true, false)
	return func() -> bool: return g.is_open and g.position.distance_to(g._base + g.open_offset) < 0.05


# --- Solutions --------------------------------------------------------------------

## 3 (third person): hop the bench, steam up grate 1, drift under the mezzanine to
## grate 2, rise, drift through the roof turbine (opens the tank lid), condense over the tank.
func _solve_03() -> void:
	await _go_to(Vector3(6, 0, 6.6), 400)
	await _jump_toward(Vector3(6, 0, 2), 40)
	await _until(_on_floor(), 120)
	await _go_to(Vector3(6, 0, 2), 300, 0.15)
	await _to_steam()
	await _until(_y_gt(8.3), 600)
	await _go_to(Vector3(2, 0, 8), 900, 0.1, _y_gt(9.7))
	await _until(_y_gt(13.0), 600)
	await _go_to(Vector3(9.6, 0, 6.2), 900, 0.4)
	await _go_to(Vector3(11.5, 0, 5.0), 600, 0.15)
	await _until(_gate_open("TankLid"), 300, [])
	await _go_to(Vector3(11.5, 0, 5.0), 200, 0.12)
	await _tap("cool")
	await _until(func() -> bool: return p.won, 400)


## 6 (2.5D): hop the spike gap into the cold drip (freezes you), slide to the grate,
## melt and slip through, steam on the launch ledge, ride the crosswind under the baffle,
## condense over the goal ledge.
func _solve_06() -> void:
	await _until(func() -> bool: return p.global_position.x > 4.9, 400, ["move_right"])
	await _jump_toward(Vector3(20, 0, 0), 40)
	await _until(func() -> bool: return p.state == Player3D.State.ICE, 300, ["move_right"])
	await _until(func() -> bool: return p.is_on_floor() and absf(p.velocity.x) < 0.1, 600, ["move_right"])
	await _tap("heat")
	await _until(_x_gt(15.2), 600, ["move_right"])
	await _to_steam()
	await _until(_x_gt(31.5), 900, ["move_right"])
	await _tap("cool")
	await _until(_on_floor(), 300)
	await _go_to(Vector3(34.4, 0, 0), 600, 0.1)


## 8 (first person): hop the spike strip, walk into the hot vent (forced STEAM), rise
## through the turbine (opens the attic shutter), drift along the duct to the well,
## freeze and smash through both cracked floors into the basement goal.
func _solve_08() -> void:
	await _go_to(Vector3(7.3, 0, 2.0), 400)
	await _jump_toward(Vector3(1.5, 0, 1.5), 40)
	await _until(_on_floor(), 120)
	await _go_to(Vector3(1.5, 0, 1.5), 400, 0.2, func() -> bool: return p.state == Player3D.State.STEAM)
	await _until(_y_gt(11.0), 600)
	await _go_to(Vector3(13.5, 0, 1.5), 900, 0.15, _x_gt(13.3))
	await _to_ice()
	await _until(func() -> bool: return p.won, 600)


# --- Rule checks (state physics in 3D) ----------------------------------------------

## Small sandbox checks: grates block only ICE, ICE presses plates (STEAM doesn't),
## blocked shifts when there's no room.
func _check_rules() -> void:
	for c in get_children():
		c.queue_free()
	await get_tree().physics_frame
	level = load("res://levels/level_03_3d.tscn").instantiate()
	add_child(level)
	p = level.get_node("Player")
	await _wait(5)
	var ok := true
	# Ice can't pass grate 1 going up; fits check: ice under the low bench is blocked.
	var grate: Block3D = level.get_node("Blocks/Grate1")
	ok = ok and (grate.collision_layer & V3D.MASK_ICE) != 0 and (grate.collision_layer & V3D.MASK_FLUID) == 0
	# Plate: drop a plate + gate into the room and press it with ice.
	var plate := Plate3D.new()
	plate.channel = "t"
	level.get_node("Interactive").add_child(plate)
	plate.global_position = Vector3(3, 0, 8)
	var gate := Gate3D.new()
	gate.channel = "t"
	gate.size = Vector3(1, 1, 1)
	gate.open_offset = Vector3(0, -1, 0)
	level.get_node("Interactive").add_child(gate)
	gate.global_position = Vector3(6, 0.5, 9)
	p.global_position = Vector3(3, 1.2, 8)
	await _to_ice()
	await _wait(40)
	var pressed_ice := plate.pressed and gate.is_open
	await _to_steam()
	await _wait(60)
	var pressed_steam := plate.pressed
	# Blocked shift: water squeezed under a low slab can't become ice.
	await _tap("cool")
	await _wait(5)
	p.global_position = Vector3(3, 0.36, 8)
	p.velocity = Vector3.ZERO
	var slab := Block3D.new()
	slab.size = Vector3(2, 0.3, 2)
	level.get_node("Blocks").add_child(slab)
	slab.global_position = Vector3(3, 0.88, 8)
	await _wait(10)
	var before := p.state
	await _tap("cool")
	var blocked := p.state == before and p.state == Player3D.State.WATER
	ok = ok and pressed_ice and not pressed_steam and blocked
	print(("  ok   " if ok else "  FAIL ") + "rules: grate mask, ice presses plate=%s steam presses=%s, blocked shift=%s"
		% [pressed_ice, pressed_steam, blocked])
	if not ok:
		_fails += 1
