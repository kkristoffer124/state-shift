@tool
class_name Hint3D
extends Label3D
## Tutorial text floating in the room, styled like the 2D level hints
## (pale text, dark outline). Y-billboarded so it reads from any camera.

func _ready() -> void:
	billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	pixel_size = 0.0045
	font_size = 40
	outline_size = 14
	modulate = Color(0.88, 0.95, 1, 0.95)
	outline_modulate = Color(0.03, 0.05, 0.08, 0.85)
	shaded = false
	double_sided = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
