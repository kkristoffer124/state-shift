@tool
class_name TdDrain
extends Node2D
## Floor drain (one 32x32 cell, ORIGIN = top-left of the cell).
## WATER that flows onto a drain with a `target` squeezes down the pipe and pops
## out of the target drain. Link both ends to each other for a two-way pipe.
## Drains of the same pipe share a `tint` ring so the player can match them.
## ICE slides over drains, STEAM floats over them.

const TEX := preload("res://assets/topdown/td_drain.png")
## How close (px) the blob's centre must get to the drain's centre to be sucked in.
const RADIUS := 10.0

@export var target: NodePath:
	set(v):
		target = v
		queue_redraw()
@export var tint := Color("66ccff"):
	set(v):
		tint = v
		queue_redraw()

var _t := 0.0
var _gulp := 0.0


func _ready() -> void:
	z_index = 1
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
	queue_redraw()


func _draw() -> void:
	var linked := not target.is_empty()
	var ring := tint if linked else Color(0.5, 0.55, 0.6)
	# soft glow + coloured collar marks which drains connect
	if linked:
		var a := 0.25 + 0.15 * sin(_t * 3.0) + _gulp * 0.5
		draw_circle(Vector2(16, 16), 17.0, Color(ring, a * 0.35))
	draw_texture(TEX, Vector2.ZERO)
	if linked:
		for i in 12:
			var ang := TAU * i / 12.0 + _t * 0.6
			var p := (Vector2(16, 16) + Vector2(cos(ang), sin(ang)) * 13.5).floor()
			draw_rect(Rect2(p, Vector2(2, 2)), Color(ring, 0.9))
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
