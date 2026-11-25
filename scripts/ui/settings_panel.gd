class_name SettingsPanel
extends Control
## Settings screen (used by the title menu and the pause menu). Edits the Settings autoload.

signal closed

@onready var master: HSlider = %Master
@onready var music: HSlider = %Music
@onready var sfx: HSlider = %Sfx
@onready var fullscreen: CheckButton = %Fullscreen
@onready var shake: CheckButton = %Shake
@onready var zoom: CycleButton = %Zoom
@onready var reset_btn: Button = %Reset
@onready var back_btn: Button = %Back

var _rows: Array[Control] = []
var _syncing := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	zoom.labels = PackedStringArray(Settings.ZOOM_CHOICES.map(func(z: float) -> String:
		return ("%.1fx" % z).replace(".0x", "x")))
	_rows = [master, music, sfx, fullscreen, shake, zoom]
	if not Settings.can_fullscreen():
		fullscreen.disabled = true
	for s in [master, music, sfx]:
		s.value_changed.connect(_on_slider.bind(s))
	fullscreen.toggled.connect(func(on: bool) -> void: if not _syncing: Settings.set_value("fullscreen", on))
	shake.toggled.connect(func(on: bool) -> void: if not _syncing: Settings.set_value("screen_shake", on))
	zoom.value_changed.connect(func(i: int) -> void: Settings.set_value("camera_zoom", Settings.ZOOM_CHOICES[i]))
	reset_btn.pressed.connect(func() -> void: Settings.reset_defaults())
	back_btn.pressed.connect(close)
	for c in _rows:
		c.focus_entered.connect(_highlight.bind(c, true))
		c.focus_exited.connect(_highlight.bind(c, false))
	UiUtil.chain([master, music, sfx, fullscreen, shake, zoom, back_btn], true)
	reset_btn.focus_neighbor_top = reset_btn.get_path_to(zoom)
	reset_btn.focus_neighbor_bottom = reset_btn.get_path_to(master)
	back_btn.focus_neighbor_left = back_btn.get_path_to(reset_btn)
	reset_btn.focus_neighbor_right = reset_btn.get_path_to(back_btn)
	UiUtil.wire(self)
	Settings.changed.connect(_sync)
	_sync()


func open() -> void:
	_sync()
	show()
	UiUtil.focus_quiet(master)


func close() -> void:
	if not visible:
		return
	hide()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		Sfx.play("select", 0.0)
		close()


func _sync() -> void:
	_syncing = true
	master.set_value_no_signal(Settings.master_volume * 100.0)
	music.set_value_no_signal(Settings.music_volume * 100.0)
	sfx.set_value_no_signal(Settings.sfx_volume * 100.0)
	for s in [master, music, sfx]:
		_pct(s).text = "%d%%" % roundi(s.value)
	fullscreen.button_pressed = Settings.fullscreen
	shake.button_pressed = Settings.screen_shake
	zoom.index = maxi(0, Settings.ZOOM_CHOICES.find(Settings.camera_zoom))
	_syncing = false


func _on_slider(v: float, s: HSlider) -> void:
	_pct(s).text = "%d%%" % roundi(v)
	var key: String = {master: "master_volume", music: "music_volume", sfx: "sfx_volume"}[s]
	Settings.set_value(key, v / 100.0)
	if s != music:
		Sfx.play("ui_move", 0.0)


func _pct(s: HSlider) -> Label:
	return s.get_parent().get_node("Pct")


## Lights up the row's label while its control has focus.
func _highlight(c: Control, on: bool) -> void:
	var label := %Grid.get_node_or_null(String(c.name) + "Label") as Label
	if label:
		label.theme_type_variation = &"AccentLabel" if on else &""
