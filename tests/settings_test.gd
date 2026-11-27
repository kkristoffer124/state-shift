extends Node
## Headless settings test (throwaway save, the real one is untouched):
##   godot --headless --path . res://tests/settings_test.tscn
## Every setting: set to a non-default value, apply hook runs, value saved, persists across
## a reload, back to default. Plus: old save files load, reset category / all, the panel
## has a row per visible setting, key rebinding reaches the InputMap, node hooks act on
## real 2D / top-down / 3D levels.

const TEST_SAVE := "user://settings_test_save.cfg"

var _fails := 0


func _ready() -> void:
	Game.testing = true
	_run.call_deferred()


func _check(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + msg)
	if not cond:
		_fails += 1


func _wipe() -> void:
	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## A value different from the default, valid for the setting's type.
func _other_value(key: String, i: int) -> Variant:
	var m := Settings.meta(key)
	var d: Variant = Settings.default_of(key)
	match m.type:
		"bool":
			return not d
		"range":
			return m.min if absf(float(d) - m.min) > 0.001 else m.max
		"choice":
			var vals: Array = m.values
			var idx := (Settings.choice_index(key, d) + 1) % vals.size()
			return float(vals[idx]) if typeof(d) == TYPE_FLOAT else int(vals[idx])
		"key":
			return KEY_F1 + i
	return d


func _run() -> void:
	_wipe()
	Save.use_path(TEST_SAVE)
	Settings.load_settings()
	await _frames(2)

	# --- Metadata -----------------------------------------------------------------
	var legacy := ["master_volume", "music_volume", "sfx_volume", "fullscreen", "screen_shake", "camera_zoom"]
	var new_count := 0
	for k in Settings.KEYS:
		if not k in legacy:
			new_count += 1
		var m := Settings.meta(k)
		_check(m.category in Settings.CATEGORIES and m.label != "" and (m.description != "" or m.get("hidden", false)),
			"metadata complete for %s" % k)
		_check(Settings.get(k) == Settings.default_of(k), "%s starts at its default" % k)
	print("  %d settings, %d new" % [Settings.KEYS.size(), new_count])
	_check(new_count >= 50, "at least 50 new settings (%d)" % new_count)

	# --- Every key: non-default, apply, save, reload, back ---------------------------
	var values := {}
	var i := 0
	for k in Settings.KEYS:
		var v: Variant = _other_value(k, i)
		i += 1
		values[k] = v
		Settings.set_value(k, v)
		_check(Settings.get(k) == v, "%s set to %s" % [k, Settings.format_value(k)])
		SettingsFx.apply(k)
		_check(Save.get_setting(k, null) == v, "%s written to the save" % k)
	await _frames(3)
	Save.load_file()
	Settings.load_settings()
	var all_kept := true
	for k in Settings.KEYS:
		if Settings.get(k) != values[k]:
			all_kept = false
			_check(false, "%s persisted (%s vs %s)" % [k, Settings.get(k), values[k]])
	_check(all_kept, "all %d settings persist across a reload" % Settings.KEYS.size())

	# --- Spot checks of the effects (everything non-default right now) ----------------
	_check(SettingsFx.post_active(), "post-process pass enabled")
	_check(Engine.max_fps == Settings.max_fps, "frame cap applied (%d)" % Engine.max_fps)
	_check(get_tree().root.content_scale_mode == Window.CONTENT_SCALE_MODE_VIEWPORT, "pixel-exact rendering applied")
	_check(get_tree().root.content_scale_stretch == Window.CONTENT_SCALE_STRETCH_INTEGER, "integer scaling applied")
	_check(is_equal_approx(get_tree().root.scaling_3d_scale, Settings.render_scale_3d), "3D render scale applied")
	var ui_db := AudioServer.get_bus_volume_db(AudioServer.get_bus_index("UI"))
	_check(AudioServer.get_bus_index("UI") != -1 and absf(ui_db - linear_to_db(maxf(Settings.ui_volume, 0.0001))) < 0.1, "UI bus volume applied")
	_check(Sfx.bus_for("jump") == &"Movement" and Sfx.bus_for("heat") == &"Shift", "sounds routed to their buses")
	var jump_keys := InputMap.action_get_events("jump").filter(func(e: InputEvent) -> bool: return e is InputEventKey)
	_check(not jump_keys.is_empty() and (jump_keys[0] as InputEventKey).physical_keycode == Settings.bind_jump, "jump rebind reached the InputMap")
	var j3 := InputMap.action_get_events("jump_3d").filter(func(e: InputEvent) -> bool: return e is InputEventKey)
	_check(not j3.is_empty() and (j3[0] as InputEventKey).physical_keycode == Settings.bind_jump, "jump rebind also moves jump_3d")
	_check(is_equal_approx(InputMap.action_get_deadzone("move_left"), Settings.gamepad_deadzone), "stick deadzone applied")
	_check(InputMap.action_get_events("heat").any(func(e: InputEvent) -> bool: return e is InputEventJoypadButton), "gamepad bindings added")
	var theme := load("res://scenes/ui/theme.tres") as Theme
	_check(theme.default_font_size == roundi(18 * Settings.text_size), "text size scales the theme (%d)" % theme.default_font_size)
	_check(not Hud.get_node("StateBar").visible, "state bar hidden")
	_check(is_equal_approx(Hud.get_node("StateBar").self_modulate.a, Settings.hud_opacity), "HUD opacity applied")
	_check(Settings.shake_scale() == 0.0, "reduce motion / shake off -> no shake")
	_check(SettingsFx.cursor_texture(2).get_width() == 48, "large cursor image built")
	_check(SettingsFx.format_time(83.456) == ("1:23.45" if Settings.timer_precision == 2 else "1:23.4"), "timer format follows precision")

	# --- Node hooks on real levels ---------------------------------------------------
	Settings.set_value("particle_density", 0.33)
	Settings.set_value("room_zoom", 2.0)
	Settings.set_value("camera_smoothing", 3.5)
	Settings.set_value("ice_grip", 2.0)
	for path in ["res://levels/level_01.tscn", "res://levels/level_02_topdown.tscn", "res://levels/level_03_3d.tscn", "res://levels/level_05_3d.tscn"]:
		var level: Node = load(path).instantiate()
		add_child(level)
		await _frames(4)
		var hints := level.get_node_or_null("Hints")
		_check(hints != null and not hints.visible, "%s: hints hidden" % path.get_file())
		var p := level.get_node("Player")
		if p is Player:
			_check(is_equal_approx(p.camera.zoom.x, p.zoom_override * 2.0), "2D room zoom applied (%.2f)" % p.camera.zoom.x)
			_check(p.camera.position_smoothing_enabled and is_equal_approx(p.camera.position_smoothing_speed, 3.5), "2D camera smoothing applied")
			_check(is_equal_approx(p.ice_friction, float(p.get_meta("_ss_ice_friction")) * 2.0), "ice grip scales friction")
			var parts := p.find_children("*", "CPUParticles2D", true, false)
			_check(not parts.is_empty() and parts.all(func(c: CPUParticles2D) -> bool: return c.has_meta("_ss_amount") and c.amount == maxi(1, roundi(int(c.get_meta("_ss_amount")) * 0.33))), "particle density scales emitters")
			var bg := level.get_node_or_null("Background")
			if bg:
				_check(bg.fps == 0.0 and not bg.bubbles.visible, "backdrop animation / bubbles off")
				_check(is_equal_approx(bg.get_child(0).modulate.r, 1.0 - Settings.background_dim), "background dimmed")
		elif p is TdPlayer:
			_check(is_equal_approx(p.camera.zoom.x, 2.0), "top-down room zoom applied")
		elif p is Player3D:
			var rig := level.get_node("CameraRig") as CameraRig3D
			var key := level.get_node_or_null("KeyLight") as DirectionalLight3D
			if key:
				_check(not key.shadow_enabled, "3D shadows off")
			var we := level.get_node_or_null("WorldEnvironment") as WorldEnvironment
			if we and we.environment:
				_check(not we.environment.fog_enabled and we.environment.glow_enabled, "3D fog off / glow on")
			match rig.mode:
				CameraRig3D.Mode.THIRD_PERSON:
					_check(is_equal_approx(rig.camera.fov, Settings.tp_fov), "third-person FOV applied (%.0f)" % rig.camera.fov)
					_check(is_equal_approx(rig.distance, float(rig.get_meta("_ss_distance")) * Settings.tp_distance / 4.6), "third-person distance applied (%.1f)" % rig.distance)
				CameraRig3D.Mode.ISOMETRIC:
					_check(is_equal_approx(rig.camera.size, float(rig.get_meta("_ss_iso_size")) / Settings.iso_zoom), "isometric zoom applied (%.1f)" % rig.camera.size)
			_check(is_equal_approx(p.ice_friction, float(p.get_meta("_ss_ice_friction")) * 2.0), "3D ice grip scales friction")
		level.queue_free()
		await _frames(2)

	# --- Older save files ----------------------------------------------------------------
	var old := ConfigFile.new()
	old.set_value("settings", "master_volume", 0.4)
	old.set_value("settings", "camera_zoom", 3.0)
	old.set_value("settings", "screen_shake", false)
	old.set_value("settings", "brightness", "bogus")
	old.set_value("settings", "max_fps", 77)
	old.set_value("settings", "gamma", 99.0)
	old.save(TEST_SAVE)
	Save.load_file()
	Settings.load_settings()
	_check(is_equal_approx(Settings.master_volume, 0.4) and Settings.camera_zoom == 3.0 and not Settings.screen_shake, "old save values load")
	_check(Settings.brightness == 1.0 and Settings.max_fps == 0 and Settings.reduce_motion == false, "missing / invalid entries fall back to defaults")
	_check(is_equal_approx(Settings.gamma, 1.6), "out-of-range values are clamped")

	# --- Reset category / all -------------------------------------------------------------
	Settings.set_value("brightness", 1.3)
	Settings.set_value("show_fps", true)
	Settings.reset_category("video")
	_check(Settings.brightness == 1.0 and Settings.show_fps, "reset category only resets that tab")
	Settings.reset_defaults()
	var all_default := true
	for k in Settings.KEYS:
		if Settings.get(k) != Settings.default_of(k):
			all_default = false
			print("  not default: ", k)
	_check(all_default, "reset all restores every default")
	_check(not SettingsFx.post_active(), "post-process pass off at defaults")
	_check(theme.default_font_size == 18, "theme text size restored")
	Save.load_file()
	Settings.load_settings()
	_check(Settings.master_volume == 1.0, "defaults saved")

	# --- Panel ---------------------------------------------------------------------------------
	var panel: SettingsPanel = load("res://scenes/ui/settings_panel.tscn").instantiate()
	add_child(panel)
	panel.open()
	await _frames(2)
	var visible_keys := 0
	for k in Settings.KEYS:
		if Settings.is_row_visible(k):
			visible_keys += 1
			_check(panel.controls.has(k), "panel row for %s" % k)
	_check(panel.controls.size() == visible_keys, "one row per visible setting (%d)" % visible_keys)
	for c in Settings.CATEGORIES:
		panel.show_category(c)
		_check(panel.current_category() == c, "tab %s opens" % c)
	panel.show_category("audio")
	panel.cycle_category(1)
	_check(panel.current_category() == "video", "next-tab shortcut")
	panel.cycle_category(-2)
	_check(panel.current_category() == "interface", "previous-tab wraps around")
	(panel.controls["bind_heat"] as Button).pressed.emit()
	_check(panel.is_capturing(), "key row waits for a key")
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_J
	ev.pressed = true
	panel._input(ev)
	_check(Settings.bind_heat == KEY_J and not panel.is_capturing(), "pressing a key rebinds")
	_check(InputMap.action_get_events("heat").any(func(e: InputEvent) -> bool: return e is InputEventKey and e.physical_keycode == KEY_J), "rebound key in the InputMap")
	(panel.controls["bind_heat"] as Button).pressed.emit()
	ev.physical_keycode = KEY_BACKSPACE
	panel._input(ev)
	_check(Settings.bind_heat == 0, "backspace restores the default key")
	(panel.controls["brightness"] as HSlider).value = 120.0
	_check(is_equal_approx(Settings.brightness, 1.2), "panel slider edits Settings")
	(panel.controls["colorblind_mode"] as CycleButton).step(1)
	_check(Settings.colorblind_mode == 1, "panel cycle button edits Settings")
	(panel.controls["show_fps"] as CheckButton).button_pressed = true
	_check(Settings.show_fps, "panel toggle edits Settings")
	panel.reset_btn.pressed.emit()
	_check(Settings.brightness == 1.0 and not Settings.show_fps and Settings.colorblind_mode == 0, "panel Reset all")
	panel.close()
	panel.queue_free()

	_wipe()
	Save.use_path(Save.DEFAULT_PATH)
	Settings.load_settings()
	Game.testing = false
	print("SETTINGS TEST %s (%d failures)" % ["PASSED" if _fails == 0 else "FAILED", _fails])
	get_tree().quit(1 if _fails else 0)
