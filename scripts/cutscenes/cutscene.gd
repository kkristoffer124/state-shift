class_name Cutscene
extends Node
## Plays the CutscenePanel children of `Panels` in order, then hands off to the game.
##
## Controls: tap any key / click = finish the caption, tap again = next panel.
## Hold SPACE / ESC (or tap ESC twice) = skip the whole cutscene.
##
## Edit a panel: select it in the scene tree (toggle its visibility), open the
## Animation tab and edit its `main` animation. Method tracks call say / narrate /
## clear / sfx / shake / flash on the panel.

signal finished

enum Next {
	FIRST_CHAPTER,  ## New game: start chapter 1.
	END_SCREEN,  ## After chapter 12: the end screen with run stats.
	NOTHING,  ## Stay here (previews).
}

@export var next := Next.FIRST_CHAPTER
## Fade time between panels (out + in).
@export var panel_fade := 0.35
## Seconds SPACE / ESC must be held to skip.
@export var hold_to_skip := 0.75

@onready var ui: CutsceneUI = $UI
@onready var panels_root: Node = $Panels

var panels: Array[CutscenePanel] = []
var index := -1
var done := false

var _switching := false
var _pending_next := false
var _hold := 0.0
var _esc_armed := 0.0
var _tap_down := false


func _ready() -> void:
	var hud := get_node_or_null("/root/Hud")
	if hud:
		hud.visible = false
	for c in panels_root.get_children():
		if c is CutscenePanel:
			var p := c as CutscenePanel
			p.cutscene = self
			p.hide()
			p.finished.connect(_on_panel_finished.bind(p))
			panels.append(p)
	ui.fade_rect.color.a = 1.0
	ui.show_hint("hold SPACE to skip", 4.0)
	_go(0)


## Next caption / next panel (tap).
func advance() -> void:
	if done or _switching:
		return
	if ui.finish_typing():
		return
	_next()


## Skips straight to the hand-off.
func skip() -> void:
	_finish()


func _next() -> void:
	_pending_next = false
	if index + 1 < panels.size():
		_go(index + 1)
	else:
		_finish()


func _go(i: int) -> void:
	_switching = true
	_pending_next = false
	if index >= 0:
		await ui.fade_to(1.0, panel_fade * 0.5)
		if done:
			return
		panels[index].end()
	ui.clear()
	ui.set_box_top(panels[i].caption_top)
	index = i
	panels[i].begin()
	_switching = false
	await ui.fade_to(0.0, panel_fade * 0.5)


func _on_panel_finished(p: CutscenePanel) -> void:
	if done or index < 0 or panels[index] != p:
		return
	_pending_next = true


func _finish() -> void:
	if done:
		return
	done = true
	ui.set_hold(0.0)
	finished.emit()
	match next:
		Next.FIRST_CHAPTER:
			Game.start_chapter(0)
		Next.END_SCREEN:
			Game.show_end_screen()
		_:
			pass


func _process(delta: float) -> void:
	if done:
		return
	# Wait for the last caption to finish typing (+ a beat) before moving on.
	if _pending_next and not _switching and not ui.is_typing():
		_next()
	if _esc_armed > 0.0:
		_esc_armed -= delta
	var held := Input.is_action_pressed(&"ui_cancel") or Input.is_action_pressed(&"jump") \
		or Input.is_action_pressed(&"ui_accept")
	_hold = _hold + delta if held else 0.0
	var ratio := clampf((_hold - 0.18) / hold_to_skip, 0.0, 1.0)
	ui.set_hold(ratio)
	if ratio >= 1.0:
		skip()


func _unhandled_input(event: InputEvent) -> void:
	if done or event.is_echo():
		return
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		if _esc_armed > 0.0:
			skip()
		else:
			_esc_armed = 2.5
			ui.show_hint("ESC again to skip", 2.5)
		return
	var tap_action := event.is_action(&"jump") or event.is_action(&"ui_accept")
	if tap_action:
		get_viewport().set_input_as_handled()
		if event.is_pressed():
			_tap_down = true
		elif _tap_down:
			_tap_down = false
			if _hold < 0.3:
				advance()
		return
	var pressed := (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton) \
		and event.is_pressed()
	if pressed:
		get_viewport().set_input_as_handled()
		advance()
