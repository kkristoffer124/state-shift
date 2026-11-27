extends Node2D
## Wet spots and ripple rings WATER leaves on the floor (td_player.tscn -> Visual/WetTrail).
## Drawn in world space (top_level) just above the floor. Spots dry out smoothly
## (ease-out shrink + fade); rings expand as flattened ellipses and fade.

const MAX_SPOTS := 90
const MAX_RINGS := 24

var _pos := PackedVector2Array()
var _size := PackedFloat32Array()
var _age := PackedFloat32Array()
var _life := PackedFloat32Array()
## rings: centre, start radius, end radius, age, life
var _rpos := PackedVector2Array()
var _r0 := PackedFloat32Array()
var _r1 := PackedFloat32Array()
var _rage := PackedFloat32Array()
var _rlife := PackedFloat32Array()


func _ready() -> void:
	top_level = true
	global_position = Vector2.ZERO
	z_as_relative = false
	z_index = 1


func add_spot(p: Vector2, radius: float, life: float) -> void:
	if _pos.size() >= MAX_SPOTS:
		_pos.remove_at(0)
		_size.remove_at(0)
		_age.remove_at(0)
		_life.remove_at(0)
	_pos.append(p.round())
	_size.append(radius)
	_age.append(0.0)
	_life.append(life)


func add_ring(p: Vector2, r_from: float, r_to: float, life: float) -> void:
	if _rpos.size() >= MAX_RINGS:
		_rpos.remove_at(0)
		_r0.remove_at(0)
		_r1.remove_at(0)
		_rage.remove_at(0)
		_rlife.remove_at(0)
	_rpos.append(p.round())
	_r0.append(r_from)
	_r1.append(r_to)
	_rage.append(0.0)
	_rlife.append(life)


func _process(delta: float) -> void:
	var i := 0
	while i < _pos.size():
		_age[i] += delta
		if _age[i] >= _life[i]:
			_pos.remove_at(i)
			_size.remove_at(i)
			_age.remove_at(i)
			_life.remove_at(i)
		else:
			i += 1
	i = 0
	while i < _rpos.size():
		_rage[i] += delta
		if _rage[i] >= _rlife[i]:
			_rpos.remove_at(i)
			_r0.remove_at(i)
			_r1.remove_at(i)
			_rage.remove_at(i)
			_rlife.remove_at(i)
		else:
			i += 1
	queue_redraw()


func _draw() -> void:
	for i in _pos.size():
		var u := _age[i] / _life[i]
		# fresh spots hold, then dry out with an ease (no linear pop at the end)
		var k := 1.0 - smoothstep(0.15, 1.0, u)
		var r := maxf(_size[i] * (0.55 + 0.45 * k), 1.0)
		# squashed disc (seen from above at a slant), pixel-stepped rows
		var rows := int(ceil(r * 0.6))
		for y in range(-rows, rows + 1):
			var w := floorf(r * sqrt(maxf(1.0 - pow(float(y) / (r * 0.6 + 0.01), 2.0), 0.0)))
			if w < 1.0:
				continue
			draw_rect(Rect2(_pos[i].x - w, _pos[i].y + y, w * 2.0, 1), Color(0.22, 0.5, 0.95, 0.38 * k))
		draw_rect(Rect2(_pos[i] + Vector2(-r * 0.4, -rows + 1).floor(), Vector2(2, 1)), Color(0.75, 0.88, 1.0, 0.45 * k))
	for i in _rpos.size():
		var u := _rage[i] / _rlife[i]
		var e := 1.0 - pow(1.0 - u, 2.0)
		var r := lerpf(_r0[i], _r1[i], e)
		var a := 0.6 * (1.0 - u) * (1.0 - u)
		draw_set_transform(_rpos[i], 0.0, Vector2(1.0, 0.55))
		draw_arc(Vector2.ZERO, r, 0.0, TAU, maxi(12, int(r * 1.5)), Color(0.75, 0.9, 1.0, a), 1.0)
	draw_set_transform(Vector2.ZERO)
