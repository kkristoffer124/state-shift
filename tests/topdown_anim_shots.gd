extends Node
## Windowed run that captures the top-down blob MID-ANIMATION (morph, slide, impact,
## drain squeeze, water/steam motion) as zoomed crops around the player:
##   godot --position -20000,-20000 --path . res://tests/topdown_anim_shots.tscn -- --bg-test --out=<dir>

var _out := "user://topdown_anim_shots"
var p: TdPlayer
var level: Node


func _ready() -> void:
	Game.testing = true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(_out)
	# Chapter 2: water -> ice morph, slide, impact
	await _load(2)
	Input.action_press("cool")
	await _frames(2)
	Input.action_release("cool")
	var prev := 0
	for f in [2, 4, 7, 12]:
		await _frames(f - prev)
		prev = f
		await _crop("morph_ice_%02d" % f)
	await _frames(20)
	Input.action_press("move_right")
	await _frames(3)
	Input.action_release("move_right")
	await _crop("slide_a")
	await _frames(5)
	await _crop("slide_b")
	await _frames(6)
	await _crop("slide_c")
	await _wait_stop()
	await _crop("impact_0")
	await _frames(4)
	await _crop("impact_4")
	await _frames(8)
	await _crop("impact_12")
	# Chapter 7: water motion, drain squeeze, steam drift
	await _load(7)
	_teleport(Vector2(6.3, 3), 1)
	await _hold(["move_right"], 20)
	await _crop("water_move")
	await _hold(["move_left"], 12)
	await _crop("water_turn_left")
	await _frames(70)
	await _crop("water_idle")
	# water -> steam -> water morphs on dry land
	Input.action_press("heat")
	await _frames(2)
	Input.action_release("heat")
	await _frames(3)
	await _crop("morph_steam_03")
	await _frames(8)
	await _crop("morph_steam_11")
	await _frames(40)
	Input.action_press("cool")
	await _frames(2)
	Input.action_release("cool")
	await _frames(4)
	await _crop("morph_water_04")
	await _frames(40)
	_teleport(Vector2(26, 11.3), 1)
	var last := 0
	for f in [3, 8, 14, 20, 30, 45, 55, 62, 70, 80]:
		await _frames(f - last)
		last = f
		await _crop("drain_%02d" % f)
	await _shot("drain_full")
	_teleport(Vector2(15, 12), 2)
	await _hold(["move_right"], 40)
	await _crop("steam_move")
	await _frames(30)
	await _crop("steam_idle")
	await _shot("props_full")
	# goal absorb
	_teleport(Vector2(26.5, 3.0), 1)
	await _frames(12)
	await _crop("win_12")
	await _frames(20)
	await _crop("win_32")
	# splat on spikes (chapter 2)
	await _load(2)
	_teleport(Vector2(7, 8), 1)
	await _frames(6)
	await _crop("splat_06")
	await _frames(14)
	await _crop("splat_20")
	get_tree().quit()


func _wait_stop() -> void:
	for i in 200:
		if not p.is_sliding():
			return
		await get_tree().process_frame


func _load(n: int) -> void:
	for c in get_children():
		c.queue_free()
	await get_tree().process_frame
	level = load("res://levels/level_%02d_topdown.tscn" % n).instantiate()
	add_child(level)
	Hud.visible = false
	p = level.get_node("Player")
	await _frames(40)


func _teleport(c: Vector2, st: int) -> void:
	p.global_position = c * 32.0 + Vector2(16, 16)
	if p.state != st:
		p.try_shift(st, true)
	p.velocity = Vector2.ZERO


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _hold(actions: Array, frames: int) -> void:
	for a in actions:
		Input.action_press(a)
	await _frames(frames)
	for a in actions:
		Input.action_release(a)


func _crop(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var k := float(img.get_width()) / 960.0
	var c := get_viewport().get_canvas_transform() * p.global_position
	var r := Rect2i(Vector2i((c - Vector2(56, 44)) * k), Vector2i(Vector2(112, 80) * k))
	r = r.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var sub := img.get_region(r)
	var target := Vector2i(448, 320)
	sub.resize(target.x, target.y, Image.INTERPOLATE_NEAREST)
	sub.save_png(_out.path_join(name + ".png"))
	print("saved ", name)


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(_out.path_join(name + ".png"))
	print("saved ", name)
