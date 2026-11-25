@tool
class_name AnimBackdrop
extends TextureRect
## Full-screen flipbook backdrop (menu / end screen art).

@export var frames: Array[Texture2D] = []:
	set(v):
		frames = v
		if not frames.is_empty():
			texture = frames[0]
@export var fps := 8.0
@export var playing := true

var _t := 0.0


func _process(delta: float) -> void:
	if not playing or frames.is_empty():
		return
	_t += delta
	var f := int(_t * fps) % frames.size()
	if texture != frames[f]:
		texture = frames[f]
