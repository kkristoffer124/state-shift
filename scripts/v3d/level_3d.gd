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
var _cut_bottom := {}
## Isometric: camera-side walls hidden for the current view direction, and blocks
## hidden while they stand between the camera and the blob (node -> seconds left).
var _near_hidden := {}
var _view_items: Array = []
var _occ_hidden := {}


func _ready() -> void:
	_apply_theme()
	assign_trims()
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
		var s: float = rig.camera.size / 4.8
		for h in find_children("*", "Label3D", true, false):
			if h is Hint3D:
				h.pixel_size *= s
				h.billboard = BaseMaterial3D.BILLBOARD_ENABLED
				h.no_depth_test = true
				h.render_priority = 5
	if camera_mode == V3D.CameraMode.ISOMETRIC or camera_mode == V3D.CameraMode.THIRD_PERSON:
		for z in find_children("*", "Area3D", true, false):
			if z is Zone3D and z.kind == Zone3D.Kind.GOAL:
				z.add_beacon(camera_mode == V3D.CameraMode.ISOMETRIC)
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
					_cut_bottom[n] = _bottom_of(n)
	_cut = y
	V3D.set_cut(y)
	for n in _cut_bottom:
		_refresh_vis(n)


## Isometric: hides the tall walls (and glass) along the camera side of the room so
## they never cover the play space, whichever way the view is turned. `fwd` is the
## camera's horizontal forward. Low walls (< 1.5 m) stay as the room's rim.
func apply_view(fwd: Vector3) -> void:
	var b := get_bounds()
	if _view_items.is_empty():
		for group in ["Blocks", "Decor"]:
			var g := get_node_or_null(group)
			if g == null:
				continue
			for n in g.get_children():
				if n is Block3D and n.kind != Block3D.Kind.DECOR:
					var bb: AABB = n.get_aabb()
					if bb.size.y >= 1.5 and minf(bb.size.x, bb.size.z) <= 0.8:
						_view_items.append([n, bb])
	var band := 0.9
	var was := _near_hidden.duplicate()
	_near_hidden.clear()
	for it in _view_items:
		var bb: AABB = it[1]
		var near := false
		if bb.size.x <= 0.8:
			near = (fwd.x < -0.3 and bb.position.x >= b.end.x - band) or (fwd.x > 0.3 and bb.end.x <= b.position.x + band)
		if bb.size.z <= 0.8 and not near:
			near = (fwd.z < -0.3 and bb.position.z >= b.end.z - band) or (fwd.z > 0.3 and bb.end.z <= b.position.z + band)
		if near:
			_near_hidden[it[0]] = true
	for n in was:
		_refresh_vis(n)
	for n in _near_hidden:
		_refresh_vis(n)


## Isometric: anything standing between the camera and the blob is hidden while it
## does (and a moment longer, so it doesn't flicker). `back` points at the camera.
func update_occluders(p: Vector3, back: Vector3, delta: float) -> void:
	if player == null:
		return
	var space := get_world_3d().direct_space_state
	var mask := V3D.L_WORLD | V3D.L_BREAKABLE | V3D.L_GLASS | V3D.L_GRATE
	var side := back.cross(Vector3.UP).normalized() * 0.32
	for off in [Vector3.ZERO, Vector3.UP * 0.35, side, -side]:
		var excl: Array[RID] = [player.get_rid()]
		var from: Vector3 = p + off
		for i in 5:
			var q := PhysicsRayQueryParameters3D.create(from, from + back * 40.0, mask, excl)
			var hit := space.intersect_ray(q)
			if hit.is_empty() or (hit.position as Vector3).y > _cut + 0.02:
				break
			excl.append(hit.rid)
			var c := hit.collider as Node3D
			while c and not c is Block3D and c.get_parent() != self and c.get_parent() is Node3D:
				c = c.get_parent()
			if c is Block3D and (c as Block3D).get_aabb().end.y > p.y - 0.3:
				if not _occ_hidden.has(c):
					_occ_hidden[c] = 0.35
					_refresh_vis(c)
				else:
					_occ_hidden[c] = 0.35
	for c in _occ_hidden.keys():
		_occ_hidden[c] -= delta
		if not is_instance_valid(c):
			_occ_hidden.erase(c)
		elif _occ_hidden[c] <= 0.0:
			_occ_hidden.erase(c)
			_refresh_vis(c)


func _refresh_vis(n: Variant) -> void:
	if not is_instance_valid(n):
		return
	var vis := not _near_hidden.has(n) and not _occ_hidden.has(n)
	if _cut_bottom.has(n):
		vis = vis and (_cut == INF or _cut_bottom[n] <= _cut)
	n.visible = vis


static func _bottom_of(n: Node3D) -> float:
	if n is Block3D:
		return (n as Block3D).get_aabb().position.y
	if n is VisualInstance3D:
		return (n.global_transform * (n as VisualInstance3D).get_aabb()).position.y
	return n.global_position.y


## Base / edge trim bits for every theme-surface block from its neighbours:
##  base  sides >= 1.2 m tall standing on another block (top within 6 cm of its bottom)
##  edge  platforms (footprint >= 1.5 m both ways, >= 0.4 m tall) whose top isn't covered
##        by a block sitting on most of it: hazard/metal strip along each side whose
##        top edge is open (no wall standing along it), i.e. the drop edges.
func assign_trims() -> void:
	var blocks: Array[Block3D] = []
	for b in find_children("*", "StaticBody3D", true, false):
		if b is Block3D and b.kind != Block3D.Kind.DECOR:
			blocks.append(b)
	var boxes := {}
	for b in blocks:
		boxes[b] = AABB(b.global_position - b.size / 2.0, b.size)
	for b in blocks:
		if not b.is_surface():
			continue
		var bb: AABB = boxes[b]
		var flags := 0
		var bottom := bb.position.y
		var top := bb.end.y
		var foot := Rect2(bb.position.x, bb.position.z, bb.size.x, bb.size.z)
		var area := foot.get_area()
		var supported := false
		var covered := 0.0
		# Strips along the four top edges (+X, -X, +Z, -Z) and how much of each is built on.
		var e := 0.3
		var strips := [
			Rect2(foot.end.x - e, foot.position.y, e, foot.size.y),
			Rect2(foot.position.x, foot.position.y, e, foot.size.y),
			Rect2(foot.position.x, foot.end.y - e, foot.size.x, e),
			Rect2(foot.position.x, foot.position.y, foot.size.x, e),
		]
		var strip_cover := [0.0, 0.0, 0.0, 0.0]
		for o in blocks:
			if o == b:
				continue
			var ob: AABB = boxes[o]
			var of := Rect2(ob.position.x, ob.position.z, ob.size.x, ob.size.z)
			var inter := foot.intersection(of).get_area()
			if inter <= 0.0001:
				continue
			if absf(ob.end.y - bottom) < 0.06:
				supported = true
			if ob.position.y <= top + 0.06 and ob.end.y > top + 0.06:
				covered += inter
				for i in 4:
					strip_cover[i] += strips[i].intersection(of).get_area()
		if supported and bb.size.y >= 1.2:
			flags |= V3D.TRIM_BASE
		if bb.size.y >= 0.4 and minf(bb.size.x, bb.size.z) >= 1.5 and covered < area * 0.6:
			for i in 4:
				if strip_cover[i] < strips[i].get_area() * 0.5:
					flags |= V3D.TRIM_EDGE << i
		b.set_trims(flags)


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
