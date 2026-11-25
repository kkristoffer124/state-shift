@tool
class_name IxPlate
extends Area2D
## Pressure plate. Only ICE is heavy enough to press it (unless `heavy_only` is off).
## ORIGIN = left end of the plate, sitting on the floor surface (plate art rises above it).
## Drives every receiver listening on `channel` (gates, drips, vents...).

signal pressed_changed(pressed: bool)

const TEX_BASE := preload("res://assets/interactive/ix_plate_base.png")
const TEX_PAD := preload("res://assets/interactive/ix_plate_pad.png")

@export var channel := "a"
@export var width := 48.0:
	set(v):
		width = maxf(v, 24.0)
		_refresh()
## Only ICE presses it. Off = any state (water/steam too).
@export var heavy_only := true
## Stay pressed forever once pressed (so a door you just opened stays open).
@export var latch := true

var pressed := false
var _sink := 0.0
var _flash := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = Ix.PLAYER_MASK
	monitoring = true
	monitorable = false
	_refresh()


func _refresh() -> void:
	if not is_inside_tree():
		return
	var cs := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs and cs.shape is RectangleShape2D:
		(cs.shape as RectangleShape2D).size = Vector2(width - 4.0, 14.0)
		cs.position = Vector2(width / 2.0, -9.0)
	queue_redraw()


func _is_heavy(body: Node) -> bool:
	var s := Ix.state_of(body)
	if s == -1:
		return false
	return s == 0 or not heavy_only


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var down := false
	for b in get_overlapping_bodies():
		if _is_heavy(b):
			down = true
	if latch and pressed:
		down = true
	if down != pressed:
		pressed = down
		_flash = 0.4
		Ix.emit(self, channel, pressed)
		pressed_changed.emit(pressed)
		if has_node("/root/Sfx"):
			get_node("/root/Sfx").play("land_ice" if pressed else "cool")
	_sink = move_toward(_sink, 3.0 if pressed else 0.0, delta * 30.0)
	_flash = maxf(_flash - delta, 0.0)
	queue_redraw()


func _draw() -> void:
	# Base: stretch-free tiling keeps texels 1:1 (left cap, repeated middle, right cap).
	_three_slice(TEX_BASE, Vector2(0, -6), width, 4.0)
	var y := -10.0 + roundf(_sink)
	_three_slice(TEX_PAD, Vector2(4, y), width - 8.0, 3.0)
	if heavy_only:
		# Ice-cube glyph (from the middle of the pad art) marks "ICE only".
		draw_texture_rect_region(TEX_PAD, Rect2(roundf(width / 2.0) - 5.0, y, 10, 6), Rect2(15, 0, 10, 6))
	# Status lamp on the base.
	var c := Ix.C_GOAL if pressed else Ix.C_FROST
	if _flash > 0.0 and int(_flash * 20.0) % 2 == 0:
		c = Color.WHITE
	draw_rect(Rect2(roundf(width / 2.0) - 3.0, -3, 6, 1), c)


func _three_slice(tex: Texture2D, at: Vector2, w: float, cap: float) -> void:
	var tw := float(tex.get_width())
	var th := float(tex.get_height())
	draw_texture_rect_region(tex, Rect2(at, Vector2(cap, th)), Rect2(0, 0, cap, th))
	var x := cap
	while x < w - cap:
		# Middle texels taken from just after the left cap (avoids the glyph).
		var cw := minf(10.0, w - cap - x)
		draw_texture_rect_region(tex, Rect2(at.x + x, at.y, cw, th), Rect2(cap, 0, cw, th))
		x += cw
	draw_texture_rect_region(tex, Rect2(at.x + w - cap, at.y, cap, th), Rect2(tw - cap, 0, cap, th))
