@tool
extends Node2D
## What you SEE of the top-down blob (td_player.tscn -> Visual). Physics in td_player.gd;
## everything here is cosmetic and never feeds back into movement.
## Sprites: assets/topdown/anim/td_*_frames.tres (built by make_frames.py), one
## direction-correct strip per motion, picked by the dominant axis of the motion.
##  ICE   idle / slide_<dir> / impact_<dir> (into the wall it hit); leans and stretches
##        along the slide, speed lines, afterimages, sparkle trail (IceSparkles), chips
##  WATER idle / move_<dir>; extra wobble, eyes follow, ripple rings + a fading puddle
##        trail (WetTrail); swirls down drains, pops out the other
##  STEAM idle / drift_<dir> hovering above its shadow (smaller + fainter), sheds wisps
## State shifts play the Shift strip (melt / freeze / boil / condense) in place of the
## bodies, then the new state's idle, with a frost burst / splash / puff ring.
## Death (splat / fall) and goal-absorb animations; procedural eyes (the art has none)
## sit on per-frame anchors baked into the SpriteFrames metadata (`eye`, `body`).
## The blob's "height" is faked by lifting the Body above the Shadow.
## Settings.reduce_motion (if present) tones squash, wobble and particles down.

const TEX_PUFFS: Array[Texture2D] = [
	preload("res://assets/topdown/td_puff_l.png"),
	preload("res://assets/topdown/td_puff_m.png"),
	preload("res://assets/topdown/td_puff_s.png"),
]
const TEX_SPARK := preload("res://assets/vfx/v1_sparkle.png")
const TEX_DROP := preload("res://assets/player/p2e_droplet.png")
## Ground shadow per state (ice / water / steam): steam hovers, so its shadow is the small one.
const TEX_SHADOWS: Array[Texture2D] = [
	preload("res://assets/topdown/anim/t5_shadow_30.png"),
	preload("res://assets/topdown/anim/t5_shadow_30.png"),
	preload("res://assets/topdown/anim/t5_shadow_20.png"),
]
## Shift strip per "from>to" state change.
const SHIFT_ANIM := {"0>1": &"melt", "1>0": &"freeze", "1>2": &"boil", "2>1": &"condense"}
const BODY_OFFSET := Vector2(0, -4)
const SHADOW_Y := 8.0
const STEAM_LIFT := 12.0
## Length of the shift strips (8 frames @ 16 fps).
const MORPH_TIME := 0.5
const SPLAT_TIME := 0.45

@onready var player: TdPlayer = get_parent() as TdPlayer
@onready var shadow: Sprite2D = $Shadow
@onready var body: Node2D = $Body
@onready var ice: AnimatedSprite2D = $Body/Ice
@onready var water: AnimatedSprite2D = $Body/Water
@onready var steam: AnimatedSprite2D = $Body/Steam
@onready var shift_spr: AnimatedSprite2D = $Body/Shift
@onready var face: Node2D = $Body/Face
@onready var speed_lines: Sprite2D = $Body/SpeedLines
@onready var wisps: CPUParticles2D = $Wisps
@onready var trail: Node2D = $WetTrail
@onready var sparkles: CPUParticles2D = get_node_or_null("IceSparkles") as CPUParticles2D

var _t := 0.0
## True while the Shift strip plays (the state bodies are hidden meanwhile).
var _shifting := false
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
## Morph clock: 0 -> 1 over the shift strip.
var _morph := 1.0
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
	for s: AnimatedSprite2D in [ice, water, steam, shift_spr]:
		s.position = BODY_OFFSET
		s.flip_h = false
	ice.play("idle")
	water.play("idle")
	steam.play("idle")
	if not Engine.is_editor_hint():
		shift_spr.animation_finished.connect(_on_shift_finished)


func _reduce_motion() -> bool:
	var s := get_node_or_null("/root/Settings")
	return s != null and s.get("reduce_motion") == true


func _add_fx(n: Node2D, at: Vector2, z := 7) -> void:
	n.z_index = z
	n.z_as_relative = false
	player.get_parent().add_child(n)
	n.global_position = at


## Compass letter of a motion's dominant axis. `keep` (the current letter) wins near-ties
## so diagonal motion doesn't flicker between two strips.
static func _dir_of(v: Vector2, keep := "") -> String:
	var ax := absf(v.x)
	var ay := absf(v.y)
	if keep in ["e", "w"] and ax * 1.25 >= ay and ax > 0.0:
		return "e" if v.x > 0.0 else "w"
	if keep in ["n", "s"] and ay * 1.25 >= ax and ay > 0.0:
		return "s" if v.y > 0.0 else "n"
	if ax >= ay:
		return "e" if v.x >= 0.0 else "w"
	return "s" if v.y > 0.0 else "n"


static func _dir_letter(anim: StringName) -> String:
	var a := String(anim)
	var i := a.rfind("_")
	return a.substr(i + 1) if i >= 0 else ""


## Switch to `anim`, keeping the frame / progress when it is the same motion in a new
## direction (the strips of one motion have the same length).
static func _play_keep(s: AnimatedSprite2D, anim: StringName) -> void:
	if s.animation == anim and s.is_playing():
		return
	var same_family := String(s.animation).get_slice("_", 0) == String(anim).get_slice("_", 0)
	var f := s.frame
	var prog := s.frame_progress
	s.play(anim)
	if same_family and f < s.sprite_frames.get_frame_count(anim):
		s.set_frame_and_progress(f, prog)


# --- Events from td_player.gd ----------------------------------------------------------

func on_shift(heating: bool) -> void:
	_heating = heating
	var from_state := player.state - 1 if heating else player.state + 1
	_morph = 0.0
	var key := "%d>%d" % [from_state, player.state]
	if SHIFT_ANIM.has(key):
		_shifting = true
		shift_spr.play(SHIFT_ANIM[key])
		# the ice / steam bodies restart from idle once the strip is done
		ice.play("idle")
		water.play("idle")
		steam.play("idle")
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
			player.splash.global_position = at
			player.splash.restart()
			if trail:
				trail.add_ring(at + Vector2(0, 6), 5.0, 18.0, 0.5)
				for i in 4:
					trail.add_spot(at + Vector2(randf_range(-12, 12), randf_range(0, 9)), randf_range(3.0, 5.0), 2.0)
		TdPlayer.State.STEAM:
			_puff_ring(at + Vector2(0, -8), 4 if _rm else 8)


func _on_shift_finished() -> void:
	_shifting = false
	_morph = 1.0


func on_push() -> void:
	ice.play("slide_" + _dir_of(player.slide_dir))
	if not _rm:
		_lean_v -= player.slide_dir.x * 2.0


func on_ice_stop(impact: float) -> void:
	# the impact strip squashes the cube against the wall it hit (player.look = slide dir)
	if not _shifting:
		ice.play("impact_" + _dir_of(player.look))
	var k := clampf(impact / 540.0, 0.2, 1.0)
	if not _rm:
		# tip forward into the wall, then wobble back (the strip does the big squash)
		_lean_v += player.look.x * 3.0 * k
		_sq_v += (Vector2(-1.2, 1.2) if absf(player.look.x) > 0.0 else Vector2(1.2, -1.2)) * k
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
		steam.visible = st == TdPlayer.State.STEAM
		shift_spr.visible = false
		shadow.texture = TEX_SHADOWS[st]
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
	if st == TdPlayer.State.ICE and String(ice.animation).begins_with("impact") and ice.is_playing():
		# the impact strip already squashes the cube: keep only a hint of the physics jolt
		target = Vector2.ONE.lerp(target, 0.3)
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

	# --- shadow: tight and dark on the floor; small and faint under the hovering steam
	var hover := clampf(_lift / STEAM_LIFT, 0.0, 1.5)
	shadow.texture = TEX_SHADOWS[TdPlayer.State.STEAM if hover > 0.5 else mini(st, TdPlayer.State.WATER)]
	shadow.position = player.vis_offset.round() + Vector2(0, SHADOW_Y + roundf(hover * 2.0))
	var base := Vector2.ONE
	if st == TdPlayer.State.WATER:
		base = Vector2(1.0 + (_sq.x - 1.0) * 0.6, 1.0 + (_sq.y - 1.0) * 0.3)
	elif hover > 0.5:
		# breathes with the bob: higher = smaller
		base = Vector2.ONE * (1.0 - _bob * 0.03)
	shadow.scale = base * (1.0 - fall)
	shadow.modulate.a = lerpf(0.9, 0.45, clampf(hover, 0.0, 1.0)) * (1.0 - fall) * (1.0 - win)

	if not _shifting:
		match st:
			TdPlayer.State.ICE: _update_ice(delta)
			TdPlayer.State.WATER: _update_water(delta)
			TdPlayer.State.STEAM: _update_steam()
	speed_lines.visible = show and st == TdPlayer.State.ICE and player.slide_speed > 300.0 and not _shifting
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
	face.queue_redraw()


## Stretch from motion on top of the strips: ice along its slide axis (the slide strips
## don't stretch), water just a jelly wobble (the move strips already elongate).
func _motion_stretch(st: int) -> Vector2:
	if player.busy or player.dead:
		return Vector2.ONE
	if st == TdPlayer.State.ICE and player.is_sliding():
		var f := clampf(player.slide_speed / player.ice_max_speed, 0.0, 1.0)
		var along := 1.0 + 0.12 * f
		var across := 1.0 - 0.07 * f
		return Vector2(along, across) if player.slide_dir.x != 0.0 else Vector2(across, along)
	if st == TdPlayer.State.WATER:
		var m := clampf(_vel_s.length() / player.water_speed, 0.0, 1.0)
		var wob := sin(_t * 15.0) * 0.045 * m
		var idle := sin(_t * 3.1) * 0.02 * (1.0 - m)
		return Vector2(1.0 + wob + idle, 1.0 - wob - idle)
	if st == TdPlayer.State.STEAM:
		return Vector2(1.0 + sin(_t * 3.3) * 0.03, 1.0 + cos(_t * 2.9) * 0.03)
	return Vector2.ONE


func _lean_target(st: int) -> float:
	if player.busy or player.dead:
		return 0.0
	if st == TdPlayer.State.ICE and player.is_sliding() and player.slide_dir.x != 0.0:
		# top lags behind while it is still picking up speed
		var f := clampf(player.slide_speed / player.ice_max_speed, 0.0, 1.0)
		return -player.slide_dir.x * 0.08 * (1.0 - f) - player.slide_dir.x * 0.03
	if st == TdPlayer.State.WATER:
		return -clampf(_vel_s.x / player.water_speed, -1.0, 1.0) * 0.1
	if st == TdPlayer.State.STEAM:
		return -clampf(_vel_s.x / 200.0, -1.0, 1.0) * 0.08
	return 0.0


## Which body is visible: the Shift strip while morphing, else the current state's.
func _update_layers(st: int, show: bool) -> void:
	var bodies := [ice, water, steam]
	for i in 3:
		(bodies[i] as AnimatedSprite2D).visible = show and i == st and not _shifting
	shift_spr.visible = show and _shifting


func _update_ice(delta: float) -> void:
	var d := player.slide_dir
	if d != Vector2.ZERO:
		var anim := StringName("slide_" + _dir_of(d))
		if ice.animation != anim:
			ice.play(anim)
		speed_lines.rotation = 0.0 if d.x != 0.0 else PI / 2.0
		speed_lines.flip_h = d.x < 0.0 or d.y < 0.0
		speed_lines.position = -d * 26.0 + Vector2(0, -4)
		speed_lines.frame = int(_t * 14.0) % speed_lines.hframes
		_after -= delta
		if player.slide_speed > 320.0 and _after <= 0.0 and not _rm:
			_after = 0.04
			_spawn_afterimage()
	elif String(ice.animation).begins_with("slide") or not ice.is_playing():
		# impact strips play out (once) and hand back to idle
		ice.play("idle")


func _update_water(delta: float) -> void:
	var v := player.velocity
	if v.length() > 20.0:
		_play_keep(water, StringName("move_" + _dir_of(v, _dir_letter(water.animation))))
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


func _update_steam() -> void:
	# smoothed velocity: wind gusts and drift ease in, so the strip doesn't flicker
	if _vel_s.length() > 18.0:
		_play_keep(steam, StringName("drift_" + _dir_of(_vel_s, _dir_letter(steam.animation))))
	elif steam.animation != &"idle":
		steam.play("idle")


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


## A fading copy of the current slide frame left behind at speed.
func _spawn_afterimage() -> void:
	var g := Sprite2D.new()
	g.texture = ice.sprite_frames.get_frame_texture(ice.animation, ice.frame)
	g.modulate = Color(0.8, 0.95, 1.0, 0.35)
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


# --- Face -----------------------------------------------------------------------------------

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


## Per-frame anchor (`eye` or `body`, from the SpriteFrames metadata) in Body space.
static func _anchor(s: AnimatedSprite2D, key: String) -> Vector2:
	var a := Vector2.ZERO
	var meta: Dictionary = s.sprite_frames.get_meta(key, {})
	var pts: PackedVector2Array = meta.get(String(s.animation), PackedVector2Array())
	if s.frame < pts.size():
		a = pts[s.frame]
	return s.position + a * s.scale


func _draw_face() -> void:
	if player.in_pipe:
		return
	if player.dead:
		if player.fall_t < 0.0 and _dead_t < SPLAT_TIME:
			_eye_set(Player.TEX_EYES.dizzy, Vector2(0, -2 + sin(_t * 8.0) * 1.5))
		return
	if _shifting:
		return # eyes pop back in once the new body has formed
	var at := Vector2.ZERO
	match player.state:
		TdPlayer.State.ICE:
			at = _anchor(ice, "eye")
			var cube := _anchor(ice, "body").round()
			if player.crack > 0.05:
				# 30 px crack art trimmed to the 26 px cube
				var lv := clampi(ceili(player.crack) - 1, 0, 2)
				face.draw_texture_rect_region(Player.TEX_ICE_CRACKS[lv], Rect2(cube - Vector2(13, 13), Vector2(26, 26)), Rect2(2, 2, 26, 26), Color(1, 1, 1, clampf(player.crack - lv, 0.3, 1.0)))
			if player.locked:
				face.draw_texture(Player.TEX_FROST_RIM, cube - Vector2(15, 15), Color(1, 1, 1, 0.7 + sin(_t * 6.0) * 0.3))
		TdPlayer.State.WATER:
			at = _anchor(water, "eye")
		TdPlayer.State.STEAM:
			at = _anchor(steam, "eye") + (-_vel_s * 0.01).limit_length(1.5)
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
