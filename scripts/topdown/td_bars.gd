@tool
class_name TdBars
extends StaticBody2D
## Top-down barrier that sorts the states. ORIGIN = top-left; `size` in px.
##  BARS  a row of iron posts: stops ICE; WATER slips between them, STEAM drifts through
##  MESH  a fine vent grille: stops ICE and WATER; only STEAM drifts through
## The posts run along the longer side of `size`; art t17_bars_h/v and t18_vent_mesh_h/v,
## one 32x32 tile per cell along that side.

enum Kind { BARS, MESH }

const LAYER_BARS := 2   # in TdPlayer's ICE mask only
const LAYER_MESH := 64  # in TdPlayer's ICE and WATER masks
const TEX_BARS_H := preload("res://assets/topdown/tex/t17_bars_h.png")
const TEX_BARS_V := preload("res://assets/topdown/tex/t17_bars_v.png")
const TEX_MESH_H := preload("res://assets/topdown/tex/t18_vent_mesh_h.png")
const TEX_MESH_V := preload("res://assets/topdown/tex/t18_vent_mesh_v.png")
## Post knobs per 32 px tile in the bars art (centres at 4, 12, 20, 28).
const POSTS_PER_TILE := 4

@export var kind: Kind = Kind.BARS:
	set(v):
		kind = v
		_refresh()
@export var size := Vector2(32, 96):
	set(v):
		size = v.max(Vector2(8, 8))
		_refresh()

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
	var cs := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs and cs.shape is RectangleShape2D:
		(cs.shape as RectangleShape2D).size = size
		cs.position = size / 2.0
	queue_redraw()


func _draw() -> void:
	var vertical := size.y > size.x
	var tex: Texture2D
	if kind == Kind.BARS:
		tex = TEX_BARS_V if vertical else TEX_BARS_H
	else:
		tex = TEX_MESH_V if vertical else TEX_MESH_H
	var length := size.y if vertical else size.x
	var across := size.x if vertical else size.y
	var n := maxi(1, ceili(length / 32.0))
	for i in n:
		var p := Vector2((across - 32.0) * 0.5, i * 32.0) if vertical else Vector2(i * 32.0, (across - 32.0) * 0.5)
		draw_texture(tex, p.round())


## Grille panel rect of the vent mesh art (cols / rows 9..23 across the tile).
func _panel() -> Rect2:
	if size.y > size.x:
		return Rect2(size.x / 2.0 - 7.0, 0, 14, size.y)
	return Rect2(0, size.y / 2.0 - 7.0, size.x, 14)


## Sweep position 0..1 along the long side (or < 0 while resting between sweeps).
func _sweep() -> float:
	var period := 3.6
	var u := fmod(_t, period) / 1.1
	return u if u <= 1.0 else -1.0


func _draw_shimmer() -> void:
	var vertical := size.y > size.x
	var length := size.y if vertical else size.x
	var u := _sweep()
	if kind == Kind.BARS:
		# a glint hops along the post knobs
		var n := maxi(1, ceili(length / 32.0)) * POSTS_PER_TILE
		for i in n:
			var along := i * 8.0 + 4.0
			var d := absf((i + 0.5) / n - u) * n
			if u < 0.0 or d > 1.5:
				continue
			var a := 0.85 * (1.0 - d / 1.5)
			var c := Vector2(size.x / 2.0, along) if vertical else Vector2(along, size.y / 2.0)
			_shimmer.draw_rect(Rect2(c.round() + Vector2(-2, -2), Vector2(2, 1)), Color(1, 1, 1, a))
			_shimmer.draw_rect(Rect2(c.round() + Vector2(-2, -1), Vector2(1, 1)), Color(1, 1, 1, a * 0.6))
	else:
		var panel := _panel()
		# faint haze of air leaking through the vent
		for i in 3:
			var ph := fmod(_t * 0.7 + i * 0.33, 1.0)
			var along := ph * (panel.size.y if vertical else panel.size.x)
			var a := 0.12 * sin(ph * PI)
			if vertical:
				_shimmer.draw_rect(Rect2(panel.position.x + 1, panel.position.y + along, panel.size.x - 2, 1), Color(0.85, 0.95, 1.0, a))
			else:
				_shimmer.draw_rect(Rect2(panel.position.x + along, panel.position.y + 1, 1, panel.size.y - 2), Color(0.85, 0.95, 1.0, a))
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
				_shimmer.draw_rect(Rect2(panel.position + q.floor(), Vector2.ONE), Color(1, 1, 1, 0.3 - w * 0.09))
