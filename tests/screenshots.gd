extends Node
## Windowed run that saves a screenshot of the menu and every level:
##   godot --position -20000,-20000 --path . res://tests/screenshots.tscn -- --bg-test --out=<dir>

func _ready() -> void:
	Game.testing = true
	var out := "user://screens"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	var scenes := ["res://scenes/menu.tscn"] + Array(Game.LEVELS) + ["res://scenes/end.tscn"]
	for path in scenes:
		var node: Node = load(path).instantiate()
		add_child(node)
		Hud.visible = path.begins_with("res://levels")
		for i in 50:
			await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		img.save_png(out.path_join(path.get_file().get_basename() + ".png"))
		node.queue_free()
		await get_tree().process_frame
	get_tree().quit()
