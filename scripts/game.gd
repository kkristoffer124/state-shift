extends Node
## Global flow: chapters (one per level), deaths, timers, restarts, pause. Autoload "Game".

signal state_changed(state: int)
signal level_changed(level_name: String, index: int, total: int)
signal deaths_changed(deaths: int)

const LEVELS: Array[String] = [
	"res://levels/level_01.tscn",
	"res://levels/level_02.tscn",
	"res://levels/level_03.tscn",
	"res://levels/level_04.tscn",
	"res://levels/level_05.tscn",
	"res://levels/level_06.tscn",
	"res://levels/level_07.tscn",
	"res://levels/level_08.tscn",
	"res://levels/level_09.tscn",
	"res://levels/level_10.tscn",
	"res://levels/level_11.tscn",
	"res://levels/level_12.tscn",
]
## Chapter names for menus (so the chapter select needn't load every level).
## The level's own `level_name` ("6 - Crosswind") wins in-game; tests check they match.
const CHAPTER_NAMES: Array[String] = [
	"Drip", "Freeze", "Rise", "Shatter", "Pressure", "Crosswind",
	"Sieve", "Chain Reaction", "Thermals", "Momentum", "Flue", "Meltdown",
]
const END_SCENE := "res://scenes/end.tscn"
const MENU_SCENE := "res://scenes/menu.tscn"

var level_index := 0
## Totals for the current play session (shown on the end screen).
var deaths := 0
var run_time := 0.0
## Current chapter attempt (saved as best time / best deaths on completion).
var chapter_time := 0.0
var chapter_deaths := 0
var in_level := false
## Smoke tests set this so deaths/wins don't change scenes.
var testing := false
## The title menu opens straight onto the chapter select once (end screen -> "Chapter select").
var open_chapter_select := false
var _transitioning := false
var _show_card := false
## Bumped on every scene change so stale awaits (death/complete timers) can bail out.
var _session := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if "--bg-test" in OS.get_cmdline_user_args():
		AudioServer.set_bus_mute(0, true)


func _process(delta: float) -> void:
	if in_level and not _transitioning and not get_tree().paused:
		run_time += delta
		chapter_time += delta


# --- Chapter names ---------------------------------------------------------------

func chapter_name(index: int) -> String:
	return CHAPTER_NAMES[index] if index >= 0 and index < CHAPTER_NAMES.size() else "Chapter %d" % (index + 1)


## "Chapter 6 — Crosswind"
func chapter_title(index: int) -> String:
	return "Chapter %d — %s" % [index + 1, chapter_name(index)]


## "6 - Crosswind" -> "Crosswind"
static func title_from_level_name(level_name: String) -> String:
	var parts := level_name.split(" - ", true, 1)
	return parts[1].strip_edges() if parts.size() == 2 else level_name


# --- Starting -------------------------------------------------------------------

## New game: wipes progress (settings stay) and starts chapter 1.
func new_game() -> void:
	Save.reset_progress()
	Save.mark_started()
	deaths = 0
	run_time = 0.0
	start_chapter(0)


## Kept for older callers.
func start_game() -> void:
	new_game()


## Resumes the furthest unlocked chapter.
func continue_game() -> void:
	deaths = 0
	run_time = 0.0
	start_chapter(Save.continue_index())


## Starts chapter `index` from scratch with a title card.
func start_chapter(index: int) -> void:
	level_index = clampi(index, 0, LEVELS.size() - 1)
	chapter_time = 0.0
	chapter_deaths = 0
	_show_card = true
	Save.mark_started()
	_change_scene(LEVELS[level_index], true)


func restart_chapter() -> void:
	chapter_time = 0.0
	chapter_deaths = 0
	_load_level()


func _load_level() -> void:
	_change_scene(LEVELS[level_index], false)


func _change_scene(path: String, with_fade: bool) -> void:
	_session += 1
	var session := _session
	_transitioning = true
	get_tree().paused = false
	if with_fade and not testing:
		Overlay.hide_cards()
		await Overlay.fade_out(0.2)
		if session != _session:
			return
	get_tree().change_scene_to_file(path)
	if with_fade and not testing:
		await get_tree().scene_changed
		# Let the (possibly slow) first frame of the new scene render under the fade.
		await get_tree().process_frame
		await get_tree().process_frame
		if session == _session:
			Overlay.fade_in(0.35)
	if session == _session:
		_transitioning = false


func on_level_ready(level: Node, player: Node) -> void:
	if testing:
		return
	_transitioning = false
	in_level = true
	var idx := LEVELS.find(level.scene_file_path)
	if idx != -1:
		level_index = idx
	Hud.visible = true
	player.state_changed.connect(func(s: int) -> void: state_changed.emit(s))
	state_changed.emit(player.state)
	level_changed.emit(level.level_name, level_index, LEVELS.size())
	deaths_changed.emit(chapter_deaths)
	if _show_card:
		_show_card = false
		Overlay.show_chapter_card(level_index, title_from_level_name(level.level_name))


# --- Called by the player ----------------------------------------------------------

func player_died() -> void:
	if testing or _transitioning:
		return
	deaths += 1
	chapter_deaths += 1
	deaths_changed.emit(chapter_deaths)
	_transitioning = true
	var session := _session
	await get_tree().create_timer(0.7, false).timeout
	if session == _session:
		_load_level()


func level_complete() -> void:
	if testing or _transitioning:
		return
	_transitioning = true
	var session := _session
	var index := level_index
	var record := Save.record_chapter(index, chapter_time, chapter_deaths)
	await get_tree().create_timer(0.6, false).timeout
	if session != _session:
		return
	await Overlay.show_complete_card(index, chapter_name(index), chapter_time, chapter_deaths, record)
	if session != _session:
		return
	_next_level()


func _next_level() -> void:
	if level_index + 1 >= LEVELS.size():
		in_level = false
		Hud.visible = false
		_change_scene(END_SCENE, true)
	else:
		start_chapter(level_index + 1)


func go_to_menu(chapter_select := false) -> void:
	in_level = false
	open_chapter_select = chapter_select
	Hud.visible = false
	Overlay.close_pause()
	_change_scene(MENU_SCENE, true)


func _unhandled_input(event: InputEvent) -> void:
	if not in_level or _transitioning or testing or get_tree().paused:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		Overlay.open_pause()
	elif event.is_action_pressed("restart"):
		_load_level()
	elif OS.is_debug_build() and event.is_action_pressed("skip_level"):
		_transitioning = true
		_next_level()
