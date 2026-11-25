extends Node
## Headless front-end test (uses a throwaway save, the real one is untouched):
##   godot --headless --path . res://tests/menu_test.tscn
## New game -> chapter 1, completing unlocks chapter 2, chapter select starts a chapter,
## locked chapters stay locked, pause works, settings persist across a reload.

const TEST_SAVE := "user://menu_test_save.cfg"

var _fails := 0


func _ready() -> void:
	_run.call_deferred()


func _check(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + msg)
	if not cond:
		_fails += 1


func _scene_path() -> String:
	var s := get_tree().current_scene
	return s.scene_file_path if s else ""


## Waits until the current scene is `path` and settled (fades done). Returns success.
func _wait_scene(path: String, timeout := 8.0) -> bool:
	var t := 0.0
	while t < timeout:
		if _scene_path() == path and not Game._transitioning:
			for i in 5:
				await get_tree().process_frame
			return true
		await get_tree().process_frame
		t += get_process_delta_time()
	return false


func _press_cancel() -> void:
	var ev := InputEventAction.new()
	ev.action = &"ui_cancel"
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().process_frame
	ev = InputEventAction.new()
	ev.action = &"ui_cancel"
	ev.pressed = false
	Input.parse_input_event(ev)
	await get_tree().process_frame


## Skips the running cutscene (tests/cutscene_test.gd covers playback).
func _skip_cutscene() -> void:
	var cs := get_tree().current_scene as Cutscene
	_check(cs != null, "cutscene is running")
	if cs:
		cs.skip()


func _wipe() -> void:
	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))


func _run() -> void:
	# Keep this node alive across change_scene_to_file.
	var ph := Node.new()
	get_tree().root.add_child(ph)
	get_tree().current_scene = ph
	Game.testing = false
	_wipe()
	Save.use_path(TEST_SAVE)
	Settings.load_settings()

	# Chapter names in menus match the levels' own names.
	for i in Game.LEVELS.size():
		var state := (load(Game.LEVELS[i]) as PackedScene).get_state()
		var lname := ""
		for p in state.get_node_property_count(0):
			if state.get_node_property_name(0, p) == "level_name":
				lname = state.get_node_property_value(0, p)
		_check(Game.title_from_level_name(lname) == Game.chapter_name(i),
			"chapter %d name '%s' matches level_name '%s'" % [i + 1, Game.chapter_name(i), lname])

	# Audio buses + Sfx routing.
	_check(AudioServer.get_bus_index("Music") > 0 and AudioServer.get_bus_index("SFX") > 0, "Music and SFX buses exist")
	var sfx_players := Sfx.get_children().filter(func(c: Node) -> bool: return c is AudioStreamPlayer)
	_check(not sfx_players.is_empty() and sfx_players.all(func(p: AudioStreamPlayer) -> bool: return p.bus == &"SFX"),
		"Sfx players route to the SFX bus")

	# --- Title menu, fresh save ---
	get_tree().change_scene_to_file(Game.MENU_SCENE)
	await _wait_scene(Game.MENU_SCENE)
	var menu := get_tree().current_scene
	_check(not menu.continue_btn.visible, "no Continue without a save")
	_check(menu.new_btn.has_focus(), "New game has focus on a fresh save")
	_check(not Save.is_unlocked(1), "chapter 2 locked on a fresh save")

	# --- New game -> intro cutscene -> chapter 1 ---
	menu.new_btn.pressed.emit()
	_check(await _wait_scene(Game.INTRO_SCENE), "New game plays the intro cutscene")
	await _skip_cutscene()
	_check(await _wait_scene(Game.LEVELS[0]), "New game loads chapter 1")
	_check(Game.level_index == 0 and Game.in_level and Hud.visible, "in chapter 1 with HUD")
	_check(Hud.level_label.text == "Chapter 1 — Drip", "HUD shows chapter name (%s)" % Hud.level_label.text)
	_check(Overlay.chapter_card.visible, "chapter title card shown")
	_check(Save.has_progress(), "save marked as started")

	# --- Pause (Esc opens it, Esc closes it) ---
	await _press_cancel()
	_check(Overlay.is_paused(), "Esc in a chapter opens the pause menu")
	await _press_cancel()
	_check(not Overlay.is_paused() and not get_tree().paused, "Esc again resumes")
	Overlay.open_pause()
	await get_tree().process_frame
	_check(get_tree().paused and Overlay.is_paused(), "pause menu pauses the tree")
	var t0 := Game.chapter_time
	for i in 10:
		await get_tree().process_frame
	_check(Game.chapter_time == t0, "chapter timer stops while paused")
	Overlay.resume_btn.pressed.emit()
	await get_tree().process_frame
	_check(not get_tree().paused and not Overlay.is_paused(), "Resume unpauses")

	# --- Complete chapter 1 -> chapter 2 unlocked + loaded ---
	Game.chapter_time = 12.5
	Game.level_complete()
	var waited := 0
	while not Overlay._complete_waiting and waited < 600:
		await get_tree().process_frame
		waited += 1
	_check(Overlay.complete_card.visible, "chapter complete card shown")
	_check(Save.is_unlocked(1) and not Save.is_unlocked(2), "completing chapter 1 unlocks chapter 2 only")
	_check(is_equal_approx(Save.best_time(0), 12.5) and Save.best_deaths(0) == 0, "best time/deaths recorded (%.2f, %d)" % [Save.best_time(0), Save.best_deaths(0)])
	Overlay._finish_complete()
	_check(await _wait_scene(Game.LEVELS[1]), "continues to chapter 2")
	_check(Game.level_index == 1, "level_index is chapter 2")

	# Reloading the save file keeps progress.
	Save.load_file()
	_check(Save.unlocked_count() == 2, "unlock persisted in %s" % TEST_SAVE)

	# --- Back to menu: Continue + chapter select ---
	Game.go_to_menu()
	await _wait_scene(Game.MENU_SCENE)
	menu = get_tree().current_scene
	_check(menu.continue_btn.visible, "Continue shown once a save exists")
	_check(not Overlay.is_paused() and not Hud.visible, "menu has no HUD / pause")
	menu.load_btn.pressed.emit()
	await get_tree().process_frame
	var cs: ChapterSelect = menu.chapter_select
	_check(cs.visible and cs.tiles.size() == 12, "chapter select lists 12 chapters")
	_check(not cs.tiles[0].locked and not cs.tiles[1].locked and cs.tiles[2].locked, "tiles: 1-2 open, 3 locked")
	_check(cs.tiles[2].lock.visible, "locked tile shows a padlock")
	_check(cs.tiles[0].stats_label.text.begins_with("0:12.5"), "cleared tile shows best time (%s)" % cs.tiles[0].stats_label.text)
	cs.tiles[5].pressed.emit()
	for i in 20:
		await get_tree().process_frame
	_check(_scene_path() == Game.MENU_SCENE, "locked chapter can't be started")
	cs.tiles[1].pressed.emit()
	_check(await _wait_scene(Game.LEVELS[1]), "chapter select starts chapter 2")

	# Continue resumes the furthest unlocked chapter.
	Game.go_to_menu()
	await _wait_scene(Game.MENU_SCENE)
	menu = get_tree().current_scene
	menu.continue_btn.pressed.emit()
	_check(await _wait_scene(Game.LEVELS[1]), "Continue resumes chapter 2")

	# New game with progress asks first.
	Game.go_to_menu()
	await _wait_scene(Game.MENU_SCENE)
	menu = get_tree().current_scene
	menu.new_btn.pressed.emit()
	await get_tree().process_frame
	_check(menu.confirm.visible and _scene_path() == Game.MENU_SCENE, "New game over a save asks to confirm")
	menu.confirm_no.pressed.emit()
	await get_tree().process_frame
	_check(not menu.confirm.visible and Save.unlocked_count() == 2, "Cancel keeps progress")

	# --- Settings persist ---
	menu.settings_btn.pressed.emit()
	await get_tree().process_frame
	var sp: SettingsPanel = menu.settings_panel
	_check(sp.visible, "settings panel opens")
	sp.zoom.step(1)  # 2x -> 3x
	sp.master.value = 50.0
	sp.shake.button_pressed = false
	_check(Settings.camera_zoom == 3.0 and Settings.master_volume == 0.5 and not Settings.screen_shake, "panel edits Settings")
	var db := AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master"))
	_check(absf(db - linear_to_db(0.5)) < 0.1, "master bus volume applied (%.1f dB)" % db)
	Settings.camera_zoom = 2.0
	Settings.master_volume = 1.0
	Settings.screen_shake = true
	Save.load_file()
	Settings.load_settings()
	_check(Settings.camera_zoom == 3.0 and Settings.master_volume == 0.5 and not Settings.screen_shake,
		"settings persist after reload")
	sp.close()

	# --- Confirmed new game wipes progress but keeps settings ---
	menu.new_btn.pressed.emit()
	await get_tree().process_frame
	menu.confirm_yes.pressed.emit()
	_check(await _wait_scene(Game.INTRO_SCENE), "confirmed New game plays the intro")
	await _skip_cutscene()
	_check(await _wait_scene(Game.LEVELS[0]), "confirmed New game starts chapter 1")
	_check(Save.unlocked_count() == 1 and Save.best_time(0) < 0.0, "progress wiped")
	_check(Settings.camera_zoom == 3.0, "settings kept after New game")

	# --- End screen after the last chapter ---
	Game.level_index = Game.LEVELS.size() - 1
	Game._next_level()
	_check(await _wait_scene(Game.ENDING_SCENE), "finishing chapter 12 plays the ending cutscene")
	await _skip_cutscene()
	_check(await _wait_scene(Game.END_SCENE), "finishing chapter 12 shows the end screen")
	get_tree().current_scene.chapters_btn.pressed.emit()
	await _wait_scene(Game.MENU_SCENE)
	await get_tree().process_frame
	_check(get_tree().current_scene.chapter_select.visible, "end screen 'Chapter select' opens the chapter list")

	# Restore the real save.
	_wipe()
	Save.use_path(Save.DEFAULT_PATH)
	Settings.load_settings()
	print("MENU TEST %s (%d failures)" % ["PASSED" if _fails == 0 else "FAILED", _fails])
	get_tree().quit(1 if _fails else 0)
