@tool
class_name CutsceneFace
extends Node2D
## The player's eyes for cutscenes: same textures and layout as Player._draw_eyes_on
## (eye whites + pupils + catchlight, blink frames, expression sets), centred on this
## node. Key `expression` from an AnimationPlayer (values match the old eyes sheet).

enum Expr {
	OPEN,  ## 0: normal eyes (auto-blinks)
	HALF,  ## 1: half-closed (blink frame 1)
	CLOSED,  ## 2: closed / asleep
	LOOK_RIGHT,  ## 3
	LOOK_LEFT,  ## 4
	HAPPY,  ## 5: ^ ^
	DETERMINED,  ## 6
	SCARED,  ## 7: wide eyes
	LOOK_UP,  ## 8
	DIZZY,  ## 9
	BLOCKED,  ## 10
	NEUTRAL,  ## 11: flat neutral set
}

const TEX_EYE_WHITE := preload("res://assets/player/p4a_eye_white.png")
const TEX_PUPIL := preload("res://assets/player/p4b_pupil.png")
const TEX_CATCHLIGHT := preload("res://assets/player/p4c_catchlight.png")
const TEX_BLINK := [preload("res://assets/player/p4d_blink_1.png"), preload("res://assets/player/p4d_blink_2.png")]
const TEX_SETS := {
	Expr.HAPPY: preload("res://assets/player/p4e_eyes_happy.png"),
	Expr.DETERMINED: preload("res://assets/player/p4e_eyes_determined.png"),
	Expr.SCARED: preload("res://assets/player/p4e_eyes_scared.png"),
	Expr.DIZZY: preload("res://assets/player/p4e_eyes_dizzy.png"),
	Expr.BLOCKED: preload("res://assets/player/p4e_eyes_blocked.png"),
	Expr.NEUTRAL: preload("res://assets/player/p4e_eyes_neutral.png"),
}

@export var expression: Expr = Expr.OPEN:
	set(v):
		expression = v
		queue_redraw()
## Blink every few seconds while the eyes are open (like the in-game player).
@export var auto_blink := true

var _t := 0.0


func _ready() -> void:
	_t = randf() * 3.0


func _process(delta: float) -> void:
	_t += delta
	if auto_blink and is_visible_in_tree():
		queue_redraw()


func _draw_set(tex: Texture2D) -> void:
	draw_texture(tex, (-tex.get_size() * 0.5).round())


func _draw() -> void:
	match expression:
		Expr.HALF:
			_draw_set(TEX_BLINK[0])
			return
		Expr.CLOSED:
			_draw_set(TEX_BLINK[1])
			return
	if TEX_SETS.has(expression):
		_draw_set(TEX_SETS[expression])
		return
	if auto_blink:
		var cycle := fmod(_t, 3.7)
		if cycle < 0.14:
			_draw_set(TEX_BLINK[0 if cycle < 0.05 or cycle > 0.10 else 1])
			return
	var look := Vector2.ZERO
	match expression:
		Expr.LOOK_RIGHT: look = Vector2(1, 0)
		Expr.LOOK_LEFT: look = Vector2(-1, 0)
		Expr.LOOK_UP: look = Vector2(0, -1)
	for ex in [-5.0, 5.0]:
		var e := Vector2(ex + look.x, 0.0)
		draw_texture(TEX_EYE_WHITE, (e - Vector2(3.5, 3.5)).round())
		var pupil := (e - Vector2(1.5, 1.5) + look).round()
		draw_texture(TEX_PUPIL, pupil)
		draw_texture(TEX_CATCHLIGHT, pupil + Vector2(1, 0))
