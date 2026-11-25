@tool
class_name IxLever
extends Area2D
## Lever / valve wheel the player flips just by touching it (in `required_state`).
## Each new touch toggles `channel`. ORIGIN = bottom centre (mount on a floor surface).

enum Style { LEVER, VALVE }
enum Need { ANY = -1, ICE = 0, WATER = 1, STEAM = 2 }

const TEX_BASE := preload("res://assets/interactive/ix_lever_base.png")
const TEX_HANDLE := preload("res://assets/interactive/ix_lever_handle.png")
const TEX_WHEEL := preload("res://assets/interactive/ix_valve_wheel_2f.png")
const TEX_PIPE := preload("res://assets/interactive/ix_pipe_v.png")

@export var channel := "a"
@export var style: Style = Style.LEVER:
	set(v):
		style = v
		queue_redraw()
@export var required_state: Need = Need.ANY
@export var on := false:
	set(v):
		on = v
		queue_redraw()
## One-way switch (can't be flipped back).
@export var one_shot := false

var _touching := false
var _swing := 0.0
var _wheel := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = Ix.PLAYER_MASK
	monitoring = true
	monitorable = false
	_swing = 1.0 if on else -1.0
	if not Engine.is_editor_hint() and on:
		# Announce the initial state once everything is in the tree.
		_announce.call_deferred()


func _announce() -> void:
	Ix.emit(self, channel, on)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var touching := false
	for b in get_overlapping_bodies():
		var s := Ix.state_of(b)
		if s != -1 and (required_state == Need.ANY or s == int(required_state)):
			touching = true
	if touching and not _touching and not (one_shot and on):
		on = not on
		Ix.emit(self, channel, on)
		if has_node("/root/Sfx"):
			get_node("/root/Sfx").play("select")
	_touching = touching
	_swing = move_toward(_swing, 1.0 if on else -1.0, delta * 8.0)
	_wheel = move_toward(_wheel, 1.0 if on else 0.0, delta * 3.0)
	queue_redraw()


func _draw() -> void:
	if style == Style.LEVER:
		draw_set_transform(Vector2(0, -6), _swing * 0.6)
		draw_texture(TEX_HANDLE, Vector2(-3, -17))
		draw_set_transform(Vector2.ZERO)
		draw_texture(TEX_BASE, Vector2(-8, -8))
		draw_rect(Rect2(-6, -3, 2, 1), Ix.C_GOAL if on else Color("ff4a5a"))
	else:
		Ix.vtile(self, TEX_PIPE, Vector2(-4, -12), 12)
		var frame := 1 if on else 0
		var spin := _wheel * PI
		draw_set_transform(Vector2(0, -16), spin)
		draw_texture_rect_region(TEX_WHEEL, Rect2(-7, -7, 14, 14), Rect2(frame * 14, 0, 14, 14))
		draw_set_transform(Vector2.ZERO)
