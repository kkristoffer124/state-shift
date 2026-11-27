@tool
class_name TdGate
extends StaticBody2D
## Top-down shutter (collision layer 1, like walls). ORIGIN = top-left; `size` in px.
## Closed it stands up like a short wall (striped top + south face); opened by
## `channel` it sinks into a floor slot. Never closes onto the player.

const TEX_TILE := preload("res://assets/interactive/ix_gate_tile.png") # 24x32 shutter panel
const RISE := 14.0

@export var channel := "a"
@export var size := Vector2(32, 32):
	set(v):
		size = v.max(Vector2(8, 8))
		_refresh()
## Open when the channel is OFF instead.
@export var inverted := false
@export var duration := 0.5
@export var preview_open := false:
	set(v):
		preview_open = v
		if Engine.is_editor_hint():
			_open = 1.0 if v else 0.0
			queue_redraw()

var is_open := false
var _open := 0.0
var _sources := {}
var _t := 0.0
## Cosmetic dust puffs kicked up along the slot while the shutter moves: [pos, vel, age].
var _dust: Array = []
var _moving_prev := false


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	z_index = 1
	_refresh()
	if Engine.is_editor_hint():
		return
	Ix.listen(self, channel)
	if inverted:
		is_open = true
		_open = 1.0
		_apply()


func _refresh() -> void:
	if not is_inside_tree():
		return
	var cs := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs and cs.shape is RectangleShape2D:
		(cs.shape as RectangleShape2D).size = size
		cs.position = size / 2.0
	queue_redraw()


func _on_channel(source_id: int, on: bool) -> void:
	if on:
		_sources[source_id] = true
	else:
		_sources.erase(source_id)
	var want := (_sources.size() > 0) != inverted
	if want != is_open:
		is_open = want
		if has_node("/root/Sfx"):
			get_node("/root/Sfx").play("heat" if is_open else "cool")


func _apply() -> void:
	var cs := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs:
		cs.set_deferred("disabled", _open > 0.6)
	queue_redraw()


func _player_inside() -> bool:
	var p := Ix.player_of(self)
	if p == null:
		return false
	return Rect2(global_position, size).grow(2.0).intersects(Rect2(p.global_position - Vector2(14, 14), Vector2(28, 28)))


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_t += delta
	_update_dust(delta)
	var target := 1.0 if is_open else 0.0
	if not is_equal_approx(_open, target):
		if target < _open and _player_inside():
			return # hold open: never squash the player
		_open = move_toward(_open, target, delta / maxf(duration, 0.05))
		_apply()
		_kick_dust(1 if randf() < 0.5 else 0)
		_moving_prev = true
		if is_equal_approx(_open, target):
			_kick_dust(6) # thunk at the end of travel
	else:
		_moving_prev = false
		if is_open or not _dust.is_empty():
			queue_redraw() # lamp blink / settling dust


func _kick_dust(n: int) -> void:
	if _dust.size() > 40:
		return
	for i in n:
		var along := randf() * maxf(size.x, size.y)
		var p := Vector2(along, size.y) if size.x >= size.y else Vector2(size.x * (0.0 if randf() < 0.5 else 1.0), along)
		var v := Vector2(randf_range(-14, 14), randf_range(-16, -4))
		if size.x < size.y:
			v.x = (randf_range(6, 16) if p.x > 0.0 else -randf_range(6, 16))
		_dust.append([p, v, 0.0])


func _update_dust(delta: float) -> void:
	var i := 0
	while i < _dust.size():
		var d: Array = _dust[i]
		d[2] += delta
		if d[2] > 0.5:
			_dust.remove_at(i)
			continue
		d[0] += d[1] * delta
		d[1] *= exp(-5.0 * delta)
		i += 1


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	# floor slot (always visible; the shutter sinks into it)
	draw_rect(r, Color("0b1016"))
	draw_rect(Rect2(0, 0, size.x, 2), Color("26323f"))
	draw_rect(Rect2(0, size.y - 1, size.x, 1), Color("4a5a6c"))
	var eo := _open * _open * (3.0 - 2.0 * _open) # smoothstep: eases in and out of travel
	var h := roundf(RISE * (1.0 - eo))
	var lamp := Ix.C_GOAL if is_open else Color("ff4a5a")
	if h > 0.5:
		var top := Rect2(0, -h, size.x, size.y)
		var face := Rect2(0, size.y - h, size.x, h)
		# top: shutter slats (panel art rotated when wide)
		var vertical := size.y >= size.x
		if vertical:
			var y := 0.0
			while y < top.size.y:
				var ch := minf(32.0, top.size.y - y)
				for x0 in range(0, int(size.x), 24):
					var cw := minf(24.0, size.x - x0)
					draw_texture_rect_region(TEX_TILE, Rect2(x0, top.position.y + y, cw, ch), Rect2(0, 0, cw, ch))
				y += 32.0
		else:
			draw_set_transform(Vector2(0, top.end.y), -PI / 2.0)
			var x := 0.0
			while x < size.x:
				var cw := minf(32.0, size.x - x)
				for y0 in range(0, int(size.y), 24):
					var chh := minf(24.0, size.y - y0)
					draw_texture_rect_region(TEX_TILE, Rect2(y0, x, chh, cw), Rect2(0, 0, chh, cw))
				x += 32.0
			draw_set_transform(Vector2.ZERO)
		# hazard stripes along the top edge
		for i in int(size.x / 4.0):
			if i % 2 == 0:
				draw_rect(Rect2(i * 4, top.position.y, 4, 3), Color("e0b43a"))
			else:
				draw_rect(Rect2(i * 4, top.position.y, 4, 3), Color("1a1a1a"))
		draw_rect(Rect2(0, top.position.y, size.x, 1), Color("f4f8ff", 0.6))
		# south face
		draw_rect(face, Color("2c3a4a"))
		draw_rect(Rect2(face.position.x, face.position.y, face.size.x, 1), Color("9ebcdb"))
		draw_rect(Rect2(face.position.x, face.end.y - 1, face.size.x, 1), Color("0e151d"))
		draw_rect(Rect2(size.x / 2.0 - 2.0, face.position.y + h * 0.4, 4, 2), lamp)
	else:
		# open: green guide lights in the slot
		var blink := 0.6 + 0.4 * sin(_t * 5.0)
		for i in range(4, int(maxf(size.x, size.y)), 10):
			var p := Vector2(i, size.y / 2.0 - 1.0) if size.x >= size.y else Vector2(size.x / 2.0 - 1.0, i)
			draw_rect(Rect2(p, Vector2(2, 2)), Color(lamp, blink))
	for d in _dust:
		var k: float = d[2] / 0.5
		var sz := 1.0 if k > 0.6 else 2.0
		draw_rect(Rect2((d[0] as Vector2).round(), Vector2(sz, sz)), Color(0.75, 0.72, 0.65, 0.6 * (1.0 - k)))
