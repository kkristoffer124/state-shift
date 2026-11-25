extends Node
## Headless cutscene test (uses a throwaway save, the real one is untouched):
##   godot --headless --path . res://tests/cutscene_test.tscn
## Both cutscenes are well-formed; New game -> intro -> chapter 1; tap advances,
## Esc twice / hold Space skips; finishing chapter 12 -> ending -> end screen;
## left alone, each cutscene hands off by itself.

const TEST_SAVE := "user://cutscene_test_save.cfg"

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


## Waits (in real seconds) until the current scene is `path` and settled.
func _wait_scene(path: String, timeout := 8.0) -> bool:
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < timeout * 1000.0:
		if _scene_path() == path and not Game._transitioning:
			for i in 5:
				await get_tree().process_frame
			return true
		await get_tree().process_frame
	return false


func _wait_until(cond: Callable, timeout := 4.0) -> bool:
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < timeout * 1000.0:
		if cond.call():
			return true
		await get_tree().process_frame
	return false


func _secs(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _tap(action: StringName) -> void:
	for pressed in [true, false]:
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await get_tree().process_frame


func _wipe() -> void:
	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))


func _run() -> void:
	var ph := Node.new()
	get_tree().root.add_child(ph)
	get_tree().current_scene = ph
	Game.testing = false
	_wipe()
	Save.use_path(TEST_SAVE)

	# --- Structure -----------------------------------------------------------------
	for path in [Game.INTRO_SCENE, Game.ENDING_SCENE]:
		var packed := load(path) as PackedScene
		_check(packed != null, "%s loads" % path)
		if packed == null:
			continue
		var cs := packed.instantiate()
		_check(cs is Cutscene, "%s root is a Cutscene" % path.get_file())
		var total := 0.0
		var count := 0
		var all_ok := true
		for p in cs.get_node("Panels").get_children():
			var anim := p.get_node_or_null("Anim") as AnimationPlayer
			var ok: bool = p is CutscenePanel and anim != null and anim.has_animation(&"main") \
				and p.get_node_or_null("Camera") is Camera2D
			if not ok:
				print("    bad panel ", p.name)
			all_ok = all_ok and ok
			if anim and anim.has_animation(&"main"):
				total += anim.get_animation(&"main").length
			count += 1
		_check(all_ok and count >= 5, "%s: %d panels, each with Anim/main + Camera" % [path.get_file(), count])
		_check(total >= 25.0 and total <= 60.0, "%s runs %.1f s (25-60)" % [path.get_file(), total])
		cs.free()

	# --- New game -> intro --------------------------------------------------------------
	Game.new_game()
	_check(await _wait_scene(Game.INTRO_SCENE), "New game plays the intro")
	var cs := get_tree().current_scene as Cutscene
	_check(cs != null and cs.index == 0 and cs.panels[0].visible, "intro starts on panel 1")
	_check(not Hud.visible and not Game.in_level, "no HUD during the cutscene")
	_check(await _wait_until(func() -> bool: return cs.ui.current_text() != "", 3.0), "a caption appears (%s)" % cs.ui.current_text())
	# Tap: finishes the caption, then moves to the next panel.
	cs.ui.say("", "A long test line that is still typing out when the player taps.")
	await get_tree().process_frame
	_check(cs.ui.is_typing(), "caption is typing")
	cs.advance()
	_check(not cs.ui.is_typing() and cs.index == 0, "first tap completes the caption")
	cs.advance()
	_check(await _wait_until(func() -> bool: return cs.index == 1, 2.0), "second tap moves to panel 2")
	# Esc once shows the hint, Esc again skips.
	await _tap(&"ui_cancel")
	_check(cs.ui.hint.text.contains("ESC again") and not cs.done, "Esc once asks to confirm the skip")
	await _tap(&"ui_cancel")
	_check(cs.done, "Esc twice skips")
	_check(await _wait_scene(Game.LEVELS[0]), "intro hands off to chapter 1")
	_check(Game.level_index == 0 and Game.in_level and Hud.visible, "in chapter 1 with HUD")
	_check(Overlay.chapter_card.visible and Overlay.card_line.text == Game.chapter_line(0),
		"chapter card shows the story line (%s)" % Overlay.card_line.text)

	# --- Left alone, the intro reaches chapter 1 by itself ----------------------------------
	Game.play_cutscene(Game.INTRO_SCENE)
	_check(await _wait_scene(Game.INTRO_SCENE), "intro replays")
	Engine.time_scale = 10.0
	_check(await _wait_scene(Game.LEVELS[0], 20.0), "intro plays through to chapter 1 on its own")
	Engine.time_scale = 1.0

	# --- Chapter 12 done -> ending -> end screen ---------------------------------------------
	Game.level_index = Game.LEVELS.size() - 1
	Game._next_level()
	_check(await _wait_scene(Game.ENDING_SCENE), "finishing chapter 12 plays the ending")
	cs = get_tree().current_scene as Cutscene
	_check(cs != null and cs.next == Cutscene.Next.END_SCREEN, "ending hands off to the end screen")
	await _secs(0.5)
	Input.action_press(&"jump")
	var skipped := await _wait_until(func() -> bool: return cs.done, 2.5)
	Input.action_release(&"jump")
	_check(skipped, "holding Space skips the ending")
	_check(await _wait_scene(Game.END_SCENE), "ending -> end screen")
	_check(get_tree().current_scene.time_label.text != "", "end screen shows run stats")

	Game.play_cutscene(Game.ENDING_SCENE)
	_check(await _wait_scene(Game.ENDING_SCENE), "ending replays")
	Engine.time_scale = 10.0
	_check(await _wait_scene(Game.END_SCENE, 20.0), "ending plays through to the end screen on its own")
	Engine.time_scale = 1.0

	_wipe()
	Save.use_path(Save.DEFAULT_PATH)
	print("CUTSCENE TEST %s (%d failures)" % ["PASSED" if _fails == 0 else "FAILED", _fails])
	get_tree().quit(1 if _fails else 0)
