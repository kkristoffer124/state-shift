class_name CutsceneSprite
extends Sprite2D
## Sprite2D with a few ambient loops for cutscene panels: a flipbook over
## `hframes`, a sine bob and a light flicker. Leave a value at 0 to disable it.
## (When an AnimationPlayer keys `frame`, keep `fps` at 0 or key `fps` too.)

## Flipbook speed in frames per second (0 = off).
@export var fps := 0.0
@export var first_frame := 0
## Last flipbook frame (-1 = last frame of the sheet).
@export var last_frame := -1
## Bob amplitude in (unscaled) pixels, applied to `offset.y`, snapped to whole pixels.
@export var bob_px := 0.0
@export var bob_hz := 0.6
## 0..1: random dips in self_modulate alpha (lamps, glows).
@export var flicker := 0.0

var _t := 0.0
var _base_offset := Vector2.ZERO
var _flick_t := 0.0


func _ready() -> void:
	_base_offset = offset


func _process(delta: float) -> void:
	_t += delta
	if fps > 0.0:
		var last := last_frame if last_frame >= 0 else hframes * vframes - 1
		var n := maxi(1, last - first_frame + 1)
		frame = first_frame + int(_t * fps) % n
	if bob_px != 0.0:
		offset.y = _base_offset.y + roundf(sin(_t * TAU * bob_hz) * bob_px)
	if flicker > 0.0:
		_flick_t -= delta
		if _flick_t <= 0.0:
			_flick_t = randf_range(0.04, 0.12)
			self_modulate.a = 1.0 - (flicker * randf() if randf() < 0.5 else 0.0)
