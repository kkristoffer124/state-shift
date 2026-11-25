extends Node
## Windowed capture of the menus / cards / pause / end screen (uses a throwaway save):
##   godot --position -20000,-20000 --path . res://tests/menu_shots.tscn -- --bg-test --out=<dir>

const SHOT_SAVE := "user://menu_shots_save.cfg"

var out := "user://menu_shots"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _secs(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("shot ", name)


func _run() -> void:
	# Keep this node alive across change_scene_to_file.
	var ph := Node.new()
	get_tree().root.add_child(ph)
	get_tree().current_scene = ph
	if FileAccess.file_exists(SHOT_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SHOT_SAVE))
	Save.use_path(SHOT_SAVE)
	Settings.load_settings()
	Save.mark_started()
	for i in 5:
		Save.record_chapter(i, 30.0 + i * 17.3, i % 3)

	get_tree().change_scene_to_file(Game.MENU_SCENE)
	await _secs(0.8)
	await _shot("01_menu")
	var menu := get_tree().current_scene
	menu.load_btn.grab_focus()
	await _secs(0.3)
	await _shot("02_menu_focus_load")
	menu._on_load()
	await _secs(0.4)
	await _shot("03_chapter_select")
	menu.chapter_select.close()
	menu._on_settings()
	await _secs(0.4)
	await _shot("04_settings")
	menu.settings_panel.close()
	menu._on_new_game()
	await _secs(0.3)
	await _shot("05_confirm_new_game")
	menu._close_confirm()

	Game.start_chapter(5)
	await _secs(1.9)
	await _shot("06_chapter_card")
	await _secs(2.1)
	await _shot("07_in_game_hud")
	Overlay.open_pause()
	await _secs(0.4)
	await _shot("08_pause")
	Overlay.settings_btn.pressed.emit()
	await _secs(0.3)
	await _shot("09_pause_settings")
	Overlay.settings_panel.close()
	Overlay.close_pause()
	Game.level_complete()
	await _secs(1.3)
	await _shot("10_chapter_complete")
	await _secs(3.0)

	Game.run_time = 754.3
	Game.deaths = 17
	Game.in_level = false
	Hud.visible = false
	get_tree().change_scene_to_file(Game.END_SCENE)
	await _secs(1.0)
	await _shot("11_end")

	Save.use_path(Save.DEFAULT_PATH)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SHOT_SAVE))
	get_tree().quit()
