@tool
class_name CutsceneBlob
extends Node2D
## Experiment 47 as the player sees it in game, for cutscene panels
## (scenes/cutscenes/cutscene_blob.tscn): the animated water blob and ice cube
## (assets/anim/*_frames.tres), the steam pixel cloud and the player's eyes.
##
## The node origin is the bottom centre (where it stands). Key `pose` and
## `expression` from the panel's AnimationPlayer; `scale` / `modulate` / `position`
## work as usual for squash, fades and hops.

enum Pose {
	WATER,  ## 0: water idle wobble
	SQUASH,  ## 1: water landing squash (then idle)
	DROP,  ## 2: water jump stretch (holds the airborne frame)
	ICE,  ## 3: ice cube idle
	STEAM,  ## 4: steam cloud
	WATER_MOVE,  ## 5: water crawling
	ICE_LAND,  ## 6: ice landing (then idle)
	ICE_SLIDE,  ## 7: ice sliding
	GRATE,  ## 8: water squeezing down through a grate (origin = grate surface)
}

const WATER_POS := Vector2(0, -28) # 64x64 frames, blob bottom at frame y 60
const ICE_POS := Vector2(0, -18) # 44x40 frames, cube bottom at frame y 38
const GRATE_POS := Vector2(0, 17) # 64x92 frames, grate surface at frame y 29
const STEAM_POS := Vector2(0, -16)

static var _anchor_cache := {}

@export var pose: Pose = Pose.WATER:
	set(v):
		if v == pose and _applied:
			return
		pose = v
		_apply()
@export var expression: CutsceneFace.Expr = CutsceneFace.Expr.OPEN:
	set(v):
		expression = v
		if face:
			face.expression = v
@export var flip_h := false:
	set(v):
		flip_h = v
		if water:
			water.flip_h = v
			ice.flip_h = v
## Show the eyes (off for a faceless puddle or a hidden blob).
@export var show_face := true

@onready var water: AnimatedSprite2D = $Water
@onready var ice: AnimatedSprite2D = $Ice
@onready var steam: Node2D = $Steam
@onready var face: CutsceneFace = $Face

var _applied := false


func _ready() -> void:
	water.animation_finished.connect(_on_finished.bind(water))
	ice.animation_finished.connect(_on_finished.bind(ice))
	face.expression = expression
	water.flip_h = flip_h
	ice.flip_h = flip_h
	_apply()


func _apply() -> void:
	if not is_node_ready():
		return
	_applied = true
	var is_ice := pose in [Pose.ICE, Pose.ICE_LAND, Pose.ICE_SLIDE]
	water.visible = not is_ice and pose != Pose.STEAM
	ice.visible = is_ice
	steam.visible = pose == Pose.STEAM
	water.position = GRATE_POS if pose == Pose.GRATE else WATER_POS
	ice.position = ICE_POS
	steam.position = STEAM_POS
	match pose:
		Pose.WATER: water.play(&"idle")
		Pose.SQUASH: water.play(&"land")
		Pose.DROP: water.play(&"jump")
		Pose.WATER_MOVE: water.play(&"move")
		Pose.GRATE: water.play(&"grate")
		Pose.ICE: ice.play(&"idle")
		Pose.ICE_LAND: ice.play(&"land")
		Pose.ICE_SLIDE: ice.play(&"slide")
	_place_face()


func _on_finished(s: AnimatedSprite2D) -> void:
	# One-shot animations settle back into the idle loop, like in game.
	if s == water and s.animation == &"land":
		s.play(&"idle")
	elif s == ice and s.animation in [&"land", &"stop"]:
		s.play(&"idle")


func _process(_delta: float) -> void:
	_place_face()


func _place_face() -> void:
	if not is_node_ready():
		return
	var at := Vector2.ZERO
	var vis := show_face
	if steam.visible:
		at = steam.position
	elif ice.visible:
		at = _anchor(ice, true)
	else:
		at = _anchor(water, false)
		if water.animation == &"grate" and water.frame >= 4:
			vis = false
	face.position = at.round()
	face.visible = vis


## Same rule as PlayerVisual._eye_anchor: the eyes ride the visible pixels of the
## current frame (centre of the cube / 10 px below the top of the blob).
func _anchor(s: AnimatedSprite2D, is_ice: bool) -> Vector2:
	if s.sprite_frames == null:
		return s.position
	var tex := s.sprite_frames.get_frame_texture(s.animation, s.frame)
	if tex == null:
		return s.position
	var key := "%s|%s|%d" % [s.sprite_frames.resource_path, s.animation, s.frame]
	var a: Vector2
	if _anchor_cache.has(key):
		a = _anchor_cache[key]
	else:
		var img := tex.get_image()
		var r := img.get_used_rect() if img else Rect2i(0, 0, tex.get_width(), tex.get_height())
		var fs := Vector2(tex.get_width(), tex.get_height())
		if is_ice:
			a = Vector2(r.get_center()) - fs * 0.5 + Vector2(0, -2)
		else:
			a = Vector2(r.get_center().x, r.position.y + 10) - fs * 0.5
		_anchor_cache[key] = a
	if s.flip_h:
		a.x = -a.x
	return s.position + a
