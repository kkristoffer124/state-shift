@tool
class_name IxGate
extends AnimatableBody2D
## Solid shutter/door/hatch (collision layer 1, like walls) opened by a channel.
## ORIGIN = top-left of the CLOSED door; `size` is the closed rect.
##  ROLL  the panel rolls up into a housing at `anchor` (shrinks; nothing pokes out)
##  SLIDE the whole panel moves by `open_offset`
## Tells the FluidWorld where it is solid, so water pools against a closed gate.
## Safety: never closes onto the player.

enum Mode { ROLL, SLIDE }
enum Anchor { TOP, BOTTOM, LEFT, RIGHT }

const TEX_TILE := preload("res://assets/interactive/ix_gate_tile.png")
const TEX_CAP := preload("res://assets/interactive/ix_gate_cap.png")

@export var channel := "a"
@export var size := Vector2(24, 128):
	set(v):
		size = v.max(Vector2(8, 8))
		_refresh()
@export var mode: Mode = Mode.ROLL
@export var anchor: Anchor = Anchor.TOP:
	set(v):
		anchor = v
		_refresh()
@export var open_offset := Vector2(0, -128)
## Seconds for a full open/close.
@export var duration := 0.7
## Needs every source on the channel (e.g. two plates) instead of any one.
@export var require_all := false
## How many distinct sources `require_all` waits for.
@export var sources_needed := 2
## Open when the channel is OFF instead.
@export var inverted := false
## Preview the open state in the editor.
@export var preview_open := false:
	set(v):
		preview_open = v
		if Engine.is_editor_hint():
			_open = 1.0 if v else 0.0
			_apply()

var is_open := false
var _open := 0.0          # 0 closed .. 1 open (animated)
var _sources := {}
var _base := Vector2.ZERO
var _fluid_rect := Rect2()
var _fluid_synced := false
var _t := 0.0


func _ready() -> void:
	_base = position
	collision_layer = 1
	collision_mask = 0
	sync_to_physics = mode == Mode.SLIDE
	_refresh()
	if Engine.is_editor_hint():
		return
	Ix.listen(self, channel)
	if inverted:
		is_open = true
		_open = 1.0
		_apply()


func _refresh() -> void:
	if not is_inside_tree():
		return
	_apply()


func _on_channel(source_id: int, on: bool) -> void:
	if on:
		_sources[source_id] = true
	else:
		_sources.erase(source_id)
	var active := _sources.size() >= (sources_needed if require_all else 1)
	var want := active != inverted
	if want != is_open:
		is_open = want
		if has_node("/root/Sfx"):
			get_node("/root/Sfx").play("heat" if is_open else "cool")


## Local rect of the solid part for an open fraction.
func _solid_rect(f: float) -> Rect2:
	if mode == Mode.SLIDE:
		return Rect2(open_offset * f, size)
	var r := Rect2(Vector2.ZERO, size)
	match anchor:
		Anchor.TOP:
			r.size.y = size.y * (1.0 - f)
		Anchor.BOTTOM:
			r.size.y = size.y * (1.0 - f)
			r.position.y = size.y - r.size.y
		Anchor.LEFT:
			r.size.x = size.x * (1.0 - f)
		Anchor.RIGHT:
			r.size.x = size.x * (1.0 - f)
			r.position.x = size.x - r.size.x
	r.size = r.size.round()
	r.position = r.position.round()
	return r


func _apply() -> void:
	var r := _solid_rect(_open)
	var cs := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if mode == Mode.SLIDE:
		if not Engine.is_editor_hint():
			position = _base + open_offset * _open
		r.position = Vector2.ZERO
	if cs and cs.shape is RectangleShape2D:
		# Keep a sliver so the shape never becomes degenerate; disable when fully open.
		(cs.shape as RectangleShape2D).size = r.size.max(Vector2(1, 1))
		cs.position = r.position + r.size / 2.0
		cs.set_deferred("disabled", r.size.x < 1.0 or r.size.y < 1.0)
	queue_redraw()


func _global_rect(f: float) -> Rect2:
	var r := _solid_rect(f)
	var par := get_parent() as Node2D
	var origin := (par.global_position if par else Vector2.ZERO) + _base
	if mode == Mode.SLIDE:
		return Rect2(origin + open_offset * f, size)
	r.position += origin
	return r


func _player_blocks(f: float) -> bool:
	var p := Ix.player_of(self)
	if p == null:
		return false
	return _global_rect(f).grow(2.0).intersects(Rect2(p.global_position - Vector2(16, 16), Vector2(32, 32)))


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_t += delta
	var target := 1.0 if is_open else 0.0
	if not is_equal_approx(_open, target):
		var nxt := move_toward(_open, target, delta / maxf(duration, 0.05))
		if nxt < _open and _player_blocks(nxt):
			pass # hold: never squash the player
		else:
			_open = nxt
			_apply()
	_sync_fluid()


func _sync_fluid() -> void:
	var r := _global_rect(_open)
	if _fluid_synced and r.position.distance_to(_fluid_rect.position) < 2.0 			and r.size.distance_to(_fluid_rect.size) < 2.0:
		return
	if Ix.fluid(self) == null:
		return
	if _fluid_synced and _fluid_rect.size.x > 0 and _fluid_rect.size.y > 0:
		Ix.set_solid(self, _fluid_rect, false)
	if r.size.x >= 1.0 and r.size.y >= 1.0:
		Ix.set_solid(self, r, true)
	_fluid_rect = r
	_fluid_synced = true


func _draw() -> void:
	var r := _solid_rect(_open)
	if mode == Mode.SLIDE:
		r.position = Vector2.ZERO
	var vertical := anchor == Anchor.TOP or anchor == Anchor.BOTTOM
	if mode == Mode.SLIDE:
		vertical = size.y >= size.x
	var thick := size.x if vertical else size.y
	var tw := minf(thick, TEX_TILE.get_width())
	if r.size.x >= 1.0 and r.size.y >= 1.0:
		if vertical:
			# Panel tiles scroll with the roll so it reads as moving.
			var off := fmod(size.y - r.size.y, 32.0) if anchor == Anchor.TOP else 0.0
			var y := -off
			while y < r.size.y:
				var y0 := maxf(y, 0.0)
				var y1 := minf(y + 32.0, r.size.y)
				if y1 > y0:
					draw_texture_rect_region(TEX_TILE, Rect2(r.position.x, r.position.y + y0, tw, y1 - y0),
							Rect2((TEX_TILE.get_width() - tw) / 2.0, y0 - y, tw, y1 - y0))
				y += 32.0
		else:
			draw_set_transform(r.position + Vector2(0, r.size.y), -PI / 2.0)
			var x := 0.0
			while x < r.size.x:
				var w := minf(32.0, r.size.x - x)
				draw_texture_rect_region(TEX_TILE, Rect2(0, x, tw, w), Rect2((TEX_TILE.get_width() - tw) / 2.0, 0, tw, w))
				x += 32.0
			draw_set_transform(Vector2.ZERO)
	# Housing cap at the anchor edge (ROLL) with a status light.
	var light := Ix.C_GOAL if is_open else Color("ff4a5a")
	if mode == Mode.ROLL:
		var cap_r: Rect2
		match anchor:
			Anchor.TOP: cap_r = Rect2(-2, -4, size.x + 4, 8)
			Anchor.BOTTOM: cap_r = Rect2(-2, size.y - 4, size.x + 4, 8)
			Anchor.LEFT: cap_r = Rect2(-4, -2, 8, size.y + 4)
			Anchor.RIGHT: cap_r = Rect2(size.x - 4, -2, 8, size.y + 4)
		draw_rect(cap_r, Ix.C_INK)
		draw_rect(cap_r.grow(-1), Color("5d7b93"))
		draw_rect(Rect2(cap_r.get_center() - Vector2(1, 1), Vector2(3, 2)).abs(), light)
	else:
		draw_rect(Rect2(r.position + Vector2(r.size.x / 2.0 - 1.0, 4), Vector2(3, 2)), light)
	# Moving lip
	if mode == Mode.ROLL and r.size.x >= 1.0 and r.size.y >= 1.0:
		var lip: Rect2
		match anchor:
			Anchor.TOP: lip = Rect2(r.position.x, r.end.y - 3, r.size.x, 3)
			Anchor.BOTTOM: lip = Rect2(r.position.x, r.position.y, r.size.x, 3)
			Anchor.LEFT: lip = Rect2(r.end.x - 3, r.position.y, 3, r.size.y)
			Anchor.RIGHT: lip = Rect2(r.position.x, r.position.y, 3, r.size.y)
		draw_rect(lip, Ix.C_INK)
		draw_rect(lip.grow(-1), Color("9ebcdb"))
