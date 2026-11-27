extends Node2D
## Wet spots WATER leaves on the floor (td_player.tscn -> Visual/WetTrail).
## Drawn in world space (top_level) just above the floor; each spot shrinks and fades.

const MAX_SPOTS := 90

var _pos := PackedVector2Array()
var _size := PackedFloat32Array()
var _age := PackedFloat32Array()
var _life := PackedFloat32Array()


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
	queue_redraw()


func _draw() -> void:
	for i in _pos.size():
		var k := 1.0 - _age[i] / _life[i]
		var r := maxf(_size[i] * (0.5 + 0.5 * k), 1.0)
		# squashed disc (seen from above at a slant), pixel-stepped rows
		var rows := int(ceil(r * 0.6))
		for y in range(-rows, rows + 1):
			var w := floorf(r * sqrt(maxf(1.0 - pow(float(y) / (r * 0.6 + 0.01), 2.0), 0.0)))
			if w < 1.0:
				continue
			draw_rect(Rect2(_pos[i].x - w, _pos[i].y + y, w * 2.0, 1), Color(0.22, 0.5, 0.95, 0.38 * k))
		draw_rect(Rect2(_pos[i] + Vector2(-r * 0.4, -rows + 1).floor(), Vector2(2, 1)), Color(0.75, 0.88, 1.0, 0.45 * k))
