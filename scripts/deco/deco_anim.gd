@tool
class_name DecoAnim
extends Sprite2D
## Cheap flipbook for decoration sprites (hframes strip). Blinks, bubbles, screens.
##  hold_first > 0: stays on frame 0 for that long, then plays the other frames once
##  (lamp flicker, sign stutter). `linked` nodes are only visible on frame 0
##  (e.g. a lamp's light cone).

@export var fps := 6.0
@export var random_frames := false
@export var hold_first := 0.0
@export var hold_jitter := 0.5
@export var linked: Array[NodePath] = []

var _t := 0.0
var _hold := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = hash(global_position) if is_inside_tree() else 1
	_t = _rng.randf() * 8.0
	_hold = hold_first * (1.0 + _rng.randf_range(-hold_jitter, hold_jitter))


func _process(delta: float) -> void:
	var n := hframes * vframes
	if n <= 1 or fps <= 0.0:
		return
	_t += delta
	var f := frame
	if hold_first > 0.0:
		var cycle := _hold + (n - 1) / fps
		var local := fmod(_t, cycle)
		if local < _hold:
			f = 0
		else:
			f = 1 + int((local - _hold) * fps) % (n - 1)
		if _t > cycle:
			_t -= cycle
			_hold = hold_first * (1.0 + _rng.randf_range(-hold_jitter, hold_jitter))
	elif random_frames:
		var step := int(_t * fps)
		if step != int((_t - delta) * fps):
			f = _rng.randi() % n
	else:
		f = int(_t * fps) % n
	if f != frame:
		frame = f
		for p in linked:
			var c := get_node_or_null(p) as CanvasItem
			if c:
				c.visible = f == 0
