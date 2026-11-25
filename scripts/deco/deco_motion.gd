@tool
class_name DecoMotion
extends Node2D
## Small procedural motion for decoration: spin (fans, gears), sway (cables,
## chains, lamps) and alpha pulse/flicker (glows, beacons). Works on any
## CanvasItem node (Sprite2D, Node2D groups...).

@export var spin_speed := 0.0 ## radians / second
@export var sway_degrees := 0.0
@export var sway_speed := 1.0
@export var pulse_min := 1.0
@export var pulse_max := 1.0
@export var pulse_speed := 2.0
## pulse_* scale the node's own modulate alpha. Chance per second of a short flicker:
@export var flicker := 0.0

var _t := 0.0
var _base_rot := 0.0
var _base_a := 1.0
var _flick := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_base_rot = rotation
	_base_a = modulate.a
	_rng.seed = hash(global_position) if is_inside_tree() else 1
	_t = _rng.randf() * 10.0


func _process(delta: float) -> void:
	_t += delta
	if spin_speed != 0.0:
		rotation = wrapf(rotation + spin_speed * delta, -PI, PI)
	elif sway_degrees != 0.0:
		rotation = _base_rot + deg_to_rad(sway_degrees) * sin(_t * sway_speed)
	if pulse_min != pulse_max or flicker > 0.0:
		var a := lerpf(pulse_min, pulse_max, 0.5 + 0.5 * sin(_t * pulse_speed))
		if flicker > 0.0:
			if _flick > 0.0:
				_flick -= delta
				a *= 0.3
			elif _rng.randf() < flicker * delta:
				_flick = _rng.randf_range(0.04, 0.18)
		modulate.a = _base_a * a
