@tool
class_name IxDrip
extends Node2D
## Leaky pipe. Every `interval` it lets go of `burst` free water pixels into the FluidWorld
## (they fall, pool, slip through grates). Without a FluidWorld it simulates its own
## drops (raycast to walls; grates let them through) and feeds IxBasins they land in.
## ORIGIN = nozzle outlet. The pipe runs `pipe_length` px straight up from it.
## With a `channel` it only flows while that channel is ON (`inverted` flips it).

const TEX_PIPE := preload("res://assets/interactive/ix_pipe_v.png")
const TEX_NOZZLE := preload("res://assets/interactive/ix_nozzle.png")

@export var pipe_length := 64.0:
	set(v):
		pipe_length = maxf(v, 0.0)
		queue_redraw()
@export var interval := 0.5
@export var burst := 2
## Random horizontal speed of each pixel.
@export var spread := 12.0
@export var start_delay := 0.0
@export var channel := ""
@export var inverted := false
## A steady stream instead of drips (interval is ignored: ~30 pixels/s).
@export var stream := false

var flowing := true
var _acc := 0.0
var _bead := 0.0
var _drops: Array = []   # fallback: [pos, vel]
var _splash: Array = []  # fallback: [pos, vel, life]
var _sources := {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_acc = -start_delay
	if Engine.is_editor_hint():
		return
	if channel != "":
		Ix.listen(self, channel)
		flowing = inverted


func _on_channel(source_id: int, on: bool) -> void:
	if on:
		_sources[source_id] = true
	else:
		_sources.erase(source_id)
	flowing = (_sources.size() > 0) != inverted


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		_bead = fmod(_bead + delta / maxf(interval, 0.1), 1.0)
		queue_redraw()
		return
	if flowing:
		_acc += delta
		var step := 1.0 / 30.0 if stream else interval
		_bead = clampf(_acc / maxf(step, 0.01), 0.0, 1.0)
		while _acc >= step:
			_acc -= step
			for i in (1 if stream else burst):
				_emit_one()
	else:
		_bead = maxf(_bead - delta * 2.0, 0.0)
	_sim_fallback(delta)
	queue_redraw()


func _emit_one() -> void:
	var pos := global_position + Vector2(_rng.randf_range(-1.5, 1.5), 1.0)
	var vel := Vector2(_rng.randf_range(-spread, spread), _rng.randf_range(10.0, 40.0))
	if Ix.spawn_water(self, pos, vel):
		return
	if _drops.size() < 48:
		_drops.append([pos, vel])


func _sim_fallback(delta: float) -> void:
	if _drops.is_empty() and _splash.is_empty():
		return
	var space := get_world_2d().direct_space_state
	var basins := get_tree().get_nodes_in_group("ix_basin")
	for i in range(_drops.size() - 1, -1, -1):
		var d: Array = _drops[i]
		var p0: Vector2 = d[0]
		var v: Vector2 = d[1]
		v.y = minf(v.y + 1300.0 * delta, 700.0)
		var p1 := p0 + v * delta
		var gone := false
		for b in basins:
			if b.global_rect().has_point(p1):
				b.add_drop()
				_splash_at(p1, 2)
				gone = true
				break
		if not gone:
			var q := PhysicsRayQueryParameters2D.create(p0, p1, Ix.WORLD_MASK)
			var hit := space.intersect_ray(q)
			if hit:
				_splash_at(hit.position, 3)
				gone = true
		if gone or p1.y > global_position.y + 4000.0:
			_drops.remove_at(i)
		else:
			d[0] = p1
			d[1] = v
	for i in range(_splash.size() - 1, -1, -1):
		var s: Array = _splash[i]
		s[1].y += 900.0 * delta
		s[0] += s[1] * delta
		s[2] -= delta
		if s[2] <= 0.0:
			_splash.remove_at(i)


func _splash_at(p: Vector2, n: int) -> void:
	for i in n:
		_splash.append([p + Vector2(0, -1), Vector2(_rng.randf_range(-50, 50), _rng.randf_range(-90, -40)), 0.25])


func _draw() -> void:
	Ix.vtile(self, TEX_PIPE, Vector2(-4, -16 - pipe_length), pipe_length)
	draw_texture(TEX_NOZZLE, Vector2(-8, -16))
	# The bead of water growing at the outlet.
	if _bead > 0.25 and not stream:
		var r := 1.0 + floorf(_bead * 2.0)
		draw_rect(Rect2(-r / 2.0 - 0.5, 0, r + 1.0, r + 1.0).abs(), Ix.C_WATER)
		draw_rect(Rect2(-1, 0, 1, 1), Ix.C_WATER_HI)
	elif stream and flowing:
		draw_rect(Rect2(-1, 0, 2, 3), Ix.C_WATER_HI)
	var inv := get_global_transform().affine_inverse()
	for d in _drops:
		var lp: Vector2 = (inv * (d[0] as Vector2)).floor()
		draw_rect(Rect2(lp, Vector2(2, 3)), Ix.C_WATER)
		draw_rect(Rect2(lp, Vector2(1, 1)), Ix.C_WATER_HI)
	for s in _splash:
		draw_rect(Rect2((inv * (s[0] as Vector2)).floor(), Vector2.ONE), Ix.C_WATER_HI)
