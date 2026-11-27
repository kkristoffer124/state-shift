extends Node
## Windowed run that saves a whole-level overview of levels 6-12 (camera zoomed to fit):
##   godot --position -20000,-20000 --path . res://tests/level_shots.tscn -- --bg-test --out=<dir>

func _ready() -> void:
	Game.testing = true
	var out := "user://level_shots"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	for n in range(1, 13):
		var path := "res://levels/level_%02d.tscn" % n
		var level: Node2D = load(path).instantiate()
		add_child(level)
		Hud.visible = false
		var player: Player = level.get_node("Player")
		player.camera.enabled = false
		var b: Rect2 = level.get_bounds()
		var cam := Camera2D.new()
		cam.position = b.get_center()
		var vp := get_viewport().get_visible_rect().size
		var z := minf(vp.x / b.size.x, vp.y / b.size.y)
		cam.zoom = Vector2(z, z)
		level.add_child(cam)
		cam.make_current()
		for i in 40:
			await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		img.save_png(out.path_join("level_%02d.png" % n))
		level.queue_free()
		await get_tree().process_frame
	get_tree().quit()
