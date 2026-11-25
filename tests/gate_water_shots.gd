extends Node
## Captures the water blob walking through an opened gate (regression shots):
##   godot --position -20000,-20000 --path . res://tests/gate_water_shots.tscn -- --bg-test --out=<dir>

var out := "user://gate_water"


func _ready() -> void:
	Game.testing = true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	var level: Node = load("res://levels/level_01.tscn").instantiate()
	add_child(level)
	var p: Player = level.get_node("Player")
	var basin = level.get_node_or_null("Interactive/Gameplay/Basin")
	await _wait(20)
	if basin:
		p.global_position = basin.global_position + Vector2(-40, -20)
	await _wait(30)
	Input.action_press("move_right")
	for i in 10:
		await _wait(6)
		await _shot(p, "gate_%02d" % i)
	Input.action_release("move_right")
	Input.action_press("move_left")
	for i in 6:
		await _wait(6)
		await _shot(p, "back_%02d" % i)
	Input.action_release("move_left")
	get_tree().quit()


func _wait(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(p: Player, n: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var k := float(img.get_width()) / get_viewport().get_visible_rect().size.x
	var sp := (get_viewport().get_canvas_transform() * p.global_position) * k
	var half := Vector2(70, 50) * k
	var r := Rect2i(Vector2i(sp - half), Vector2i(half * 2.0)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	img = img.get_region(r)
	img.resize(280, 200, Image.INTERPOLATE_NEAREST)
	img.save_png(out.path_join(n + ".png"))
