@tool
class_name CutsceneSteam
extends Node2D
## The in-game steam look for cutscenes: the FluidBody pixel cloud (4x4 pixels on a
## spread 2 px lattice, white core fading to blue-grey edges) with the core glow,
## centred on this node. Pixels wobble around their home slots instead of being
## simulated, so it costs nothing and scrubs cleanly in the editor.

const CELL := 2
const C_STEAM := Color("f2f7ff")
const C_STEAM_EDGE := Color("c5d3e6")
const TEX_CORE_GLOW := preload("res://assets/player/p3d_core_glow.png")

## Number of cloud pixels (FluidBody uses 80).
@export var pixels := 80:
	set(v):
		pixels = v
		_build()
## Wobble amplitude in pixels.
@export var wobble := 1.6
@export var wobble_hz := 1.1
@export var core_glow := true

var _homes := PackedVector2Array()
var _phase := PackedFloat32Array()
var _t := 0.0


func _ready() -> void:
	_build()


func _build() -> void:
	var cells: Array[Vector2] = []
	for y in range(-12, 13):
		for x in range(-12, 13):
			cells.append(Vector2(x, y) * CELL)
	cells.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.length_squared() < b.length_squared())
	_homes.clear()
	_phase.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 47
	for i in mini(pixels, cells.size()):
		_homes.append(cells[i] * (1.0 + 1.6 * (cells[i].length() / 24.0)))
		_phase.append(rng.randf() * TAU)
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	if is_visible_in_tree():
		queue_redraw()


func _draw() -> void:
	if _homes.is_empty():
		return
	var r2 := maxf(_homes[_homes.size() - 1].length(), 1.0)
	var w := _t * TAU * wobble_hz
	for i in _homes.size():
		var h := _homes[i]
		var edge := clampf(h.length() / r2, 0.0, 1.0)
		var col := C_STEAM.lerp(C_STEAM_EDGE, edge)
		col.a = 0.9 - edge * 0.5
		var ph := _phase[i]
		var p := h + Vector2(sin(w + ph), cos(w * 0.8 + ph * 1.7)) * wobble * (0.4 + edge)
		draw_rect(Rect2(p.round() - Vector2(2, 2), Vector2(4, 4)), col)
	if core_glow:
		draw_texture(TEX_CORE_GLOW, -TEX_CORE_GLOW.get_size() * 0.5, Color(1, 1, 1, 0.8))
