@tool
class_name PlayerVisual
extends Node2D
## Everything you SEE of the player (scenes/player.tscn -> Visual):
##  ICE   : animated cube (idle / fall / land / slide / stop) + skid trail,
##          speed lines, fall trail, afterimages, chips and landing dust
##  WATER : animated blob (idle / move / jump / land / grate squeeze)
##  STEAM : the FluidBody pixel cloud (this node only adds the face)
## plus the eyes on top. Physics lives in player.gd; it calls on_land/on_jump.

const ICE_OFFSET := Vector2(0, -3)    # cube centre (22,23) vs frame centre (22,20)
const WATER_OFFSET := Vector2(0, -17) # blob bottom (frame y 60) on the collision bottom (+11)
const WATER_GRATE_LINE := 29.0        # frame y of the grate surface in the "grate" strip

const TEX_AFTER := [preload("res://assets/anim/ice_trails/v14_ice_afterimage_1.png"),
	preload("res://assets/anim/ice_trails/v14_ice_afterimage_2.png")]
const TEX_CHIPS := [preload("res://assets/anim/ice_trails/v5_ice_chip_1.png"),
	preload("res://assets/anim/ice_trails/v5_ice_chip_2.png"),
	preload("res://assets/anim/ice_trails/v5_ice_chip_3.png")]
const TEX_DUST := preload("res://assets/anim/ice_trails/v5_ice_land_dust_4f.png")

static var _eye_cache := {}

var _t := 0.0
var _after_timer := 0.0
var _in_grate := false

@onready var player: Player = get_parent() as Player
@onready var ice: AnimatedSprite2D = $Ice
@onready var water: AnimatedSprite2D = $Water
@onready var skid: Sprite2D = $SkidTrail
@onready var speed_lines: Sprite2D = $SpeedLines
@onready var fall_trail: Sprite2D = $FallTrail
@onready var face: Node2D = $Face


func _ready() -> void:
	face.draw.connect(_draw_face)
	ice.position = ICE_OFFSET
	water.position = WATER_OFFSET
	ice.play("idle")
	water.play("idle")


# --- Events from player.gd ------------------------------------------------------

func on_land(impact: float) -> void:
	if player.state == Player.State.ICE:
		ice.play("land")
		if impact > 300.0:
			_spawn_dust()
			_spawn_chips(int(clampf(impact / 150.0, 2, 8)))
	elif player.state == Player.State.WATER and impact > 150.0:
		water.play("land")


func on_jump() -> void:
	water.play("jump")


# --- Per frame ---------------------------------------------------------------------

func _process(delta: float) -> void:
	if player == null:
		return
	_t += delta
	var st := player.state
	ice.visible = st == Player.State.ICE and not player.dead
	water.visible = st == Player.State.WATER and not player.dead
	if Engine.is_editor_hint():
		skid.visible = false
		speed_lines.visible = false
		fall_trail.visible = false
		face.queue_redraw()
		return
	match st:
		Player.State.ICE: _update_ice(delta)
		Player.State.WATER: _update_water()
	if st != Player.State.ICE:
		skid.visible = false
		speed_lines.visible = false
		fall_trail.visible = false
	face.queue_redraw()


func _update_ice(delta: float) -> void:
	var v := player.velocity
	var on_floor := player.is_on_floor()
	if absf(v.x) > 5.0:
		ice.flip_h = v.x < 0.0
	var busy := ice.is_playing() and ice.animation in [&"land", &"stop"]
	if not on_floor:
		_play(ice, "fall")
	elif busy:
		pass
	elif absf(v.x) > 40.0:
		_play(ice, "slide")
	elif ice.animation == &"slide":
		_play(ice, "stop")
	elif not (ice.animation == &"stop" and ice.is_playing()):
		_play(ice, "idle")
	# Trails
	var dir := signf(v.x) if absf(v.x) > 1.0 else 1.0
	skid.visible = on_floor and absf(v.x) > 80.0
	if skid.visible:
		skid.frame = int(_t * 16.0) % skid.hframes
		skid.position = Vector2(-dir * 14.0, 13.0)
		skid.flip_h = dir < 0.0
	speed_lines.visible = absf(v.x) > 230.0
	if speed_lines.visible:
		speed_lines.frame = int(_t * 14.0) % speed_lines.hframes
		speed_lines.position = Vector2(-dir * 30.0, -2.0)
		speed_lines.flip_h = dir < 0.0
	fall_trail.visible = not on_floor and v.y > 420.0
	if fall_trail.visible:
		fall_trail.frame = int(_t * 14.0) % fall_trail.hframes
		fall_trail.position = Vector2(0, -34.0)
	_after_timer -= delta
	if (absf(v.x) > 250.0 or v.y > 650.0) and _after_timer <= 0.0:
		_after_timer = 0.05
		_spawn_afterimage()


func _update_water() -> void:
	var v := player.velocity
	var on_floor := player.is_on_floor()
	# Squeezing through a grate: frame follows how far through we are, the strip
	# stays pinned to the grate surface.
	var world := get_tree().get_first_node_in_group("fluid_world") as FluidWorld
	var gt := NAN
	if world:
		gt = world.grate_top_near(player.global_position.x, player.global_position.y - 20.0, player.global_position.y + 40.0)
	if not is_nan(gt):
		var p := player.global_position.y + 11.0 - gt
		if p > -4.0 and p < 60.0:
			_in_grate = true
			water.animation = &"grate"
			water.stop()
			water.frame = clampi(int(remap(p, -4.0, 60.0, 1.0, 11.0)), 1, 11)
			water.global_position = Vector2(player.global_position.x, gt - WATER_GRATE_LINE + 46.0).round()
			return
	if _in_grate:
		_in_grate = false
		water.position = WATER_OFFSET
		water.play("land")
		return
	water.position = WATER_OFFSET
	if absf(v.x) > 5.0:
		water.flip_h = v.x < 0.0
	if not on_floor:
		if water.animation != &"jump":
			water.play("jump")
			water.frame = 4 # walked off a ledge: falling pose
	elif water.animation == &"land" and water.is_playing():
		pass
	elif absf(v.x) > 20.0:
		_play(water, "move")
	else:
		_play(water, "idle")


func _play(s: AnimatedSprite2D, anim: String) -> void:
	if s.animation != anim or not s.is_playing():
		s.play(anim)


# --- Effects -------------------------------------------------------------------------

func _spawn_afterimage() -> void:
	var g := Sprite2D.new()
	g.texture = TEX_AFTER[randi() % 2]
	g.flip_h = ice.flip_h
	g.modulate = Color(1, 1, 1, 0.45)
	g.z_index = -1
	player.get_parent().add_child(g)
	g.global_position = (ice.global_position).round()
	var tw := g.create_tween()
	tw.tween_property(g, "modulate:a", 0.0, 0.22)
	tw.tween_callback(g.queue_free)


func _spawn_dust() -> void:
	var d := Sprite2D.new()
	d.texture = TEX_DUST
	d.hframes = 4
	player.get_parent().add_child(d)
	d.global_position = (player.global_position + Vector2(0, 8)).round()
	var tw := d.create_tween()
	tw.tween_property(d, "frame", 3, 0.25)
	tw.tween_callback(d.queue_free)


func _spawn_chips(n: int) -> void:
	for i in n:
		var c := Sprite2D.new()
		c.texture = TEX_CHIPS[randi() % TEX_CHIPS.size()]
		player.get_parent().add_child(c)
		var p0 := player.global_position + Vector2(randf_range(-12, 12), 12)
		c.global_position = p0
		var vel := Vector2(randf_range(-110, 110), randf_range(-200, -80))
		var life := randf_range(0.35, 0.6)
		var tw := c.create_tween().set_parallel()
		tw.tween_method(func(t: float) -> void:
			c.global_position = (p0 + vel * t + Vector2(0, 900.0) * t * t * 0.5).round(), 0.0, life, life)
		tw.tween_property(c, "modulate:a", 0.0, life * 0.4).set_delay(life * 0.6)
		tw.chain().tween_callback(c.queue_free)


# --- Face ----------------------------------------------------------------------------

## Where the eyes sit (local to the player) for the frame a sprite is showing.
func _eye_anchor(s: AnimatedSprite2D, is_ice: bool) -> Vector2:
	var tex := s.sprite_frames.get_frame_texture(s.animation, s.frame)
	if tex == null:
		return Vector2.ZERO
	var key := "%s|%s|%d" % [s.sprite_frames.resource_path, s.animation, s.frame]
	var a: Vector2
	if _eye_cache.has(key):
		a = _eye_cache[key]
	else:
		var img := tex.get_image()
		var r := img.get_used_rect() if img else Rect2i(0, 0, tex.get_width(), tex.get_height())
		var fs := Vector2(tex.get_width(), tex.get_height())
		if is_ice:
			a = Vector2(r.get_center()) - fs * 0.5 + Vector2(0, -2)
		else:
			a = Vector2(r.get_center().x, r.position.y + 10) - fs * 0.5
		_eye_cache[key] = a
	if s.flip_h:
		a.x = -a.x
	return (s.global_position - player.global_position) + a


func _draw_face() -> void:
	if player.dead:
		face.draw_set_transform(player._death_face + Vector2(0, sin(_t * 8.0) * 1.5))
		player._draw_eye_set_on(face, Player.TEX_EYES.dizzy)
		face.draw_set_transform(Vector2.ZERO)
		return
	var jitter := sin(_t * 70.0) * 2.0 if player._blocked_flash > 0.0 else 0.0
	var at := Vector2.ZERO
	match player.state:
		Player.State.ICE:
			at = _eye_anchor(ice, true)
			face.draw_set_transform((ice.position - ICE_OFFSET).round())
			if player._crack > 0.05:
				var level := clampi(ceili(player._crack) - 1, 0, 2)
				face.draw_texture(Player.TEX_ICE_CRACKS[level], Vector2(-15, -15), Color(1, 1, 1, clampf(player._crack - level, 0.3, 1.0)))
			if player._locked:
				face.draw_texture(Player.TEX_FROST_RIM, Vector2(-15, -15), Color(1, 1, 1, 0.7 + sin(_t * 6.0) * 0.3))
		Player.State.WATER:
			at = _eye_anchor(water, false)
		Player.State.STEAM:
			if not Engine.is_editor_hint():
				at = (player.fluid.visual_center - player.global_position) / maxf(player.global_scale.x, 0.001)
			face.draw_set_transform(at)
			face.draw_texture(Player.TEX_CORE_GLOW, -Player.TEX_CORE_GLOW.get_size() * 0.5, Color(1, 1, 1, 0.8))
	face.draw_set_transform((at + Vector2(jitter, 2)).round())
	player._draw_eyes_on(face)
	face.draw_set_transform(Vector2.ZERO)
