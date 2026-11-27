extends Node
## Windowed capture of the settings panel tabs and a few settings effects (throwaway save):
##   godot --position -20000,-20000 --path . res://tests/settings_shots.tscn -- --bg-test --out=<dir>

const SHOT_SAVE := "user://settings_shots_save.cfg"

var out := "user://settings_shots"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _secs(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("shot ", name)


func _run() -> void:
	var ph := Node.new()
	get_tree().root.add_child(ph)
	get_tree().current_scene = ph
	if FileAccess.file_exists(SHOT_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SHOT_SAVE))
	Save.use_path(SHOT_SAVE)
	Settings.load_settings()
	Save.mark_started()

	get_tree().change_scene_to_file(Game.MENU_SCENE)
	await _secs(0.8)
	var menu := get_tree().current_scene
	menu._on_settings()
	await _secs(0.4)
	var sp: SettingsPanel = menu.settings_panel
	var n := 1
	for c in Settings.CATEGORIES:
		sp.show_category(c)
		var ctrls: Array = sp._page_controls[c]
		ctrls[0].grab_focus()
		await _secs(0.8)
		await _shot("s%02d_tab_%s" % [n, c])
		n += 1
	# Scrolled to the bottom of the longest tab, with a changed value.
	sp.show_category("video")
	Settings.set_value("glow_3d", true)
	(sp._page_controls["video"][-1] as Control).grab_focus()
	await _secs(0.4)
	await _shot("s%02d_video_scrolled" % n)
	n += 1
	# Rebinding prompt.
	sp.show_category("controls")
	(sp.controls["bind_heat"] as Control).grab_focus()
	(sp.controls["bind_heat"] as Button).pressed.emit()
	await _secs(0.3)
	await _shot("s%02d_rebind_prompt" % n)
	n += 1
	sp._capturing = ""
	# Large text.
	Settings.set_value("text_size", 1.3)
	sp.show_category("access")
	await _secs(0.4)
	await _shot("s%02d_text_huge" % n)
	n += 1
	Settings.set_value("text_size", 1.0)
	sp.close()

	# In-game: info HUD, control hints, locator + state name.
	for k in ["show_fps", "show_timer", "show_total_timer", "show_deaths", "show_perspective", "show_controls", "player_locator", "state_label"]:
		Settings.set_value(k, true)
	Settings.set_value("skip_chapter_cards", true)
	Game.start_chapter(0)
	await _secs(2.0)
	await _shot("s%02d_ingame_info" % n)
	n += 1
	Settings.set_value("info_corner", 2)
	Settings.set_value("room_zoom", 1.5)
	Settings.set_value("background_dim", 0.5)
	await _secs(1.0)
	await _shot("s%02d_zoom_dim_corner" % n)
	n += 1
	Settings.set_value("room_zoom", 1.0)
	Settings.set_value("background_dim", 0.0)
	# Post-process looks.
	Settings.set_value("scanlines", 0.8)
	Settings.set_value("vignette", 0.8)
	Settings.set_value("bloom", 0.6)
	Settings.set_value("chromatic_aberration", 0.6)
	await _secs(0.5)
	await _shot("s%02d_crt_look" % n)
	n += 1
	Settings.reset_category("video")
	Settings.set_value("colorblind_mode", 2)
	await _secs(0.3)
	await _shot("s%02d_deuteranopia" % n)
	n += 1
	Settings.set_value("colorblind_mode", 4)
	Settings.set_value("brightness", 1.3)
	await _secs(0.3)
	await _shot("s%02d_greyscale_bright" % n)
	n += 1
	Settings.reset_defaults()
	# 3D chapter with the locator and a wide FOV.
	Settings.set_value("player_locator", true)
	Settings.set_value("state_label", true)
	Settings.set_value("tp_fov", 95.0)
	Settings.set_value("skip_chapter_cards", true)
	Game.start_chapter(2)
	await _secs(2.5)
	await _shot("s%02d_3d_fov_locator" % n)
	n += 1
	Settings.set_value("tp_fov", 64.0)
	Settings.set_value("glow_3d", true)
	Settings.set_value("shadows_3d", false)
	Settings.set_value("fog_3d", false)
	await _secs(0.5)
	await _shot("s%02d_3d_glow_noshadow_nofog" % n)
	n += 1

	if FileAccess.file_exists(SHOT_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SHOT_SAVE))
	Save.use_path(Save.DEFAULT_PATH)
	Settings.load_settings()
	get_tree().quit()
