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
		var p: Player = level.get_node("Player")
		await _frames(120)
		_check(not p.dead and p.is_on_floor(), "%s: player spawns and lands" % path.get_file())

	# Grates: ice stands on them, water drips through.
	var l1 := await _load("res://levels/level_01.tscn")
	var p: Player = l1.get_node("Player")
	p.global_position = Vector2(576, 420)
	p.try_shift(Player.State.ICE, true)
	await _frames(90)
	_check(p.global_position.y < 448, "ice rests on grate (y=%d)" % p.global_position.y)
	p.try_shift(Player.State.WATER, true)
	await _frames(90)
	_check(p.global_position.y > 480, "water drips through grate (y=%d)" % p.global_position.y)

	# Spikes: water dies, ice survives.
	var l2 := await _load("res://levels/level_02.tscn")
	p = l2.get_node("Player")
	p.try_shift(Player.State.ICE, true)
	p.global_position = Vector2(600, 420)
	await _frames(60)
	_check(not p.dead, "ice survives spikes")
	p.try_shift(Player.State.WATER, true)
	await _frames(10)
	_check(p.dead, "water dies on spikes")

	# Steam rises through a grate.
	var l3 := await _load("res://levels/level_03.tscn")
	p = l3.get_node("Player")
	p.global_position = Vector2(350, 930)
	await _frames(10)
	p.try_shift(Player.State.STEAM, true)
	await _frames(600)
	_check(p.global_position.y < 600, "steam rises through grate (y=%d)" % p.global_position.y)

	# Falling ice shatters cracked floor.
	var l4 := await _load("res://levels/level_04.tscn")
	p = l4.get_node("Player")
	var cracked := l4.get_node("Blocks/CrackedFloor")
	p.try_shift(Player.State.ICE, true)
	p.global_position = Vector2(800, 40)
	await _frames(240)
	_check(not is_instance_valid(cracked), "falling ice shatters cracked floor")
	_check(p.global_position.y > 800 and not p.dead, "ice falls through and survives spikes (y=%d)" % p.global_position.y)

	# Walking ice does NOT shatter.
	l4 = await _load("res://levels/level_04.tscn")
	p = l4.get_node("Player")
	cracked = l4.get_node("Blocks/CrackedFloor")
	p.try_shift(Player.State.ICE, true)
	p.global_position = Vector2(800, 420)
	await _frames(120)
	_check(is_instance_valid(cracked), "resting ice does not shatter cracked floor")

	# Heat zone forces steam, freeze zone forces ice, shifting is locked.
	var l5 := await _load("res://levels/level_05.tscn")
	p = l5.get_node("Player")
	p.global_position = Vector2(384, 810)
	await _frames(20)
	_check(p.state == Player.State.STEAM, "heat zone forces steam")
	p.global_position = Vector2(700, 120)
	await _frames(5)
	_check(p.state == Player.State.ICE, "freeze zone forces ice")
	# Goal
	p.global_position = Vector2(1504, 300)
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
		_check(n_amb >= 8 and scripted, "%s: %d ambient + %d gameplay props, all scripted"
			% [Game.LEVELS[i].get_file(), n_amb, n_game])

	# Level 2: ICE plate opens the shutter; water can't press it; closed shutter blocks.
	var l2 := await _load("res://levels/level_02.tscn")
	var p: Player = l2.get_node("Player")
	var plate: IxPlate = _ix(l2, "Gameplay/IcePlate")
	var gate: IxGate = _ix(l2, "Gameplay/ExitShutter")
	p.global_position = Vector2(1300, 360)
	await _frames(30)
	await _hold("move_right", 120)
	_check(not gate.is_open and p.global_position.x < 1392, "closed shutter blocks the ledge (x=%d)" % p.global_position.x)
	p.global_position = Vector2(1150, 430)
	p.velocity = Vector2.ZERO
	await _frames(40)
	_check(not plate.pressed, "WATER is too light for the plate")
	p.try_shift(Player.State.ICE, true)
	await _frames(40)
	_check(plate.pressed and gate.is_open, "ICE presses the plate and opens the shutter")
	p.try_shift(Player.State.WATER, true)
	p.global_position = Vector2(1300, 360)
	await _frames(100)
	await _hold("move_right", 160)
	_check(p.won, "open shutter lets the player reach the goal")

	# Gate never closes onto the player.
	l2 = await _load("res://levels/level_02.tscn")
	p = l2.get_node("Player")
	gate = _ix(l2, "Gameplay/ExitShutter")
	gate._on_channel(1, true)
	await _frames(120)
	p.global_position = Vector2(1404, 368)
	await _frames(10)
	gate._on_channel(1, false)
	await _frames(120)
	var bottom: float = gate.global_position.y + gate.size.y * (1.0 - gate._open)
	_check(not p.dead and bottom < p.global_position.y - 10.0 and absf(p.global_position.x - 1404) < 20,
		"closing shutter stops above the player (edge y=%d, player y=%d)" % [bottom, p.global_position.y])

	# Level 3: steam spins the roof turbine, which raises the shutter.
	var l3 := await _load("res://levels/level_03.tscn")
	p = l3.get_node("Player")
	var turbine: IxTurbine = _ix(l3, "Gameplay/RoofTurbine")
	gate = _ix(l3, "Gameplay/ExitShutter")
	p.try_shift(Player.State.WATER, true)
	p.global_position = Vector2(470, 60)
	await _frames(5)
	_check(not turbine.charged, "turbine ignores water")
	p.try_shift(Player.State.STEAM, true)
	p.global_position = Vector2(480, 40)
	await _frames(80)
	_check(turbine.charged and gate.is_open, "steam charges the turbine and opens the shutter")

	# Level 1: dropping into the basin as water fills it and opens the exit.
	var l1 := await _load("res://levels/level_01.tscn")
	p = l1.get_node("Player")
	var basin: IxBasin = _ix(l1, "Gameplay/Basin")
	gate = _ix(l1, "Gameplay/ExitShutter")
	_check(not basin.full and not gate.is_open, "basin starts empty, exit shut")
	p.global_position = Vector2(576, 580)
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
	p.global_position = Vector2(420, 240)
	await _frames(20)
	_check(valve.on and drip.flowing, "touching the valve opens the pipe")

	# Ambient: ice rushing past knocks flasks off; bumping a lamp swings it.
	l2 = await _load("res://levels/level_02.tscn")
	p = l2.get_node("Player")
	var shelf: IxFlaskShelf = _ix(l2, "Ambient/Shelf1")
	p.try_shift(Player.State.ICE, true)
	p.global_position = Vector2(230, 430)
	p.velocity = Vector2(300, 0)
	await _frames(60)
	_check(shelf._items.any(func(it: Array) -> bool: return it[2] != 0), "fast ice knocks the flasks off the shelf")
	var lamp: IxSwing = _ix(l2, "Ambient/Lamp1")
	p.try_shift(Player.State.STEAM, true)
	p.global_position = lamp.global_position + lamp.bob_local()
	p.velocity = Vector2(250, -100)
	await _frames(30)
	_check(absf(lamp.angle) > 0.05, "bumping a lamp swings it (angle=%.2f)" % lamp.angle)
