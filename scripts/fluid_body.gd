class_name FluidBody
extends Node2D
## Physics-driven visuals for the WATER and STEAM states.
##  WATER: a soft body of droplets on springs (with squash/stretch springs),
##         loose splash droplets that fly off and merge back, and puddle splats.
##         Body + loose drops are rendered together as one metaball surface
##         (Water CanvasGroup + shaders/metaball.gdshader).
##  STEAM: a cloud of buoyant, swirling puff sprites that peel off as wisps.
## Gameplay collision still uses the Player's CharacterBody2D shape; this node
## only simulates how the body LOOKS. Positions are in world space (top_level).

@export_group("Water")
@export var droplet_count := 18
@export var droplet_texture: Texture2D
## Drawn radius of one body droplet sprite (before the metaball threshold).
@export var droplet_radius := 14.0
## Drawn radius of a loose splash droplet.
@export var splash_radius := 10.0
## Rest distance of droplets from the body centre.
@export var ring_radius := 7.0
@export var spring := 1100.0
@export var damping := 16.0
@export var droplet_gravity := 0.3
## Squash/stretch spring (landing flattens, jumping stretches).
@export var squash_stiffness := 260.0
@export var squash_damping := 9.0
@export var splat_textures: Array[Texture2D] = []
@export var highlight_texture: Texture2D

@export_group("Steam")
@export var puff_count := 30
@export var puff_textures: Array[Texture2D] = []
@export var wisp_texture: Texture2D
@export var steam_ramp: Texture2D
@export var puff_size := Vector2(7.0, 11.0)
@export var puff_life := Vector2(0.7, 1.5)
@export var cohesion := 70.0
@export var buoyancy := 60.0
@export var swirl := 40.0

const MASK := 1 | 4 # world + breakables (grates never stop fluids)
const GRATE_MASK := 2
const GRAVITY := 1300.0

var center := Vector2.ZERO
var center_velocity := Vector2.ZERO
var visual_center := Vector2.ZERO
var water_active := false
var steam_active := false
var alpha := 1.0

# Body droplets
var _drops := PackedVector2Array()
var _drop_vel := PackedVector2Array()
var _bound := true
var _squash := 0.0     # >0 flattened, <0 stretched tall
var _squash_v := 0.0
# Loose splash droplets: {pos, vel, age, life, r}
var _loose: Array[Dictionary] = []
# Puddle splats on surfaces: {pos, age, tex, flip}
var _splats: Array[Dictionary] = []
# Steam puffs
var _puffs: Array[Dictionary] = []
var _cohesive := true
var _ramp_img: Image

var _ray := PhysicsRayQueryParameters2D.new()
var _point := PhysicsPointQueryParameters2D.new()
var _fading := false
var _scale := 1.0
var _t := 0.0
var _drip_timer := 0.0
var _prev_center_vel := Vector2.ZERO

@onready var droplets_node: Node2D = $Water/Droplets
@onready var steam_node: Node2D = $Steam
@onready var splats_node: Node2D = $Splats
@onready var gloss_node: Node2D = $Gloss


func _ready() -> void:
	top_level = true
	global_position = Vector2.ZERO
	droplets_node.draw.connect(_draw_droplets)
	steam_node.draw.connect(_draw_steam)
	splats_node.draw.connect(_draw_splats)
	gloss_node.draw.connect(_draw_gloss)
	var body := get_parent() as CollisionObject2D
	_ray.collision_mask = MASK
	if body:
		_ray.exclude = [body.get_rid()]
	_point.collision_mask = GRATE_MASK
	_point.collide_with_bodies = true
	_scale = (get_parent() as Node2D).global_scale.x
	center = get_parent().global_position
	visual_center = center
	if steam_ramp:
		_ramp_img = steam_ramp.get_image()


# --- Public API (called by Player) ------------------------------------------

func set_state(state: int, from_points: PackedVector2Array) -> void:
	var was_water := water_active
	var old_drops := _drops.duplicate()
	water_active = state == Player.State.WATER
	steam_active = state == Player.State.STEAM
	_bound = true
	_cohesive = true
	_squash = 0.0
	_squash_v = 0.0
	if water_active:
		var src := from_points
		if src.is_empty():
			src = _puff_points()
		_spawn_droplets(src)
		_squash_v = 4.0 # melt/condense: a little slump on arrival
	elif was_water:
		_drops.clear()
		_drop_vel.clear()
	if steam_active:
		var src := old_drops if was_water else from_points
		_spawn_puffs(src)


## Droplet / puff positions, used to seed the next state.
func current_points() -> PackedVector2Array:
	if water_active:
		return _drops.duplicate()
	return _puff_points()


## Called by the player when it lands. impact = downward speed before landing.
func on_land(impact: float) -> void:
	if not water_active:
		return
	_squash_v += clampf(impact * 0.012, 0.0, 9.0)
	if impact > 260.0:
		var n := int(clampf((impact - 200.0) / 70.0, 1, 9))
		var foot := center + Vector2(0, 9) * _scale
		for i in n:
			var side := -1.0 if i % 2 == 0 else 1.0
			_spawn_loose(foot + Vector2(side * randf_range(4, 10), -2) * _scale,
				Vector2(side * randf_range(60, 200), -randf_range(120, 120 + impact * 0.45)) * _scale)
		if impact > 420.0:
			_add_splat(foot + Vector2(0, 2) * _scale)


func on_jump() -> void:
	if not water_active:
		return
	_squash_v -= 7.0
	var foot := center + Vector2(0, 9) * _scale
	for i in 3:
		_spawn_loose(foot + Vector2(randf_range(-6, 6), 0) * _scale,
			Vector2(randf_range(-110, 110), randf_range(-60, 40)) * _scale)


func splatter(impact: Vector2) -> void:
	_bound = false
	_cohesive = false
	for i in _drops.size():
		_spawn_loose(_drops[i], impact * 0.3 + Vector2(randf_range(-260, 260), randf_range(-340, -80)) * _scale, true)
	_drops.clear()
	_drop_vel.clear()
	for p in _puffs:
		var out: Vector2 = (p.pos - center).normalized()
		p.vel = out * randf_range(120, 260) * _scale + Vector2(0, -60)
	_fading = true


func swirl_away() -> void:
	_fading = true


# --- Simulation ---------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_t += delta
	var body := get_parent() as Node2D
	var new_center := body.global_position
	_prev_center_vel = center_velocity
	center_velocity = (new_center - center) / delta
	center = new_center
	if _fading:
		alpha = maxf(alpha - delta * 1.4, 0.0)
	var space := get_world_2d().direct_space_state
	if water_active:
		_step_water(delta, space)
	_step_loose(delta, space)
	_step_splats(delta)
	_step_steam(delta, space)
	var target := center
	if water_active and not _drops.is_empty():
		target = _average(_drops)
	elif steam_active:
		target = _average(_puff_points(true))
	var follow := 60.0 if water_active else 14.0
	visual_center = visual_center.lerp(target, minf(follow * delta, 1.0))
	droplets_node.queue_redraw()
	steam_node.queue_redraw()
	splats_node.queue_redraw()
	gloss_node.queue_redraw()


func _step_water(delta: float, space: PhysicsDirectSpaceState2D) -> void:
	# Squash spring: smooth, overshooting jelly response.
	_squash_v += (-squash_stiffness * _squash - squash_damping * _squash_v) * delta
	_squash = clampf(_squash + _squash_v * delta, -0.55, 0.6)
	# Sudden horizontal stops slosh the body.
	var dv := center_velocity.x - _prev_center_vel.x
	if absf(dv) > 120.0:
		_squash_v += absf(dv) * 0.004
	# Stretch along the direction of motion.
	var speed := center_velocity.length()
	var dir := center_velocity / speed if speed > 1.0 else Vector2.UP
	var stretch := clampf(speed / 1400.0, 0.0, 0.3)
	var sx := 1.0 + _squash
	var sy := 1.0 - _squash * 0.85
	var n := _drops.size()
	var g := Vector2(0, GRAVITY) * _scale
	for i in n:
		var p := _drops[i]
		var v := _drop_vel[i]
		var a := TAU * i / n + sin(_t * 3.0 + i) * 0.05
		var o := Vector2(cos(a), sin(a)) * ring_radius * _scale
		o = dir * o.dot(dir) * (1.0 + stretch) + dir.orthogonal() * o.dot(dir.orthogonal()) * (1.0 - stretch * 0.5)
		o = Vector2(o.x * sx, o.y * sy)
		if _squash > 0.0:
			o.y += _squash * 6.0 * _scale # flatten towards the floor, not the middle
		var home := center + o
		v += ((home - p) * spring + g * droplet_gravity) * delta
		v *= exp(-damping * delta)
		if p.distance_to(center) > 60.0 * _scale:
			p = home
			v = center_velocity
		var next := p + v * delta
		_ray.from = p
		_ray.to = next
		var hit := space.intersect_ray(_ray)
		if hit:
			var nrm: Vector2 = hit.normal
			next = hit.position + nrm * 1.0
			v = v.slide(nrm) * 0.8
		_drops[i] = next
		_drop_vel[i] = v
	# Drip while squeezing through a grate.
	_point.position = center
	_drip_timer -= delta
	if _drip_timer <= 0.0 and not space.intersect_point(_point, 1).is_empty():
		_drip_timer = 0.05
		_spawn_loose(center + Vector2(randf_range(-8, 8), 6) * _scale, Vector2(randf_range(-30, 30), randf_range(60, 160)) * _scale)


func _step_loose(delta: float, space: PhysicsDirectSpaceState2D) -> void:
	var keep: Array[Dictionary] = []
	for d in _loose:
		d.age += delta
		var v: Vector2 = d.vel
		v.y += GRAVITY * _scale * delta
		var next: Vector2 = d.pos + v * delta
		_ray.from = d.pos
		_ray.to = next
		var hit := space.intersect_ray(_ray)
		if hit:
			if hit.normal.y < -0.5 and (d.age > 0.05 or d.orphan):
				# Hit the floor: leave a small splat and disappear.
				if randf() < 0.5 or d.orphan:
					_add_splat(hit.position)
				continue
			next = hit.position + hit.normal * 1.0
			v = v.bounce(hit.normal) * 0.3
		# Merge back into the body when they fall onto it.
		if water_active and _bound and not d.orphan and d.age > 0.12 and next.distance_to(center) < 12.0 * _scale:
			continue
		if d.age > d.life:
			continue
		d.pos = next
		d.vel = v
		keep.append(d)
	_loose = keep


func _step_splats(delta: float) -> void:
	var keep: Array[Dictionary] = []
	for s in _splats:
		s.age += delta
		if s.age < 1.4:
			keep.append(s)
	_splats = keep


func _step_steam(delta: float, space: PhysicsDirectSpaceState2D) -> void:
	var alive: Array[Dictionary] = []
	for p in _puffs:
		p.age += delta
		if p.age >= p.life:
			if steam_active and _cohesive:
				_reset_puff(p, center + _rand_in_circle(6.0 * _scale))
			else:
				continue
		var to_c: Vector2 = center - p.pos
		var v: Vector2 = p.vel
		var attached: bool = p.attached and _cohesive
		if attached:
			v += to_c * cohesion * delta
			v += Vector2(-to_c.y, to_c.x).normalized() * swirl * delta * signf(p.spin)
			if to_c.length() > 18.0 * _scale and p.age > p.life * 0.4:
				p.attached = false
		v += Vector2(0, -buoyancy * (1.0 if attached else 1.6)) * delta * _scale
		v += Vector2(sin(_t * 2.3 + p.seed), cos(_t * 1.7 + p.seed)) * 30.0 * delta
		v *= exp(-3.0 * delta)
		var next: Vector2 = p.pos + v * delta
		_ray.from = p.pos
		_ray.to = next
		var hit := space.intersect_ray(_ray)
		if hit:
			next = hit.position + hit.normal * 2.0
			v = v.slide(hit.normal) * 0.5
		p.pos = next
		p.vel = v
		alive.append(p)
	_puffs = alive


# --- Spawning -----------------------------------------------------------------

func _spawn_droplets(src: PackedVector2Array) -> void:
	_drops.resize(droplet_count)
	_drop_vel.resize(droplet_count)
	for i in droplet_count:
		var p := center + _rand_in_circle(8.0 * _scale)
		if not src.is_empty():
			p = src[(i * src.size()) / droplet_count]
		_drops[i] = p
		_drop_vel[i] = center_velocity * 0.5


func _spawn_loose(at: Vector2, vel: Vector2, orphan := false) -> void:
	if _loose.size() > 60:
		return
	_loose.append({ "pos": at, "vel": vel, "age": 0.0, "life": randf_range(0.8, 1.4),
		"r": randf_range(0.7, 1.0), "orphan": orphan })


func _add_splat(at: Vector2) -> void:
	if splat_textures.is_empty() or _splats.size() > 12:
		return
	_splats.append({ "pos": at, "age": 0.0, "tex": splat_textures.pick_random(), "flip": randf() < 0.5 })


func _spawn_puffs(src: PackedVector2Array) -> void:
	for i in puff_count:
		var p := {}
		var at := center + _rand_in_circle(8.0 * _scale)
		if not src.is_empty():
			at = src[i % src.size()] + _rand_in_circle(3.0 * _scale)
		_reset_puff(p, at)
		p.age = randf() * p.life * 0.5
		p.vel = (at - center) * 4.0 + Vector2(0, -80) * _scale
		_puffs.append(p)


func _reset_puff(p: Dictionary, at: Vector2) -> void:
	p.pos = at
	p.vel = center_velocity * 0.6 + _rand_in_circle(30.0)
	p.age = 0.0
	p.life = randf_range(puff_life.x, puff_life.y)
	p.size = randf_range(puff_size.x, puff_size.y) * _scale
	p.attached = true
	p.spin = randf_range(-1, 1)
	p.seed = randf() * 100.0
	p.tex = randi() % maxi(puff_textures.size(), 1)


func _puff_points(attached_only := false) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for p in _puffs:
		if not attached_only or p.attached:
			pts.append(p.pos)
	return pts


# --- Drawing (world space) ------------------------------------------------------

func _draw_droplets() -> void:
	if droplet_texture == null:
		return
	var col := Color(1, 1, 1, alpha)
	if water_active:
		var r := droplet_radius * _scale
		for p in _drops:
			droplets_node.draw_texture_rect(droplet_texture, Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0), false, col)
	for d in _loose:
		var shrink := clampf(1.0 - (d.age - d.life * 0.6) / (d.life * 0.4), 0.0, 1.0)
		var r: float = splash_radius * _scale * d.r * shrink
		if r > 0.5:
			droplets_node.draw_texture_rect(droplet_texture, Rect2(d.pos - Vector2(r, r), Vector2(r, r) * 2.0), false, col)


func _draw_gloss() -> void:
	if not water_active or highlight_texture == null or _drops.is_empty():
		return
	var top := visual_center + Vector2(-6, -9 + _squash * 6.0) * _scale
	var sz := highlight_texture.get_size() * _scale * Vector2(1.0 + _squash * 0.5, 1.0 - _squash * 0.4)
	gloss_node.draw_texture_rect(highlight_texture, Rect2(top - sz * 0.5, sz), false, Color(1, 1, 1, 0.8 * alpha))


func _draw_splats() -> void:
	for s in _splats:
		var tex: Texture2D = s.tex
		var a := clampf(1.0 - (s.age - 0.6) / 0.8, 0.0, 1.0) * 0.85
		var sz := tex.get_size() * _scale * (0.6 + minf(s.age * 6.0, 0.4))
		if s.flip:
			sz.x = -sz.x
		splats_node.draw_texture_rect(tex, Rect2(s.pos - Vector2(sz.x * 0.5, sz.y - 2.0), sz), false, Color(1, 1, 1, a))


func _draw_steam() -> void:
	if puff_textures.is_empty():
		return
	for p in _puffs:
		var k: float = p.age / p.life
		var fade := sin(k * PI)
		var tint := _ramp_color(k)
		tint.a *= fade * 0.75 * alpha
		var s: float = p.size * (1.0 + k * 0.8)
		if not p.attached and wisp_texture:
			var vel: Vector2 = p.vel
			steam_node.draw_set_transform(p.pos, vel.angle(), Vector2.ONE)
			var w := wisp_texture.get_size() * (s / 30.0)
			steam_node.draw_texture_rect(wisp_texture, Rect2(-w * 0.5, w), false, tint)
			steam_node.draw_set_transform(Vector2.ZERO)
		else:
			var tex: Texture2D = puff_textures[p.tex % puff_textures.size()]
			steam_node.draw_texture_rect(tex, Rect2(p.pos - Vector2(s, s), Vector2(s, s) * 2.0), false, tint)


func _ramp_color(k: float) -> Color:
	if _ramp_img == null:
		return Color(0.95, 0.97, 1.0, 1.0)
	var x := clampi(int(k * (_ramp_img.get_width() - 1)), 0, _ramp_img.get_width() - 1)
	return _ramp_img.get_pixel(x, _ramp_img.get_height() / 2)


# --- Helpers --------------------------------------------------------------------

static func _rand_in_circle(r: float) -> Vector2:
	return Vector2.from_angle(randf() * TAU) * sqrt(randf()) * r


static func _average(pts: PackedVector2Array) -> Vector2:
	if pts.is_empty():
		return Vector2.ZERO
	var s := Vector2.ZERO
	for p in pts:
		s += p
	return s / pts.size()
