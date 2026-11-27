@tool
extends TextureRect
## Title logo: water beads swell at the tips of the dripping "SHIFT" letters and fall off.
## Tip positions are in logo texture pixels; the logo uses keep-aspect-centered stretch.

@export var tips: PackedVector2Array = [Vector2(678, 247), Vector2(762, 299), Vector2(846, 239), Vector2(914, 255), Vector2(982, 291)]
@export var interval := Vector2(0.9, 2.2)

var _bead := -1
var _grow := 0.0
var _wait := 1.0


func _tip_local(i: int) -> Vector2:
	var ts := texture.get_size()
	var s := minf(size.x / ts.x, size.y / ts.y)
	var off := (size - ts * s) / 2.0
	return (off + tips[i] * s).round()


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or texture == null or not is_visible_in_tree():
		return
	var fx := get_node_or_null("/root/UiFx")
	if fx == null or not fx.full():
		if _bead >= 0:
			_bead = -1
			queue_redraw()
		return
	if _bead < 0:
		_wait -= delta
		if _wait <= 0.0:
			_bead = randi() % tips.size()
			_grow = 0.0
		return
	_grow += delta / 0.9
	if _grow >= 1.0:
		fx.drip(self, get_global_transform() * (_tip_local(_bead) + Vector2(0, 2)), 1)
		_bead = -1
		_wait = randf_range(interval.x, interval.y)
	queue_redraw()


func _draw() -> void:
	if _bead < 0 or texture == null:
		return
	var p := _tip_local(_bead)
	var r := roundf(_grow * 2.0)
	var c := Color(0.36, 0.66, 1.0)
	draw_rect(Rect2(p + Vector2(-r / 2.0, 0), Vector2(maxf(r, 1.0) + 1.0, roundf(_grow * 3.0) + 1.0)), c)
	draw_rect(Rect2(p + Vector2(-r / 2.0, 0), Vector2.ONE), Color(1, 1, 1, 0.8))
