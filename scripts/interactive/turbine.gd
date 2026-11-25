@tool
class_name IxTurbine
extends Area2D
## Steam turbine. Drifting through it as STEAM (or a fan blowing on it) spins the rotor.
## Spin it up long enough and it powers `channel` (latched). Leave `channel` empty for
## a purely decorative turbine. ORIGIN = rotor centre.

const TEX_HOUSING := preload("res://assets/interactive/ix_turbine_housing.png")
const TEX_ROTOR := preload("res://assets/interactive/ix_turbine_rotor_4f.png")

@export var channel := ""
## Seconds of steam needed to fully charge.
@export var charge_time := 0.35
## Fans spin it too (decorative), but only steam charges it.
@export var fan_spins := true
## Sensor radius (px). Bigger than the art so drifting steam reliably catches it.
@export var radius := 26.0:
	set(v):
		radius = v
		_refresh()

## Draws a mounting strut this many px straight up (0 = none).
@export var pole_length := 0.0:
	set(v):
		pole_length = maxf(v, 0.0)
		queue_redraw()

var charged := false
var _charge := 0.0
var _spin := 0.0     # rad/s
var _angle := 0.0
var _fans := []
var _flash := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = Ix.PLAYER_MASK
	monitoring = true
	monitorable = false
	_refresh()
	if not Engine.is_editor_hint():
		_fans = Ix.fans_of(self)


func _refresh() -> void:
	if not is_inside_tree():
		return
	var cs := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs and cs.shape is CircleShape2D:
		(cs.shape as CircleShape2D).radius = radius


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		_angle += delta * 2.0
		queue_redraw()
		return
	var steam := false
	for b in get_overlapping_bodies():
		if Ix.state_of(b) == 2:
			steam = true
			_spin += (absf(b.velocity.x) + absf(b.velocity.y)) * 0.08 * delta + 30.0 * delta
	if fan_spins:
		var w := Ix.wind_at(_fans, global_position)
		_spin += w.length() * 0.004 * delta
	_spin = clampf(_spin - _spin * 0.6 * delta, 0.0, 40.0)
	_angle = fmod(_angle + _spin * delta, TAU)
	if channel != "" and not charged:
		_charge = clampf(_charge + (delta if steam else -delta * 0.5), 0.0, charge_time)
		if _charge >= charge_time:
			charged = true
			_flash = 0.6
			Ix.emit(self, channel, true)
			if has_node("/root/Sfx"):
				get_node("/root/Sfx").play("select", 0.0)
	_flash = maxf(_flash - delta, 0.0)
	queue_redraw()


func _draw() -> void:
	if pole_length > 0.0:
		var top := -18.0 - pole_length
		draw_rect(Rect2(-3, top, 6, pole_length), Ix.C_INK)
		draw_rect(Rect2(-2, top, 4, pole_length), Color("5d7b93"))
		draw_rect(Rect2(-1, top, 1, pole_length), Ix.C_STEEL)
		draw_rect(Rect2(-6, top, 12, 3), Ix.C_INK)
		draw_rect(Rect2(-5, top, 10, 2), Color("5d7b93"))
	draw_texture(TEX_HOUSING, -TEX_HOUSING.get_size() / 2.0)
	var frame := int(_angle / (PI / 8.0)) % 4
	draw_texture_rect_region(TEX_ROTOR, Rect2(-16, -16, 32, 32), Rect2(frame * 32, 0, 32, 32))
	if channel == "":
		return
	# Charge ticks around the rim; green when powered.
	var n := 12
	var lit := n if charged else int(round(_charge / maxf(charge_time, 0.01) * n))
	for i in n:
		var a := -PI / 2.0 + TAU * i / n
		var p := (Vector2(cos(a), sin(a)) * 21.5).round() - Vector2(1, 1)
		var c := Color("18222d")
		if i < lit:
			c = Ix.C_GOAL if charged else Ix.C_HEAT
		if _flash > 0.0 and int(_flash * 16.0) % 2 == 0:
			c = Color.WHITE
		draw_rect(Rect2(p, Vector2(2, 2)), c)
