@tool
class_name IxTracker
extends Node2D
## Watches the player. CAMERA: wall-mounted security camera that pans toward you while
## it has line of sight (LED goes red), and fogs up when STEAM drifts in front of it.
## MONITOR: a screen whose pixel eyes follow you and change with your state.
## ORIGIN = mount point (CAMERA: wall/ceiling bolt; MONITOR: bottom centre of the stand).

enum Style { CAMERA, MONITOR }

const TEX_HEAD := preload("res://assets/interactive/ix_camera_head.png")
const TEX_MOUNT := preload("res://assets/interactive/ix_camera_mount.png")
const TEX_MONITOR := preload("res://assets/interactive/ix_monitor.png")

@export var style: Style = Style.CAMERA:
	set(v):
		style = v
		queue_redraw()
@export var view_range := 420.0
## CAMERA: pans within rest_angle +- sweep (rad, 0 = facing right).
@export var rest_angle := 0.6
@export var sweep := 1.0
@export var flip := false:
	set(v):
		flip = v
		queue_redraw()

var _aim := 0.0
var _seen := false
var _fog := 0.0
var _t := 0.0
var _look := Vector2.ZERO
var _state := 1
var _blink := 0.0


func _ready() -> void:
	_aim = rest_angle


func _physics_process(delta: float) -> void:
	_t += delta
	if Engine.is_editor_hint():
		queue_redraw()
		return
	var pl := Ix.player_of(self)
	_seen = false
	var eye := global_position + (Vector2(0, 8) if style == Style.CAMERA else Vector2(0, -12))
	if pl and Ix.state_of(pl) != -1:
		_state = Ix.state_of(pl)
		var to := pl.global_position - eye
		if to.length() < view_range:
			var q := PhysicsRayQueryParameters2D.create(eye, pl.global_position, 1)
			_seen = get_world_2d().direct_space_state.intersect_ray(q).is_empty()
			if _seen and _state == 2 and to.length() < 90.0:
				_fog = minf(_fog + delta * 1.5, 1.0)
		if _seen:
			_look = _look.lerp(to.normalized(), minf(delta * 8.0, 1.0))
	if not _seen:
		_look = _look.lerp(Vector2(sin(_t * 0.7), 0.2), minf(delta * 2.0, 1.0))
	_fog = maxf(_fog - delta * 0.25, 0.0)
	_blink = fmod(_t, 4.3)
	if style == Style.CAMERA:
		var target := rest_angle + sin(_t * 0.6) * sweep * 0.6
		if _seen:
			var to2: Vector2 = pl.global_position - (global_position + Vector2(0, 8))
			var a := to2.angle()
			if flip:
				a = PI - a
			target = clampf(wrapf(a, -PI, PI), rest_angle - sweep, rest_angle + sweep)
		_aim = lerp_angle(_aim, target, minf(delta * (5.0 if _seen else 1.0), 1.0))
	queue_redraw()


func _draw() -> void:
	if style == Style.CAMERA:
		var sx := -1.0 if flip else 1.0
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(sx, 1))
		draw_texture(TEX_MOUNT, Vector2(-5, -2))
		draw_set_transform(Vector2(0, 8), -_aim if flip else _aim, Vector2(sx, 1))
		draw_texture(TEX_HEAD, Vector2(-4, -5))
		# LED: red when it sees you, slow green blink otherwise.
		var led := Color("ff4a5a") if _seen else (Ix.C_GOAL if fmod(_t, 1.4) < 0.2 else Color("18222d"))
		draw_rect(Rect2(2, -3, 2, 1), led)
		if _fog > 0.05:
			draw_rect(Rect2(15, -3, 5, 7), Color(0.9, 0.95, 1.0, _fog * 0.8))
		draw_set_transform(Vector2.ZERO)
	else:
		draw_texture(TEX_MONITOR, Vector2(-15, -24))
		# Screen area: 26x15 at (-13, -22).
		var scr := Rect2(-13, -22, 26, 15)
		var tint: Color = [Color("80d9ff"), Color("3f8cff"), Color("e8eef4")][clampi(_state, 0, 2)]
		if _fog > 0.05:
			draw_rect(scr, Color(0.9, 0.95, 1.0, _fog * 0.6))
		# Scanlines.
		for y in range(0, 15, 3):
			draw_rect(Rect2(scr.position.x, scr.position.y + y, scr.size.x, 1), Color(tint, 0.08))
		var off := (_look * Vector2(3, 2)).round()
		var c := scr.get_center().round()
		for ex in [-6.0, 6.0]:
			var e := c + Vector2(ex, 0)
			if _blink < 0.12:
				draw_rect(Rect2(e + Vector2(-3, 0), Vector2(6, 1)), tint)
			else:
				draw_rect(Rect2(e + Vector2(-3, -3), Vector2(6, 6)), Color(tint, 0.35))
				draw_rect(Rect2(e + off + Vector2(-1, -1), Vector2(2, 2)), tint)
		if not _seen and fmod(_t, 1.0) < 0.5:
			draw_rect(Rect2(scr.end.x - 4, scr.position.y + 1, 2, 2), Color("ff4a5a"))
