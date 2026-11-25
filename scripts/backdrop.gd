@tool
extends CanvasLayer
## Animated parallax lab backdrop (scenes/background.tscn).
## Gradient sky + far layer (e9a_back) + mid layer (e9b_mid), 16-frame loops,
## scrolled horizontally from the active camera at different speeds, plus
## rising bubbles. Everything wraps horizontally.
## `theme` (set by the owning level) recolours the lab art for the other wings with
## shaders/backdrop_theme.gdshader; "lab" shows the art untouched.

const FRAMES := 16
const SHADER := preload("res://shaders/backdrop_theme.gdshader")

## Per-theme shader parameters. "back"/"mid" override the shared ones per layer;
## "sky" tints the gradient, "bubbles" tints the bubbles (alpha 0 hides them).
const THEMES := {
	"cryo": {
		"dark_col": Color(0.03, 0.09, 0.13), "light_col": Color(0.46, 0.72, 0.84),
		"ramp_gain": 2.4, "tint": 0.82, "fill": 2,
		"fill_a": Color(0.10, 0.22, 0.29), "fill_b": Color(0.04, 0.10, 0.14),
		"glow_col": Color(0.55, 0.85, 1.0), "glow": 0.16, "glow_height": 0.3,
		"sky": Color(0.55, 0.8, 0.95), "bubbles": Color(0.9, 0.97, 1.0, 0.45),
	},
	"boiler": {
		"dark_col": Color(0.06, 0.035, 0.03), "light_col": Color(0.64, 0.35, 0.21),
		"ramp_gain": 2.6, "tint": 0.88, "fill": 1,
		"fill_a": Color(0.25, 0.135, 0.10), "fill_b": Color(0.09, 0.05, 0.04),
		"glow_col": Color(1.0, 0.40, 0.10), "glow": 0.34, "glow_height": 0.42, "flicker": 0.3,
		"sky": Color(0.7, 0.4, 0.3), "bubbles": Color(1.0, 0.55, 0.2, 0.35),
	},
	"sewer": {
		"dark_col": Color(0.025, 0.07, 0.06), "light_col": Color(0.36, 0.56, 0.42),
		"ramp_gain": 2.6, "tint": 0.82, "fill": 1,
		"fill_a": Color(0.12, 0.18, 0.155), "fill_b": Color(0.045, 0.075, 0.065),
		"glow_col": Color(0.25, 0.6, 0.42), "glow": 0.16, "glow_height": 0.35, "flicker": 0.05,
		"water_line": 472.0, "water_col": Color(0.07, 0.24, 0.21),
		"sky": Color(0.4, 0.6, 0.5), "bubbles": Color(0.55, 0.85, 0.6, 0.4),
	},
	"rooftop": {
		"dark_col": Color(0.02, 0.025, 0.06), "light_col": Color(0.25, 0.3, 0.5),
		"ramp_gain": 2.6, "tint": 0.9, "fill": 3,
		"fill_a": Color(0.015, 0.02, 0.07), "fill_b": Color(0.13, 0.13, 0.27),
		"glow_col": Color(0.45, 0.35, 0.65), "glow": 0.14, "glow_height": 0.35,
		"back": {"keep_art": 0.0}, "mid": {"hidden": true},
		"sky": Color(0.3, 0.35, 0.6), "bubbles": Color(1, 1, 1, 0.0),
	},
}

## Environment theme (lab, cryo, boiler, sewer, rooftop); the level sets it on ready.
@export_enum("lab", "cryo", "boiler", "sewer", "rooftop") var theme := "lab":
	set(v):
		theme = v
		_apply_theme()

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
var _bubble_mod := Color(1, 1, 1, 0.5)
static var _materials := {} # theme -> [back material, mid material]

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
	# Pick up the owning level's theme (also in the editor); the level re-applies it on ready.
	var t := EnvTheme.find_theme(self)
	if t != theme:
		theme = t
	else:
		_apply_theme()


func _apply_theme() -> void:
	if not is_node_ready():
		return
	var cfg: Dictionary = THEMES.get(theme, {})
	if cfg.is_empty():
		back.material = null
		mid.material = null
		mid.visible = true
		gradient.self_modulate = Color.WHITE
		_bubble_mod = Color(1, 1, 1, 0.5)
		bubbles.visible = true
		return
	if not _materials.has(theme):
		_materials[theme] = [_make_material(cfg, cfg.get("back", {}), 1), _make_material(cfg, cfg.get("mid", {}), 0)]
	back.material = _materials[theme][0]
	mid.material = _materials[theme][1]
	mid.visible = not cfg.get("mid", {}).get("hidden", false)
	gradient.self_modulate = cfg.get("sky", Color.WHITE)
	_bubble_mod = cfg.get("bubbles", Color(1, 1, 1, 0.5))
	bubbles.visible = _bubble_mod.a > 0.0


static func _make_material(cfg: Dictionary, layer: Dictionary, fill_layer: int) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	for k in cfg:
		if k in ["back", "mid", "sky", "bubbles"]:
			continue
		var v = cfg[k]
		if v is Color:
			v = Vector3(v.r, v.g, v.b)
		m.set_shader_parameter(k, v)
	if fill_layer == 0:
		m.set_shader_parameter("fill", 0)
	for k in layer:
		if k != "hidden":
			m.set_shader_parameter(k, layer[k])
	return m


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
	if bubbles.visible:
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
		bubbles.draw_texture(tex, (p - tex.get_size() * 0.5).round(), _bubble_mod)
