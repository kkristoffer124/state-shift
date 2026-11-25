@tool
class_name DecoStrip
extends Sprite2D
## Tiles its texture along one axis (pipes, rails, trims, ladders, chains...).
## Origin is the top-left corner. For atlases stacked vertically (several strip
## variants in one texture) pick the band with `row` / `row_height`.

@export var length := 64.0:
	set(v):
		length = maxf(v, 1.0)
		_apply()
@export var vertical := false:
	set(v):
		vertical = v
		_apply()
@export var row := 0:
	set(v):
		row = v
		_apply()
## Height of one band in a stacked atlas (0 = whole texture).
@export var row_height := 0.0:
	set(v):
		row_height = v
		_apply()


func _ready() -> void:
	_apply()


func _apply() -> void:
	if texture == null:
		return
	centered = false
	region_enabled = true
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	var ts := texture.get_size()
	if vertical:
		region_rect = Rect2(0, 0, ts.x, length)
	else:
		var rh := row_height if row_height > 0.0 else ts.y
		region_rect = Rect2(0, row * rh, length, rh)
