extends Node
## Headless smoke test:
##   godot --headless --path . res://tests/smoke_test.tscn
## Loads every level and checks the core mechanics with scripted states.

var _fails := 0


func _ready() -> void:
	Game.testing = true
	await _run()
	print("SMOKE TEST %s (%d failures)" % ["PASSED" if _fails == 0 else "FAILED", _fails])
	get_tree().quit(1 if _fails else 0)


func _check(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + msg)
	if not cond:
		_fails += 1


func _load(path: String) -> Node:
	for c in get_children():
		c.queue_free()
	await get_tree().physics_frame
	var level: Node = load(path).instantiate()
	add_child(level)
	return level


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _run() -> void:
	for path in Game.LEVELS:
		var level := await _load(path)
		var pn: Node = level.get_node("Player")
		await _frames(120)
		if pn is Player:
			_check(not pn.dead and pn.is_on_floor(), "%s: player spawns and lands" % path.get_file())
		else: # top-down / 3D chapters have their own tests
			_check(not pn.dead and "state" in pn and pn.has_signal("state_changed"), "%s: player spawns alive" % path.get_file())

	# Grates: ice stands on them, water drips through.
	var l1 := await _load("res://levels/level_01.tscn")
	var p: Player = l1.get_node("Player")
	p.global_position = Vector2(592, 170)
	p.try_shift(Player.State.ICE, true)
	await _frames(90)
	_check(p.global_position.y < 192, "ice rests on grate (y=%d)" % p.global_position.y)
	p.try_shift(Player.State.WATER, true)
	await _frames(90)
	_check(p.global_position.y > 300, "water drips through grate (y=%d)" % p.global_position.y)

	# Spikes: water dies, ice survives.
	var l2 := await _load("res://levels/level_02.tscn")
	p = l2.get_node("Player")
	p.try_shift(Player.State.ICE, true)
	p.global_position = Vector2(464, 238)
	await _frames(60)
	_check(not p.dead, "ice survives spikes")
	p.try_shift(Player.State.WATER, true)
	await _frames(10)
	_check(p.dead, "water dies on spikes")

	# Steam rises through a grate.
	var l3 := await _load("res://levels/level_03.tscn")
	p = l3.get_node("Player")
	p.global_position = Vector2(336, 460)
	await _frames(10)
	p.try_shift(Player.State.STEAM, true)
	await _frames(300)
	_check(p.global_position.y < 300, "steam rises through grate (y=%d)" % p.global_position.y)

	# Falling ice shatters cracked floor.
	var l4 := await _load("res://levels/level_04.tscn")
	p = l4.get_node("Player")
	var cracked := l4.get_node("Blocks/CrackedFloor")
	p.try_shift(Player.State.ICE, true)
	p.global_position = Vector2(624, 48)
	await _frames(240)
	_check(not is_instance_valid(cracked), "falling ice shatters cracked floor")
	_check(p.global_position.y > 400 and not p.dead, "ice falls through and survives spikes (y=%d)" % p.global_position.y)

	# Walking ice does NOT shatter.
	l4 = await _load("res://levels/level_04.tscn")
	p = l4.get_node("Player")
	cracked = l4.get_node("Blocks/CrackedFloor")
	p.try_shift(Player.State.ICE, true)
	p.global_position = Vector2(624, 270)
	await _frames(120)
	_check(is_instance_valid(cracked), "resting ice does not shatter cracked floor")

	# A short drop (well under ~150 px) doesn't shatter it either.
	l4 = await _load("res://levels/level_04.tscn")
	p = l4.get_node("Player")
	cracked = l4.get_node("Blocks/CrackedFloor")
	p.try_shift(Player.State.ICE, true)
	p.global_position = Vector2(624, 180)
	await _frames(120)
	_check(is_instance_valid(cracked) and p.global_position.y < 288, "a short ice drop does not shatter it")

	# Level 8: one long fall chains through both cracked floors.
	var l8 := await _load("res://levels/level_08.tscn")
	p = l8.get_node("Player")
	var c1 := l8.get_node("Blocks/CrackedFloor1")
	var c2 := l8.get_node("Blocks/CrackedFloor2")
	p.try_shift(Player.State.ICE, true)
	p.global_position = Vector2(736, 48)
	await _frames(240)
	_check(not is_instance_valid(c1) and not is_instance_valid(c2), "falling ice chains through both cracked floors")

	# Heat zone forces steam, freeze zone forces ice, shifting is locked.
	var l5 := await _load("res://levels/level_05.tscn")
	p = l5.get_node("Player")
	p.global_position = Vector2(208, 440)
	await _frames(20)
	_check(p.state == Player.State.STEAM, "heat zone forces steam")
	p.global_position = Vector2(528, 100)
	await _frames(5)
	_check(p.state == Player.State.ICE, "freeze zone forces ice")
	# Goal
	p.global_position = Vector2(864, 192)
	p.try_shift(Player.State.WATER, true)
	await _frames(20)
	_check(p.won, "goal completes level")

	await _interactive()


func _ix(level: Node, path: String) -> Node:
	return level.get_node_or_null("Interactive/" + path)


func _hold(action: String, n: int) -> void:
	Input.action_press(action)
	await _frames(n)
	Input.action_release(action)


## Interactive props (scenes/interactive): every level is dressed, and the gameplay
## pieces (plate, gate, turbine, basin, lever, drip) behave.
func _interactive() -> void:
	for i in Game.LEVELS.size():
		if not Game.LEVELS[i].get_file().begins_with("level_%02d.tscn" % (i + 1)):
			continue # top-down / 3D chapters: no 2D interactive layer
		var lv := await _load(Game.LEVELS[i])
		var ix := lv.get_node_or_null("Interactive")
		var amb := ix.get_node_or_null("Ambient") if ix else null
		var n_amb := amb.get_child_count() if amb else 0
		var n_game := ix.get_node("Gameplay").get_child_count() if ix and ix.has_node("Gameplay") else 0
		var scripted := true
		if ix:
			for c in ix.find_children("*", "", true, false):
				if c.get_parent() in [amb, ix.get_node_or_null("Gameplay")] and c.get_script() == null:
					scripted = false
		_check(scripted, "%s: %d ambient + %d gameplay props, all scripted"
			% [Game.LEVELS[i].get_file(), n_amb, n_game])

	# Level 2: ICE plate opens the shutter; water can't press it; closed shutter blocks.
	var l2 := await _load("res://levels/level_02.tscn")
	var p: Player = l2.get_node("Player")
	var plate: IxPlate = _ix(l2, "Gameplay/IcePlate")
	var gate: IxGate = _ix(l2, "Gameplay/ExitShutter")
	p.global_position = Vector2(250, 244)
	await _frames(30)
	await _hold("move_left", 120)
	_check(not gate.is_open and p.global_position.x > 216, "closed shutter blocks the goal (x=%d)" % p.global_position.x)
	p.global_position = Vector2(308, 244)
	p.velocity = Vector2.ZERO
	await _frames(40)
	_check(not plate.pressed, "WATER is too light for the plate")
	p.try_shift(Player.State.ICE, true)
	await _frames(40)
	_check(plate.pressed and gate.is_open, "ICE presses the plate and opens the shutter")
	p.try_shift(Player.State.WATER, true)
	p.global_position = Vector2(250, 244)
	await _frames(100)
	await _hold("move_left", 160)
	_check(p.won, "open shutter lets the player reach the goal")

	# Gate never closes onto the player.
	l2 = await _load("res://levels/level_02.tscn")
	p = l2.get_node("Player")
	gate = _ix(l2, "Gameplay/ExitShutter")
	gate._on_channel(1, true)
	await _frames(120)
	p.global_position = Vector2(204, 244)
	await _frames(10)
	gate._on_channel(1, false)
	await _frames(120)
	var bottom: float = gate.global_position.y + gate.size.y * (1.0 - gate._open)
	_check(not p.dead and bottom < p.global_position.y - 10.0 and absf(p.global_position.x - 204) < 20,
		"closing shutter stops above the player (edge y=%d, player y=%d)" % [bottom, p.global_position.y])

	# Level 3: steam spins the roof turbine, which raises the shutter.
	var l3 := await _load("res://levels/level_03.tscn")
	p = l3.get_node("Player")
	var turbine: IxTurbine = _ix(l3, "Gameplay/RoofTurbine")
	gate = _ix(l3, "Gameplay/ExitShutter")
	p.try_shift(Player.State.WATER, true)
	p.global_position = Vector2(600, 80)
	await _frames(5)
	_check(not turbine.charged, "turbine ignores water")
	p.try_shift(Player.State.STEAM, true)
	p.global_position = Vector2(600, 60)
	await _frames(80)
	_check(turbine.charged and gate.is_open, "steam charges the turbine and opens the shutter")

	# Level 1: dropping into the basin as water fills it and opens the exit.
	var l1 := await _load("res://levels/level_01.tscn")
	p = l1.get_node("Player")
	var basin: IxBasin = _ix(l1, "Gameplay/Basin")
	gate = _ix(l1, "Gameplay/ExitShutter")
	_check(not basin.full and not gate.is_open, "basin starts empty, exit shut")
	p.global_position = Vector2(592, 330)
	await _frames(60)
	_check(basin.full and gate.is_open, "water player fills the basin, exit opens")

	# Level 1 again: the leaky pipe alone fills the basin (fluid pixels or fallback drops).
	l1 = await _load("res://levels/level_01.tscn")
	basin = _ix(l1, "Gameplay/Basin")
	var t := 0
	while not basin.full and t < 2400:
		await get_tree().physics_frame
		t += 1
	var fw := get_tree().get_first_node_in_group("fluid_world")
	_check(basin.full, "drip pipe fills the basin by itself in %.1fs (%s)"
		% [t / 120.0, "fluid world" if fw else "fallback drops"])

	# Level 7: touching the valve starts the leak over the first grate.
	var l7 := await _load("res://levels/level_07.tscn")
	p = l7.get_node("Player")
	var valve: IxLever = _ix(l7, "Gameplay/Valve")
	var drip: IxDrip = _ix(l7, "Ambient/GratePipe1")
	await _frames(10)
	_check(not drip.flowing, "valve-fed pipe starts dry")
	p.global_position = Vector2(420, 148)
	await _frames(20)
	_check(valve.on and drip.flowing, "touching the valve opens the pipe")

	# Level 10: freezing right at the ledge edge is too slow to clear the pit.
	var l10 := await _load("res://levels/level_10.tscn")
	p = l10.get_node("Player")
	p.global_position = Vector2(330, 277)
	await _frames(20)
	p.try_shift(Player.State.ICE, true)
	await _hold("move_right", 120)
	_check(p.global_position.y > 440, "ice without a run-up falls short of the far ledge (y=%d)" % p.global_position.y)

	# Level 6: steam pushed by the side fan crosses the pit.
	var l6 := await _load("res://levels/level_06.tscn")
	p = l6.get_node("Player")
	p.global_position = Vector2(200, 300)
	p.try_shift(Player.State.STEAM, true)
	await _frames(120)
	_check(not p.dead and p.global_position.x > 600, "side fan blows steam across the pit (x=%d)" % p.global_position.x)
