class_name ChapterTile
extends Button
## One chapter in the chapter select grid. Locked tiles are greyed with a padlock.

signal chosen(index: int)

@export var index := 0

@onready var num_label: Label = $Box/Num
@onready var title_label: Label = $Box/Title
@onready var stats_label: Label = $Box/Stats
@onready var lock: TextureRect = $Lock

var locked := false


func _ready() -> void:
	set_meta("no_click_sfx", true)
	pressed.connect(_on_pressed)
	refresh()


func refresh() -> void:
	locked = not Save.is_unlocked(index)
	theme_type_variation = &"LockedTile" if locked else &"ChapterTile"
	num_label.text = "CHAPTER %d" % (index + 1)
	if not locked and Game.chapter_view(index) != "":
		num_label.text += "  ·  " + Game.chapter_view(index).to_upper()
	title_label.text = Game.chapter_name(index)
	lock.visible = locked
	var dim := Color(0.55, 0.65, 0.75, 0.55)
	title_label.modulate = dim if locked else Color.WHITE
	num_label.modulate = dim if locked else Color.WHITE
	if locked:
		stats_label.text = "Locked"
	elif Save.is_cleared(index):
		stats_label.text = "%s   ·   %d lost" % [Save.format_time(Save.best_time(index)), Save.best_deaths(index)]
	else:
		stats_label.text = "New"
	stats_label.modulate = dim if locked else Color.WHITE
	if has_focus():
		# Re-apply the focused look for the new variation.
		add_theme_stylebox_override("normal", get_theme_stylebox("hover"))


func _on_pressed() -> void:
	if locked:
		Sfx.play("blocked", 0.0)
		var t := create_tween()
		for dx in [5.0, -5.0, 3.0, 0.0]:
			t.tween_property(lock, "position:x", _lock_x + dx, 0.04)
		return
	Sfx.play("select", 0.0)
	chosen.emit(index)


var _lock_x: float:
	get:
		return size.x - 34.0
