extends Node
## Windowed run that pans a camera across every level and saves several frames
## per level (checks parallax + dressing over the whole map, not just the spawn):
##   godot --position -20000,-20000 --path . res://tests/dressing_shots.tscn -- --bg-test --out=<dir> [--levels=1,5] [--overview]
##   add --count (works with --headless) to print CanvasItem counts instead

func _ready() -> void:
	Game.testing = true
	var out := "user://dressing_shots"
	var only: Array[int] = []
	var overview := false
	var count := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--levels="):
			for s in a.substr(9).split(","):
				only.append(int(s))
		elif a == "--overview":
			overview = true
		elif a == "--count":
			count = true
	DirAccess.make_dir_recursive_absolute(out)
	Hud.visible = false
	for n in range(1, 13):
		if not only.is_empty() and not n in only:
			continue
		var level: Node2D = load("res://levels/level_%02d.tscn" % n).instantiate()
		add_child(level)
		Hud.visible = false
		if count:
			await get_tree().process_frame
			var d := level.get_node("Dressing")
			print("level %02d: dressing canvas items %d, level total %d" % [n, _count(d), _count(level)])
			level.queue_free()
			await get_tree().process_frame
			continue
		var player: Node2D = level.get_node("Player")
		player.camera.enabled = false
		player.process_mode = Node.PROCESS_MODE_DISABLED
		var b: Rect2 = level.get_bounds()
		var cam := Camera2D.new()
		cam.limit_left = int(b.position.x)
		cam.limit_top = int(b.position.y)
		cam.limit_right = int(b.end.x)
		cam.limit_bottom = int(b.end.y)
		level.add_child(cam)
		cam.make_current()
		var vp := get_viewport().get_visible_rect().size
		if overview:
			cam.limit_left = -100000
			cam.limit_top = -100000
			cam.limit_right = 100000
			cam.limit_bottom = 100000
			cam.position = b.get_center()
			var z := minf(vp.x / b.size.x, vp.y / b.size.y)
			cam.zoom = Vector2(z, z)
			for i in 30:
				await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png(out.path_join("level_%02d_overview.png" % n))
		else:
			var cols := 3 if b.size.x > vp.x * 1.6 else 2
			var rows := 2 if b.size.y > vp.y * 1.3 else 1
			if b.size.y > vp.y * 2.2:
				rows = 3
			for r in rows:
				for c in cols:
					var fx := 0.0 if cols == 1 else float(c) / (cols - 1)
					var fy := 0.0 if rows == 1 else float(r) / (rows - 1)
					cam.position = Vector2(
						lerpf(b.position.x + vp.x / 2, b.end.x - vp.x / 2, fx),
						lerpf(b.position.y + vp.y / 2, b.end.y - vp.y / 2, fy))
					cam.reset_smoothing()
					for i in 20:
						await get_tree().process_frame
					get_viewport().get_texture().get_image().save_png(out.path_join("level_%02d_%d%d.png" % [n, r, c]))
		level.queue_free()
		await get_tree().process_frame
	get_tree().quit()


func _count(n: Node) -> int:
	var c := 1 if n is CanvasItem else 0
	for k in n.get_children():
		c += _count(k)
	return c
