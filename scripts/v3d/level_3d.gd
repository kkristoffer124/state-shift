@tool
class_name Level3D
extends Node3D
## Root of a 3D chapter. Expected children (all real nodes in the .tscn):
##   WorldEnvironment   colours/fog are filled in from the theme palette (V3D.PALETTES)
##   KeyLight           DirectionalLight3D, coloured from the palette
##   Blocks             Block3D pieces (level bounds = their union)
##   Zones              Zone3D volumes (spikes, heat, freeze, fans, goal)
##   Interactive        Turbine3D / Gate3D / Plate3D (channel-driven)
##   Decor              lamps, pipes, furniture (no gameplay)
##   Hints              Hint3D labels
##   Player             scenes/v3d/player_3d.tscn
##   CameraRig          scenes/v3d/camera_rig_3d.tscn (its yaw_deg sets the start view)
## In _ready it wires the player to the rig and calls Game.on_level_ready(self, player).

@export var level_name := "Level"
@export_enum("lab", "cryo", "boiler", "sewer", "rooftop") var theme := "lab":
	set(v):
		theme = v
		_apply_theme()
@export var camera_mode: V3D.CameraMode = V3D.CameraMode.THIRD_PERSON
## SIDE_25D: the plane (z) the blob is locked to.
@export var side_plane_z := 0.0
## Falling below this kills (safety net).
@export var kill_y := -12.0
## Outdoor levels: highest the blob can float (steam stops rising here).
@export var max_y := 1000.0
## Multiplies the palette ambient light (isometric rooms want more).
@export var ambient_boost := 1.0:
	set(v):
		ambient_boost = v
		_apply_theme()
## Multiplies the palette fog density.
@export var fog_scale := 1.0:
	set(v):
		fog_scale = v
		_apply_theme()

var player: Player3D
var rig: CameraRig3D
var _cut := INF
var _cut_items: Array = []


func _ready() -> void:
	_apply_theme()
	if Engine.is_editor_hint():
		return
	V3D.set_cut(100000.0)
	player = get_node_or_null("Player") as Player3D
	rig = get_node_or_null("CameraRig") as CameraRig3D
	if player == null or rig == null:
		push_error("Level3D %s needs Player and CameraRig children" % name)
		return
	var side := camera_mode == V3D.CameraMode.SIDE_25D
	rig.setup(self, player, camera_mode, get_bounds(), side_plane_z)
	player.setup(self, rig, side, side_plane_z, kill_y)
	player.max_y = max_y
	if camera_mode == V3D.CameraMode.ISOMETRIC:
		# Orthographic view shows far more of the room: scale the hints up to match
		# and keep them readable over walls.
		var s: float = rig.camera.size / 6.0
		for h in find_children("*", "Label3D", true, false):
			if h is Hint3D:
				h.pixel_size *= s
				h.billboard = BaseMaterial3D.BILLBOARD_ENABLED
				h.no_depth_test = true
				h.render_priority = 5
	Game.on_level_ready(self, player)


func _exit_tree() -> void:
	if not Engine.is_editor_hint() and _cut < INF:
		V3D.set_cut(100000.0)


## Isometric cutaway: shared pixel materials discard everything above `y`, and
## plain-colour props (decor, trims, glass, pipes) that start above it are hidden.
func apply_cut(y: float) -> void:
	if absf(y - _cut) < 0.05:
		return
	if _cut == INF:
		for group in ["Decor", "Blocks", "Interactive"]:
			var g := get_node_or_null(group)
			if g == null:
				continue
			for n in g.get_children():
				if n is Block3D and group == "Blocks" and n.kind != Block3D.Kind.GLASS and n.look < Block3D.Look.METAL:
					continue
				if n is Node3D and not n is Light3D:
					_cut_items.append([n, _bottom_of(n)])
	_cut = y
	V3D.set_cut(y)
	for it in _cut_items:
		it[0].visible = it[1] <= y


static func _bottom_of(n: Node3D) -> float:
	if n is Block3D:
		return (n as Block3D).get_aabb().position.y
	if n is VisualInstance3D:
		return (n.global_transform * (n as VisualInstance3D).get_aabb()).position.y
	return n.global_position.y


## Union of all solid blocks.
func get_bounds() -> AABB:
	var r := AABB()
	var first := true
	if not has_node("Blocks"):
		return r
	for b in $Blocks.find_children("*", "StaticBody3D", true, false):
		if b is Block3D and b.kind != Block3D.Kind.DECOR:
			var bb: AABB = b.get_aabb()
			r = bb if first else r.merge(bb)
			first = false
	return r


func _apply_theme() -> void:
	if not is_inside_tree():
		return
	var pal := V3D.palette(theme)
	var we := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we:
		if we.environment == null:
			we.environment = Environment.new()
		var env := we.environment
		env.background_mode = Environment.BG_COLOR
		env.background_color = pal.bg
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = pal.ambient
		env.ambient_light_energy = pal.ambient_energy * ambient_boost
		env.fog_enabled = true
		env.fog_light_color = pal.fog
		env.fog_density = pal.fog_density * fog_scale
		env.fog_sky_affect = 0.0
	var key := get_node_or_null("KeyLight") as DirectionalLight3D
	if key:
		key.light_color = pal.key
		key.light_energy = pal.key_energy
	if Engine.is_editor_hint():
		for n in find_children("*", "", true, false):
			if (n is Block3D or n is Zone3D) and n.has_method("_refresh"):
				n._refresh()
