extends CanvasLayer
## Always-on-top UI: chapter title cards, chapter-complete cards, pause menu and
## screen fades. Autoload "Overlay" (scenes/ui/overlay.tscn).

signal card_finished

const CARD_IN := 0.45
const CARD_HOLD := 1.2
const CARD_OUT := 0.5
const COMPLETE_HOLD := 2.6

@onready var chapter_card: Control = $ChapterCard
@onready var card_num: Label = $ChapterCard/Box/Num
@onready var card_title: Label = $ChapterCard/Box/Title
@onready var card_line: Label = $ChapterCard/Box/Line
@onready var complete_card: Control = $CompleteCard
@onready var done_title: Label = $CompleteCard/Box/Title
@onready var done_stats: Label = $CompleteCard/Box/Stats
@onready var done_best: Label = $CompleteCard/Box/Best
@onready var done_hint: Label = $CompleteCard/Box/Hint
@onready var pause_menu: Control = $PauseMenu
@onready var pause_chapter: Label = %PauseChapter
@onready var resume_btn: Button = %Resume
@onready var restart_btn: Button = %Restart
@onready var settings_btn: Button = %Settings
@onready var menu_btn: Button = %MainMenu
@onready var pause_buttons: Control = $PauseMenu/Center/Panel
@onready var settings_panel: SettingsPanel = $PauseMenu/SettingsPanel
@onready var fade: ColorRect = $Fade

var _card_tween: Tween
var _complete_waiting := false
var _complete_t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Menu blips, synthesized with the Sfx autoload's generator.
	if not Sfx.overrides.has("ui_move"):
		Sfx.overrides["ui_move"] = Sfx._sweep([[880.0, 1040.0, 0.035]], "sine", 0.16)
	chapter_card.hide()
	complete_card.hide()
	pause_menu.hide()
	settings_panel.hide()
	fade.color.a = 0.0
	fade.hide()
	resume_btn.pressed.connect(close_pause)
	restart_btn.pressed.connect(func() -> void:
		close_pause()
		Game.restart_chapter())
	settings_btn.pressed.connect(func() -> void:
		pause_buttons.hide()
		settings_panel.open())
	menu_btn.pressed.connect(func() -> void:
		close_pause()
		Game.go_to_menu())
	settings_panel.closed.connect(func() -> void:
		pause_buttons.show()
		UiUtil.focus_quiet(settings_btn))
	UiUtil.chain([resume_btn, restart_btn, settings_btn, menu_btn], true)
	UiUtil.wire(pause_menu)
	get_tree().scene_changed.connect(_on_scene_changed)


func _on_scene_changed() -> void:
	var scene := get_tree().current_scene
	if scene == null or not scene.scene_file_path in Game.LEVELS:
		hide_cards()
		close_pause()


# --- Chapter title card -------------------------------------------------------

## Fades in "CHAPTER n / Title" over the level; never blocks input. Any jump/accept skips it.
func show_chapter_card(index: int, title: String, delay := 0.35) -> void:
	card_num.text = "CHAPTER %d" % (index + 1)
	card_title.text = title
	# One line of story under the title (Game.CHAPTER_LINES); stays a little longer.
	card_line.text = Game.chapter_line(index)
	card_line.visible = not card_line.text.is_empty()
	var hold := CARD_HOLD + (1.2 if card_line.visible else 0.0)
	if _card_tween:
		_card_tween.kill()
	chapter_card.show()
	chapter_card.modulate.a = 0.0
	var box: Control = chapter_card.get_node("Box")
	var base_y := chapter_card.size.y * box.anchor_top + box.offset_top
	box.position.y = base_y + 8.0
	_card_tween = create_tween().set_parallel()
	_card_tween.tween_property(chapter_card, "modulate:a", 1.0, CARD_IN).set_delay(delay)
	_card_tween.tween_property(box, "position:y", base_y, CARD_IN).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_card_tween.chain().tween_interval(hold)
	_card_tween.chain().tween_property(chapter_card, "modulate:a", 0.0, CARD_OUT)
	_card_tween.chain().tween_callback(chapter_card.hide)


func skip_chapter_card() -> void:
	if not chapter_card.visible or chapter_card.modulate.a <= 0.0:
		return
	if _card_tween:
		_card_tween.kill()
	_card_tween = create_tween()
	_card_tween.tween_property(chapter_card, "modulate:a", 0.0, 0.2)
	_card_tween.tween_callback(chapter_card.hide)


func hide_cards() -> void:
	if _card_tween:
		_card_tween.kill()
	chapter_card.hide()
	complete_card.hide()
	_complete_waiting = false


# --- Chapter complete card ----------------------------------------------------

## Shows the results; returns (await) after a few seconds or when the player presses jump/accept.
func show_complete_card(index: int, title: String, time: float, deaths: int, record: Dictionary) -> void:
	skip_chapter_card()
	done_title.text = "CHAPTER %d COMPLETE" % (index + 1)
	done_stats.text = "%s      Time %s      Puddles lost %d" % [title, Save.format_time(time), deaths]
	var bests := []
	if not record.get("first_clear", false):
		if record.get("best_time", false):
			bests.append("new best time")
		if record.get("best_deaths", false):
			bests.append("fewest puddles lost")
	done_best.text = ("★ " + "  ·  ".join(bests).to_upper() + " ★") if not bests.is_empty() else ""
	done_best.visible = not bests.is_empty()
	var last := index >= Game.LEVELS.size() - 1
	done_hint.text = "SPACE  continue" if not last else "SPACE  escape the lab"
	complete_card.show()
	complete_card.modulate.a = 0.0
	create_tween().tween_property(complete_card, "modulate:a", 1.0, 0.3)
	_complete_waiting = true
	_complete_t = 0.0
	await card_finished
	var t := create_tween()
	t.tween_property(complete_card, "modulate:a", 0.0, 0.25)
	t.tween_callback(complete_card.hide)


func _process(delta: float) -> void:
	if _complete_waiting:
		_complete_t += delta
		if _complete_t >= COMPLETE_HOLD:
			_finish_complete()


func _finish_complete() -> void:
	if _complete_waiting:
		_complete_waiting = false
		card_finished.emit()


func _input(event: InputEvent) -> void:
	if pause_menu.visible:
		return
	var go := event.is_action_pressed("jump") or event.is_action_pressed("ui_accept")
	if _complete_waiting and go and _complete_t > 0.35:
		Sfx.play("select", 0.0)
		_finish_complete()
	elif go and chapter_card.visible and chapter_card.modulate.a > 0.5:
		# Don't swallow the jump: the card just gets out of the way.
		skip_chapter_card()


# --- Pause menu ----------------------------------------------------------------

func is_paused() -> bool:
	return pause_menu.visible


func open_pause() -> void:
	if pause_menu.visible:
		return
	get_tree().paused = true
	pause_chapter.text = Game.chapter_title(Game.level_index)
	pause_menu.show()
	pause_buttons.show()
	settings_panel.hide()
	pause_menu.modulate.a = 0.0
	create_tween().tween_property(pause_menu, "modulate:a", 1.0, 0.12)
	Sfx.play("select", 0.0)
	UiUtil.focus_quiet(resume_btn)


func close_pause() -> void:
	if not pause_menu.visible:
		return
	settings_panel.hide()
	pause_menu.hide()
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if pause_menu.visible and pause_buttons.visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		Sfx.play("select", 0.0)
		close_pause()


# --- Fades ---------------------------------------------------------------------

func fade_out(time := 0.2) -> void:
	fade.show()
	fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var t := create_tween()
	t.tween_property(fade, "color:a", 1.0, time)
	await t.finished


func fade_in(time := 0.3) -> void:
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := create_tween()
	t.tween_property(fade, "color:a", 0.0, time)
	await t.finished
	if fade.color.a <= 0.01:
		fade.hide()
