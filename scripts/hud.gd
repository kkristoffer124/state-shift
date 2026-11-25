extends CanvasLayer
## In-level overlay. Autoload "Hud" (scenes/hud.tscn).

const COLORS := [Color(0.72, 0.9, 1.0), Color(0.35, 0.65, 1.0), Color(0.95, 0.97, 1.0)]

@onready var level_label: Label = $LevelLabel
@onready var deaths_label: Label = $DeathsLabel
@onready var state_labels: Array[Label] = [$StateBar/Ice, $StateBar/Water, $StateBar/Steam]


func _ready() -> void:
	visible = false
	Game.state_changed.connect(_on_state_changed)
	Game.level_changed.connect(_on_level_changed)
	Game.deaths_changed.connect(func(d: int) -> void: deaths_label.text = "Puddles lost: %d" % d)


func _on_level_changed(level_name: String, index: int, total: int) -> void:
	level_label.text = "%s   (%d/%d)" % [level_name, index + 1, total]


func _on_state_changed(s: int) -> void:
	for i in state_labels.size():
		var l := state_labels[i]
		l.pivot_offset = l.size / 2.0
		if i == s:
			l.modulate = COLORS[i]
			l.scale = Vector2(1.25, 1.25)
			create_tween().tween_property(l, "scale", Vector2.ONE, 0.2)
		else:
			l.modulate = Color(1, 1, 1, 0.25)
			l.scale = Vector2.ONE
