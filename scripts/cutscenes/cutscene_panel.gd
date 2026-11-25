class_name CutscenePanel
extends Node2D
## One shot of a cutscene. Children: `Art` / `Fx` (pixel art at 2x), `Camera`
## and `Anim` (an AnimationPlayer whose `main` animation is the whole shot).
##
## The animation drives everything: sprite frames, positions, the camera and
## method-track calls to the functions below (say, narrate, clear, sfx, shake,
## flash). Select the panel, open the Animation tab and scrub to edit it.

signal finished

@export var animation := &"main"
## Extra seconds to wait after the animation ends (after the caption has typed out).
@export var linger := 0.0
## Put the dialogue box at the top of the screen (shots with action near the floor).
@export var caption_top := false

var cutscene: Node  ## The owning Cutscene (null when the panel runs on its own).

@onready var anim: AnimationPlayer = get_node_or_null("Anim")
@onready var camera: Camera2D = get_node_or_null("Camera")

var _shake := 0.0
var _shake_time := 0.0
var _shake_left := 0.0


func _ready() -> void:
	if anim and not anim.animation_finished.is_connected(_on_anim_finished):
		anim.animation_finished.connect(_on_anim_finished)


func begin() -> void:
	show()
	if camera:
		camera.enabled = true
		camera.make_current()
	if anim and anim.has_animation(animation):
		anim.play(animation)
		anim.seek(0.0, true)
	else:
		finished.emit.call_deferred()


func end() -> void:
	if anim:
		anim.stop()
	_shake_left = 0.0
	if camera:
		camera.offset = Vector2.ZERO
	hide()


func length() -> float:
	return anim.get_animation(animation).length if anim and anim.has_animation(animation) else 0.0


func _on_anim_finished(_name: StringName) -> void:
	if linger > 0.0:
		await get_tree().create_timer(linger).timeout
	finished.emit()


func _process(delta: float) -> void:
	if _shake_left > 0.0 and camera:
		_shake_left -= delta
		var k := clampf(_shake_left / maxf(_shake_time, 0.001), 0.0, 1.0)
		var amt := _shake * k * (1.0 if _shake_allowed() else 0.0)
		camera.offset = Vector2(randf_range(-amt, amt), randf_range(-amt, amt)).round()
		if _shake_left <= 0.0:
			camera.offset = Vector2.ZERO


func _shake_allowed() -> bool:
	var s := get_node_or_null("/root/Settings")
	return s == null or bool(s.get("screen_shake"))


# --- Called from animation method tracks -------------------------------------

## A speaker line in the dialogue box ("DR. KETTLE", "PA", "LAB LOG"...).
func say(who: String, line: String) -> void:
	if cutscene:
		cutscene.ui.say(who, line)


## A narration line (no speaker tag).
func narrate(line: String) -> void:
	say("", line)


func clear() -> void:
	if cutscene:
		cutscene.ui.clear()


func sfx(sound: String) -> void:
	var s := get_node_or_null("/root/Sfx")
	if s:
		s.play(sound, 0.05)


func shake(amount: float, time: float) -> void:
	_shake = amount
	_shake_time = time
	_shake_left = time


func flash(time: float) -> void:
	if cutscene:
		cutscene.ui.flash(time)
