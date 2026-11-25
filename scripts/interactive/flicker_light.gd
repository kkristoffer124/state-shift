@tool
class_name IxLight
extends Node2D
## Wall lamp or ceiling tube with a soft glow. It flickers now and then, a lot more while
## STEAM drifts within `steam_radius` (condensation on the contacts), and a nearby
## IxSteamVent puff makes it stutter too. Decorative. ORIGIN = mount point.

enum Style { WALL, TUBE, BEACON }

const TEX_WALL := preload("res://assets/interactive/ix_wall_lamp.png")
const TEX_TUBE := preload("res://assets/interactive/ix_tube_lamp.png")
const TEX_GLOW := preload("res://assets/interactive/ix_glow.png")

@export var style: Style = Style.WALL:
	set(v):
		style = v
		queue_redraw()
@export var color := Color(1.0, 0.92, 0.7):
	set(v):
		color = v
		queue_redraw()
## 0 = steady, 1 = very unreliable.
@export_range(0.0, 1.0) var faultiness := 0.2
@export var steam_radius := 110.0
@export var glow_scale := 1.0

var _dim := 1.0
var _flick := 0.0
var _t := 0.0
var _rng := RandomNumberGenerator.new()
var _vents: Array = []


func _ready() -> void:
	_rng.randomize()
	_t = _rng.randf() * 10.0
	if not Engine.is_editor_hint():
		_find_vents.call_deferred()


func _find_vents() -> void:
	if not is_inside_tree():
		return
	for n in get_tree().get_nodes_in_group("ix_vent"):
		if Ix.level_of(n) == Ix.level_of(self) and (n as Node2D).global_position.distance_to(global_position) < steam_radius * 2.0:
			_vents.append(n)


func _process(delta: float) -> void:
	_t += delta
	if Engine.is_editor_hint():
		return
	var chance := faultiness * 0.02
	var pl := Ix.player_of(self)
	if pl and Ix.state_of(pl) == 2 and pl.global_position.distance_to(global_position) < steam_radius:
		chance = 0.25
	for v in _vents:
		if is_instance_valid(v) and v.puffing:
			chance = maxf(chance, 0.12)
	if _rng.randf() < chance:
		_flick = _rng.randf_range(0.05, 0.3)
	var was := _dim
	if _flick > 0.0:
		_flick -= delta
		_dim = 0.15 if _rng.randf() < 0.5 else 0.8
	else:
		_dim = 1.0 if style != Style.BEACON else 0.55 + 0.45 * sin(_t * 4.0)
	if was != _dim or style == Style.BEACON:
		queue_redraw()


func _draw() -> void:
	var g := color
	g.a = 0.5 * _dim
	var gs := TEX_GLOW.get_size() * glow_scale
	match style:
		Style.WALL:
			draw_texture_rect(TEX_GLOW, Rect2(Vector2(0, 14) - gs / 2.0, gs).abs(), false, g)
			draw_texture(TEX_WALL, Vector2(-6, 0))
			draw_rect(Rect2(-3, 5, 6, 1), color.lerp(Color(0.25, 0.25, 0.25), 1.0 - _dim))
		Style.TUBE:
			var gs2 := Vector2(gs.x * 1.6, gs.y)
			draw_texture_rect(TEX_GLOW, Rect2(Vector2(0, 12) - gs2 / 2.0, gs2), false, g)
			draw_texture(TEX_TUBE, Vector2(-18, 0))
			draw_rect(Rect2(-15, 4, 30, 2), Color(0.91, 0.96, 1.0).lerp(Color(0.25, 0.3, 0.35), 1.0 - _dim))
		Style.BEACON:
			draw_texture_rect(TEX_GLOW, Rect2(-gs / 2.0 * 0.6, gs * 0.6), false, g)
			draw_rect(Rect2(-3, -3, 6, 6), Ix.C_INK)
			draw_rect(Rect2(-2, -2, 4, 4), color.lerp(Color(0.2, 0.2, 0.2), 1.0 - _dim))
			draw_rect(Rect2(-1, -2, 1, 1), Color.WHITE)
