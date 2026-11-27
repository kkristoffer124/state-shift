class_name CutsceneUI
extends CanvasLayer
## Cutscene overlay: letterbox bars, the typewriter dialogue box, the skip hint
## + hold-to-skip bar, a white flash and a fade.

## Speaker tag -> name colour. Unknown speakers use DEFAULT_COLOR; "" is narration.
const SPEAKER_COLORS := {
	"DR. KETTLE": Color("b8e6ff"),
	"PA": Color("ffb04a"),
	"LAB LOG": Color("66ff99"),
}
const DEFAULT_COLOR := Color("c9d9e6")
const NARRATION_COLOR := Color(0.84, 0.89, 0.96)

## Characters per second for the typewriter.
@export var chars_per_second := 42.0
## Extra pause (seconds) after . ! ? and , characters.
@export var stop_pause := 0.18

@onready var box: Control = %Box
@onready var speaker: Label = %Speaker
@onready var line_label: Label = %Line
@onready var hint: Label = %Hint
@onready var hold_bar: Control = %HoldBar
@onready var hold_fill: ColorRect = %HoldFill
@onready var flash_rect: ColorRect = %Flash
@onready var fade_rect: ColorRect = %Fade

var _typing := false
var _shown := 0.0
var _pause := 0.0
var _blip_count := 0
var _voice := "blip"
var _hint_t := 0.0
var _box_tween: Tween


func _ready() -> void:
	box.modulate.a = 0.0
	box.hide()
	hold_bar.hide()
	flash_rect.color.a = 0.0
	hint.modulate.a = 0.0


func say(who: String, text: String) -> void:
	var narration := who.is_empty()
	speaker.visible = not narration
	speaker.text = who
	speaker.add_theme_color_override("font_color", SPEAKER_COLORS.get(who, DEFAULT_COLOR))
	line_label.text = text
	line_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if narration else HORIZONTAL_ALIGNMENT_LEFT
	line_label.add_theme_color_override("font_color", NARRATION_COLOR if narration else Color.WHITE)
	line_label.visible_characters = 0
	_shown = 0.0
	_pause = 0.0
	_blip_count = 0
	_voice = "blip_low" if who == "PA" else ("" if narration else "blip")
	_typing = true
	if not box.visible or box.modulate.a < 1.0:
		var was_hidden := not box.visible or box.modulate.a <= 0.05
		box.show()
		if _box_tween:
			_box_tween.kill()
		_box_tween = create_tween()
		_box_tween.tween_property(box, "modulate:a", 1.0, 0.15)
		# Condenses out of steam (UiFx), when that autoload is around.
		var fx := get_node_or_null("/root/UiFx")
		if fx and was_hidden and fx.full():
			box.pivot_offset = (box.size / 2.0).round()
			box.scale = Vector2(1.04, 1.12)
			_box_tween.parallel().tween_property(box, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			fx.condense_rect(box, box.get_global_rect())


func clear() -> void:
	_typing = false
	if not box.visible:
		return
	if _box_tween:
		_box_tween.kill()
	_box_tween = create_tween()
	_box_tween.tween_property(box, "modulate:a", 0.0, 0.2)
	_box_tween.tween_callback(box.hide)
	var fx := get_node_or_null("/root/UiFx")
	if fx:
		fx.evaporate_rect(box, box.get_global_rect())


func is_typing() -> bool:
	return _typing


func current_text() -> String:
	return line_label.text if box.visible else ""


## Shows the rest of the current line at once. Returns true if it was still typing.
func finish_typing() -> bool:
	if not _typing:
		return false
	_typing = false
	line_label.visible_characters = -1
	return true


func flash(time := 0.25) -> void:
	flash_rect.color.a = 0.9
	create_tween().tween_property(flash_rect, "color:a", 0.0, time)


func fade_to(alpha: float, time: float) -> void:
	var t := create_tween()
	t.tween_property(fade_rect, "color:a", alpha, time)
	await t.finished


## Dialogue box at the top or bottom of the screen.
func set_box_top(top: bool) -> void:
	var h := box.offset_bottom - box.offset_top
	box.anchor_top = 0.0 if top else 1.0
	box.anchor_bottom = box.anchor_top
	box.offset_top = 22.0 if top else -20.0 - h
	box.offset_bottom = box.offset_top + h
	box.grow_vertical = Control.GROW_DIRECTION_END if top else Control.GROW_DIRECTION_BEGIN


func show_hint(text: String, time := 3.0) -> void:
	hint.text = text
	_hint_t = time
	hint.modulate.a = 1.0
	# The skip prompt condenses in: slides up a few pixels with a wisp of steam.
	var fx := get_node_or_null("/root/UiFx")
	if fx and fx.full():
		if not hint.has_meta("_base_y"):
			hint.set_meta("_base_y", hint.position.y)
		var base_y: float = hint.get_meta("_base_y")
		hint.position.y = base_y + 6.0
		hint.modulate.a = 0.0
		var t: Tween = fx.tw(hint, "hint")
		t.tween_property(hint, "modulate:a", 1.0, 0.2)
		t.parallel().tween_property(hint, "position:y", base_y, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var r := hint.get_global_rect()
		fx.puff(hint, Vector2(r.end.x - 30.0, r.get_center().y), 3, 24.0, 4.0)


func set_hold(ratio: float) -> void:
	hold_bar.visible = ratio > 0.0
	hold_fill.size.x = (hold_bar.size.x - 4.0) * clampf(ratio, 0.0, 1.0)
	# Water filling the bar: a bubble now and then pops off the leading edge.
	var fx := get_node_or_null("/root/UiFx")
	if fx and ratio > 0.0 and ratio < 1.0 and randf() < 0.18:
		var p := hold_fill.get_global_rect()
		fx.splash(hold_fill, Vector2(p.end.x, p.position.y + 1.0), 0.12)


func _process(delta: float) -> void:
	if _hint_t > 0.0:
		_hint_t -= delta
		if _hint_t <= 0.0:
			# Evaporates: fades while drifting up.
			var t := create_tween().set_parallel()
			t.tween_property(hint, "modulate:a", 0.0, 0.4)
			if hint.has_meta("_base_y"):
				t.tween_property(hint, "position:y", float(hint.get_meta("_base_y")) - 4.0, 0.4).set_trans(Tween.TRANS_SINE)
	if not _typing:
		return
	if _pause > 0.0:
		_pause -= delta
		return
	var total := line_label.get_total_character_count()
	var before := int(_shown)
	_shown += delta * chars_per_second
	var now := mini(int(_shown), total)
	if now > before:
		line_label.visible_characters = now
		var ch := line_label.text.substr(now - 1, 1)
		if ch in [".", "!", "?", ",", "—"] and now < total:
			_pause = stop_pause * (0.5 if ch == "," else 1.0)
		if ch != " " and not _voice.is_empty():
			_blip_count += 1
			if _blip_count % 3 == 1:
				var s := get_node_or_null("/root/Sfx")
				if s:
					s.play(_voice, 0.12)
	if now >= total:
		_typing = false
		line_label.visible_characters = -1
