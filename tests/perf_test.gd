extends Node
## Per-level performance probe (windowed, off-screen, so draw calls are real):
##   godot --position -20000,-20000 --path . res://tests/perf_test.tscn -- --bg-test
## The player walks right and shifts states while we sample timings.

func _ready() -> void:
	Game.testing = true
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	print("level            fps   frame_ms  physics_ms  process_ms  draws  objs  nodes")
	for path in Game.LEVELS:
		var level: Node = load(path).instantiate()
		add_child(level)
		var p: Player = level.get_node("Player")
		for i in 30:
			await get_tree().process_frame
		Input.action_press("move_right")
		var frames := 0
		var t0 := Time.get_ticks_usec()
		var phys := 0.0
		var proc := 0.0
		var draws := 0
		for i in 240:
			if i % 60 == 20:
				p.try_shift((p.state + 1) % 3, true)
			await get_tree().process_frame
			frames += 1
			phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
			proc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
			draws = maxi(draws, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		var dt := (Time.get_ticks_usec() - t0) / 1000.0 / frames
		Input.action_release("move_right")
		print("%-16s %5.0f  %8.2f  %10.2f  %10.2f  %5d  %4d  %5d" % [path.get_file().get_basename(),
			1000.0 / dt, dt, phys / frames, proc / frames, draws,
			int(Performance.get_monitor(Performance.OBJECT_COUNT)),
			int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))])
		level.queue_free()
		await get_tree().process_frame
	get_tree().quit()
