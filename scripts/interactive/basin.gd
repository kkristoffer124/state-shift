@tool
class_name IxBasin
extends Area2D
## Glass basin with a level sensor. When enough free water pools inside (FluidWorld
## water_count_in) it powers `channel`. Pouring yourself in as WATER for a moment also
## fills it, so it never depends on the drip timing alone.
## ORIGIN = top-left of the basin's inside; `size` = inside. Walls are drawn just outside
## and are solid only for the fluid sim (the player passes them).

const TEX_WALL := preload("res://assets/interactive/ix_basin_wall.png")
const TEX_LIP := preload("res://assets/interactive/ix_basin_lip.png")

@export var channel := ""
@export var size := Vector2(96, 40):
	set(v):
		size = v.max(Vector2(16, 8))
		_refresh()
## Free water pixels needed (FluidWorld present).
@export var threshold := 60
## Fallback drops (no FluidWorld) needed, fed by IxDrip pipes.
@export var fallback_drops := 14
## Seconds the WATER player must sit in it to count as full.
@export var player_fill_time := 0.25
@export var latch := true
## Draw a bottom lip (off when the basin stands on a floor block).
@export var has_floor := false:
	set(v):
		has_floor = v
		queue_redraw()

var full := false
var level := 0.0        # 0..1 shown on the gauge
var _drops := 0
var _player_t := 0.0
var _poll := 0.0
var _walls_sent := false
var _t := 0.0
var _ripple := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = Ix.PLAYER_MASK
	monitoring = true
	monitorable = false
	_refresh()
	if not Engine.is_editor_hint():
		add_to_group("ix_basin")


func _refresh() -> void:
	if not is_inside_tree():
		return
	var cs := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs and cs.shape is RectangleShape2D:
		(cs.shape as RectangleShape2D).size = size
		cs.position = size / 2.0
	queue_redraw()


func global_rect() -> Rect2:
	return Rect2(global_position, size)


## Called by fallback drips that land inside.
func add_drop() -> void:
	_drops += 1
	_ripple = 1.0


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_t += delta
	_ripple = maxf(_ripple - delta * 2.0, 0.0)
	if not _walls_sent and Ix.fluid(self):
		_walls_sent = true
		var r := global_rect()
		Ix.set_solid(self, Rect2(r.position + Vector2(-4, -2), Vector2(4, r.size.y + 2)), true)
		Ix.set_solid(self, Rect2(Vector2(r.end.x, r.position.y - 2), Vector2(4, r.size.y + 2)), true)
		if has_floor:
			Ix.set_solid(self, Rect2(Vector2(r.position.x - 4, r.end.y), Vector2(r.size.x + 8, 4)), true)
	var water_player := false
	for b in get_overlapping_bodies():
		if Ix.state_of(b) == 1:
			water_player = true
			_ripple = maxf(_ripple, 0.6)
	_player_t = _player_t + delta if water_player else maxf(_player_t - delta, 0.0)
	_poll -= delta
	if _poll <= 0.0:
		_poll = 0.2
		var n := Ix.water_in(self, global_rect())
		var target := 0.0
		if n >= 0:
			target = float(n) / maxf(threshold, 1)
		target = maxf(target, float(_drops) / maxf(fallback_drops, 1))
		if _player_t >= player_fill_time:
			target = 1.0
		level = clampf(target, 0.0, 1.0) if not (latch and full) else 1.0
		var now := level >= 1.0
		if now != full and (not latch or now):
			full = now
			Ix.emit(self, channel, full)
			if full and has_node("/root/Sfx"):
				get_node("/root/Sfx").play("select", 0.0)
	queue_redraw()


func _draw() -> void:
	# Fallback water body (when there is no FluidWorld the sim pixels aren't there to see).
	var show := float(_drops) / maxf(fallback_drops, 1)
	if Engine.is_editor_hint():
		show = 0.5
	elif Ix.fluid(self) != null:
		show = 0.0
	show = clampf(show, 0.0, 1.0)
	if show > 0.0:
		var h := roundf(size.y * show)
		draw_rect(Rect2(0, size.y - h, size.x, h), Color(Ix.C_WATER, 0.75))
		var y := size.y - h
		for x in range(0, int(size.x), 2):
			var wy := roundf(sin(_t * 4.0 + x * 0.3) * (1.0 + _ripple * 1.5))
			draw_rect(Rect2(x, y + wy, 2, 1), Ix.C_WATER_HI)
	# Glass walls + optional lip.
	Ix.vtile(self, TEX_WALL, Vector2(-6, -2), size.y + 2)
	Ix.vtile(self, TEX_WALL, Vector2(size.x, -2), size.y + 2)
	if has_floor:
		Ix.htile(self, TEX_LIP, Vector2(-6, size.y), size.x + 12)
	# Gauge on the right wall: 6 cells.
	var cells := 6
	var gx := size.x + 7.0
	draw_rect(Rect2(gx - 1, -1, 5, cells * 4 + 1), Ix.C_INK)
	for i in cells:
		var on := level * cells >= cells - i - 0.01 and level > 0.0
		var c := Color("18222d")
		if on:
			c = Ix.C_GOAL if full else Ix.C_FROST
		draw_rect(Rect2(gx, i * 4, 3, 3), c)
	if channel != "":
		draw_rect(Rect2(gx, cells * 4 + 2, 3, 2), Ix.C_GOAL if full else Color("ff4a5a"))
