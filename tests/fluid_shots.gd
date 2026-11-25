extends Node
## Windowed capture of the physics water/steam in motion:
##   godot --position -20000,-20000 --path . res://tests/fluid_shots.tscn -- --bg-test --out=<dir>

var out := "user://fluid"


func _ready() -> void:
	Game.testing = true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	var level: Node = load("res://levels/level_01.tscn").instantiate()
	add_child(level)
	var p: Player = level.get_node("Player")
	_player = p
	await _wait(40)
	await _shot("01_water_idle")
	Input.action_press("move_right")
	await _wait(12)
	await _shot("02_water_moving")
	Input.action_press("jump")
	await _wait(8)
	await _shot("03_water_jump")
	Input.action_release("jump")
	await _wait(30)
	await _shot("04_water_landed")
	Input.action_release("move_right")
	p.try_shift(Player.State.STEAM)
	await _wait(10)
	await _shot("05_boil_to_steam")
	await _wait(40)
	await _shot("06_steam_rising")
	Input.action_press("move_left")
	await _wait(30)
	await _shot("07_steam_drifting")
	Input.action_release("move_left")
	p.try_shift(Player.State.WATER)
	await _wait(10)
	await _shot("08_condense_to_water")
	await _wait(60)
	p.try_shift(Player.State.ICE)
	await _wait(30)
	p.try_shift(Player.State.WATER)
	await _wait(6)
	await _shot("09_melt_from_ice")
	await _wait(30)
	# Ice: slide, stop, fall, land.
	p.try_shift(Player.State.ICE, true)
	await _wait(20)
	Input.action_press("move_right")
	await _wait(40)
	await _shot("11_ice_slide")
	Input.action_release("move_right")
	await _wait(8)
	await _shot("12_ice_stop")
	p.global_position += Vector2(0, -160)
	p.velocity = Vector2(260, 0)
	await _wait(14)
	await _shot("13_ice_fall")
	await _wait(14)
	await _shot("14_ice_land")
	p.try_shift(Player.State.WATER, true)
	await _wait(30)
	p.die()
	await _wait(10)
	await _shot("10_death_splatter")
	get_tree().quit()


func _wait(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


var _player: Player


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if _player:
		var k := float(img.get_width()) / get_viewport().get_visible_rect().size.x
		var sp := (get_viewport().get_canvas_transform() * _player.global_position) * k
		var half := Vector2(110, 80) * k
		var r := Rect2i(Vector2i(sp - half), Vector2i(half * 2.0)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		img = img.get_region(r)
		img.resize(330, 240)
	img.save_png(out.path_join(shot_name + ".png"))
