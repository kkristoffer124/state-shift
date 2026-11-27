@tool
class_name TdBars
extends StaticBody2D
## Top-down barrier that sorts the states. ORIGIN = top-left; `size` in px.
##  BARS  a row of iron posts: stops ICE; WATER slips between them, STEAM drifts through
##  MESH  a fine vent grille: stops ICE and WATER; only STEAM drifts through
## The posts run along the longer side of `size`.

enum Kind { BARS, MESH }

const LAYER_BARS := 2   # in TdPlayer's ICE mask only
const LAYER_MESH := 64  # in TdPlayer's ICE and WATER masks
const POST_H := 16.0

@export var kind: Kind = Kind.BARS:
	set(v):
		kind = v
		_refresh()
@export var size := Vector2(32, 96):
	set(v):
		size = v.max(Vector2(8, 8))
		_refresh()

var _theme := "lab"
var _t := 0.0
## Optional overlay child (td_bars.tscn / td_mesh.tscn -> Shimmer): a glint that sweeps
## along the metal now and then. Redrawn per frame; the heavy grille art is not.
@onready var _shimmer: Node2D = get_node_or_null("Shimmer") as Node2D


func _ready() -> void:
	_refresh()
	if _shimmer:
		_shimmer.draw.connect(_draw_shimmer)
	_t = fmod(global_position.x * 0.013 + global_position.y * 0.007, 4.0)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _shimmer == null:
		return
	_t += delta
	_shimmer.queue_redraw()


func _refresh() -> void:
	if not is_inside_tree():
		return
	collision_layer = LAYER_BARS if kind == Kind.BARS else LAYER_MESH
	collision_mask = 0
	z_index = 2
	_theme = EnvTheme.find_theme(self)
	var cs := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs and cs.shape is RectangleShape2D:
		(cs.shape as RectangleShape2D).size = size
		cs.position = size / 2.0
	queue_redraw()


func _metal() -> Array[Color]:
	if _theme == "sewer":
		return [Color("2b3a35"), Color("6f8f80"), Color("a9c7b6"), Color("7a4a2c")]
	return [Color("27313d"), Color("7d93ab"), Color("c9dcef"), Color("5a6a7c")]


func _draw() -> void:
	var m := _metal()
	var vertical := size.y > size.x
	# floor track
	var track := Rect2(size.x / 2.0 - 3.0, 0, 6, size.y) if vertical else Rect2(0, size.y / 2.0 - 3.0, size.x, 6)
	draw_rect(track, Color(0, 0, 0, 0.35))
	draw_rect(track.grow(-1), m[0])
	if kind == Kind.BARS:
		_draw_bars(m, vertical)
	else:
		_draw_mesh(m, vertical)


func _draw_bars(m: Array[Color], vertical: bool) -> void:
	var n := maxi(2, int((size.y if vertical else size.x) / 8.0))
	var length := size.y if vertical else size.x
	var step := length / n
	for i in n:
		var base: Vector2
		if vertical:
			base = Vector2(size.x / 2.0, (i + 0.5) * step)
		else:
			base = Vector2((i + 0.5) * step, size.y / 2.0)
		base = base.round()
		# post seen in 3/4: a 3 px column rising POST_H above its foot, shadow at the foot
		draw_rect(Rect2(base + Vector2(-1, 0), Vector2(5, 2)), Color(0, 0, 0, 0.45))
		draw_rect(Rect2(base + Vector2(-2, -POST_H), Vector2(4, POST_H)), m[0])
		draw_rect(Rect2(base + Vector2(-1, -POST_H), Vector2(2, POST_H)), m[1])
		draw_rect(Rect2(base + Vector2(-1, -POST_H), Vector2(1, POST_H - 2)), m[2])
		draw_rect(Rect2(base + Vector2(-2, -POST_H - 1), Vector2(4, 2)), m[2])
		if _theme == "sewer" and (i * 7) % 3 == 0:
			draw_rect(Rect2(base + Vector2(0, -POST_H * 0.5), Vector2(1, 3)), m[3])
	# top rail tying the posts together
	if vertical:
		draw_rect(Rect2(size.x / 2.0 - 2.0, -POST_H - 2.0, 4, 3), m[0])
		draw_rect(Rect2(size.x / 2.0 - 2.0, size.y - POST_H - 2.0, 4, 3), m[0])
	else:
		draw_rect(Rect2(0, size.y / 2.0 - POST_H - 2.0, size.x, 3), m[0])
		draw_rect(Rect2(0, size.y / 2.0 - POST_H - 2.0, size.x, 1), m[2])


func _draw_mesh(m: Array[Color], vertical: bool) -> void:
	# a thin standing grille panel: frame + diamond mesh, seen from the south
	var panel: Rect2
	if vertical:
		panel = Rect2(size.x / 2.0 - 6.0, -POST_H * 0.5, 12, size.y + POST_H * 0.5)
	else:
		panel = Rect2(0, size.y / 2.0 - POST_H, size.x, POST_H + 2.0)
	draw_rect(panel, Color(m[0], 0.55))
	var p0 := panel.position
	for y in int(panel.size.y):
		for x in int(panel.size.x):
			if (x + y) % 4 == 0 or (x - y + 400) % 4 == 0:
				draw_rect(Rect2(p0 + Vector2(x, y), Vector2.ONE), Color(m[1], 0.8))
	draw_rect(Rect2(panel.position, Vector2(panel.size.x, 2)), m[2])
	draw_rect(Rect2(panel.position.x, panel.end.y - 1, panel.size.x, 1), m[0])
	if not vertical:
		draw_rect(Rect2(panel.position, Vector2(2, panel.size.y)), m[1])
		draw_rect(Rect2(panel.end.x - 2, panel.position.y, 2, panel.size.y), m[0])
		# little "steam only" vent arrows
		for x in range(12, int(size.x) - 8, 32):
			draw_rect(Rect2(x, panel.position.y + 5, 6, 1), Color("dff2ff", 0.8))
			draw_rect(Rect2(x + 1, panel.position.y + 4, 4, 1), Color("dff2ff", 0.8))
			draw_rect(Rect2(x + 2, panel.position.y + 3, 2, 1), Color("dff2ff", 0.8))


## Sweep position 0..1 along the long side (or < 0 while resting between sweeps).
func _sweep() -> float:
	var period := 3.6
	var u := fmod(_t, period) / 1.1
	return u if u <= 1.0 else -1.0


func _draw_shimmer() -> void:
	var vertical := size.y > size.x
	var length := size.y if vertical else size.x
	var u := _sweep()
	var m := _metal()
	if kind == Kind.BARS:
		var n := maxi(2, int(length / 8.0))
		var step := length / n
		for i in n:
			var base: Vector2
			if vertical:
				base = Vector2(size.x / 2.0, (i + 0.5) * step)
			else:
				base = Vector2((i + 0.5) * step, size.y / 2.0)
			base = base.round()
			var d := absf((i + 0.5) / n - u) * n
			if u < 0.0 or d > 1.5:
				continue
			var a := 0.75 * (1.0 - d / 1.5)
			# glint runs down the lit edge of the post
			var y0 := -POST_H + roundf(fmod(_t * 40.0 + i * 3.0, POST_H - 3.0))
			_shimmer.draw_rect(Rect2(base + Vector2(-1, y0), Vector2(2, 3)), Color(1, 1, 1, a))
			_shimmer.draw_rect(Rect2(base + Vector2(-2, -POST_H - 1), Vector2(4, 1)), Color(m[2].lightened(0.5), a))
	else:
		var panel: Rect2
		if vertical:
			panel = Rect2(size.x / 2.0 - 6.0, -POST_H * 0.5, 12, size.y + POST_H * 0.5)
		else:
			panel = Rect2(0, size.y / 2.0 - POST_H, size.x, POST_H + 2.0)
		# faint heat-haze flicker of air leaking through the vent
		for i in 3:
			var ph := fmod(_t * 0.7 + i * 0.33, 1.0)
			var along := ph * (panel.size.y if vertical else panel.size.x)
			var a := 0.12 * sin(ph * PI)
			if vertical:
				_shimmer.draw_rect(Rect2(panel.position.x + 1, panel.position.y + along, panel.size.x - 2, 1), Color(0.85, 0.95, 1.0, a))
			else:
				_shimmer.draw_rect(Rect2(panel.position.x + along, panel.position.y + 2, 1, panel.size.y - 3), Color(0.85, 0.95, 1.0, a))
		if u < 0.0:
			return
		# diagonal glint band sweeping along the grille
		var span := panel.size.y if vertical else panel.size.x
		var head := u * (span + 16.0) - 8.0
		var across := int(panel.size.x if vertical else panel.size.y)
		for j in across:
			for w in 3:
				var q := Vector2(j, head + j * 0.6 + w) if vertical else Vector2(head + j * 0.6 + w, j)
				if q.x < 0.0 or q.x >= panel.size.x or q.y < 0.0 or q.y >= panel.size.y:
					continue
				_shimmer.draw_rect(Rect2(panel.position + q.floor(), Vector2.ONE), Color(1, 1, 1, 0.35 - w * 0.1))
