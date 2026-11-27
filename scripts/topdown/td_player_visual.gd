@tool
extends Node2D
## What you SEE of the top-down blob (td_player.tscn -> Visual). Physics in td_player.gd;
## everything here is cosmetic and never feeds back into movement.
##  ICE   animated cube: leans/stretches along the slide, jelly squash on impact,
##        speed lines, afterimages, sparkle trail (IceSparkles), chips
##  WATER animated blob: wobbles and stretches the way it moves, eyes follow, ripple
##        rings + a fading puddle trail (WetTrail); swirls down drains, pops out the other
##  STEAM a cluster of puffs hovering above its shadow; puffs sway and lag behind,
##        the shadow shrinks/fades with hover height, sheds wisps
## State shifts cross-fade the two bodies (scale + alpha) with a frost burst / splash /
## puff ring. Death (splat / fall) and goal-absorb animations, blinking, glancing eyes.
## The blob's "height" is faked by lifting the Body above the Shadow.
## Settings.reduce_motion (if present) tones squash, wobble and particles down.

const TEX_PUFFS: Array[Texture2D] = [
	preload("res://assets/topdown/td_puff_l.png"),
	preload("res://assets/topdown/td_puff_m.png"),
	preload("res://assets/topdown/td_puff_s.png"),
]
const TEX_SPARK := preload("res://assets/vfx/v1_sparkle.png")
const TEX_DROP := preload("res://assets/player/p2e_droplet.png")
## Puff layout of the steam cloud: offset, size index, wobble phase.
const CLOUD := [
	[Vector2(0, 3), 0, 0.0], [Vector2(-9, 2), 1, 1.3], [Vector2(9, 2), 1, 2.1],
	[Vector2(-5, -5), 1, 0.7], [Vector2(6, -6), 2, 2.9], [Vector2(-13, -2), 2, 3.7],
	[Vector2(13, -1), 2, 4.4],
]
const ICE_OFFSET := Vector2(0, -6)
const WATER_OFFSET := Vector2(0, -19)
const STEAM_LIFT := 12.0
const MORPH_TIME := 0.3
const SPLAT_TIME := 0.45

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
@onready var sparkles: CPUParticles2D = get_node_or_null("IceSparkles") as CPUParticles2D

static var _eye_cache := {}

var _t := 0.0
var _after := 0.0
var _trail_from := Vector2.INF
var _bob := 0.0
## Jelly spring on the squash the physics script asks for.
var _sq := Vector2.ONE
var _sq_v := Vector2.ZERO
## Lean (skew) spring: ice leans back while accelerating, tips forward on impact.
var _lean := 0.0
var _lean_v := 0.0
var _lift := 0.0
## Morph between states: 0 -> 1 after a shift; _from_state fades out.
var _morph := 1.0
var _from_state := -1
var _heating := true
## Drain swirl: extra body rotation while squeezing.
var _spin := 0.0
var _dead_t := 0.0
var _was_won := false
var _was_dead := false
var _ripple_t := 0.0
var _vel_s := Vector2.ZERO
var _pupil := Vector2.ZERO
var _glance := Vector2.ZERO
var _idle_t := 0.0
var _next_blink := 2.5
var _blink_t := -1.0
var _rm := false
var _rm_check := 0.0


func _ready() -> void:
	face.draw.connect(_draw_face)
	cloud.draw.connect(_draw_cloud)
	ice.position = ICE_OFFSET
	water.position = WATER_OFFSET
	ice.play("idle")
	water.play("idle")


func _reduce_motion() -> bool:
	var s := get_node_or_null("/root/Settings")
	return s != null and s.get("reduce_motion") == true


func _add_fx(n: Node2D, at: Vector2, z := 7) -> void:
	n.z_index = z
	n.z_as_relative = false
	player.get_parent().add_child(n)
	n.global_position = at


# --- Events from td_player.gd ----------------------------------------------------------

func on_shift(heating: bool) -> void:
	_heating = heating
	_from_state = player.state - 1 if heating else player.state + 1
	_morph = 0.0 if not _rm else 0.6
	var ring := Sprite2D.new()
	ring.texture = Player.TEX_BURST
	ring.hframes = 5
	ring.modulate = TdPlayer.STATE_COLORS[player.state]
	_add_fx(ring, player.global_position + Vector2(0, -6))
	var tw := ring.create_tween()
	tw.tween_property(ring, "frame", 4, 0.25)
	tw.tween_callback(ring.queue_free)
	var at := player.global_position
	match player.state:
		TdPlayer.State.ICE:
			# frost burst: chips fly, snow sparkles settle
			_spawn_chips(3 if _rm else 6)
			_spray(TEX_SPARK, at + Vector2(0, -6), 4 if _rm else 10, 28.0, Color(0.8, 0.95, 1.0), 0.45, 0.0)
		TdPlayer.State.WATER:
			water.play("land")
			player.splash.global_position = at
			player.splash.restart()
			if trail:
				trail.add_ring(at + Vector2(0, 6), 5.0, 18.0, 0.5)
				for i in 4:
					trail.add_spot(at + Vector2(randf_range(-12, 12), randf_range(0, 9)), randf_range(3.0, 5.0), 2.0)
		TdPlayer.State.STEAM:
			_puff_ring(at + Vector2(0, -8), 4 if _rm else 8)


func on_push() -> void:
	ice.play("slide")
	if not _rm:
		_lean_v -= player.slide_dir.x * 4.0


func on_ice_stop(impact: float) -> void:
	ice.play("stop")
	var k := clampf(impact / 540.0, 0.2, 1.0)
	if not _rm:
		# tip forward into the wall, then wobble back
		_lean_v += player.look.x * 5.0 * k
		_sq_v += (Vector2(-3.0, 3.0) if absf(player.look.x) > 0.0 else Vector2(3.0, -3.0)) * k
	if impact > 300.0:
		_spawn_chips(int(clampf(impact / 90.0, 3, 7)))
	_spray(TEX_SPARK, player.global_position + player.look * 12.0 + Vector2(0, -4), 3 if _rm else 6, 18.0, Color(0.85, 0.97, 1.0), 0.35, 0.0)


func on_splat() -> void:
	if trail:
		for i in 6:
			trail.add_spot(player.global_position + Vector2(randf_range(-10, 10), randf_range(-6, 6)), randf_range(4.0, 8.0), 6.0)
		trail.add_ring(player.global_position + Vector2(0, 4), 6.0, 22.0, 0.6)


## Water starts down a drain: swirl and funnel into the grate.
func on_drain_in(at: Vector2) -> void:
	var tw := create_tween()
	_spin = 0.0
	tw.tween_property(self, "_spin", TAU * (0.5 if _rm else 1.75), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if trail:
		trail.add_ring(at, 13.0, 3.0, 0.4)
		trail.add_ring(at, 16.0, 4.0, 0.5)
	if _rm:
		return
	# droplets spiral in
	for i in 6:
		var d := Sprite2D.new()
		d.texture = TEX_DROP
		d.modulate = Color(0.6, 0.82, 1.0, 0.85)
		_add_fx(d, at)
		var a0 := TAU * i / 6.0
		var r0 := 18.0 + (i % 3) * 3.0
		var tw2 := d.create_tween()
		tw2.tween_method(func(k: float) -> void:
			var a := a0 + k * 4.0
			var r := r0 * (1.0 - k)
			d.global_position = (at + Vector2(cos(a), sin(a) * 0.6) * r).round()
			d.scale = Vector2.ONE * (0.55 - k * 0.35), 0.0, 1.0, 0.3 + i * 0.015)
		tw2.tween_callback(d.queue_free)


## Water pops out of the linked drain: unwinds and splashes.
func on_drain_out(at: Vector2) -> void:
	_spin = -TAU * (0.25 if _rm else 0.6)
	var tw := create_tween()
	tw.tween_property(self, "_spin", 0.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if trail:
		trail.add_ring(at, 4.0, 20.0, 0.55)
		trail.add_ring(at, 2.0, 12.0, 0.4)
		for i in 5:
			trail.add_spot(at + Vector2(randf_range(-13, 13), randf_range(-7, 9)), randf_range(3.0, 5.5), 2.4)
	if not _rm:
		_sq_v += Vector2(-4.0, 6.0)


# --- Per frame ----------------------------------------------------------------------------

func _process(delta: float) -> void:
	if player == null:
		return
	_t += delta
	var st := player.state
	if Engine.is_editor_hint():
		ice.visible = st == TdPlayer.State.ICE
		water.visible = st == TdPlayer.State.WATER
		cloud.visible = st == TdPlayer.State.STEAM
		cloud.queue_redraw()
		face.queue_redraw()
		return
	_rm_check -= delta
	if _rm_check <= 0.0:
		_rm_check = 0.5
		_rm = _reduce_motion()
	_morph = minf(_morph + delta / MORPH_TIME, 1.0)
	_vel_s = _vel_s.lerp(player.velocity, minf(8.0 * delta, 1.0))
	# death / win edge triggers
	if player.dead and not _was_dead:
		_dead_t = 0.0
	_was_dead = player.dead
	if player.dead:
		_dead_t += delta
	if player.won and not _was_won:
		_on_win()
	_was_won = player.won
	var splat := player.dead and player.fall_t < 0.0
	var splat_k := clampf(_dead_t / SPLAT_TIME, 0.0, 1.0) if splat else 0.0
	var show := not player.in_pipe and (not player.dead or (splat and splat_k < 1.0))
	_update_layers(st, show)
	shadow.visible = show and not player.dead

	# --- height: steam hovers and bobs, the others sit on the floor (eased between)
	var lift_target := 0.0
	if st == TdPlayer.State.STEAM:
		_bob = sin(_t * 2.4) * (1.0 if _rm else 2.5)
		lift_target = STEAM_LIFT + _bob
	_lift = lerpf(_lift, lift_target, minf(10.0 * delta, 1.0))
	if player.won:
		_lift += delta * 10.0 * (1.0 - player.win_t)

	# --- squash: jelly spring toward what the physics asked for, plus motion stretch
	var target := player.squash
	if splat:
		target = Vector2(1.0, 1.0).lerp(Vector2(1.9, 0.18), _ease_out(splat_k))
	target *= _motion_stretch(st)
	if _rm:
		target = Vector2.ONE.lerp(target, 0.35)
		_sq = target
		_sq_v = Vector2.ZERO
	else:
		_sq_v += (target - _sq) * 340.0 * delta
		_sq_v *= exp(-15.0 * delta)
		_sq += _sq_v * delta
	# lean spring
	var lean_target := _lean_target(st)
	if _rm:
		_lean = lean_target * 0.3
		_lean_v = 0.0
	else:
		_lean_v += (lean_target - _lean) * 260.0 * delta
		_lean_v *= exp(-12.0 * delta)
		_lean += _lean_v * delta
	_lean = clampf(_lean, -0.3, 0.3)

	body.position = (player.vis_offset + Vector2(0, -_lift)).round()
	var fall := clampf(player.fall_t, 0.0, 1.0)
	var win := player.win_t
	var s := _sq * (1.0 - fall * 0.95) * (1.0 - win * 0.95)
	body.scale = s.max(Vector2(0.02, 0.02))
	body.skew = _lean
	body.rotation = win * TAU * 1.5 + _spin + fall * 1.2
	var mod := Color(1, 1, 1).lerp(Color(0.2, 0.25, 0.35), fall)
	if win > 0.0:
		mod = mod.lerp(Color(1.6, 2.0, 1.7), win)
	if splat:
		mod.a = 1.0 - _ease_out(clampf((splat_k - 0.4) / 0.6, 0.0, 1.0))
	body.modulate = mod

	# --- shadow: tight and dark on the floor, wide and faint when hovering
	var hover := clampf(_lift / STEAM_LIFT, 0.0, 1.5)
	shadow.position = player.vis_offset.round() + Vector2(0, 9.0 + hover)
	var base := 1.0 if st == TdPlayer.State.ICE else 0.85
	if st == TdPlayer.State.WATER:
		base = 0.85 * (1.0 + (_sq.x - 1.0) * 0.6)
	shadow.scale = Vector2(base * (1.0 - hover * 0.18), base * (1.0 - hover * 0.22)) * (1.0 - fall)
	shadow.modulate.a = lerpf(0.85, 0.4, clampf(hover, 0.0, 1.0)) * (1.0 - fall) * (1.0 - win)

	match st:
		TdPlayer.State.ICE: _update_ice(delta)
		TdPlayer.State.WATER: _update_water(delta)
	speed_lines.visible = show and st == TdPlayer.State.ICE and player.slide_speed > 300.0 and _morph >= 1.0
	wisps.emitting = show and st == TdPlayer.State.STEAM and not _rm
	if wisps.emitting:
		wisps.position = body.position
	if sparkles:
		sparkles.emitting = show and player.is_sliding() and player.slide_speed > 260.0 and not _rm
		if sparkles.emitting:
			sparkles.position = body.position + Vector2(0, -2) - player.slide_dir * 12.0
	if st != TdPlayer.State.WATER:
		_trail_from = Vector2.INF
	_update_eyes(delta)
	cloud.queue_redraw()
	face.queue_redraw()


## Stretch from motion: ice along its slide axis, water toward where it flows.
func _motion_stretch(st: int) -> Vector2:
	if player.busy or player.dead:
		return Vector2.ONE
	if st == TdPlayer.State.ICE and player.is_sliding():
		var f := clampf(player.slide_speed / player.ice_max_speed, 0.0, 1.0)
		var along := 1.0 + 0.16 * f
		var across := 1.0 - 0.09 * f
		return Vector2(along, across) if player.slide_dir.x != 0.0 else Vector2(across, along)
	if st == TdPlayer.State.WATER:
		var v := _vel_s
		var m := clampf(v.length() / player.water_speed, 0.0, 1.0)
		var n := v.normalized() if m > 0.02 else Vector2.ZERO
		var wob := sin(_t * 15.0) * 0.07 * m
		var idle := sin(_t * 3.1) * 0.025 * (1.0 - m)
		return Vector2(1.0 + 0.13 * m * absf(n.x) - 0.05 * m * absf(n.y) + wob + idle,
			1.0 + 0.1 * m * absf(n.y) - 0.07 * m * absf(n.x) - wob - idle)
	if st == TdPlayer.State.STEAM:
		return Vector2(1.0 + sin(_t * 3.3) * 0.03, 1.0 + cos(_t * 2.9) * 0.03)
	return Vector2.ONE


func _lean_target(st: int) -> float:
	if player.busy or player.dead:
		return 0.0
	if st == TdPlayer.State.ICE and player.is_sliding() and player.slide_dir.x != 0.0:
		# top lags behind while it is still picking up speed
		var f := clampf(player.slide_speed / player.ice_max_speed, 0.0, 1.0)
		return -player.slide_dir.x * 0.16 * (1.0 - f) - player.slide_dir.x * 0.05
	if st == TdPlayer.State.WATER:
		return -clampf(_vel_s.x / player.water_speed, -1.0, 1.0) * 0.14
	if st == TdPlayer.State.STEAM:
		return -clampf(_vel_s.x / 200.0, -1.0, 1.0) * 0.12
	return 0.0


## Visibility + cross-fade of the three bodies during a morph.
func _update_layers(st: int, show: bool) -> void:
	var k := _ease_out(_morph)
	var nodes := [ice, water, cloud]
	var offs := [ICE_OFFSET, WATER_OFFSET, Vector2.ZERO]
	for i in 3:
		var n: Node2D = nodes[i]
		var a := 0.0
		var sc := 1.0
		if i == st:
			a = k
			sc = lerpf(0.55 if _heating else 1.35, 1.0, _ease_back(_morph))
		elif i == _from_state and _morph < 1.0:
			a = 1.0 - k
			# melting ice slumps; boiling water swells; condensing steam shrinks
			sc = lerpf(1.0, 1.4 if _heating else 0.6, k)
		n.visible = show and a > 0.01
		n.modulate.a = a
		var v := Vector2(sc, sc)
		if i == TdPlayer.State.ICE and i == _from_state and _heating:
			v = Vector2(lerpf(1.0, 1.3, k), lerpf(1.0, 0.5, k))
		n.scale = v
		n.position = (offs[i] as Vector2) * v.y


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
		if player.slide_speed > 320.0 and _after <= 0.0 and not _rm:
			_after = 0.04
			_spawn_afterimage()
	elif ice.animation == &"slide":
		ice.play("stop")
	elif not ice.is_playing():
		ice.play("idle")


func _update_water(delta: float) -> void:
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
	var p := player.global_position
	if player.busy or player.in_pipe or player.dead:
		_trail_from = Vector2.INF
		return
	# ripple rings: quick while moving, a slow lazy one when still
	_ripple_t -= delta
	var moving := v.length() > 25.0
	if _ripple_t <= 0.0 and trail:
		_ripple_t = 0.32 if moving else 1.6
		if moving:
			trail.add_ring(p + Vector2(0, 6) - v.normalized() * 4.0, 4.0, 13.0, 0.55)
		else:
			trail.add_ring(p + Vector2(0, 6), 8.0, 15.0, 0.9)
	# wet trail: a spot every few px travelled
	if _trail_from == Vector2.INF:
		_trail_from = p
	elif p.distance_to(_trail_from) > 7.0:
		_trail_from = p
		trail.add_spot(p + Vector2(randf_range(-3, 3), 6 + randf_range(-2, 2)), randf_range(3.0, 5.5), 2.6)


func _update_eyes(delta: float) -> void:
	# pupils glide toward where the blob is heading; idle blobs glance around
	var dir := player.look
	if player.state == TdPlayer.State.WATER or player.state == TdPlayer.State.STEAM:
		if _vel_s.length() > 20.0:
			dir = _vel_s.normalized()
	var moving := _vel_s.length() > 20.0 or player.is_sliding()
	_idle_t = 0.0 if moving else _idle_t + delta
	if _idle_t > 2.0:
		if fmod(_idle_t, 2.2) < delta:
			_glance = [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 0.6), Vector2.ZERO].pick_random()
		dir = _glance
	var target := Vector2(clampf(dir.x * 1.4, -1.2, 1.2), clampf(dir.y * 1.2, -1.0, 1.0))
	_pupil = _pupil.lerp(target, minf(14.0 * delta, 1.0))
	# random blink timing (sometimes a double blink)
	_next_blink -= delta
	if _next_blink <= 0.0:
		_blink_t = 0.0
		_next_blink = randf_range(2.2, 4.5) if randf() > 0.2 else 0.25
	if _blink_t >= 0.0:
		_blink_t += delta
		if _blink_t > 0.14:
			_blink_t = -1.0


func _on_win() -> void:
	# sparkles spiral into the goal with the blob
	var at := player.global_position
	for i in (5 if _rm else 12):
		var sp := Sprite2D.new()
		sp.texture = TEX_SPARK
		sp.modulate = Color(0.7, 1.0, 0.8)
		_add_fx(sp, at)
		var a0 := TAU * i / 12.0
		var tw := sp.create_tween()
		tw.tween_method(func(k: float) -> void:
			var c := player.global_position + Vector2(0, -6)
			var a := a0 + k * 6.0
			var r := 34.0 * (1.0 - k)
			sp.global_position = (c + Vector2(cos(a), sin(a) * 0.7) * r).round()
			sp.modulate.a = 1.0 - k * 0.7, 0.0, 1.0, 0.7)
		tw.tween_callback(sp.queue_free)


# --- Effects ------------------------------------------------------------------------------

static func _ease_out(k: float) -> float:
	return 1.0 - pow(1.0 - clampf(k, 0.0, 1.0), 3.0)


static func _ease_back(k: float) -> float:
	k = clampf(k, 0.0, 1.0)
	var c1 := 1.9
	return 1.0 + (c1 + 1.0) * pow(k - 1.0, 3.0) + c1 * pow(k - 1.0, 2.0)


## Little sprites thrown outward that slow down and fade.
func _spray(tex: Texture2D, at: Vector2, n: int, dist: float, col: Color, life: float, grav: float) -> void:
	for i in n:
		var sp := Sprite2D.new()
		sp.texture = tex
		sp.modulate = col
		sp.scale = Vector2.ONE * randf_range(0.6, 1.0)
		_add_fx(sp, at)
		var dir := Vector2.from_angle(TAU * i / n + randf_range(-0.3, 0.3))
		var r := dist * randf_range(0.6, 1.1)
		var tw := sp.create_tween()
		tw.tween_method(func(k: float) -> void:
			var e := _ease_out(k)
			sp.global_position = (at + dir * r * e + Vector2(0, grav * k * k)).round()
			sp.modulate.a = col.a * (1.0 - k * k), 0.0, 1.0, life * randf_range(0.8, 1.2))
		tw.tween_callback(sp.queue_free)


## Steam puffs blooming outward from the blob.
func _puff_ring(at: Vector2, n: int) -> void:
	for i in n:
		var sp := Sprite2D.new()
		sp.texture = TEX_PUFFS[1 + i % 2]
		_add_fx(sp, at, 8)
		var dir := Vector2.from_angle(TAU * i / n + 0.3)
		var tw := sp.create_tween()
		tw.tween_method(func(k: float) -> void:
			var e := _ease_out(k)
			sp.global_position = (at + Vector2(dir.x, dir.y * 0.7) * (8.0 + 18.0 * e) + Vector2(0, -6.0 * k)).round()
			sp.scale = Vector2.ONE * (0.6 + 0.7 * e)
			sp.modulate.a = 0.9 * (1.0 - k), 0.0, 1.0, 0.55)
		tw.tween_callback(sp.queue_free)


func _spawn_afterimage() -> void:
	var g := Sprite2D.new()
	g.texture = PlayerVisual.TEX_AFTER[randi() % 2]
	g.flip_h = ice.flip_h
	g.modulate = Color(1, 1, 1, 0.4)
	g.scale = body.scale
	_add_fx(g, ice.global_position.round(), 5)
	var tw := g.create_tween()
	tw.tween_property(g, "modulate:a", 0.0, 0.2)
	tw.tween_callback(g.queue_free)


func _spawn_chips(n: int) -> void:
	for i in n:
		var c := Sprite2D.new()
		c.texture = PlayerVisual.TEX_CHIPS[randi() % PlayerVisual.TEX_CHIPS.size()]
		var p0 := player.global_position + Vector2(randf_range(-12, 12), randf_range(-8, 8))
		_add_fx(c, p0)
		var vel := Vector2(randf_range(-90, 90), randf_range(-60, 60))
		var life := randf_range(0.3, 0.5)
		var tw := c.create_tween().set_parallel()
		tw.tween_method(func(k: float) -> void:
			c.global_position = (p0 + vel * k + Vector2(0, -30.0 * sin(PI * k / life))).round(), 0.0, life, life)
		tw.tween_property(c, "modulate:a", 0.0, life * 0.4).set_delay(life * 0.6)
		tw.chain().tween_callback(c.queue_free)


# --- Steam cloud + face -------------------------------------------------------------------

func _draw_cloud() -> void:
	# outer puffs trail behind the motion, each with its own sway
	var drag := (-_vel_s * 0.03).limit_length(7.0)
	for i in CLOUD.size():
		var e: Array = CLOUD[i]
		var tex: Texture2D = TEX_PUFFS[e[1]]
		var o: Vector2 = e[0]
		var lag := 0.25 + o.length() / 13.0
		var sway := 1.5 if not _rm else 0.6
		var off: Vector2 = o + drag * lag + Vector2(sin(_t * 2.0 + e[2]) * sway, cos(_t * 1.6 + e[2]) * sway * 0.8)
		var breathe := 1.0 + sin(_t * 2.6 + e[2]) * 0.06
		var sz := tex.get_size() * breathe
		cloud.draw_texture_rect(tex, Rect2((off - sz * 0.5).round(), sz.round()), false)
	cloud.draw_texture(Player.TEX_CORE_GLOW, -Player.TEX_CORE_GLOW.get_size() * 0.5 + Vector2(0, -1), Color(1, 1, 1, 0.45 + sin(_t * 3.0) * 0.12))


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
	return s.position + a * s.scale


func _draw_face() -> void:
	if player.in_pipe:
		return
	if player.dead:
		if player.fall_t < 0.0 and _dead_t < SPLAT_TIME:
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
			at = Vector2(0, -1) + (-_vel_s * 0.01).limit_length(2.0)
	if _morph < 0.5:
		return # eyes pop back in once the new body has formed
	var jitter := sin(_t * 70.0) * 2.0 if player.blocked_flash > 0.0 else 0.0
	at += Vector2(jitter, 2)
	var expr := _expression()
	if expr != "":
		_eye_set(Player.TEX_EYES[expr], at)
		return
	if _blink_t >= 0.0:
		_eye_set(Player.TEX_BLINK[0 if _blink_t < 0.05 or _blink_t > 0.10 else 1], at)
		return
	var po := _pupil.round()
	for ex in [-5.0, 5.0]:
		var e: Vector2 = at + Vector2(ex + roundf(_pupil.x * 0.5), -2.0 + minf(roundf(_pupil.y * 0.5), 0.0))
		face.draw_texture(Player.TEX_EYE_WHITE, (e - Vector2(3.5, 3.5)).round())
		var pupil := (e - Vector2(1.5, 1.5) + po).round()
		face.draw_texture(Player.TEX_PUPIL, pupil)
		face.draw_texture(Player.TEX_CATCHLIGHT, pupil + Vector2(1, 0))


func _eye_set(tex: Texture2D, at: Vector2) -> void:
	face.draw_texture(tex, (at - tex.get_size() * 0.5 + Vector2(0, -2)).round())
