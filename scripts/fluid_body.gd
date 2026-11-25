class_name FluidBody
extends Node2D
## Physics-driven visuals for the WATER and STEAM states.
##  WATER: a soft body of droplets on springs, rendered as one metaball blob
##         (Water CanvasGroup + shaders/metaball.gdshader).
##  STEAM: a cloud of buoyant, swirling puffs that peel off and fade.
## Gameplay collision still uses the Player's CharacterBody2D shape; this node
## only simulates how the body LOOKS. Positions are in world space (top_level).

@export_group("Water")
@export var droplet_count := 16
@export var droplet_texture: Texture2D
## Drawn radius of one droplet sprite (before the metaball threshold).
@export var droplet_radius := 13.0
## Rest distance of droplets from the body centre.
@export var ring_radius := 6.0
@export var spring := 900.0
@export var damping := 14.0
@export var droplet_gravity := 0.35

@export_group("Steam")
@export var puff_count := 34
@export var puff_texture: Texture2D
@export var puff_size := Vector2(7.0, 12.0)
@export var puff_life := Vector2(0.7, 1.5)
@export var cohesion := 70.0
@export var buoyancy := 60.0
@export var swirl := 40.0

const MASK := 1 | 4 # world + breakables (grates never stop fluids)

var center := Vector2.ZERO
var center_velocity := Vector2.ZERO
var visual_center := Vector2.ZERO
var water_active := false
var steam_active := false
var alpha := 1.0

var _drops := PackedVector2Array()
var _drop_vel := PackedVector2Array()
var _bound := true # springs on (false = splattered)

var _puffs: Array[Dictionary] = []
var _cohesive := true

var _ray := PhysicsRayQueryParameters2D.new()
var _exclude: Array[RID] = []
var _fading := false
var _scale := 1.0
var _t := 0.0

@onready var droplets_node: Node2D = $Water/Droplets
@onready var steam_node: Node2D = $Steam


func _ready() -> void:
	top_level = true
	global_position = Vector2.ZERO
	droplets_node.draw.connect(_draw_droplets)
	steam_node.draw.connect(_draw_steam)
	_ray.collision_mask = MASK
	var body := get_parent() as CollisionObject2D
	if body:
		_exclude = [body.get_rid()]
	_ray.exclude = _exclude
	_scale = (get_parent() as Node2D).global_scale.x
	center = get_parent().global_position
	visual_center = center


# --- Public API (called by Player) ------------------------------------------

func set_state(state: int, from_points: PackedVector2Array) -> void:
	var was_water := water_active
	var old_drops := _drops.duplicate()
	water_active = state == Player.State.WATER
	steam_active = state == Player.State.STEAM
	_bound = true
	_cohesive = true
	if water_active:
		var src := from_points
		if src.is_empty():
			src = _puff_points()
		_spawn_droplets(src)
	if steam_active:
		var src := old_drops if was_water else from_points
		_spawn_puffs(src)


## Droplet / puff positions, used to seed the next state.
func current_points() -> PackedVector2Array:
	if water_active:
		return _drops.duplicate()
	return _puff_points()


func splatter(impact: Vector2) -> void:
	_bound = false
	_cohesive = false
	for i in _drop_vel.size():
		_drop_vel[i] = impact * 0.3 + Vector2(randf_range(-260, 260), randf_range(-320, -60)) * _scale
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
	center_velocity = (new_center - center) / delta
	center = new_center
	if _fading:
		alpha = maxf(alpha - delta * 1.6, 0.0)
	if water_active or not _drops.is_empty():
		_step_water(delta)
	_step_steam(delta)
	var target := center
	if water_active and not _drops.is_empty():
		target = _average(_drops)
	elif steam_active:
		target = _average(_puff_points(true))
	# Water's face sits on the droplets' centre; steam's is smoothed (puffs churn).
	var follow := 60.0 if water_active else 14.0
	visual_center = visual_center.lerp(target, minf(follow * delta, 1.0))
	droplets_node.queue_redraw()
	steam_node.queue_redraw()


func _step_water(delta: float) -> void:
	if not water_active:
		_drops.clear()
		_drop_vel.clear()
		return
	var space := get_world_2d().direct_space_state
	var n := _drops.size()
	var g := Vector2(0, 1300.0) * _scale
	for i in n:
		var p := _drops[i]
		var v := _drop_vel[i]
		if _bound:
			var a := TAU * i / n
			var home := center + Vector2(cos(a), sin(a)) * ring_radius * _scale
			v += ((home - p) * spring + g * droplet_gravity) * delta
			v *= exp(-damping * delta)
			# Never get stuck behind a wall when the body moved on.
			if p.distance_to(center) > 60.0 * _scale:
				p = home
				v = center_velocity
		else:
			v += g * delta
			v *= exp(-1.5 * delta)
		var next := p + v * delta
		_ray.from = p
		_ray.to = next
		var hit := space.intersect_ray(_ray)
		if hit:
			var nrm: Vector2 = hit.normal
			next = hit.position + nrm * 1.5
			v = v.slide(nrm) * (0.75 if _bound else 0.4)
		_drops[i] = next
		_drop_vel[i] = v


func _step_steam(delta: float) -> void:
	var space := get_world_2d().direct_space_state
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
			v += Vector2(-to_c.y, to_c.x).normalized() * swirl * delta * (1.0 if p.spin > 0 else -1.0)
			# Lagging puffs peel off into a trail.
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


func _spawn_puffs(src: PackedVector2Array) -> void:
	for i in puff_count:
		var p := {}
		var at := center + _rand_in_circle(8.0 * _scale)
		if not src.is_empty():
			at = src[i % src.size()] + _rand_in_circle(3.0 * _scale)
		_reset_puff(p, at)
		p.age = randf() * p.life * 0.5 # stagger so they don't all respawn at once
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


func _puff_points(attached_only := false) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for p in _puffs:
		if not attached_only or p.attached:
			pts.append(p.pos)
	return pts


# --- Drawing (world space) ------------------------------------------------------

func _draw_droplets() -> void:
	if not water_active or droplet_texture == null:
		return
	var r := droplet_radius * _scale
	var col := Color(1, 1, 1, alpha)
	for p in _drops:
		droplets_node.draw_texture_rect(droplet_texture, Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0), false, col)


func _draw_steam() -> void:
	if puff_texture == null:
		return
	for p in _puffs:
		var k: float = p.age / p.life
		var a := sin(k * PI) # fade in, fade out
		var s: float = p.size * (1.0 + k * 0.8)
		var tint := Color(0.95, 0.97, 1.0, a * 0.6 * alpha).lerp(Color(0.75, 0.82, 0.9, a * 0.4 * alpha), k)
		steam_node.draw_texture_rect(puff_texture, Rect2(p.pos - Vector2(s, s), Vector2(s, s) * 2.0), false, tint)


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
