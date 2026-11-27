extends Node
## Windowed run that saves screenshots of the top-down chapters (start + mid-play):
##   godot --position -20000,-20000 --path . res://tests/topdown_shots.tscn -- --bg-test --out=<dir>

const ACTIONS := ["move_left", "move_right", "move_up", "move_down", "heat", "cool"]

var _out := "user://topdown_shots"
var p: TdPlayer
var level: Node


func _ready() -> void:
	Game.testing = true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(_out)
	# Chapter 2
	await _load(2)
	await _shot("td_02_start")
	await _press("cool", 3)
	await _frames(20)
	await _press("move_right", 3)
	await _frames(22)
	await _shot("td_02_slide")
	await _frames(60)
	await _press("move_down", 3)
	await _frames(50)
	await _press("move_right", 3)
	await _frames(70)
	await _shot("td_02_plate")
	# Chapter 7
	await _load(7)
	await _shot("td_07_start")
	_teleport(Vector2(6.3, 3), 1)
	await _hold(["move_right"], 25)
	await _shot("td_07_water")
	_teleport(Vector2(15, 12), 2)
	await _hold(["move_right"], 55)
	await _shot("td_07_steam")
	_teleport(Vector2(26, 11.3), 1)
	await _frames(14)
	await _shot("td_07_drain")
	get_tree().quit()


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


func _press(action: String, frames: int) -> void:
	Input.action_press(action)
	await _frames(frames)
	Input.action_release(action)


func _hold(actions: Array, frames: int) -> void:
	for a in actions:
		Input.action_press(a)
	await _frames(frames)
	for a in actions:
		Input.action_release(a)


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(_out.path_join(name + ".png"))
	print("saved ", name)
