extends Node
## Headless worst-case fluid benchmark:  godot --headless --path . res://tests/fluid_bench.tscn

func _ready() -> void:
	Game.testing = true
	var level: Node = load("res://levels/level_01.tscn").instantiate()
	add_child(level)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var fw: FluidWorld = get_tree().get_first_node_in_group("fluid_world")
	var p: Player = level.get_node("Player")
	# Fill the level with free water and steam.
	for i in FluidWorld.MAX_WATER:
		fw.spawn_water(Vector2(randf_range(40, 1200), randf_range(40, 400)), Vector2(randf_range(-50, 50), 0))
	for i in FluidWorld.MAX_STEAM:
		fw.spawn_steam(Vector2(randf_range(40, 1200), randf_range(40, 400)))
	var tf := Time.get_ticks_usec()
	for i in 60:
		fw._physics_process(1.0 / 60.0)
	print("falling phase: %.2fms/tick" % ((Time.get_ticks_usec() - tf) / 1000.0 / 60))
	for i in 500:
		fw._physics_process(1.0 / 60.0)
	var tw := 0
	var td := 0
	var tb := 0
	var n := 120
	for i in n:
		var t0 := Time.get_ticks_usec()
		fw._physics_process(1.0 / 60.0)
		var t1 := Time.get_ticks_usec()
		pass
		var t2 := Time.get_ticks_usec()
		p.fluid._physics_process(1.0 / 120.0)
		var t3 := Time.get_ticks_usec()
		tw += t1 - t0
		td += t2 - t1
		tb += t3 - t2
	print("water=%d steam=%d  world_step=%.2fms  world_draw=%.2fms  body_step=%.2fms" % [
		fw.wpos.size(), fw.spos.size(), tw / 1000.0 / n, td / 1000.0 / n, tb / 1000.0 / n])
	get_tree().quit()
