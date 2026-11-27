@tool
class_name TdLevel
extends Node2D
## Root of a top-down chapter (levels/level_XX_topdown.tscn). One 960x540 room shown 1:1.
## Layout (names matter: Ix channels look for Blocks + Zones, props find Blocks/Terrain):
##   Blocks/Terrain  TdTerrain (walls, floor, pits, sewage, spikes) + solid props (TdGate, TdBars, TdCracked)
##   Zones           TdZone areas (heat, freeze, fan, goal)
##   Props           plates, drains (floor-level interactive pieces)
##   Decor           plain Sprite2Ds / lights (no gameplay)
##   Hints           in-world Labels
##   Player          scenes/topdown/td_player.tscn

@export var level_name := "Level"
@export_enum("lab", "cryo", "boiler", "sewer", "rooftop") var theme := "lab":
	set(v):
		theme = v
		if is_inside_tree():
			_retheme(self)


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var player := get_node_or_null("Player") as TdPlayer
	if player == null:
		push_error("Top-down level %s has no Player child" % name)
		return
	var b := get_bounds()
	var cam := player.camera
	cam.limit_left = int(b.position.x)
	cam.limit_top = int(b.position.y)
	cam.limit_right = int(b.position.x + 960.0)
	cam.limit_bottom = int(b.position.y + 540.0)
	cam.zoom = Vector2.ONE
	cam.position_smoothing_enabled = false
	cam.reset_smoothing()
	Game.on_level_ready(self, player)


func get_bounds() -> Rect2:
	var t := get_node_or_null("Blocks/Terrain") as TdTerrain
	return t.bounds() if t else Rect2(0, 0, 960, 540)


## Theme changed in the inspector: let every themed child refresh.
func _retheme(n: Node) -> void:
	for c in n.get_children():
		if c.has_method("_refresh"):
			c.call("_refresh")
		elif c is CanvasItem:
			(c as CanvasItem).queue_redraw()
		_retheme(c)
