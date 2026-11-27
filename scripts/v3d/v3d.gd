@tool
class_name V3D
extends RefCounted
## Shared constants and helpers for the 3D chapters (scripts/v3d/).
##
## SCALE: 1 world unit (metre) = 32 art pixels, so the 2D tuning numbers
## (px/s) become 3D numbers by multiplying with PX. The blob is ~1 m.
##
## PHYSICS LAYERS (same bits as 2D where they overlap):
##   1  world       walls, floors, gates            (everyone collides)
##   2  grate       blocks only ICE
##   4  breakable   cracked blocks (ICE shatters them when falling fast)
##   8  player      the blob's body (turbines/plates watch this)
##   16 zones       Zone3D areas (spikes, heat, freeze, fan, goal)
##   32 glass       lab glass: solid for the blob, invisible to the camera probe
##
## RENDER LAYERS: 1 world, 2 the blob's own body (hidden from the first-person camera).
##
## CHANNELS: Turbine3D / Plate3D call V3D.emit(self, channel, on); receivers
## (Gate3D) join the "v3d_receivers" group and implement `_on_channel(source_id, on)`.

const PX := 1.0 / 32.0

const L_WORLD := 1
const L_GRATE := 2
const L_BREAKABLE := 4
const L_PLAYER := 8
const L_ZONES := 16
const L_GLASS := 32

const MASK_ICE := L_WORLD | L_GRATE | L_BREAKABLE | L_GLASS
const MASK_FLUID := L_WORLD | L_BREAKABLE | L_GLASS
const MASK_CAMERA := L_WORLD | L_BREAKABLE

const RL_BLOB := 2

enum CameraMode { THIRD_PERSON, FIRST_PERSON, SIDE_25D, ISOMETRIC }

const C_WATER := Color("3f8cff")
const C_FROST := Color("80d9ff")
const C_HEAT := Color("ff5a1a")
const C_GOAL := Color("66ff99")
const C_STEEL := Color("9ebcdb")
const STATE_COLORS := [Color(0.72, 0.9, 1.0), Color(0.25, 0.58, 1.0), Color(0.95, 0.97, 1.0)]

## Per-theme mood for the 3D rooms: background/fog, ambient, key + fill light,
## accent light (lamps) and the tint used on floors/tops.
const PALETTES := {
	"lab": {
		"bg": Color("0b1420"), "fog": Color("13233a"), "fog_density": 0.035,
		"ambient": Color("5f7ea6"), "ambient_energy": 0.55,
		"key": Color("cfe6ff"), "key_energy": 0.75,
		"accent": Color("7fd6ff"), "warm": Color("ffd59a"),
		"top_tint": Color(1.05, 1.08, 1.12), "metal": Color("6f8aa8"),
	},
	"sewer": {
		"bg": Color("07120f"), "fog": Color("10261f"), "fog_density": 0.045,
		"ambient": Color("5a8a76"), "ambient_energy": 0.75,
		"key": Color("bfe8cf"), "key_energy": 0.6,
		"accent": Color("8dffb8"), "warm": Color("ffc870"),
		"top_tint": Color(0.95, 1.05, 1.0), "metal": Color("5d7466"),
	},
	"boiler": {
		"bg": Color("140906"), "fog": Color("2a1209"), "fog_density": 0.04,
		"ambient": Color("8a5a40"), "ambient_energy": 0.5,
		"key": Color("ffd2a0"), "key_energy": 0.7,
		"accent": Color("ff8a3a"), "warm": Color("ffb060"),
		"top_tint": Color(1.1, 1.0, 0.92), "metal": Color("8a6a52"),
	},
	"cryo": {
		"bg": Color("0a1622"), "fog": Color("1d3850"), "fog_density": 0.04,
		"ambient": Color("8fb8e0"), "ambient_energy": 0.6,
		"key": Color("e6f4ff"), "key_energy": 0.8,
		"accent": Color("9fe8ff"), "warm": Color("ffe0b0"),
		"top_tint": Color(1.15, 1.18, 1.22), "metal": Color("7f9ab8"),
	},
	"rooftop": {
		"bg": Color("0d1020"), "fog": Color("1a1f38"), "fog_density": 0.02,
		"ambient": Color("6d74a8"), "ambient_energy": 0.55,
		"key": Color("c8d0ff"), "key_energy": 0.7,
		"accent": Color("a0b0ff"), "warm": Color("ffd090"),
		"top_tint": Color(1.0, 1.0, 1.08), "metal": Color("707a96"),
	},
}

const SH_WORLD := preload("res://shaders/v3d/pixel_world.gdshader")
const SH_GRATE := preload("res://shaders/v3d/pixel_grate.gdshader")

static var _mat_cache := {}


static func palette(theme: String) -> Dictionary:
	return PALETTES.get(theme, PALETTES["lab"])


## Shared pixel-art material for a block look in `theme`. Looks:
## "wall" (9-slice panel art on sides, fill art on tops), "fill" (fill art everywhere),
## "grate", "cracked", "gate" (object-space, for moving parts), "dark" (dimmed wall).
static func world_material(theme: String, look: String, tint := Color.WHITE) -> Material:
	var key := "%s/%s/%s" % [theme, look, tint.to_html()]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var tex := EnvTheme.textures(theme)
	var pal := palette(theme)
	var fill: Texture2D = load("res://assets/env_%s/e1b_wall_fill.png" % theme) if ResourceLoader.exists("res://assets/env_%s/e1b_wall_fill.png" % theme) else tex.wall
	var m := ShaderMaterial.new()
	m.shader = SH_GRATE if look == "grate" else SH_WORLD
	var side: Texture2D = tex.wall
	var top: Texture2D = fill
	var tint_side := tint
	var tint_top: Color = tint * pal.top_tint
	match look:
		"fill":
			side = fill
		"grate":
			side = tex.grate
			top = tex.grate
			tint_top = tint
		"cracked":
			side = tex.cracked
			top = tex.cracked
			tint_top = tint
		"gate":
			side = load("res://assets/interactive/ix_gate_tile.png")
			top = side
			m.set_shader_parameter("local_space", true)
		"dark":
			tint_side = tint * Color(0.55, 0.55, 0.6)
			tint_top = tint * Color(0.6, 0.6, 0.65)
	m.set_shader_parameter("side_tex", side)
	m.set_shader_parameter("top_tex", top)
	m.set_shader_parameter("tint", tint_side)
	m.set_shader_parameter("top_tint", tint_top)
	_mat_cache[key] = m
	return m


static func glass_material() -> Material:
	if _mat_cache.has("glass"):
		return _mat_cache["glass"]
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.55, 0.85, 1.0, 0.16)
	m.roughness = 0.05
	m.metallic_specular = 0.9
	m.rim_enabled = true
	m.rim = 0.6
	m.rim_tint = 0.2
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat_cache["glass"] = m
	return m


## Plain lit colour material (metal trims, pipes, furniture).
static func flat_material(color: Color, metallic := 0.3, roughness := 0.6, emission := Color.BLACK, emission_energy := 0.0) -> Material:
	var key := "flat/%s/%.2f/%.2f/%s/%.2f" % [color.to_html(), metallic, roughness, emission.to_html(), emission_energy]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = roughness
	if emission_energy > 0.0:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = emission_energy
	_mat_cache[key] = m
	return m


## Unshaded additive/alpha sprite material for glows, sparkles and particles.
static func sprite_material(tex: Texture2D, additive := false, billboard := BaseMaterial3D.BILLBOARD_ENABLED, color := Color.WHITE) -> Material:
	var key := "spr/%s/%s/%d/%s" % [tex.resource_path if tex else "none", additive, billboard, color.to_html()]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_texture = tex
	m.albedo_color = color
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.billboard_mode = billboard
	m.billboard_keep_scale = true
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat_cache[key] = m
	return m


## Cutaway height for every shared pixel-art material (isometric view).
static func set_cut(y: float) -> void:
	for m in _mat_cache.values():
		if m is ShaderMaterial:
			(m as ShaderMaterial).set_shader_parameter("cut_y", y)


# --- Channels ---------------------------------------------------------------------

static func emit(source: Node, channel: String, on: bool) -> void:
	if channel == "" or not source.is_inside_tree():
		return
	for r in source.get_tree().get_nodes_in_group("v3d_receivers"):
		if r.get("channel") == channel and r.has_method("_on_channel"):
			r._on_channel(source.get_instance_id(), on)


## Player state as int (0 ICE, 1 WATER, 2 STEAM), -1 if not a live 3D player.
static func state_of(body: Node) -> int:
	if body == null or not is_instance_valid(body) or not (body is CharacterBody3D) or not ("state" in body):
		return -1
	if body.get("dead") or body.get("won"):
		return -1
	return int(body.get("state"))


## The level root (Level3D) above `n`, or null.
static func level_of(n: Node) -> Node:
	var p := n
	while p:
		if p is Level3D:
			return p
		p = p.get_parent()
	return null


## Recursively puts every VisualInstance3D under `n` on render layer `layer` only.
static func set_render_layer(n: Node, layer: int) -> void:
	if n is VisualInstance3D:
		(n as VisualInstance3D).layers = layer
	for c in n.get_children():
		set_render_layer(c, layer)


## Adds an internal (unsaved) child: generated visuals of @tool props live here.
static func add_internal(parent: Node, child: Node) -> Node:
	parent.add_child(child, false, Node.INTERNAL_MODE_FRONT)
	return child
