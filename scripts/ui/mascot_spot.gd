@tool
extends Control
## Invisible hotspot over one of the three blob mascots baked into the menu backdrop art.
## Keeps itself aligned with the backdrop (TextureRect, keep-aspect-covered) and makes the
## mascot feel alive: idle frost glints / drips / steam wisps, a small reaction on hover and
## a burst (frost shards / splash / puff cloud) on click.

enum Kind { ICE, WATER, STEAM }

@export var kind: Kind = Kind.WATER
## Mascot bounds in backdrop texture pixels.
@export var tex_rect := Rect2(0, 0, 32, 32):
	set(v):
		tex_rect = v
		_place()
@export var backdrop_path := NodePath("../../../Backdrop")

var _idle := 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_idle = randf_range(0.6, 2.0)
	var bd := _backdrop()
	if bd:
		bd.resized.connect(_place)
	_place.call_deferred()
	if Engine.is_editor_hint():
		return
	mouse_entered.connect(_react.bind(false))


func _backdrop() -> TextureRect:
	return get_node_or_null(backdrop_path) as TextureRect if is_inside_tree() else null


func _place() -> void:
	var bd := _backdrop()
	if bd == null or bd.texture == null:
		return
	var ts := bd.texture.get_size()
	var s := maxf(bd.size.x / ts.x, bd.size.y / ts.y)
	var off := (bd.size - ts * s) / 2.0
	global_position = bd.global_position + off + tex_rect.position * s
	size = tex_rect.size * s


func _gui_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		_react(true)


func _fx() -> Node:
	return get_node_or_null("/root/UiFx")


func _pt(local: Vector2) -> Vector2:
	return get_global_transform() * local


func _react(big: bool) -> void:
	var fx := _fx()
	if fx == null or not is_visible_in_tree():
		return
	var w := size.x
	var h := size.y
	match kind:
		Kind.ICE:
			if big:
				fx.frost_burst(self, _pt(Vector2(w * 0.5, h * 0.35)), 18)
				fx.frost_burst(self, _pt(Vector2(w * 0.5, 2)), 8)
				Sfx.play("land_ice", 0.1)
			for i in (3 if big else 2):
				fx.glint(self, _pt(Vector2(randf_range(4, w - 4), randf_range(4, h * 0.6))).round(), 3.0 if big else 2.0, 0.5)
		Kind.WATER:
			var top := _pt(Vector2(w * 0.5, h * 0.12))
			if big:
				fx.splash(self, top, 1.6)
				fx.ripple(self, _pt(Vector2(w * 0.5, h - 2)), w * 0.6)
				Sfx.play("bubble", 0.1)
			else:
				fx.splash(self, top, 0.5)
		Kind.STEAM:
			if big:
				fx.puff_ring(self, _pt(Vector2(w * 0.5, h * 0.45)), 10, 110.0, 5.0)
				Sfx.play("poof", 0.1)
			else:
				fx.puff(self, _pt(Vector2(w * 0.5, h * 0.15)), 3, w * 0.25, 5.0)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not is_visible_in_tree():
		return
	_idle -= delta
	if _idle > 0.0:
		return
	_idle = randf_range(1.4, 3.2)
	var fx := _fx()
	if fx == null:
		return
	var w := size.x
	var h := size.y
	match kind:
		Kind.ICE:
			fx.glint(self, _pt(Vector2(randf_range(6, w - 6), randf_range(6, h - 10))).round(), 2.0, 0.55)
		Kind.WATER:
			fx.drip(self, _pt(Vector2(randf_range(w * 0.2, w * 0.8), h - 4)), 1)
		Kind.STEAM:
			fx.puff_at(self, _pt(Vector2(randf_range(w * 0.3, w * 0.7), h * 0.1)), Vector2(randf_range(-6, 6), -26), 0.9, 4.0)
