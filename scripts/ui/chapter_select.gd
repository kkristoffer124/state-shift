class_name ChapterSelect
extends Control
## "Load" screen: grid of the 12 chapters with best time / fewest puddles lost.

signal chosen(index: int)
signal closed

@onready var grid: GridContainer = %Grid
@onready var progress_label: Label = %Progress
@onready var back_btn: Button = %Back

var tiles: Array[ChapterTile] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for c in grid.get_children():
		if c is ChapterTile:
			tiles.append(c)
			c.chosen.connect(func(i: int) -> void: chosen.emit(i))
	back_btn.pressed.connect(close)
	# Bottom row -> Back, Back -> up into the grid.
	var cols := grid.columns
	for i in tiles.size():
		if i >= tiles.size() - cols:
			tiles[i].focus_neighbor_bottom = tiles[i].get_path_to(back_btn)
		if i < cols:
			tiles[i].focus_neighbor_top = tiles[i].get_path_to(back_btn)
	back_btn.focus_neighbor_bottom = back_btn.get_path_to(tiles[0])
	UiUtil.wire(self)
	Save.progress_changed.connect(refresh)
	refresh()


func refresh() -> void:
	for t in tiles:
		t.refresh()
	var best := Save.best_total_time()
	progress_label.text = "%d / %d unlocked   ·   %d cleared%s" % [
		Save.unlocked_count(), tiles.size(), Save.cleared_count(),
		("   ·   best total %s" % Save.format_time(best)) if Save.cleared_count() == tiles.size() else ""]


func open() -> void:
	refresh()
	show()
	var focus_i := clampi(Save.continue_index(), 0, tiles.size() - 1)
	back_btn.focus_neighbor_top = back_btn.get_path_to(tiles[mini(tiles.size() - 1, tiles.size() - grid.columns + focus_i % grid.columns)])
	UiUtil.focus_quiet(tiles[focus_i])


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
