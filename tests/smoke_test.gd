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
