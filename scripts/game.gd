extends Node
## Global flow: level order, deaths, timer, restarts. Autoload "Game".

signal state_changed(state: int)
signal level_changed(level_name: String, index: int, total: int)
signal deaths_changed(deaths: int)

const LEVELS: Array[String] = [
	"res://levels/level_01.tscn",
	"res://levels/level_02.tscn",
	"res://levels/level_03.tscn",
	"res://levels/level_04.tscn",
	"res://levels/level_05.tscn",
]
const END_SCENE := "res://scenes/end.tscn"
const MENU_SCENE := "res://scenes/menu.tscn"

var level_index := 0
var deaths := 0
var run_time := 0.0
var in_level := false
## Smoke tests set this so deaths/wins don't change scenes.
var testing := false
var _transitioning := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if "--bg-test" in OS.get_cmdline_user_args():
		AudioServer.set_bus_mute(0, true)


func _process(delta: float) -> void:
	if in_level and not _transitioning:
		run_time += delta


func start_game() -> void:
	level_index = 0
	deaths = 0
	run_time = 0.0
	_load_level()


func _load_level() -> void:
	_transitioning = false
	get_tree().change_scene_to_file(LEVELS[level_index])


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
	deaths_changed.emit(deaths)


func player_died() -> void:
	if testing or _transitioning:
		return
	deaths += 1
	deaths_changed.emit(deaths)
	_transitioning = true
	await get_tree().create_timer(0.7).timeout
	_load_level()


func level_complete() -> void:
	if testing or _transitioning:
		return
	_transitioning = true
	await get_tree().create_timer(0.9).timeout
	_next_level()


func _next_level() -> void:
	level_index += 1
	if level_index >= LEVELS.size():
		in_level = false
		_transitioning = false
		Hud.visible = false
		get_tree().change_scene_to_file(END_SCENE)
	else:
		_load_level()


func go_to_menu() -> void:
	in_level = false
	_transitioning = false
	Hud.visible = false
	get_tree().change_scene_to_file(MENU_SCENE)


func _unhandled_input(event: InputEvent) -> void:
	if not in_level or _transitioning or testing:
		return
	if event.is_action_pressed("restart"):
		_load_level()
	elif event.is_action_pressed("ui_cancel"):
		go_to_menu()
	elif OS.is_debug_build() and event.is_action_pressed("skip_level"):
		_next_level()
