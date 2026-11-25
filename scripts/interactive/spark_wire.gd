@tool
class_name IxSparkWire
extends Node2D
## A torn cable dangling from the ceiling. Its frayed end sputters sparks every few
## seconds; brushing it swings it and throws a shower of sparks (a WATER blob gets a big
## harmless zap). Nearby IxLights stutter when it zaps. Decorative: never hurts.
## ORIGIN = ceiling anchor. The child Area2D "Sensor" follows the frayed end.

const TEX_SPARK := preload("res://assets/interactive/ix_spark_2f.png")
const TEX_CLAMP := preload("res://assets/interactive/ix_clamp.png")
const TEX_GLOW := preload("res://assets/interactive/ix_glow.png")

@export var length := 56.0:
	set(v):
		length = maxf(v, 8.0)
		queue_redraw()
@export var interval := 2.2

var angle := 0.2
var omega := 0.0
var _t := 0.0
var _next := 1.0
var _sparks: Array = []  # [pos(local), vel, life]
var _zap := 0.0
var _touch := false
var _rng := RandomNumberGenerator.new()
@onready var _sensor: Area2D = get_node_or_null("Sensor")


func _ready() -> void:
	_rng.randomize()
	_next = _rng.randf_range(0.3, interval)
	if _sensor:
		_sensor.collision_layer = 0
		_sensor.collision_mask = Ix.PLAYER_MASK
		_sensor.monitorable = false


func tip() -> Vector2:
	return Vector2(sin(angle), cos(angle)) * length


func _physics_process(delta: float) -> void:
	_t += delta
	var acc := -(900.0 / length) * sin(angle) - omega * 0.5 + sin(_t * 1.7) * 0.4
	var touch := false
	if _sensor and not Engine.is_editor_hint():
		_sensor.position = tip()
		for b in _sensor.get_overlapping_bodies():
			var s := Ix.state_of(b)
			if s == -1:
				continue
			touch = true
			acc += (b.velocity as Vector2).x * cos(angle) / length * 6.0
			if not _touch:
				_burst(16 if s == 1 else 9)
				_zap = 0.35 if s == 1 else 0.15
	_touch = touch
	omega = clampf(omega + acc * delta, -8.0, 8.0)
	angle = clampf(angle + omega * delta, -1.2, 1.2)
	_next -= delta
	if _next <= 0.0:
		_next = interval * _rng.randf_range(0.6, 1.4)
		_burst(_rng.randi_range(3, 7))
		_zap = maxf(_zap, 0.08)
	_zap = maxf(_zap - delta, 0.0)
	for i in range(_sparks.size() - 1, -1, -1):
		var s2: Array = _sparks[i]
		s2[1].y += 700.0 * delta
		s2[0] += s2[1] * delta
		s2[2] -= delta
		if s2[2] <= 0.0:
			_sparks.remove_at(i)
	queue_redraw()


func _burst(n: int) -> void:
	var tp := tip()
	for i in n:
		_sparks.append([tp, Vector2(_rng.randf_range(-120, 120), _rng.randf_range(-150, 20)), _rng.randf_range(0.2, 0.5)])


func _draw() -> void:
	var tp := tip()
	draw_texture(TEX_CLAMP, Vector2(-4, -2))
	# Slight sag: two segments.
	var mid := tp * 0.5 + Vector2(cos(angle), -sin(angle)) * 3.0
	Ix.pixel_line(self, Vector2(0, 2), mid, Color("18222d"))
	Ix.pixel_line(self, mid, tp, Color("18222d"))
	Ix.pixel_line(self, Vector2(1, 2), mid + Vector2(1, 0), Color("3d4f60"))
	# Frayed copper strands.
	var d := tp.normalized()
	var n := Vector2(-d.y, d.x)
	for k in [-1.0, 0.0, 1.0]:
		Ix.pixel_line(self, tp, tp + d * 4.0 + n * k * 2.0, Color("c88a4a"))
	if _zap > 0.0:
		var g := Color(1.0, 0.9, 0.5, minf(_zap * 3.0, 0.8))
		draw_texture_rect(TEX_GLOW, Rect2(tp - Vector2(20, 20), Vector2(40, 40)), false, g)
	for s in _sparks:
		var frame := 0 if s[2] > 0.25 else 1
		draw_texture_rect_region(TEX_SPARK, Rect2((s[0] as Vector2).round() - Vector2(2, 2), Vector2(5, 5)), Rect2(frame * 5, 0, 5, 5))


## IxLight-friendly: is it zapping right now?
func zapping() -> bool:
	return _zap > 0.0
