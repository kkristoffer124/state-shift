extends Node2D
## Level root. Put solid pieces under "Blocks", triggers under "Zones",
## tutorial text under "Hints" and one Player instance as a direct child.
## Camera limits are computed from the Blocks' bounds.

@export var level_name := "Level"
## Camera zoom for this room (1 = native pixel scale, whole 960x540 room visible).
@export var room_zoom := 1.0
## Environment art set (assets/env_<theme>/) used by Blocks, Zones and the Background.
@export_enum("lab", "cryo", "boiler", "sewer", "rooftop") var theme := "lab":
	set(v):
		theme = v
		_apply_theme()


func _ready() -> void:
	_apply_theme()
	if Engine.is_editor_hint():
		return
	var player := get_node_or_null("Player") as Player
	if player == null:
		push_error("Level %s has no Player child" % name)
		return
	var bounds := get_bounds()
	var cam := player.camera
	cam.limit_left = int(bounds.position.x)
	cam.limit_top = int(bounds.position.y)
	cam.limit_right = int(bounds.end.x)
	cam.limit_bottom = int(bounds.end.y)
	# Rooms are built at the art's native scale (one screen = 960x540), so the
	# camera shows them 1:1 like the tileset mock-ups; bigger rooms scroll.
	player.zoom_override = room_zoom
	cam.zoom = Vector2(room_zoom, room_zoom)
	cam.reset_smoothing()
	# Pixel fluid simulation for the whole level (free water/steam pixels).
	var fluid := FluidWorld.new()
	fluid.name = "FluidWorld"
	fluid.z_index = 4
	add_child(fluid)
	var blocks: Array = $Blocks.get_children()
	var zones: Array = $Zones.get_children() if has_node("Zones") else []
	fluid.build(bounds, blocks, zones)
	Game.on_level_ready(self, player)


func get_bounds() -> Rect2:
	var r := Rect2()
	var first := true
	for b in $Blocks.get_children():
		if b is Block:
			var br := Rect2(b.position, b.size)
			r = br if first else r.merge(br)
			first = false
	return r


## Passes the theme on to the backdrop (Blocks/Zones look it up themselves).
func _apply_theme() -> void:
	if not is_inside_tree():
		return
	var bg := get_node_or_null("Background")
	if bg and "theme" in bg:
		bg.theme = theme
