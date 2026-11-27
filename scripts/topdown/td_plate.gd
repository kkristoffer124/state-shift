@tool
class_name TdPlate
extends Area2D
## Top-down pressure plate (one 32x32 cell, ORIGIN = top-left of the cell).
## Only a resting ICE cube is heavy enough (sliding over it doesn't count).
## Drives every receiver on `channel` through Ix (TdGate, IxGate...).

signal pressed_changed(pressed: bool)

const TEX := preload("res://assets/topdown/td_plate.png") # 2 frames: up, down

@export var channel := "a"
## Stay down once pressed.
@export var latch := true

var pressed := false
var _flash := 0.0
var _t := 0.0
## Visual press depth (spring, 0 up .. 1 down; overshoots a little) - drawing only.
var _press := 0.0
var _press_v := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = Ix.PLAYER_MASK
	monitoring = true
	monitorable = false
	z_index = 1


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_t += delta
	var down := false
	for b in get_overlapping_bodies():
		if Ix.state_of(b) == 0 and b.has_method("is_resting") and b.is_resting():
			# centred on the plate, not just clipping its edge
			if b.global_position.distance_to(global_position + Vector2(16, 16)) < 10.0:
				down = true
	if latch and pressed:
		down = true
	if down != pressed:
		pressed = down
		_flash = 0.5
		Ix.emit(self, channel, pressed)
		pressed_changed.emit(pressed)
		if has_node("/root/Sfx"):
			get_node("/root/Sfx").play("land_ice" if pressed else "cool")
	_flash = maxf(_flash - delta, 0.0)
	# eased press / spring-back (cosmetic)
	_press_v += ((1.0 if pressed else 0.0) - _press) * 420.0 * delta
	_press_v *= exp(-16.0 * delta)
	_press += _press_v * delta
	queue_redraw()


func _draw() -> void:
	var k := clampf(_press, 0.0, 1.0)
	# cross-fade the up / down art while the plate sinks; the top dips a pixel
	draw_texture_rect_region(TEX, Rect2(0, 0, 32, 32), Rect2(0, 0, 32, 32))
	if k > 0.02:
		draw_texture_rect_region(TEX, Rect2(0, 0, 32, 32), Rect2(32, 0, 32, 32), Color(1, 1, 1, k))
	var dip := roundf(clampf(_press, -0.4, 1.3) * 1.5)
	if absf(dip) >= 1.0:
		draw_rect(Rect2(6, 6, 20, 20), Color(0, 0, 0, 0.12 * signf(dip)) if dip > 0.0 else Color(1, 1, 1, 0.08))
		draw_rect(Rect2(6, 5 + dip, 20, 1), Color(0, 0, 0, 0.25))
	# press ring: a pulse that runs out to the rim
	if _flash > 0.0 and pressed:
		var u := 1.0 - _flash / 0.5
		var r := 6.0 + u * 14.0
		draw_rect(Rect2(Vector2(16, 16) - Vector2(r, r), Vector2(r, r) * 2.0), Color(Ix.C_GOAL, 0.5 * (1.0 - u)), false, 1.0)
	# status lamps in the corners
	var c := Ix.C_GOAL if pressed else Ix.C_FROST.darkened(0.2 + 0.2 * sin(_t * 4.0))
	if _flash > 0.0 and int(_flash * 20.0) % 2 == 0:
		c = Color.WHITE
	for p in [Vector2(3, 3), Vector2(27, 3), Vector2(3, 27), Vector2(27, 27)]:
		draw_rect(Rect2(p, Vector2(2, 2)), c)
