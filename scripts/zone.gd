@tool
class_name Zone
extends Area2D
## Trigger area. Origin is the TOP-LEFT corner; set `size` in the inspector.
##  SPIKES  kill WATER and STEAM (ICE is safe)
##  HEAT    forces STEAM while inside
##  FREEZE  forces ICE while inside
##  FAN     pushes STEAM (and a little WATER) along push_direction
##  GOAL    finishes the level

enum Kind { SPIKES, HEAT, FREEZE, FAN, GOAL }

const TEX_SPIKE := preload("res://assets/env/e4a_spike.png")             # 16x32
const TEX_SPIKE_PLATE := preload("res://assets/env/e4b_spike_plate.png") # 32x6
const TEX_HEAT_VENT := preload("res://assets/env/e5a_heat_vent.png")     # 32x12
const TEX_HEAT_HAZE := preload("res://assets/env/e5b_heat_haze.png")     # 8x128
const TEX_EMBER := preload("res://assets/env/e5c_ember.png")             # 4x4
const TEX_FREEZE_EMITTER := preload("res://assets/env/e6a_freeze_emitter.png") # 32x16
const TEX_FROST_HAZE := preload("res://assets/env/e6b_frost_haze.png")   # 8x128
const TEX_FROST_EDGE := preload("res://assets/env/e6d_frost_edge_9s16.png")
const TEX_SNOW: Array[Texture2D] = [
	preload("res://assets/env/e6c_snowflake_1.png"),
	preload("res://assets/env/e6c_snowflake_2.png"),
	preload("res://assets/env/e6c_snowflake_3.png"),
]
const TEX_FAN_HOUSING := preload("res://assets/env/e7a_fan_housing_9s8.png") # 128x24
const TEX_FAN_BLADE := preload("res://assets/env/e7b_fan_blade_4f.png")      # 4 frames of 24x24
const TEX_AIRFLOW := preload("res://assets/env/e7c_airflow_streak.png")      # 4x32
const TEX_GOAL_SWIRL := preload("res://assets/env/e8a_goal_swirl.png")       # 64x64
const TEX_GOAL_GLOW := preload("res://assets/env/e8b_goal_glow.png")         # 128x128
const TEX_SPARKLES: Array[Texture2D] = [
	preload("res://assets/env/e8c_sparkle_1.png"),
	preload("res://assets/env/e8c_sparkle_2.png"),
]

const FAN_H := 24.0
const BLADE := 24.0

@export var kind: Kind = Kind.SPIKES:
	set(v):
		kind = v
		_refresh()
@export var size := Vector2(64, 32):
	set(v):
		size = v
		_refresh()
@export var push_direction := Vector2.UP
@export var push_strength := 1500.0

var _t := 0.0
var _frost_box: StyleBoxTexture
var _fan_box: StyleBoxTexture


func _ready() -> void:
	collision_layer = 16
	collision_mask = 0
	monitoring = false
	monitorable = true
	_refresh()


func _refresh() -> void:
	if not is_inside_tree():
		return
	var cs := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs and cs.shape is RectangleShape2D:
		var s := size
		if kind == Kind.SPIKES:
			s.y = maxf(size.y - 8.0, 4.0) # forgiving hitbox
			cs.position = Vector2(size.x / 2.0, size.y - s.y / 2.0)
		else:
			cs.position = size / 2.0
		(cs.shape as RectangleShape2D).size = s
	_frost_box = _nine(TEX_FROST_EDGE, 16.0, 16.0, size)
	_fan_box = _nine(TEX_FAN_HOUSING, 8.0, 8.0, Vector2(size.x, FAN_H))
	queue_redraw()


## 9-slice box with margins clamped so they never overlap; TILE keeps texels 1:1.
static func _nine(tex: Texture2D, mx: float, my: float, area: Vector2) -> StyleBoxTexture:
	var b := StyleBoxTexture.new()
	b.texture = tex
	mx = minf(mx, floorf(area.x / 2.0))
	my = minf(my, floorf(area.y / 2.0))
	b.texture_margin_left = mx
	b.texture_margin_right = mx
	b.texture_margin_top = my
	b.texture_margin_bottom = my
	b.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	b.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	return b


func push_vector() -> Vector2:
	return push_direction.normalized() * push_strength


func _process(delta: float) -> void:
	if kind != Kind.SPIKES:
		_t += delta
		queue_redraw()


## Repeats `tex` horizontally across [x0, x0+w) at height y, cropping the last tile.
func _hrepeat(tex: Texture2D, x0: float, y: float, w: float, mod := Color.WHITE) -> void:
	var tw := tex.get_width()
	var th := tex.get_height()
	var x := 0.0
	while x < w:
		var cw := minf(tw, w - x)
		draw_texture_rect_region(tex, Rect2(x0 + x, y, cw, th), Rect2(0, 0, cw, th), mod)
		x += tw


## Vertical gradient strip (8 px wide) tiled across the width and stretched to the height.
func _haze(tex: Texture2D, r: Rect2, mod: Color) -> void:
	var tw := tex.get_width()
	var th := tex.get_height()
	var x := 0.0
	while x < r.size.x:
		var cw := minf(tw, r.size.x - x)
		draw_texture_rect_region(tex, Rect2(r.position.x + x, r.position.y, cw, r.size.y), Rect2(0, 0, cw, th), mod)
		x += tw


func _draw() -> void:
	match kind:
		Kind.SPIKES:
			_draw_spikes()
		Kind.HEAT:
			_draw_heat()
		Kind.FREEZE:
			_draw_freeze()
		Kind.FAN:
			_draw_fan()
		Kind.GOAL:
			_draw_goal()


func _draw_spikes() -> void:
	var sw := float(TEX_SPIKE.get_width())
	var sh := float(TEX_SPIKE.get_height())
	var n := maxi(1, int(size.x / sw))
	var x0 := floorf((size.x - n * sw) / 2.0)
	for i in n:
		draw_texture(TEX_SPIKE, Vector2(x0 + i * sw, size.y - sh))
	var ph := TEX_SPIKE_PLATE.get_height()
	_hrepeat(TEX_SPIKE_PLATE, 0.0, size.y - ph, size.x)


func _draw_heat() -> void:
	var a := 0.85 + sin(_t * 2.3) * 0.15
	_haze(TEX_HEAT_HAZE, Rect2(Vector2.ZERO, size), Color(1, 1, 1, a))
	for i in int(size.x * size.y / 900.0) + 4:
		var px := fmod(i * 37.7, size.x)
		var travel := fmod(_t * (40.0 + i % 5 * 12.0) + i * 53.0, size.y)
		var py := size.y - travel
		var fade := clampf(1.0 - travel / size.y, 0.0, 1.0)
		var p := Vector2(px + sin(_t * 3.0 + i) * 4.0, py).round() - Vector2(2, 2)
		draw_texture(TEX_EMBER, p, Color(1, 1, 1, 0.35 + 0.65 * fade))
	_hrepeat(TEX_HEAT_VENT, 0.0, size.y - TEX_HEAT_VENT.get_height(), size.x)


func _draw_freeze() -> void:
	_haze(TEX_FROST_HAZE, Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.9))
	if _frost_box:
		draw_style_box(_frost_box, Rect2(Vector2.ZERO, size))
	var top := float(TEX_FREEZE_EMITTER.get_height())
	var span := maxf(size.y - top, 1.0)
	for i in int(size.x * size.y / 900.0) + 4:
		var px := fmod(i * 41.3, size.x)
		var py := top + fmod(_t * (20.0 + i % 4 * 8.0) + i * 47.0, span)
		var p := Vector2(px + sin(_t * 2.0 + i) * 6.0, py).round() - Vector2(2, 2)
		draw_texture(TEX_SNOW[i % TEX_SNOW.size()], p)
	_hrepeat(TEX_FREEZE_EMITTER, 0.0, 0.0, size.x)


func _draw_fan() -> void:
	var flow := maxf(size.y - FAN_H, 1.0)
	var sh := TEX_AIRFLOW.get_height()
	var cols := maxi(2, int(size.x / 16.0))
	for i in cols:
		var x := roundf((i + 0.5) * size.x / cols) - 2.0
		var speed := 220.0 + (i * 37) % 80
		var y := flow - fmod(_t * speed + i * 67.0, flow + sh)
		# Crop the streak to the flow area so it never draws over the housing.
		var top := maxf(y, 0.0)
		var bottom := minf(y + sh, flow)
		if bottom > top:
			var fade := clampf(y / flow, 0.0, 1.0)
			draw_texture_rect_region(TEX_AIRFLOW, Rect2(x, roundf(top), 4, roundf(bottom - top)),
					Rect2(0, top - y, 4, bottom - top), Color(1, 1, 1, 0.5 + 0.5 * fade))
	var base := Rect2(0, size.y - FAN_H, size.x, FAN_H)
	if _fan_box:
		draw_style_box(_fan_box, base)
	# Blades sit on the housing, one per 32 px, centred.
	var frame := int(_t * 20.0) % 4
	var n := maxi(1, int((size.x - 16.0) / 32.0))
	var x0 := floorf((size.x - n * 32.0) / 2.0) + 4.0
	for i in n:
		draw_texture_rect_region(TEX_FAN_BLADE, Rect2(x0 + i * 32.0, size.y - FAN_H, BLADE, BLADE),
				Rect2(frame * BLADE, 0, BLADE, BLADE))


func _draw_goal() -> void:
	var c := (size / 2.0).round()
	var glow_a := 0.7 + sin(_t * 3.0) * 0.25
	draw_texture(TEX_GOAL_GLOW, c - TEX_GOAL_GLOW.get_size() / 2.0, Color(1, 1, 1, glow_a))
	draw_set_transform(c, -_t * 2.5)
	draw_texture(TEX_GOAL_SWIRL, -TEX_GOAL_SWIRL.get_size() / 2.0)
	draw_set_transform(Vector2.ZERO)
	for i in 4:
		var a := _t * 2.0 + i * TAU / 4.0
		var p := (c + Vector2(cos(a), sin(a)) * 34.0).round() - Vector2(3, 3)
		var tex := TEX_SPARKLES[(i + int(_t * 6.0)) % 2]
		draw_texture(tex, p)
