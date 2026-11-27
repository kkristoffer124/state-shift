extends Node
## Mid-animation captures of the UiFx water / ice / steam UI animation (throwaway save):
##   godot --position -20000,-20000 --path . res://tests/uifx_shots.tscn -- --bg-test --out=<dir>

const SHOT_SAVE := "user://uifx_shots_save.cfg"

var out := "user://uifx_shots"


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
	for i in 5:
		Save.record_chapter(i, 30.0 + i * 17.3, i % 3)

	# --- Title screen ---------------------------------------------------------------
	get_tree().change_scene_to_file(Game.MENU_SCENE)
	await _secs(0.62)
	await _shot("01_intro_drip")
	await _secs(1.2)
	var menu := get_tree().current_scene
	menu.load_btn.grab_focus()
	await _secs(0.06)
	await _shot("02_hover_wobble")
	await _secs(0.9)
	await _shot("03_hover_beads")
	UiFx._last_input_mouse = false
	UiFx._on_down(menu.load_btn)
	await _secs(0.06)
	UiFx._on_up(menu.load_btn)
	UiFx._on_pressed(menu.load_btn)
	await _secs(0.09)
	await _shot("04_click_splash")
	await _secs(0.6)
	for s in menu.get_node("Main/Mascots").get_children():
		s._react(true)
	await _secs(0.14)
	await _shot("05_mascot_bursts")
	await _secs(0.8)

	# --- Chapter select -----------------------------------------------------------------
	menu._on_load()
	await _secs(0.09)
	await _shot("06_chapters_condense")
	await _secs(0.6)
	menu.chapter_select.tiles[7].grab_focus()
	await _secs(0.7)
	await _shot("07_chapters_locked_ice")
	menu.chapter_select.close()
	await _secs(0.1)
	await _shot("08_chapters_evaporate")
	await _secs(0.6)

	# --- Settings -----------------------------------------------------------------------
	menu._on_settings()
	await _secs(0.1)
	await _shot("09_settings_condense")
	await _secs(0.6)
	var sp: Control = menu.settings_panel
	var vis := func(c: Node) -> bool: return (c as Control).is_visible_in_tree()
	var toggles := sp.find_children("*", "CheckButton", true, false).filter(vis)
	var sliders := sp.find_children("*", "HSlider", true, false).filter(vis)
	if not sliders.is_empty():
		var sl := sliders[0] as HSlider
		sl.grab_focus()
		await _secs(0.3)
		sl.value = 55.0
		await _secs(0.05)
		await _shot("10_slider_water")
	if not toggles.is_empty():
		var tb := toggles[0] as CheckButton
		tb.grab_focus()
		await _secs(0.3)
		tb.button_pressed = not tb.button_pressed
		await _secs(0.07)
		await _shot("11_toggle_change")
		await _secs(0.5)
		tb.button_pressed = not tb.button_pressed
		await _secs(0.12)
		await _shot("12_toggle_melt")
	sp.close()
	await _secs(0.5)

	# --- Confirm dialog -------------------------------------------------------------------
	menu._on_new_game()
	await _secs(0.12)
	await _shot("13_confirm_condense")
	menu._close_confirm()
	await _secs(0.5)

	# --- Transition + chapter card ----------------------------------------------------------
	Game.start_chapter(5)
	await _secs(0.16)
	await _shot("14_water_wipe")
	await _secs(0.95)
	await _shot("15_card_drip")
	await _secs(1.4)
	await _shot("16_card_settled")
	await _secs(1.5)

	# --- HUD --------------------------------------------------------------------------------
	Hud._on_state_changed(0)
	await _secs(0.07)
	await _shot("17_hud_ice")
	await _secs(0.5)
	Hud._on_state_changed(2)
	await _secs(0.12)
	await _shot("18_hud_steam")
	await _secs(0.5)
	Hud._on_state_changed(1)
	Game.deaths_changed.emit(3)
	await _secs(0.12)
	await _shot("19_hud_water_drip")
	Hud.set_locked(true)
	await _secs(0.08)
	await _shot("20_hud_lock")
	Hud.set_locked(false)
	await _secs(0.4)

	# --- Pause + complete card ----------------------------------------------------------------
	Overlay.open_pause()
	await _secs(0.1)
	await _shot("21_pause_condense")
	await _secs(0.5)
	Overlay.close_pause()
	await _secs(0.12)
	await _shot("22_pause_evaporate")
	Game.level_complete()
	await _secs(1.25)
	await _shot("23_complete_card")
	await _secs(3.0)

	# --- End screen ----------------------------------------------------------------------------
	Game.run_time = 754.3
	Game.deaths = 17
	Game.in_level = false
	Hud.visible = false
	# Let the post-card transition settle, then go to the end screen.
	await _secs(1.0)
	get_tree().change_scene_to_file(Game.END_SCENE)
	while get_tree().current_scene == null or get_tree().current_scene.scene_file_path != Game.END_SCENE:
		await get_tree().process_frame
	await _secs(0.45)
	await _shot("24_end_drip")
	await _secs(1.5)
	await _shot("25_end_settled")

	Save.use_path(Save.DEFAULT_PATH)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SHOT_SAVE))
	get_tree().quit()
