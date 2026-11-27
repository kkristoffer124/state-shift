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

## box_mesh() trim bits: base band on the sides; edge trim on side face i (0 +X,
## 1 -X, 2 +Z, 3 -Z) is TRIM_EDGE << i.
const TRIM_BASE := 1
const TRIM_EDGE := 2
const TRIM_EDGE_ALL := 30

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
const SH_SURFACE := preload("res://shaders/v3d/pixel_surface.gdshader")
const SH_GRATE := preload("res://shaders/v3d/pixel_grate.gdshader")
const SH_GLOW := preload("res://shaders/v3d/pixel_glow.gdshader")
const SH_GLASS := preload("res://shaders/v3d/pixel_glass.gdshader")
const SH_SCREEN := preload("res://shaders/v3d/pixel_screen.gdshader")
const TEX_DIR := "res://assets/v3d/tex/"

## Per-theme surface tuning: floor B share of the 2x2 m cells, chance a 2 m row of a
## block's sides uses wall B, chance a whole block does.
const SURFACE := {
	"lab": {"floor_b": 0.3, "rows": 0.22, "blocks": 0.0},
	"cryo": {"floor_b": 0.35, "rows": 0.25, "blocks": 0.0},
	"boiler": {"floor_b": 0.35, "rows": 0.25, "blocks": 0.0},
	"sewer": {"floor_b": 0.4, "rows": 0.3, "blocks": 0.0},
	"rooftop": {"floor_b": 0.35, "rows": 0.0, "blocks": 0.4},
}

## Warning light states (Gate3D status lamp).
enum Warn { OFF, BLINK, OPEN }

static var _mat_cache := {}
static var _mesh_cache := {}


static func palette(theme: String) -> Dictionary:
	return PALETTES.get(theme, PALETTES["lab"])


## Hand-made 3D texture `name` (assets/v3d/tex/<name>.png).
static func tex(name: String) -> Texture2D:
	return load(TEX_DIR + name + ".png")


## Shared pixel-art material for a block look in `theme`. Looks:
## "wall" (floor A/B tops, wall A/B sides, ceiling undersides, base/edge trims),
## "fill" (same art, wall A only and no trims: furniture), "dark" (dimmed wall),
## "grate" (see-through bars), "cracked" (crack1 frame), "gate" (steel shutter with a
## hazard frame, object space so it moves with the gate).
static func world_material(theme: String, look: String, tint := Color.WHITE) -> Material:
	if not SURFACE.has(theme):
		theme = "lab"
	var key := "%s/%s/%s" % [theme, look, tint.to_html()]
	if _mat_cache.has(key):
		return _mat_cache[key]
	match look:
		"grate":
			var g := ShaderMaterial.new()
			g.shader = SH_GRATE
			g.set_shader_parameter("side_tex", tex("m6_grate"))
			g.set_shader_parameter("top_tex", tex("m6_grate"))
			g.set_shader_parameter("tint", tint)
			g.set_shader_parameter("top_tint", tint)
			_mat_cache[key] = g
			return g
		"cracked":
			return cracked_material(1, tint)
		"gate":
			var gm := ShaderMaterial.new()
			gm.shader = SH_WORLD
			gm.set_shader_parameter("side_tex", tex("m9_metal_steel"))
			gm.set_shader_parameter("top_tex", tex("m9_metal_steel"))
			gm.set_shader_parameter("local_space", true)
			gm.set_shader_parameter("frame_tex", tex("m9_metal_hazard"))
			gm.set_shader_parameter("frame_w", 0.19)
			gm.set_shader_parameter("tint", Color(0.78, 0.8, 0.85) * tint)
			gm.set_shader_parameter("top_tint", Color(0.85, 0.87, 0.92) * tint)
			gm.set_shader_parameter("metal", 0.5)
			gm.set_shader_parameter("rough", 0.5)
			_mat_cache[key] = gm
			return gm
	var pal := palette(theme)
	var cfg: Dictionary = SURFACE[theme]
	var m := ShaderMaterial.new()
	m.shader = SH_SURFACE
	m.set_shader_parameter("floor_a", tex("m1_floor_a_" + theme))
	m.set_shader_parameter("floor_b", tex("m1_floor_b_" + theme))
	m.set_shader_parameter("wall_a", tex("m2_wall_a_" + theme))
	m.set_shader_parameter("wall_b", tex("m2_wall_b_" + theme))
	m.set_shader_parameter("ceil_tex", tex("m4_ceiling_" + theme))
	m.set_shader_parameter("base_trim", tex("m3_wall_base_trim_" + theme))
	m.set_shader_parameter("edge_trim", tex("m5_edge_trim_" + theme))
	m.set_shader_parameter("floor_b_chance", cfg.floor_b)
	m.set_shader_parameter("wall_b_rows", cfg.rows)
	m.set_shader_parameter("wall_b_blocks", cfg.blocks)
	var tint_side := tint
	var tint_top: Color = tint * pal.top_tint
	match look:
		"fill":
			m.set_shader_parameter("wall_b_rows", 0.0)
			m.set_shader_parameter("wall_b_blocks", 0.0)
			m.set_shader_parameter("trims", false)
		"dark":
			tint_side = tint * Color(0.62, 0.62, 0.68)
			tint_top = tint * Color(0.68, 0.68, 0.72)
	m.set_shader_parameter("tint", tint_side)
	m.set_shader_parameter("top_tint", tint_top)
	m.set_shader_parameter("ceil_tint", tint_side)
	_mat_cache[key] = m
	return m


## Cracked block (m7 atlas): frame 0 intact, 1 cracked, 2 about to break.
static func cracked_material(frame: int, tint := Color.WHITE) -> Material:
	var key := "cracked/%d/%s" % [frame, tint.to_html()]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := ShaderMaterial.new()
	m.shader = SH_WORLD
	m.set_shader_parameter("side_tex", tex("m7_cracked_block_3f"))
	m.set_shader_parameter("top_tex", tex("m7_cracked_block_3f"))
	m.set_shader_parameter("atlas_frames", 3)
	m.set_shader_parameter("atlas_frame", clampi(frame, 0, 2))
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("top_tint", tint * 1.08)
	_mat_cache[key] = m
	return m


## Pixel-art steel (m9 steel, 32 px = 1 m) recoloured to `tint`: trims, rails, plates,
## turbines and other steel props.
static func metal_material(tint: Color, shine := 0.55) -> Material:
	var key := "metal/%s/%.2f" % [tint.to_html(), shine]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := ShaderMaterial.new()
	m.shader = SH_WORLD
	m.set_shader_parameter("side_tex", tex("m9_metal_steel"))
	m.set_shader_parameter("top_tex", tex("m9_metal_steel"))
	m.set_shader_parameter("recolor", 0.85)
	m.set_shader_parameter("tint", tint * 1.35)
	m.set_shader_parameter("top_tint", tint * 1.35)
	m.set_shader_parameter("metal", shine)
	m.set_shader_parameter("rough", 0.5)
	_mat_cache[key] = m
	return m


## Copper (m9 copper pipe art) for pipes, bands and warm metal trims. `pipe`: cylinder
## mapping (local Y axis) so the highlight streak runs along the pipe.
static func copper_material(tint := Color.WHITE, pipe := false) -> Material:
	return _metal_tex_material("m9_metal_copper_pipe", tint, pipe, 0.6)


## Steel art wrapped around a pipe (cold / coloured pipes), recoloured to `tint`.
static func steel_pipe_material(tint: Color) -> Material:
	var key := "steelpipe/%s" % tint.to_html()
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := _metal_tex_material("m9_metal_steel", Color.WHITE, true, 0.6, key) as ShaderMaterial
	m.set_shader_parameter("recolor", 0.85)
	m.set_shader_parameter("tint", tint * 1.45)
	m.set_shader_parameter("top_tint", tint * 1.6)
	return m


## Yellow/black hazard stripes (plate rims, drop edges, warning pads, gate frames).
static func hazard_material() -> Material:
	return _metal_tex_material("m9_metal_hazard", Color(0.95, 0.95, 0.95), false, 0.2)


static func _metal_tex_material(file: String, tint: Color, pipe: bool, shine: float, key := "") -> Material:
	if key == "":
		key = "%s/%s/%s" % [file, tint.to_html(), pipe]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := ShaderMaterial.new()
	m.shader = SH_WORLD
	m.set_shader_parameter("side_tex", tex(file))
	m.set_shader_parameter("top_tex", tex(file))
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("top_tint", tint * 1.1)
	m.set_shader_parameter("metal", shine)
	m.set_shader_parameter("rough", 0.5)
	if pipe:
		m.set_shader_parameter("local_space", true)
		m.set_shader_parameter("uv_mode", 1)
		m.set_shader_parameter("bevel", 0.0)
	_mat_cache[key] = m
	return m


## True for warm (orange/brown) tints: those metals use the copper art.
static func is_warm(c: Color) -> bool:
	return c.r > c.b * 1.35 and c.r >= c.g


## Emissive panel / screen / sign (pixel scanlines + dark bezel on box faces).
static func glow_material(color: Color, energy := 2.0, scanlines := 1.0) -> Material:
	var key := "glow/%s/%.2f/%.2f" % [color.to_html(), energy, scanlines]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := ShaderMaterial.new()
	m.shader = SH_GLOW
	m.set_shader_parameter("glow_color", color)
	m.set_shader_parameter("energy", energy)
	m.set_shader_parameter("scanlines", scanlines)
	_mat_cache[key] = m
	return m


## Animated monitor (m10 monitor, 4 frames at 4 fps) filling the face height and
## repeating across wide faces as a row of panels.
static func screen_material(energy := 1.5) -> Material:
	var key := "screen/%.2f" % energy
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := ShaderMaterial.new()
	m.shader = SH_SCREEN
	m.set_shader_parameter("screen_tex", tex("m10_emissive_monitor_4f"))
	m.set_shader_parameter("screen_frames", 4)
	m.set_shader_parameter("fps", 4.0)
	m.set_shader_parameter("energy", energy)
	_mat_cache[key] = m
	return m


## Round warning lamp (m10 warning light: off / on). OPEN shows it lit green.
static func warning_material(state: Warn) -> Material:
	var key := "warn/%d" % state
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := ShaderMaterial.new()
	m.shader = SH_SCREEN
	m.set_shader_parameter("screen_tex", tex("m10_emissive_warning_light_2f"))
	m.set_shader_parameter("screen_frames", 2)
	m.set_shader_parameter("cutout", true)
	m.set_shader_parameter("energy", 2.2)
	match state:
		Warn.OFF:
			m.set_shader_parameter("still_frame", 0)
			m.set_shader_parameter("energy", 0.6)
		Warn.BLINK:
			m.set_shader_parameter("blink", 3.0)
		Warn.OPEN:
			m.set_shader_parameter("still_frame", 1)
			m.set_shader_parameter("recolor_to", Color(0.45, 1.0, 0.55, 1.0))
	_mat_cache[key] = m
	return m


## Box mesh of `size` centred on the origin whose UV is the face position in metres
## from the face's top-left and UV2 the face size: pixel_world / pixel_glow draw a
## texel-snapped bevel along the edges from it. Shared per size.
## `trims` (pixel_surface): TRIM_BASE draws the base trim band along the bottom 0.5 m
## of the sides, TRIM_EDGE << face the edge trim along that side's top 0.25 m
## (stored in COLOR.r / COLOR.g).
static func box_mesh(size: Vector3, trims := 0) -> Mesh:
	var key := "%.3f/%.3f/%.3f/%d" % [size.x, size.y, size.z, trims]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var h := size / 2.0
	var faces := [
		[Vector3.RIGHT, Vector3.FORWARD, Vector3.DOWN],
		[Vector3.LEFT, Vector3.BACK, Vector3.DOWN],
		[Vector3.BACK, Vector3.RIGHT, Vector3.DOWN],
		[Vector3.FORWARD, Vector3.LEFT, Vector3.DOWN],
		[Vector3.UP, Vector3.RIGHT, Vector3.BACK],
		[Vector3.DOWN, Vector3.RIGHT, Vector3.FORWARD],
	]
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	for fi in faces.size():
		var f: Array = faces[fi]
		var edge := fi < 4 and trims & (TRIM_EDGE << fi) != 0
		var col := Color(0.0 if trims & TRIM_BASE else 1.0, 0.0 if edge else 1.0, 1.0, 1.0)
		var n: Vector3 = f[0]
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var w := absf(u.dot(size))
		var hh := absf(v.dot(size))
		var base := verts.size()
		for c in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
			verts.append(n * absf(n.dot(h)) + u * (c.x - 0.5) * w + v * (c.y - 0.5) * hh)
			norms.append(n)
			uvs.append(Vector2(c.x * w, c.y * hh))
			uv2s.append(Vector2(w, hh))
			cols.append(col)
		idx.append_array([base, base + 1, base + 2, base, base + 2, base + 3])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_TEX_UV2] = uv2s
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	_mesh_cache[key] = m
	return m


static func glass_material() -> Material:
	if _mat_cache.has("glass"):
		return _mat_cache["glass"]
	var m := ShaderMaterial.new()
	m.shader = SH_GLASS
	m.set_shader_parameter("side_tex", tex("m8_glass"))
	m.set_shader_parameter("top_tex", tex("m8_glass"))
	m.set_shader_parameter("bevel", 0.0)
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
