class_name CycleButton
extends Button
## Button that cycles through `labels` with left/right (or click / accept = next).

signal value_changed(index: int)

@export var labels: PackedStringArray = []
@export var index := 0:
	set(v):
		index = v
		_refresh()


func _ready() -> void:
	theme_type_variation = &"CycleButton"
	set_meta("no_click_sfx", true)
	pressed.connect(func() -> void: step(1))
	_refresh()


func _gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left", true):
		step(-1)
		accept_event()
	elif event.is_action_pressed("ui_right", true):
		step(1)
		accept_event()


func step(dir: int) -> void:
	if labels.is_empty():
		return
	index = wrapi(index + dir, 0, labels.size())
	Sfx.play("ui_move", 0.04)
	value_changed.emit(index)


func _refresh() -> void:
	if labels.is_empty():
		return
	text = "<   %s   >" % labels[clampi(index, 0, labels.size() - 1)]
