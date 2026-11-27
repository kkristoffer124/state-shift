@tool
extends Node2D
## What you SEE of the top-down blob (td_player.tscn -> Visual). Physics in td_player.gd.
##  ICE   animated cube (idle / slide / stop) + speed lines, afterimages, chips
##  WATER animated blob (idle / move / land) + wet trail on the floor
##  STEAM a cluster of puffs hovering above its shadow, shedding wisps
## plus a drop shadow and the eyes. The blob's "height" is faked by lifting the
## Body above the Shadow (steam floats higher).

const TEX_PUFFS: Array[Texture2D] = [
	preload("res://assets/topdown/td_puff_l.png"),
	preload("res://assets/topdown/td_puff_m.png"),
	preload("res://assets/topdown/td_puff_s.png"),
]
## Puff layout of the steam cloud: offset, size index, wobble phase.
const CLOUD := [
	[Vector2(0, 3), 0, 0.0], [Vector2(-9, 2), 1, 1.3], [Vector2(9, 2), 1, 2.1],
	[Vector2(-5, -5), 1, 0.7], [Vector2(6, -6), 2, 2.9], [Vector2(-13, -2), 2, 3.7],
	[Vector2(13, -1), 2, 4.4],
]
const ICE_OFFSET := Vector2(0, -6)
const WATER_OFFSET := Vector2(0, -19)
const STEAM_LIFT := 12.0

@onready var player: TdPlayer = get_parent() as TdPlayer
@onready var shadow: Sprite2D = $Shadow
@onready var body: Node2D = $Body
@onready var ice: AnimatedSprite2D = $Body/Ice
@onready var water: AnimatedSprite2D = $Body/Water
@onready var cloud: Node2D = $Body/Cloud
@onready var face: Node2D = $Body/Face
@onready var speed_lines: Sprite2D = $Body/SpeedLines
@onready var wisps: CPUParticles2D = $Wisps
@onready var trail: Node2D = $WetTrail

static var _eye_cache := {}

var _t := 0.0
var _after := 0.0
var _trail_from := Vector2.INF
var _bob := 0.0


func _ready() -> void:
	face.draw.connect(_draw_face)
	cloud.draw.connect(_draw_cloud)
	ice.position = ICE_OFFSET
	water.position = WATER_OFFSET
	ice.play("idle")
	water.play("idle")


# --- Events from td_player.gd ----------------------------------------------------------

func on_shift(_heating: bool) -> void:
	var ring := Sprite2D.new()
	ring.texture = Player.TEX_BURST
	ring.hframes = 5
	ring.modulate = TdPlayer.STATE_COLORS[player.state]
	ring.z_index = 7
	ring.z_as_relative = false
	player.get_parent().add_child(ring)
	ring.global_position = player.global_position + Vector2(0, -6)
	var tw := ring.create_tween()
	tw.tween_property(ring, "frame", 4, 0.25)
	tw.tween_callback(ring.queue_free)
	if player.state == TdPlayer.State.WATER:
		water.play("land")


func on_push() -> void:
	ice.play("slide")


func on_ice_stop(impact: float) -> void:
	ice.play("stop")
	if impact > 300.0:
		_spawn_chips(int(clampf(impact / 90.0, 3, 7)))


func on_splat() -> void:
	if trail:
		for i in 6:
			trail.add_spot(player.global_position + Vector2(randf_range(-10, 10), randf_range(-6, 6)), randf_range(4.0, 8.0), 6.0)


# --- Per frame ----------------------------------------------------------------------------

func _process(delta: float) -> void:
	if player == null:
		return
	_t += delta
	var st := player.state
	var show := not player.dead and not player.in_pipe
	ice.visible = show and st == TdPlayer.State.ICE
	water.visible = show and st == TdPlayer.State.WATER
	cloud.visible = show and st == TdPlayer.State.STEAM
	shadow.visible = show
	if Engine.is_editor_hint():
		cloud.queue_redraw()
		face.queue_redraw()
		return
	# height: steam hovers and bobs, the others sit on the floor
	var lift := 0.0
	if st == TdPlayer.State.STEAM:
		_bob = sin(_t * 2.4) * 2.0
		lift = STEAM_LIFT + _bob
	body.position = (player.vis_offset + Vector2(0, -lift)).round()
	var sq := player.squash
	var fall := clampf(player.fall_t, 0.0, 1.0)
	var win := player.win_t
	var s := sq * (1.0 - fall * 0.95) * (1.0 - win * 0.95)
	body.scale = s
	body.rotation = win * TAU * 1.5
	body.modulate = Color(1, 1, 1).lerp(Color(0.2, 0.25, 0.35), fall)
	shadow.position = player.vis_offset.round() + Vector2(0, 9 if st != TdPlayer.State.STEAM else 10)
	var shadow_k := 1.0 - fall
	if st == TdPlayer.State.STEAM:
		shadow.scale = Vector2(0.8, 0.8) * (1.0 - _bob * 0.03)
		shadow.modulate.a = 0.45 * shadow_k
	elif st == TdPlayer.State.ICE:
		shadow.scale = Vector2(1.0, 1.0)
		shadow.modulate.a = 0.9 * shadow_k
	else:
		shadow.scale = Vector2(0.85, 0.85)
		shadow.modulate.a = 0.8 * shadow_k
	shadow.modulate.a *= 1.0 - win
	match st:
		TdPlayer.State.ICE: _update_ice(delta)
		TdPlayer.State.WATER: _update_water()
	speed_lines.visible = show and st == TdPlayer.State.ICE and player.slide_speed > 300.0
	wisps.emitting = show and st == TdPlayer.State.STEAM
	if wisps.emitting:
		wisps.position = body.position
	if st != TdPlayer.State.WATER:
		_trail_from = Vector2.INF
	cloud.queue_redraw()
	face.queue_redraw()


func _update_ice(delta: float) -> void:
	var d := player.slide_dir
	if d.x != 0.0:
		ice.flip_h = d.x < 0.0
	if d != Vector2.ZERO:
		if ice.animation != &"slide":
			ice.play("slide")
		speed_lines.rotation = 0.0 if d.x != 0.0 else PI / 2.0
		speed_lines.flip_h = d.x < 0.0 or d.y < 0.0
		speed_lines.position = -d * 26.0 + Vector2(0, -4)
		speed_lines.frame = int(_t * 14.0) % speed_lines.hframes
		_after -= delta
		if player.slide_speed > 320.0 and _after <= 0.0:
			_after = 0.04
			_spawn_afterimage()
	elif ice.animation == &"slide":
		ice.play("stop")
	elif not ice.is_playing():
		ice.play("idle")


func _update_water() -> void:
	var v := player.velocity
	if absf(v.x) > 5.0:
		water.flip_h = v.x < 0.0
	if water.animation == &"land" and water.is_playing():
		pass
	elif v.length() > 20.0:
		if water.animation != &"move":
			water.play("move")
	elif water.animation != &"idle":
		water.play("idle")
	# wet trail: a spot every few px travelled
	var p := player.global_position
	if player.busy or player.in_pipe:
		_trail_from = Vector2.INF
		return
	if _trail_from == Vector2.INF:
		_trail_from = p
	elif p.distance_to(_trail_from) > 7.0:
		_trail_from = p
		trail.add_spot(p + Vector2(randf_range(-3, 3), 6 + randf_range(-2, 2)), randf_range(3.0, 5.5), 2.6)


# --- Effects ------------------------------------------------------------------------------

func _spawn_afterimage() -> void:
	var g := Sprite2D.new()
	g.texture = PlayerVisual.TEX_AFTER[randi() % 2]
	g.flip_h = ice.flip_h
	g.modulate = Color(1, 1, 1, 0.4)
	g.z_index = 5
	g.z_as_relative = false
	player.get_parent().add_child(g)
	g.global_position = ice.global_position.round()
	var tw := g.create_tween()
	tw.tween_property(g, "modulate:a", 0.0, 0.2)
	tw.tween_callback(g.queue_free)


func _spawn_chips(n: int) -> void:
	for i in n:
		var c := Sprite2D.new()
		c.texture = PlayerVisual.TEX_CHIPS[randi() % PlayerVisual.TEX_CHIPS.size()]
		c.z_index = 7
		c.z_as_relative = false
		player.get_parent().add_child(c)
		var p0 := player.global_position + Vector2(randf_range(-12, 12), randf_range(-8, 8))
		c.global_position = p0
		var vel := Vector2(randf_range(-90, 90), randf_range(-60, 60))
		var life := randf_range(0.3, 0.5)
		var tw := c.create_tween().set_parallel()
		tw.tween_method(func(k: float) -> void:
			c.global_position = (p0 + vel * k + Vector2(0, -30.0 * sin(PI * k / life))).round(), 0.0, life, life)
		tw.tween_property(c, "modulate:a", 0.0, life * 0.4).set_delay(life * 0.6)
		tw.chain().tween_callback(c.queue_free)


# --- Steam cloud + face -------------------------------------------------------------------

func _draw_cloud() -> void:
	for i in CLOUD.size():
		var e: Array = CLOUD[i]
		var tex: Texture2D = TEX_PUFFS[e[1]]
		var off: Vector2 = e[0] + Vector2(sin(_t * 2.0 + e[2]) * 1.5, cos(_t * 1.6 + e[2]) * 1.2)
		cloud.draw_texture(tex, (off - tex.get_size() * 0.5).round())
	cloud.draw_texture(Player.TEX_CORE_GLOW, -Player.TEX_CORE_GLOW.get_size() * 0.5 + Vector2(0, -1), Color(1, 1, 1, 0.55))


func _expression() -> String:
	if player.won:
		return "happy"
	if player.blocked_flash > 0.0:
		return "blocked"
	if player.fall_t >= 0.0:
		return "scared"
	if player.locked:
		return "determined"
	if player.state == TdPlayer.State.ICE and player.slide_speed > 420.0:
		return "determined"
	return ""


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
	return s.position + a


func _draw_face() -> void:
	if player.in_pipe:
		return
	if player.dead:
		if player.fall_t < 0.0:
			_eye_set(Player.TEX_EYES.dizzy, Vector2(0, 2 + sin(_t * 8.0) * 1.5))
		return
	var at := Vector2.ZERO
	match player.state:
		TdPlayer.State.ICE:
			at = _eye_anchor(ice, true)
			var cube := ice.position + Vector2(0, 3)
			if player.crack > 0.05:
				var lv := clampi(ceili(player.crack) - 1, 0, 2)
				face.draw_texture(Player.TEX_ICE_CRACKS[lv], cube + Vector2(-15, -15), Color(1, 1, 1, clampf(player.crack - lv, 0.3, 1.0)))
			if player.locked:
				face.draw_texture(Player.TEX_FROST_RIM, cube + Vector2(-15, -15), Color(1, 1, 1, 0.7 + sin(_t * 6.0) * 0.3))
		TdPlayer.State.WATER:
			at = _eye_anchor(water, false)
		TdPlayer.State.STEAM:
			at = Vector2(0, -1)
	var jitter := sin(_t * 70.0) * 2.0 if player.blocked_flash > 0.0 else 0.0
	at += Vector2(jitter, 2)
	var expr := _expression()
	if expr != "":
		_eye_set(Player.TEX_EYES[expr], at)
		return
	var cycle := fmod(_t, 3.7)
	if cycle < 0.14:
		_eye_set(Player.TEX_BLINK[0 if cycle < 0.05 or cycle > 0.10 else 1], at)
		return
	var lk := player.look
	var pupil_off := Vector2(signf(lk.x) if absf(lk.x) > 0.3 else 0.0, signf(lk.y) if absf(lk.y) > 0.3 else 0.0)
	for ex in [-5.0, 5.0]:
		var e: Vector2 = at + Vector2(ex + pupil_off.x, -2.0 + minf(pupil_off.y, 0.0))
		face.draw_texture(Player.TEX_EYE_WHITE, (e - Vector2(3.5, 3.5)).round())
		var pupil := (e - Vector2(1.5, 1.5) + pupil_off).round()
		face.draw_texture(Player.TEX_PUPIL, pupil)
		face.draw_texture(Player.TEX_CATCHLIGHT, pupil + Vector2(1, 0))


func _eye_set(tex: Texture2D, at: Vector2) -> void:
	face.draw_texture(tex, (at - tex.get_size() * 0.5 + Vector2(0, -2)).round())
