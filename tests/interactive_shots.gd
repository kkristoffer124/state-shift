extends Node
## Windowed capture of the interactive props: a whole-level overview per level plus 2x
## close-ups around every prop under Interactive/Gameplay and a few ambient ones.
##   godot --position -20000,-20000 --path . res://tests/interactive_shots.tscn -- --bg-test --out=<dir> [--only=3]

func _ready() -> void:
	Game.testing = true
	var out := "user://interactive_shots"
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--only="):
			only = a.substr(7)
	DirAccess.make_dir_recursive_absolute(out)
	for n in range(1, 13):
		if only != "" and str(n) != only:
			continue
		var path := "res://levels/level_%02d.tscn" % n
		var level: Node2D = load(path).instantiate()
		add_child(level)
		Hud.visible = false
		var player: Player = level.get_node("Player")
		player.camera.enabled = false
		var b: Rect2 = level.get_bounds()
		var cam := Camera2D.new()
		level.add_child(cam)
		cam.make_current()
		var vp := get_viewport().get_visible_rect().size
		# Let drips pool, vents puff, lamps settle.
		cam.position = b.get_center()
		var z := minf(vp.x / b.size.x, vp.y / b.size.y)
		cam.zoom = Vector2(z, z)
		for i in 150:
			await get_tree().physics_frame
		await _snap(out.path_join("ix_%02d_overview.png" % n))
		var ix := level.get_node("Interactive")
		var targets: Array = []
		if ix.has_node("Gameplay"):
			targets.append_array(ix.get_node("Gameplay").get_children())
		var amb := ix.get_node("Ambient").get_children()
		for i in mini(3, amb.size()):
			targets.append(amb[i * amb.size() / 3])
		for t in targets:
			var at: Vector2 = t.global_position
			if "size" in t and t.get("size") is Vector2:
				at += (t.get("size") as Vector2) / 2.0
			cam.position = at
			cam.zoom = Vector2(2, 2)
			for i in 4:
				await get_tree().process_frame
			await _snap(out.path_join("ix_%02d_%s.png" % [n, t.name]))
		level.queue_free()
		await get_tree().process_frame
	get_tree().quit()


func _snap(file: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(file)
