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
	_animate_in()


## The results panel condenses out of steam, the title drips in, then the stat rows
## and buttons rise one by one.
func _animate_in() -> void:
	UiFx.panel_in($Panel)
	UiFx.drip_text($Panel/VBox/Title, 0.2, 0.05)
	var rows: Array = [$Panel/VBox/Sub]
	rows.append_array($Panel/VBox/Stats.get_children())
	UiFx.stagger_in(rows, 0.06, 6.0, 0.55)
	UiFx.stagger_in([menu_btn, chapters_btn], 0.08, 12.0, 1.1)


func _leave(chapter_select: bool) -> void:
	menu_btn.disabled = true
	chapters_btn.disabled = true
	Game.go_to_menu(chapter_select)
