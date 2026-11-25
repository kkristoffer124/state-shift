@tool
class_name IxDebris
extends Node2D
## Loose papers / leaves / dust lying on a floor. They scatter when the player rushes
## past, flutter in fan wind and settle again. No collision, purely visual.
## ORIGIN = left end, on the floor surface. Pieces stay inside [-margin, width+margin]
## horizontally and above `-ceiling` px.

enum Kind { PAPER, LEAF, DUST }

const TEX_PAPER: Array[Texture2D] = [
	preload("res://assets/interactive/ix_paper_1.png"),
	preload("res://assets/interactive/ix_paper_2.png"),
	preload("res://assets/interactive/ix_paper_3.png"),
]
const TEX_LEAF: Array[Texture2D] = [
	preload("res://assets/interactive/ix_leaf_1.png"),
	preload("res://assets/interactive/ix_leaf_2.png"),
]

@export var kind: Kind = Kind.PAPER:
	set(v):
		kind = v
		_scatter()
@export var width := 96.0:
	set(v):
		width = maxf(v, 8.0)
		_scatter()
@export var count := 7:
	set(v):
		count = clampi(v, 1, 60)
		_scatter()
@export var margin := 48.0
@export var ceiling := 160.0
@export var seed_value := 1:
	set(v):
		seed_value = v
		_scatter()

var _p: Array = []   # [pos, vel, rot, spin, tex_idx]
var _fans := []
var _t := 0.0


func _ready() -> void:
	_scatter()
	if not Engine.is_editor_hint():
		_fans = Ix.fans_of(self)


func _scatter() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 7919 + int(kind) * 31
	_p.clear()
	for i in count:
		var y := 0.0 if kind != Kind.DUST else -rng.randf_range(2.0, 40.0)
		_p.append([Vector2(rng.randf() * width, y), Vector2.ZERO, rng.randf_range(-0.3, 0.3), 0.0, rng.randi() % 3])
	queue_redraw()


func _physics_process(delta: float) -> void:
	_t += delta
	if Engine.is_editor_hint():
		return
	var pl := Ix.player_of(self)
	var pp := Vector2.INF
	var pv := Vector2.ZERO
	if pl and Ix.state_of(pl) != -1:
		pp = pl.global_position - global_position
		pv = pl.velocity
	var near := pp.x > -margin - 60.0 and pp.x < width + margin + 60.0 and pp.y > -ceiling - 60.0 and pp.y < 60.0
	var any_wind := false
	var light := 1.0 if kind == Kind.PAPER else (1.3 if kind == Kind.LEAF else 0.5)
	for q in _p:
		var pos: Vector2 = q[0]
		var vel: Vector2 = q[1]
		var w := Ix.wind_at(_fans, global_position + pos) if not _fans.is_empty() else Vector2.ZERO
		if w != Vector2.ZERO:
			any_wind = true
			vel += w * 0.05 * light * delta * 10.0
			vel += Vector2(sin(_t * 9.0 + pos.x), cos(_t * 7.0 + pos.y)) * 30.0 * delta
		if near:
			var d := pos - pp
			var r := 34.0 if kind != Kind.DUST else 48.0
			if d.length() < r and pv.length() > 50.0:
				var push := (pv * 0.6 + d.normalized() * 60.0) * (1.0 - d.length() / r)
				vel += push * light * delta * 8.0
				vel.y -= 60.0 * light * delta * 8.0
				q[3] = randf_range(-8.0, 8.0)
		# Gravity + air drag; dust just hovers and drifts.
		if kind == Kind.DUST:
			vel *= 1.0 - 1.5 * delta
			vel.y += sin(_t * 1.3 + pos.x * 0.1) * 6.0 * delta
		else:
			vel.y += 260.0 * delta
			vel *= 1.0 - 2.2 * delta
			vel.x += sin(_t * 6.0 + pos.x * 0.2) * absf(vel.y) * 0.4 * delta
		pos += vel * delta
		if pos.y >= 0.0 and kind != Kind.DUST:
			pos.y = 0.0
			vel.y = minf(vel.y, 0.0)
			vel.x *= 1.0 - 8.0 * delta
			q[3] = move_toward(q[3], 0.0, 20.0 * delta)
			q[2] = move_toward(q[2], 0.0, 2.0 * delta)
		pos.y = clampf(pos.y, -ceiling, 0.0 if kind != Kind.DUST else -1.0)
		if pos.x < -margin or pos.x > width + margin:
			pos.x = clampf(pos.x, -margin, width + margin)
			vel.x *= -0.4
		q[2] += q[3] * delta
		q[0] = pos
		q[1] = vel
	if near or any_wind or kind == Kind.DUST:
		queue_redraw()


func _draw() -> void:
	for q in _p:
		var pos: Vector2 = (q[0] as Vector2).round()
		match kind:
			Kind.PAPER:
				var tex := TEX_PAPER[int(q[4]) % 3]
				draw_set_transform(pos + Vector2(0, -2), q[2])
				draw_texture(tex, -tex.get_size() / 2.0 + Vector2(0, 0))
				draw_set_transform(Vector2.ZERO)
			Kind.LEAF:
				var tex2 := TEX_LEAF[int(q[4]) % 2]
				draw_set_transform(pos + Vector2(0, -2), q[2])
				draw_texture(tex2, -tex2.get_size() / 2.0)
				draw_set_transform(Vector2.ZERO)
			Kind.DUST:
				var a := 0.35 + 0.25 * sin(_t * 2.0 + pos.x)
				draw_rect(Rect2(pos, Vector2.ONE), Color(0.78, 0.86, 0.95, a))
