@tool
class_name IxPuddle
extends Area2D
## Shallow floor puddle. Ripples when the player moves through or lands in it, ICE
## standing on it frosts it over (thaws later), STEAM above it makes it steam gently.
## A WATER player landing splashes droplets. Visual only. ORIGIN = left end on the floor.

@export var width := 56.0:
	set(v):
		width = maxf(v, 12.0)
		_refresh()

var _ripples: Array = []   # [x, age]
var _frost := 0.0
var _drops: Array = []     # [pos(local), vel, life]
var _wisps: Array = []     # [pos, life]
var _t := 0.0
var _was_in := false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	collision_layer = 0
	collision_mask = Ix.PLAYER_MASK
	monitoring = true
	monitorable = false
	_rng.randomize()
	_refresh()


func _refresh() -> void:
	if not is_inside_tree():
		return
	var cs := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs and cs.shape is RectangleShape2D:
		(cs.shape as RectangleShape2D).size = Vector2(width, 48)
		cs.position = Vector2(width / 2.0, -24)
	queue_redraw()


func _physics_process(delta: float) -> void:
	_t += delta
	if Engine.is_editor_hint():
		return
	var inside := false
	for b in get_overlapping_bodies():
		var s := Ix.state_of(b)
		if s == -1:
			continue
		var lx: float = b.global_position.x - global_position.x
		var ly: float = b.global_position.y - global_position.y
		var v: Vector2 = b.velocity
		if s == 0 and ly > -20.0:
			inside = true
			_frost = minf(_frost + delta * 2.5, 1.0)
		elif s == 1 and ly > -16.0:
			inside = true
			if not _was_in and v.y > 120.0 or (absf(v.x) > 60.0 and _rng.randf() < delta * 10.0):
				_ripples.append([lx, 0.0])
				for i in 5:
					_drops.append([Vector2(lx + _rng.randf_range(-6, 6), -1), Vector2(_rng.randf_range(-60, 60) + v.x * 0.2, _rng.randf_range(-110, -50)), 0.5])
		elif s == 2 and _rng.randf() < delta * 12.0:
			_wisps.append([Vector2(_rng.randf() * width, -1), 0.0])
		if absf(v.x) > 40.0 and s != 2 and _rng.randf() < delta * 6.0 and _frost < 0.5:
			_ripples.append([lx, 0.0])
	_was_in = inside
	if not inside:
		_frost = maxf(_frost - delta * 0.12, 0.0)
	# Idle drip ripple now and then.
	if _rng.randf() < delta * 0.25 and _frost < 0.3:
		_ripples.append([_rng.randf() * width, 0.0])
	for i in range(_ripples.size() - 1, -1, -1):
		_ripples[i][1] += delta
		if _ripples[i][1] > 0.9:
			_ripples.remove_at(i)
	for i in range(_drops.size() - 1, -1, -1):
		var d: Array = _drops[i]
		d[1].y += 900.0 * delta
		d[0] += d[1] * delta
		d[2] -= delta
		if d[2] <= 0.0 or d[0].y > 0.0:
			_drops.remove_at(i)
	for i in range(_wisps.size() - 1, -1, -1):
		_wisps[i][1] += delta
		_wisps[i][0].y -= 20.0 * delta
		if _wisps[i][1] > 1.2:
			_wisps.remove_at(i)
	queue_redraw()


func _draw() -> void:
	# Thin lens of water lying on the floor top (2 px), tapered at the ends.
	var base := Color(Ix.C_WATER, 0.8).lerp(Color("b8e6ff"), _frost)
	var hi := Ix.C_WATER_HI.lerp(Color.WHITE, _frost)
	draw_rect(Rect2(2, -2, width - 4, 2), base)
	draw_rect(Rect2(0, -1, width, 1), base)
	for x in range(4, int(width) - 4, 6):
		var on := sin(_t * 2.0 + x * 0.7) > 0.6
		if on and _frost < 0.5:
			draw_rect(Rect2(x, -2, 2, 1), hi)
	if _frost > 0.4:
		for x in range(3, int(width) - 3, 5):
			draw_rect(Rect2(x, -2, 1, 1), Color(1, 1, 1, _frost))
	for r in _ripples:
		var k: float = r[1] / 0.9
		var rad := 2.0 + k * 14.0
		var c := Color(Ix.C_WATER_HI, 1.0 - k)
		var x0 := clampf(r[0] - rad, 0.0, width - 2.0)
		var x1 := clampf(r[0] + rad, 1.0, width - 1.0)
		draw_rect(Rect2(roundf(x0), -3, 2, 1), c)
		draw_rect(Rect2(roundf(x1) - 1, -3, 2, 1), c)
	for d in _drops:
		draw_rect(Rect2((d[0] as Vector2).round(), Vector2.ONE), Ix.C_WATER_HI)
	for w in _wisps:
		var a: float = 1.0 - w[1] / 1.2
		draw_rect(Rect2((w[0] as Vector2).round(), Vector2(2, 1)), Color(0.92, 0.95, 1.0, a * 0.6))
