extends Node
## Player options, persisted in the Save file's [settings] section. Autoload "Settings".
## Read `camera_zoom` / `screen_shake` directly; listen to `changed` to react to edits.

signal changed

const ZOOM_CHOICES: Array[float] = [1.5, 2.0, 3.0]
const KEYS := ["master_volume", "music_volume", "sfx_volume", "fullscreen", "screen_shake", "camera_zoom"]

## Linear 0..1 bus volumes.
var master_volume := 1.0
var music_volume := 0.8
var sfx_volume := 0.8
var fullscreen := false
var screen_shake := true
var camera_zoom := 2.0

var _defaults := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for k in KEYS:
		_defaults[k] = get(k)
	load_settings()
	_apply_window(true)


## Re-reads all settings from Save (call after Save.use_path()).
func load_settings() -> void:
	for k in KEYS:
		var v: Variant = Save.get_setting(k, _defaults[k])
		match typeof(_defaults[k]):
			TYPE_BOOL: set(k, bool(v))
			TYPE_FLOAT: set(k, float(v))
	master_volume = clampf(master_volume, 0.0, 1.0)
	music_volume = clampf(music_volume, 0.0, 1.0)
	sfx_volume = clampf(sfx_volume, 0.0, 1.0)
	if not camera_zoom in ZOOM_CHOICES:
		camera_zoom = 2.0
	_apply_audio()
	changed.emit()


## Changes one setting, applies it, saves and emits `changed`.
func set_value(key: String, value: Variant) -> void:
	if not key in KEYS:
		push_error("Settings: unknown key %s" % key)
		return
	if get(key) == value:
		return
	set(key, value)
	Save.set_setting(key, value)
	_apply_audio()
	if key == "fullscreen":
		_apply_window(false)
	changed.emit()


func reset_defaults() -> void:
	for k in KEYS:
		set(k, _defaults[k])
		Save.set_setting(k, _defaults[k], false)
	Save.flush()
	_apply_audio()
	_apply_window(false)
	changed.emit()


## Fullscreen works on desktop and on web (from a click/key press = user gesture).
func can_fullscreen() -> bool:
	return DisplayServer.get_name() != "headless"


func _apply_audio() -> void:
	_set_bus("Master", master_volume)
	_set_bus("Music", music_volume)
	_set_bus("SFX", sfx_volume)


func _set_bus(bus: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))


func _apply_window(at_startup: bool) -> void:
	if not can_fullscreen() or "--bg-test" in OS.get_cmdline_user_args():
		return
	# Browsers only allow fullscreen from a user gesture, so don't force it on load.
	if at_startup and OS.has_feature("web"):
		return
	var mode := DisplayServer.window_get_mode()
	var is_full := mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if fullscreen and not is_full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif not fullscreen and is_full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
