@tool
class_name TdDrain
extends Node2D
## Floor drain (one 32x32 cell, ORIGIN = top-left of the cell).
## WATER that flows onto a drain with a `target` squeezes down the pipe and pops
## out of the target drain. Link both ends to each other for a two-way pipe.
## Drains of the same pipe share a `tint`; the grate art with the nearest ring colour
## (magenta / yellow / violet / white) is used, so set tint to one of RING_COLORS.
## ICE slides over drains, STEAM floats over them.

const TEX_RINGS: Array[Texture2D] = [
	preload("res://assets/topdown/tex/t19_drain_magenta.png"),
	preload("res://assets/topdown/tex/t19_drain_yellow.png"),
	preload("res://assets/topdown/tex/t19_drain_violet.png"),
	preload("res://assets/topdown/tex/t19_drain_white.png"),
]
## Ring colours of TEX_RINGS (sampled from the art).
const RING_COLORS: Array[Color] = [Color8(224, 107, 208), Color8(242, 194, 48), Color8(154, 123, 255), Color8(242, 247, 255)]
## How close (px) the blob's centre must get to the drain's centre to be sucked in.
const RADIUS := 10.0

@export var target: NodePath:
	set(v):
		target = v
		queue_redraw()
@export var tint := Color8(242, 247, 255):
	set(v):
		tint = v
		_ring = _nearest_ring(v)
		queue_redraw()

var _t := 0.0
var _gulp := 0.0
var _spin := 0.0
var _ring := 3


static func _nearest_ring(c: Color) -> int:
	var best := 0
	var bd := INF
	for i in RING_COLORS.size():
		var r := RING_COLORS[i]
		var d := Vector3(r.r - c.r, r.g - c.g, r.b - c.b).length_squared()
		if d < bd:
			bd = d
			best = i
	return best


func _ready() -> void:
	z_index = 1
	_ring = _nearest_ring(tint)
	if not Engine.is_editor_hint():
		add_to_group("td_drain")


func center() -> Vector2:
	return global_position + Vector2(16, 16)


func target_drain() -> TdDrain:
	if target.is_empty():
		return null
	return get_node_or_null(target) as TdDrain


## Called by the player when it goes down (or comes up) this drain.
func gulp() -> void:
	_gulp = 1.0


func _process(delta: float) -> void:
	_t += delta
	_gulp = maxf(_gulp - delta * 2.0, 0.0)
	_spin += delta * (2.2 + _gulp * 16.0)
	queue_redraw()


func _draw() -> void:
	var linked := not target.is_empty()
	var ring := RING_COLORS[_ring] if linked else Color(0.5, 0.55, 0.6)
	# soft glow under the grate marks which drains connect
	if linked:
		var a := 0.25 + 0.15 * sin(_t * 3.0) + _gulp * 0.5
		draw_circle(Vector2(16, 16), 16.0, Color(ring, a * 0.35))
	draw_texture(TEX_RINGS[_ring], Vector2.ZERO, Color.WHITE if linked else Color(0.6, 0.62, 0.66))
	if linked:
		# whirlpool: three spiral arms turning in the grate (spin up when gulping)
		var hi := ring.lightened(0.45)
		for arm in 3:
			for j in 6:
				var rr := 2.0 + j * 1.5
				var ang := arm * TAU / 3.0 + _spin + j * 0.55
				var sp := (Vector2(16, 16) + Vector2(cos(ang), sin(ang)) * rr).floor()
				var dsz := Vector2(2, 2) if j < 2 else Vector2.ONE
				draw_rect(Rect2(sp, dsz), Color(hi, (0.8 - j * 0.11) * (0.6 + _gulp * 0.4)))
		draw_rect(Rect2(15, 15, 2, 2), Color(0, 0, 0, 0.6))
		# a glint running round the coloured collar
		var ga := _t * 1.6
		for i in 3:
			var p := (Vector2(15.5, 15.5) + Vector2(cos(ga - i * 0.18), sin(ga - i * 0.18)) * 12.5).floor()
			draw_rect(Rect2(p, Vector2.ONE), Color(1, 1, 1, 0.8 - i * 0.25))
		# bubbles rising from the pipe now and then
		for i in 2:
			var ph := fmod(_t * 0.8 + i * 0.5, 1.0)
			var bp := Vector2(13 + i * 6, 18 - ph * 8.0).round()
			draw_rect(Rect2(bp, Vector2(2, 2)), Color(ring.lightened(0.5), 1.0 - ph))
	if _gulp > 0.0:
		draw_circle(Vector2(16, 16), 6.0 + (1.0 - _gulp) * 10.0, Color(Ix.C_WATER_HI, _gulp * 0.6), false, 2.0)
	if Engine.is_editor_hint() and linked:
		var t := get_node_or_null(target) as Node2D
		if t:
			draw_line(Vector2(16, 16), to_local(t.global_position) + Vector2(16, 16), Color(ring, 0.6), 1.0)
