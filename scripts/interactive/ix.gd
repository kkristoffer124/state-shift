class_name Ix
extends RefCounted
## Shared helpers for the interactive props in scenes/interactive/.
##
## CHANNELS: gameplay props talk through string channels, scoped to their level.
##   Sources (IxPlate, IxTurbine, IxBasin, IxLever) call Ix.emit(self, channel, on).
##   Receivers (IxGate, IxDrip, IxVent ...) call Ix.listen(self, channel) in _ready and
##   implement `_on_channel(source_id: int, on: bool)`.
## FLUID: every call is defensive so props work with or without the level's FluidWorld.

const PLAYER_MASK := 8     # layer 4: the player's body
const ZONE_MASK := 16      # layer 5: Zone areas (fans, heat, ...)
const WORLD_MASK := 1 | 4  # walls + breakables (grates let fluids through)
const SOLID_MASK := 1 | 2 | 4

const C_WATER := Color("3f8cff")
const C_WATER_HI := Color("6fb0ff")
const C_FROST := Color("80d9ff")
const C_HEAT := Color("ff5a1a")
const C_GOAL := Color("66ff99")
const C_STEEL := Color("9ebcdb")
const C_INK := Color("0e151d")


# --- Level / player lookup ---------------------------------------------------------

## The level root that owns `n` (the ancestor with a "Blocks" child), or null.
static func level_of(n: Node) -> Node:
	var p := n
	while p:
		if p.has_node("Blocks") and p.has_node("Zones"):
			return p
		p = p.get_parent()
	return null


static func player_of(n: Node) -> Node2D:
	var lv := level_of(n)
	if lv == null:
		return null
	return lv.get_node_or_null("Player") as Node2D


## Player state as int (0 ICE, 1 WATER, 2 STEAM), -1 if not a live player.
static func state_of(body: Node) -> int:
	if body == null or not is_instance_valid(body) or not ("state" in body):
		return -1
	if body.get("dead") or body.get("won"):
		return -1
	return int(body.get("state"))


static func is_player(body: Node) -> bool:
	return body != null and body is CharacterBody2D and ("state" in body)


## All FAN zones of the level (cached by callers).
static func fans_of(n: Node) -> Array:
	var out := []
	var lv := level_of(n)
	if lv == null:
		return out
	for z in lv.get_node("Zones").get_children():
		if z is Zone and z.kind == Zone.Kind.FAN:
			out.append(z)
	return out


## Wind velocity (px/s^2 push) at a global point from the given fans.
static func wind_at(fans: Array, p: Vector2) -> Vector2:
	var v := Vector2.ZERO
	for z in fans:
		if not is_instance_valid(z):
			continue
		var local: Vector2 = (z as Node2D).get_global_transform().affine_inverse() * p
		if Rect2(Vector2.ZERO, z.size).has_point(local):
			v += z.push_vector()
	return v


# --- Channels -------------------------------------------------------------------------

static func _group(channel: String) -> String:
	return "ix_ch_" + channel


static func listen(n: Node, channel: String) -> void:
	if channel != "" and not Engine.is_editor_hint():
		n.add_to_group(_group(channel))


static func emit(source: Node, channel: String, on: bool) -> void:
	if channel == "" or Engine.is_editor_hint() or not source.is_inside_tree():
		return
	var lv := level_of(source)
	for r in source.get_tree().get_nodes_in_group(_group(channel)):
		if level_of(r) == lv and r.has_method("_on_channel"):
			r._on_channel(source.get_instance_id(), on)


# --- Fluid world (defensive) ----------------------------------------------------------

static func fluid(n: Node) -> Node:
	if n == null or not n.is_inside_tree():
		return null
	return n.get_tree().get_first_node_in_group("fluid_world")


static func spawn_water(n: Node, pos: Vector2, vel := Vector2.ZERO) -> bool:
	var fw := fluid(n)
	if fw and fw.has_method("spawn_water"):
		fw.spawn_water(pos, vel)
		return true
	return false


static func spawn_steam(n: Node, pos: Vector2, vel := Vector2.ZERO) -> bool:
	var fw := fluid(n)
	if fw and fw.has_method("spawn_steam"):
		fw.spawn_steam(pos, vel)
		return true
	return false


static func set_solid(n: Node, rect: Rect2, solid: bool) -> bool:
	var fw := fluid(n)
	if fw and fw.has_method("set_solid_rect"):
		fw.set_solid_rect(rect, solid)
		return true
	return false


## Free water pixels in rect, or -1 when there is no fluid world.
static func water_in(n: Node, rect: Rect2) -> int:
	var fw := fluid(n)
	if fw and fw.has_method("water_count_in"):
		return int(fw.water_count_in(rect))
	return -1


# --- Small drawing helpers ---------------------------------------------------------------

## Repeats `tex` along +y from `at` for `length` px, cropping the last tile.
static func vtile(ci: CanvasItem, tex: Texture2D, at: Vector2, length: float, mod := Color.WHITE) -> void:
	var th := float(tex.get_height())
	var tw := float(tex.get_width())
	var y := 0.0
	while y < length:
		var h := minf(th, length - y)
		ci.draw_texture_rect_region(tex, Rect2(at.x, at.y + y, tw, h), Rect2(0, 0, tw, h), mod)
		y += th


## Repeats `tex` along +x.
static func htile(ci: CanvasItem, tex: Texture2D, at: Vector2, length: float, mod := Color.WHITE) -> void:
	var tw := float(tex.get_width())
	var th := float(tex.get_height())
	var x := 0.0
	while x < length:
		var w := minf(tw, length - x)
		ci.draw_texture_rect_region(tex, Rect2(at.x + x, at.y, w, th), Rect2(0, 0, w, th), mod)
		x += tw


## A 1px pixel line (no AA) between two points.
static func pixel_line(ci: CanvasItem, a: Vector2, b: Vector2, c: Color) -> void:
	var n := int(maxf(absf(b.x - a.x), absf(b.y - a.y)))
	for i in n + 1:
		var t := float(i) / maxf(n, 1)
		ci.draw_rect(Rect2(a.lerp(b, t).floor(), Vector2.ONE), c)
