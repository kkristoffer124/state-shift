@tool
class_name DecoSparks
extends CPUParticles2D
## Fires a one-shot burst every few seconds (sparking wires). An optional
## `flash` CanvasItem blinks with each burst.

@export var min_interval := 1.5
@export var max_interval := 5.0
@export var flash: NodePath

var _wait := 1.0
var _flash_t := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	one_shot = true
	_rng.seed = hash(global_position) if is_inside_tree() else 1
	_wait = _rng.randf_range(0.2, max_interval)
	_set_flash(false)


func _process(delta: float) -> void:
	_wait -= delta
	if _flash_t > 0.0:
		_flash_t -= delta
		if _flash_t <= 0.0:
			_set_flash(false)
	if _wait <= 0.0:
		_wait = _rng.randf_range(min_interval, max_interval)
		restart()
		_flash_t = 0.08
		_set_flash(true)


func _set_flash(on: bool) -> void:
	var f := get_node_or_null(flash) as CanvasItem
	if f:
		f.visible = on
