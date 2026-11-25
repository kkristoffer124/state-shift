extends Node2D
## Level root. Put solid pieces under "Blocks", triggers under "Zones",
## tutorial text under "Hints" and one Player instance as a direct child.
## Camera limits are computed from the Blocks' bounds.

@export var level_name := "Level"


func _ready() -> void:
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
	cam.reset_smoothing()
	# Pixel fluid simulation for the whole level (free water/steam pixels).
	var fluid := FluidWorld.new()
	fluid.name = "FluidWorld"
	fluid.z_index = 1
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
