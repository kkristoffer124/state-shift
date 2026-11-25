extends Control
## Title screen: Continue / New game / Load (chapter select) / Settings / Quit.

@onready var buttons: HBoxContainer = %Buttons
@onready var continue_btn: Button = %Continue
@onready var new_btn: Button = %NewGame
@onready var load_btn: Button = %Load
@onready var settings_btn: Button = %Settings
@onready var quit_btn: Button = %Quit
@onready var hint: Label = %Hint
@onready var main_ui: Control = $Main
@onready var chapter_select: ChapterSelect = $ChapterSelect
@onready var settings_panel: SettingsPanel = $SettingsPanel
@onready var confirm: Control = $Confirm
@onready var confirm_yes: Button = %ConfirmYes
@onready var confirm_no: Button = %ConfirmNo

var _last_focus: Control


func _ready() -> void:
	Hud.visible = false
	get_tree().paused = false
	quit_btn.visible = not OS.has_feature("web")
	chapter_select.hide()
	settings_panel.hide()
	confirm.hide()
	continue_btn.pressed.connect(_on_continue)
	new_btn.pressed.connect(_on_new_game)
	load_btn.pressed.connect(_on_load)
	settings_btn.pressed.connect(_on_settings)
	quit_btn.pressed.connect(_on_quit)
	confirm_yes.pressed.connect(_on_confirm_yes)
	confirm_no.pressed.connect(_close_confirm)
	chapter_select.chosen.connect(_on_chapter_chosen)
	chapter_select.closed.connect(_show_main)
	settings_panel.closed.connect(_show_main)
	for b in buttons.get_children():
		(b as Control).focus_entered.connect(_update_hint.bind(b))
	UiUtil.chain([confirm_yes, confirm_no], false)
	UiUtil.wire(main_ui)
	UiUtil.wire(confirm)
	_refresh()
	if Game.open_chapter_select:
		Game.open_chapter_select = false
		_on_load()
	else:
		_show_main()


func _refresh() -> void:
	continue_btn.visible = Save.has_progress()
	UiUtil.chain(buttons.get_children(), false)


func _show_main() -> void:
	_refresh()
	main_ui.show()
	var target: Control = _last_focus if _last_focus and _last_focus.visible else (continue_btn if continue_btn.visible else new_btn)
	UiUtil.focus_quiet(target)
	_update_hint(target)


func _update_hint(b: Control) -> void:
	match b:
		continue_btn:
			hint.text = Game.chapter_title(Save.continue_index())
		new_btn:
			hint.text = "Start over from Chapter 1" if Save.has_progress() else "Begin your escape"
		load_btn:
			hint.text = "Chapter select   ·   %d / %d unlocked" % [Save.unlocked_count(), Game.LEVELS.size()]
		settings_btn:
			hint.text = "Volume, display and camera"
		quit_btn:
			hint.text = "Leave the lab"


func _on_continue() -> void:
	_lock_input()
	Game.continue_game()


func _on_new_game() -> void:
	_last_focus = new_btn
	if Save.has_progress():
		main_ui.hide()
		confirm.show()
		UiUtil.focus_quiet(confirm_no)
	else:
		_lock_input()
		Game.new_game()


func _on_confirm_yes() -> void:
	confirm.hide()
	_lock_input()
	Game.new_game()


func _close_confirm() -> void:
	confirm.hide()
	_show_main()


func _on_load() -> void:
	_last_focus = load_btn
	main_ui.hide()
	chapter_select.open()


func _on_chapter_chosen(index: int) -> void:
	_lock_input()
	Game.deaths = 0
	Game.run_time = 0.0
	Game.start_chapter(index)


func _on_settings() -> void:
	_last_focus = settings_btn
	main_ui.hide()
	settings_panel.open()


func _on_quit() -> void:
	get_tree().quit()


## Stops double-presses while the scene fades out.
func _lock_input() -> void:
	for c in find_children("*", "BaseButton", true, false):
		var b := c as BaseButton
		b.add_theme_stylebox_override("disabled", b.get_theme_stylebox("normal"))
		b.disabled = true
	var owner_c := get_viewport().gui_get_focus_owner()
	if owner_c:
		owner_c.release_focus()


func _unhandled_input(event: InputEvent) -> void:
	if confirm.visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		Sfx.play("select", 0.0)
		_close_confirm()
