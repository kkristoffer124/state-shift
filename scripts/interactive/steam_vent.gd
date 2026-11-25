@tool
class_name IxSteamVent
extends Area2D
## Floor vent that hisses, then puffs steam every `period` seconds: spawns free steam
## pixels in the FluidWorld, draws its own puffs and gives a STEAM player an upward kick
## (WATER too if `push_water`). It never forces a state and never hurts.
## ORIGIN = centre of the grill, on the floor surface. The column rises `height` px.

const TEX_GRILL := preload("res://assets/interactive/ix_vent_grill.png")
const TEX_PUFFS: Array[Texture2D] = [
	preload("res://assets/player/p3a_puff_1.png"),
	preload("res://assets/player/p3a_puff_2.png"),
	preload("res://assets/player/p3a_puff_3.png"),
	preload("res://assets/player/p3a_puff_4.png"),
]

@export var width := 32.0:
	set(v):
		width = maxf(v, 16.0)
		_refresh()
@export var height := 160.0:
	set(v):
		height = maxf(v, 16.0)
		_refresh()
@export var period := 2.6
@export var puff_time := 0.7
@export var phase := 0.0
## Upward acceleration (px/s^2) on a STEAM player inside the column during a puff.
@export var push := 1400.0
@export var push_water := false
## If set, the vent only works while this channel is ON (`inverted` flips it).
@export var channel := ""
@export var inverted := false

var active := true
var puffing := false
var _t := 0.0
var _puffs: Array = []   # [pos(local), vel, age, life, tex]
var _rng := RandomNumberGenerator.new()
var _sources := {}
var _emit_acc := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = Ix.PLAYER_MASK
	monitoring = true
	monitorable = false
	_rng.randomize()
	_t = phase
	_refresh()
	if not Engine.is_editor_hint():
		add_to_group("ix_vent")
	if not Engine.is_editor_hint() and channel != "":
		Ix.listen(self, channel)
		active = inverted


func _on_channel(source_id: int, on: bool) -> void:
	if on:
		_sources[source_id] = true
	else:
		_sources.erase(source_id)
	active = (_sources.size() > 0) != inverted


func _refresh() -> void:
	if not is_inside_tree():
		return
	var cs := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs and cs.shape is RectangleShape2D:
		(cs.shape as RectangleShape2D).size = Vector2(width, height)
		cs.position = Vector2(0, -height / 2.0)
	queue_redraw()


func _physics_process(delta: float) -> void:
	_t += delta
	var cyc := fmod(_t, maxf(period, 0.1))
	var hissing := active and cyc > period - 0.45
	puffing = active and cyc < puff_time
	if puffing:
		_emit_acc += delta
		while _emit_acc > 0.03:
			_emit_acc -= 0.03
			_add_puff(true)
			if not Engine.is_editor_hint():
				var gp := global_position + Vector2(_rng.randf_range(-width / 2.0, width / 2.0), -4)
				Ix.spawn_steam(self, gp, Vector2(_rng.randf_range(-20, 20), _rng.randf_range(-260, -160)))
		if not Engine.is_editor_hint():
			for b in get_overlapping_bodies():
				var s := Ix.state_of(b)
				if s == 2 or (s == 1 and push_water):
					b.velocity.y -= push * delta * (1.0 if s == 2 else 0.35)
	elif hissing and _rng.randf() < delta * 14.0:
		_add_puff(false)
	for i in range(_puffs.size() - 1, -1, -1):
		var p: Array = _puffs[i]
		p[2] += delta
		p[1] *= 1.0 - 1.5 * delta
		p[0] += p[1] * delta
		if p[2] >= p[3]:
			_puffs.remove_at(i)
	queue_redraw()


func _add_puff(big: bool) -> void:
	if _puffs.size() > 40:
		return
	var x := _rng.randf_range(-width / 2.0 + 4.0, width / 2.0 - 4.0)
	var v := Vector2(_rng.randf_range(-15, 15), -_rng.randf_range(160, 320) if big else -_rng.randf_range(30, 60))
	var life := (height / 260.0) * _rng.randf_range(0.8, 1.2) if big else 0.4
	_puffs.append([Vector2(x, -4), v, 0.0, life, _rng.randi() % TEX_PUFFS.size()])


func _draw() -> void:
	for p in _puffs:
		var k: float = p[2] / p[3]
		var tex: Texture2D = TEX_PUFFS[p[4]]
		var a := (1.0 - k) * 0.8
		draw_texture(tex, ((p[0] as Vector2) - tex.get_size() / 2.0).round(), Color(1, 1, 1, a))
	# Grill, tiled across the width, sunk a few px into the floor.
	var n := maxi(1, int(width / 32.0))
	var x0 := -n * 16.0
	for i in n:
		draw_texture(TEX_GRILL, Vector2(x0 + i * 32.0, -5))
	# Warm glow in the slots while charging/puffing.
	var cyc := fmod(_t, maxf(period, 0.1))
	var heat := 0.0
	if active:
		heat = 1.0 if cyc < puff_time else clampf((cyc - (period - 0.6)) / 0.6, 0.0, 1.0)
	if heat > 0.0:
		for i in n:
			for sx in range(3, 29, 4):
				draw_rect(Rect2(x0 + i * 32.0 + sx, -3, 2, 1), Color(Ix.C_HEAT, heat))
