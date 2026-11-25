extends Control
## Final screen after chapter 12: run totals + Main menu / Chapter select.

@onready var time_label: Label = %Time
@onready var deaths_label: Label = %Deaths
@onready var best_label: Label = %Best
@onready var menu_btn: Button = %MainMenu
@onready var chapters_btn: Button = %Chapters


func _ready() -> void:
	Hud.visible = false
	get_tree().paused = false
	time_label.text = Save.format_time(Game.run_time)
	deaths_label.text = str(Game.deaths)
	best_label.text = Save.format_time(Save.best_total_time())
	menu_btn.pressed.connect(func() -> void: _leave(false))
	chapters_btn.pressed.connect(func() -> void: _leave(true))
	UiUtil.chain([menu_btn, chapters_btn], false)
	UiUtil.wire(self)
	UiUtil.focus_quiet(menu_btn)


func _leave(chapter_select: bool) -> void:
	menu_btn.disabled = true
	chapters_btn.disabled = true
	Game.go_to_menu(chapter_select)
