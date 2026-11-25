extends Control
## Title screen (also used by the end screen with `is_end_screen`).

@export var is_end_screen := false

@onready var stats: Label = get_node_or_null("Center/Stats")


func _ready() -> void:
	Hud.visible = false
	if is_end_screen and stats:
		var t := int(Game.run_time)
		stats.text = "Time  %d:%02d      Puddles lost  %d" % [t / 60, t % 60, Game.deaths]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("jump") or event.is_action_pressed("ui_accept"):
		Sfx.play("select", 0.0)
		Game.start_game()
	elif is_end_screen and event.is_action_pressed("ui_cancel"):
		Game.go_to_menu()
