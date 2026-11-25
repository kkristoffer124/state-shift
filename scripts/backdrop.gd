@tool
extends CanvasLayer
## Animated parallax lab backdrop (scenes/background.tscn).
## Gradient sky + far layer (e9a_back) + mid layer (e9b_mid), 16-frame loops,
## scrolled horizontally from the active camera at different speeds, plus
## rising bubbles. Everything wraps horizontally.

const FRAMES := 16

@export var fps := 8.0
## How much each layer follows the camera (0 = fixed, 1 = moves with the world).
@export var back_scroll := Vector2(0.06, 0.02)
@export var mid_scroll := Vector2(0.14, 0.04)
@export var bubble_count := 14

var _back: Array[Texture2D] = []
var _mid: Array[Texture2D] = []
var _bubble_tex: Array[Texture2D] = []
var _bubbles: Array[Vector4] = [] # x, y, speed, size index
var _t := 0.0
var _origin := Vector2.INF

@onready var gradient: TextureRect = $Gradient
@onready var back: Sprite2D = $Back
@onready var mid: Sprite2D = $Mid
@onready var bubbles: Node2D = $Bubbles


func _ready() -> void:
	for i in FRAMES:
		_back.append(load("res://assets/backdrops/e9a_back_f%02d.png" % (i + 1)))
		_mid.append(load("res://assets/backdrops/e9b_mid_f%02d.png" % (i + 1)))
	for s in [8, 16, 32]:
		_bubble_tex.append(load("res://assets/backdrops/e9c_bubble_%d.png" % s))
	for i in bubble_count:
		_bubbles.append(Vector4(randf(), randf(), randf_range(8.0, 22.0), randi() % 3))
	bubbles.draw.connect(_draw_bubbles)
	back.texture = _back[0]
	mid.texture = _mid[0]


func _process(delta: float) -> void:
	_t += delta
	var f := int(_t * fps) % FRAMES
	back.texture = _back[f]
	mid.texture = _mid[f]
	var vp := get_viewport().get_visible_rect().size
	var cam_pos := Vector2.ZERO
	var cam := get_viewport().get_camera_2d()
	if cam and not Engine.is_editor_hint():
		cam_pos = cam.get_screen_center_position()
		if _origin == Vector2.INF:
			_origin = cam_pos
		cam_pos -= _origin
	_layer(back, cam_pos * back_scroll, vp)
	_layer(mid, cam_pos * mid_scroll, vp)
	for i in _bubbles.size():
		var b := _bubbles[i]
		b.y -= b.z * delta / vp.y
		if b.y < -0.1:
			b = Vector4(randf(), 1.1, randf_range(8.0, 22.0), randi() % 3)
		_bubbles[i] = b
	bubbles.queue_redraw()


## Scales the 960x540 art to cover the screen and scrolls it with wrap-around.
func _layer(s: Sprite2D, offset: Vector2, vp: Vector2) -> void:
	var tex_size := Vector2(960, 540)
	var k := maxf(vp.x / tex_size.x, vp.y / tex_size.y)
	k = maxf(1.0, floorf(k)) if k >= 1.0 else k
	s.scale = Vector2(k, k)
	var region_w := vp.x / k
	var slack := maxf((tex_size.y - vp.y / k) * 0.5, 0.0) # never wrap vertically
	var y := slack + clampf(offset.y, -slack, slack)
	s.region_rect = Rect2(offset.x, y, region_w, vp.y / k)
	s.position = Vector2.ZERO


func _draw_bubbles() -> void:
	var vp := get_viewport().get_visible_rect().size
	for b in _bubbles:
		var tex := _bubble_tex[int(b.w)]
		var p := Vector2(b.x * vp.x + sin(_t * 0.7 + b.x * 20.0) * 6.0, b.y * vp.y)
		bubbles.draw_texture(tex, (p - tex.get_size() * 0.5).round(), Color(1, 1, 1, 0.5))
