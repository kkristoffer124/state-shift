@tool
class_name IxSwing
extends Node2D
## Hanging lamp / chain / sign: a damped pendulum. Bumping it (the player brushes the
## bob) or a fan's wind swings it. Purely decorative: the sensor only *reads* the player.
## ORIGIN = ceiling anchor. The child Area2D "Sensor" follows the bob.

enum Style { LAMP, CHAIN, SIGN, CABLE }

const TEX_SHADE := preload("res://assets/interactive/ix_lamp_shade.png")
const TEX_GLOW := preload("res://assets/interactive/ix_glow.png")
const TEX_LINK := preload("res://assets/interactive/ix_chain_link.png")
const TEX_HOOK := preload("res://assets/interactive/ix_hook.png")
const TEX_SIGN := preload("res://assets/interactive/ix_sign_arrow.png")
const TEX_CLAMP := preload("res://assets/interactive/ix_clamp.png")

@export var style: Style = Style.LAMP:
	set(v):
		style = v
		queue_redraw()
@export var length := 72.0:
	set(v):
		length = maxf(v, 8.0)
		queue_redraw()
@export var light_color := Color(1.0, 0.92, 0.7, 1.0)
## Lamps only: flickers now and then (more when steam drifts past).
@export var flicker := true
@export var flip_sign := false
## Initial swing (rad).
@export var start_angle := 0.0

var angle := 0.0
var omega := 0.0
var _fans := []
var _t := 0.0
var _dim := 1.0
var _flick := 0.0
var _rng := RandomNumberGenerator.new()
@onready var _sensor: Area2D = get_node_or_null("Sensor")


func _ready() -> void:
	angle = start_angle
	_rng.randomize()
	_t = _rng.randf() * 10.0
	if _sensor:
		_sensor.collision_layer = 0
		_sensor.collision_mask = Ix.PLAYER_MASK
		_sensor.monitorable = false
	if not Engine.is_editor_hint():
		_fans = Ix.fans_of(self)


func bob_local() -> Vector2:
	return Vector2(sin(angle), cos(angle)) * length


func _physics_process(delta: float) -> void:
	_t += delta
	if Engine.is_editor_hint():
		angle = start_angle + sin(_t * 1.5) * 0.05
		queue_redraw()
		return
	var g := 900.0
	var acc := -(g / length) * sin(angle) - omega * 0.7
	var bob := global_position + bob_local()
	# Wind from fans (sideways component swings it; capped so it leans, not spins).
	var w := Ix.wind_at(_fans, bob)
	acc += w.x * cos(angle) / length * 0.25 + w.y * sin(angle) / length * 0.1
	if w != Vector2.ZERO:
		acc += sin(_t * 7.0) * 2.0
	var steam_near := false
	if _sensor:
		_sensor.position = bob_local()
		for b in _sensor.get_overlapping_bodies():
			var s := Ix.state_of(b)
			if s == -1:
				continue
			var v: Vector2 = b.velocity
			var tangent := Vector2(cos(angle), -sin(angle))
			acc += v.dot(tangent) / length * (9.0 if s == 0 else 4.0)
			# Head-on bumps (e.g. falling past) still knock it aside.
			var side := signf(bob.x - b.global_position.x)
			acc += side * v.length() / length * (4.0 if s == 0 else 1.5)
			if s == 2:
				steam_near = true
	omega += acc * delta
	omega = clampf(omega, -9.0, 9.0)
	angle = clampf(angle + omega * delta, -1.3, 1.3)
	# Flicker.
	if style == Style.LAMP and flicker:
		var p := 0.15 if steam_near else 0.004
		if _rng.randf() < p:
			_flick = _rng.randf_range(0.05, 0.25)
		_flick = maxf(_flick - delta, 0.0)
		_dim = 0.25 if _flick > 0.0 and int(_t * 40.0) % 2 == 0 else 1.0
	queue_redraw()


func _draw() -> void:
	var b := bob_local()
	draw_texture(TEX_CLAMP, Vector2(-4, -2))
	match style:
		Style.CHAIN:
			var n := int(length / 4.0)
			for i in n:
				var p := (b * (float(i) + 0.5) / n).round()
				draw_texture(TEX_LINK, p - Vector2(1, 2))
			draw_set_transform(b, -angle)
			draw_texture(TEX_HOOK, Vector2(-4, -1))
			draw_set_transform(Vector2.ZERO)
		Style.SIGN:
			# Two wires to the sign corners.
			var r := Vector2(cos(angle), -sin(angle))
			Ix.pixel_line(self, Vector2(-3, 2), b - r * 11.0, Color("5d7b93"))
			Ix.pixel_line(self, Vector2(3, 2), b + r * 11.0, Color("5d7b93"))
			draw_set_transform(b, -angle, Vector2(-1 if flip_sign else 1, 1))
			draw_texture(TEX_SIGN, Vector2(-14, 0))
			draw_set_transform(Vector2.ZERO)
		Style.CABLE:
			# Sagging loose cable with a frayed plug end.
			Ix.pixel_line(self, Vector2(0, 2), b, Color("18222d"))
			Ix.pixel_line(self, Vector2(1, 2), b + Vector2(1, 0), Color("3d4f60"))
			draw_rect(Rect2(b.round() - Vector2(2, 0), Vector2(5, 4)), Color("5d7b93"))
			draw_rect(Rect2(b.round() + Vector2(-1, 4), Vector2(1, 2)), Ix.C_STEEL)
			draw_rect(Rect2(b.round() + Vector2(1, 4), Vector2(1, 2)), Ix.C_STEEL)
		_:
			Ix.pixel_line(self, Vector2(0, 2), b, Color("18222d"))
			var glow := light_color
			glow.a = 0.55 * _dim
			draw_texture(TEX_GLOW, (b + Vector2(0, 8) - TEX_GLOW.get_size() / 2.0).round(), glow)
			draw_set_transform(b.round(), -angle)
			draw_texture(TEX_SHADE, Vector2(-8, -1))
			var bulb := light_color.lerp(Color(0.3, 0.3, 0.3), 1.0 - _dim)
			draw_rect(Rect2(-2, 9, 4, 2), bulb)
			draw_set_transform(Vector2.ZERO)
