extends Node2D
## One cheap procedural particle layer per CanvasLayer (created by the UiFx autoload).
## Everything is drawn with 1-unit rects at rounded positions, so it stays crisp pixel art:
## water droplets, ice shards, steam puffs, ripple rings and frost glints.

enum { DROP, SHARD, PUFF, RING, GLINT }

const MAX_PARTICLES := 420


class P:
	var type := 0
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var age := 0.0
	var life := 0.5
	var size := 2.0
	var color := Color.WHITE
	var squash := 1.0  # RING: vertical radius factor; DROP: gravity factor


var _p: Array[P] = []


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 200
	z_as_relative = false
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_process(false)


func count() -> int:
	return _p.size()


func add(type: int, pos: Vector2, vel: Vector2, life: float, size: float, color: Color, squash := 1.0) -> void:
	if _p.size() >= MAX_PARTICLES:
		return
	var q := P.new()
	q.type = type
	q.pos = pos
	q.vel = vel
	q.life = maxf(life, 0.05)
	q.size = size
	q.color = color
	q.squash = squash
	_p.append(q)
	set_process(true)


func _process(delta: float) -> void:
	delta /= maxf(Engine.time_scale, 0.01)  # real time: unaffected by the game-speed assist
	for i in range(_p.size() - 1, -1, -1):
		var q := _p[i]
		q.age += delta
		if q.age >= q.life:
			_p.remove_at(i)
			continue
		match q.type:
			DROP:
				q.vel.y += 720.0 * q.squash * delta
			SHARD:
				q.vel.y += 300.0 * delta
				q.vel.x *= pow(0.25, delta)
			PUFF:
				q.vel *= pow(0.18, delta)
				q.vel.y -= 14.0 * delta
		q.pos += q.vel * delta
	queue_redraw()
	if _p.is_empty():
		set_process(false)


func _draw() -> void:
	for q in _p:
		var k := q.age / q.life
		var c := q.color
		match q.type:
			DROP:
				c.a *= 1.0 - smoothstep(0.55, 1.0, k)
				var s := maxf(1.0, roundf(q.size))
				var stretch := roundf(clampf(absf(q.vel.y) / 260.0, 0.0, 2.0))
				var p := q.pos.round() - Vector2(floorf(s / 2.0), 0)
				draw_rect(Rect2(p, Vector2(s, s + stretch)), c)
				if s >= 2.0:
					draw_rect(Rect2(p, Vector2.ONE), Color(1, 1, 1, c.a * 0.85))
			SHARD:
				c.a *= 1.0 - smoothstep(0.5, 1.0, k)
				var p := q.pos.round()
				var horiz := absf(q.vel.x) > absf(q.vel.y)
				var len := maxf(1.0, roundf(q.size))
				draw_rect(Rect2(p, Vector2(len, 1) if horiz else Vector2(1, len)), c)
				if k < 0.5:
					draw_rect(Rect2(p, Vector2.ONE), Color(1, 1, 1, c.a))
			PUFF:
				var e := 1.0 - pow(1.0 - k, 2.0)
				var r := roundf(lerpf(q.size * 0.55, q.size * 1.4, e))
				c.a *= (1.0 - k) * minf(1.0, k * 8.0)
				# Three-lobed little cloud: a big centre lobe with two smaller shoulders.
				var ctr := q.pos.round()
				var side := roundf(r * 0.62)
				_blob(ctr + Vector2(-roundf(r * 0.75), roundf(r * 0.3)), side, Color(c, c.a * 0.8), false)
				_blob(ctr + Vector2(roundf(r * 0.8), roundf(r * 0.35)), side, Color(c, c.a * 0.8), false)
				_blob(ctr, r, c, true)
			RING:
				var e := 1.0 - pow(1.0 - k, 3.0)
				var r := lerpf(2.0, q.size, e)
				c.a *= 1.0 - k
				var n := clampi(int(r * 1.4), 8, 56)
				var last := Vector2(INF, INF)
				for j in n:
					var a := TAU * j / n
					var pt := (q.pos + Vector2(cos(a) * r, sin(a) * r * q.squash)).round()
					if pt != last:
						draw_rect(Rect2(pt, Vector2.ONE), c)
						last = pt
			GLINT:
				var l := roundf(q.size * sin(PI * k))
				var ctr := q.pos.round()
				c.a *= sin(PI * k)
				draw_rect(Rect2(ctr - Vector2(l, 0), Vector2(l * 2.0 + 1.0, 1)), c)
				draw_rect(Rect2(ctr - Vector2(0, l), Vector2(1, l * 2.0 + 1.0)), c)
				if l >= 2.0:
					var d := Color(c, c.a * 0.5)
					for o in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
						draw_rect(Rect2(ctr + o, Vector2.ONE), d)


## Round pixel blob (one rect per row) with a soft lit top and a shaded underside, so steam
## reads as a cloud even over light backgrounds.
func _blob(ctr: Vector2, r: float, c: Color, lit_top := true) -> void:
	if r < 1.0:
		draw_rect(Rect2(ctr, Vector2.ONE), c)
		return
	var shade := Color(0.55, 0.66, 0.82, c.a * 0.7)
	var lit := Color(1, 1, 1, minf(1.0, c.a * 1.3))
	var ir := int(r)
	for dy in range(-ir, ir + 1):
		var hw := roundf(sqrt(maxf(r * r - dy * dy, 0.0)))
		var row := Rect2(ctr.x - hw, ctr.y + dy, hw * 2.0 + 1.0, 1)
		draw_rect(row, shade if dy == ir else c)
		if lit_top and dy == -ir + 1 and hw > 1.0:
			draw_rect(Rect2(ctr.x - hw + 1.0, ctr.y + dy, hw, 1), lit)
