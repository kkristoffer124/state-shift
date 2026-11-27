extends "res://tests/v3d_test.gd"
## Camera-quality probe: plays the scripted v3d_test solutions of the third-person and
## isometric chapters and measures what the camera does on the way.
##   godot --headless --fixed-fps 120 --path . res://tests/camera_probe.tscn [-- --only=3]
## Windowed (off-screen) it can also save a frame every N physics frames:
##   godot --position -20000,-20000 --fixed-fps 120 --path . res://tests/camera_probe.tscn -- --bg-test --shots=<dir> [--every=60] [--only=3]
## Metrics per level:
##   jumps      frames where the camera arm length changed > 0.25 m in one 1/120 s frame
##   arm        total arm-length travel (m) - jitter from collision pulls
##   occl       % frames the blob's centre is hidden behind visible solid geometry
##   off        % frames the blob is outside the middle 80 % of the screen (or behind)
##   spin       frames the view turned faster than 200 deg/s, and the max turn rate
##   clip       frames the near plane is within 0.12 m of a solid (wall clipping)
##   ndc_y      average vertical screen position of the blob (0 = centre, + = lower half)
##   cuts       isometric cutaway jumps (> 0.3 m in one frame) per second (popping)

const LEVELS := [3, 12, 5, 10]
const VIS_MASK := V3D.L_WORLD | V3D.L_BREAKABLE

var _m := {}
var _shot_dir := ""
var _every := 60
var _prev_fwd := Vector3.ZERO
var _prev_arm := -1.0
var _prev_cut := INF
var _cur_level := 0
var _camtrace := false


func _ready() -> void:
	Game.testing = true
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7)
		elif a.begins_with("--shots="):
			_shot_dir = a.substr(8)
		elif a == "--camtrace":
			_camtrace = true
		elif a.begins_with("--every="):
			_every = int(a.substr(8))
	if _shot_dir != "":
		DirAccess.make_dir_recursive_absolute(_shot_dir)
		Hud.visible = false
	var solutions := { 3: _solve_03, 5: _solve_05, 10: _solve_10, 12: _solve_12 }
	for n in LEVELS:
		if only != "" and str(n) != only:
			continue
		_cur_level = n
		_m = { "frames": 0, "jumps": 0, "arm": 0.0, "occl": 0, "off": 0, "spin": 0, "spin_max": 0.0,
			"clip": 0, "ndc_y": 0.0, "cuts": 0, "arm_min": 99.0, "arm_sum": 0.0 }
		_prev_fwd = Vector3.ZERO
		_prev_arm = -1.0
		_prev_cut = INF
		await _play(n, solutions[n])
		_report(n)
	print("CAMERA PROBE DONE (%d solve failures)" % _fails)
	get_tree().quit(1 if _fails else 0)


func _report(n: int) -> void:
	var f: int = maxi(_m.frames, 1)
	var mode: String = V3D.CameraMode.keys()[level.camera_mode]
	var secs := f / 120.0
	print("  CAM ch%02d %-12s frames=%d jumps=%d arm=%.1fm arm_avg=%.2f arm_min=%.2f occl=%.1f%% off=%.1f%% spin=%d (max %.0f deg/s) clip=%d ndc_y=%+.2f cuts=%.2f/s"
		% [n, mode, f, _m.jumps, _m.arm, _m.arm_sum / f, _m.arm_min, 100.0 * _m.occl / f, 100.0 * _m.off / f,
			_m.spin, _m.spin_max, _m.clip, _m.ndc_y / f, _m.cuts / secs])
	for kind in ["short", "occ"]:
		if _m.has(kind + "_by"):
			print("      %s by: %s" % [kind, _m[kind + "_by"]])


func _tally(kind: String, what: String) -> void:
	var d: Dictionary = _m.get(kind + "_by", {})
	d[what] = d.get(what, 0) + 1
	_m[kind + "_by"] = d


func _step() -> void:
	await super._step()
	if level == null or p == null or not is_instance_valid(p) or p.rig == null or _frame < 32:
		return
	await _measure()


func _measure() -> void:
	var rig := p.rig
	var cam := rig.camera
	var space := level.get_world_3d().direct_space_state
	var cpos := cam.global_position
	var ppos := p.global_position
	_m.frames += 1
	if _camtrace and _frame % 30 == 0:
		print("    f%d p=%s cam=%s yaw=%.0f pitch=%.0f/%.0f arm=%.2f won=%s" % [_frame, _r(ppos), _r(cpos), rad_to_deg(rig.yaw), rad_to_deg(rig.pitch), rad_to_deg(rig._tp_pitch), rig._arm, p.won])
	var iso := rig.mode == V3D.CameraMode.ISOMETRIC
	# Arm length (perspective modes).
	if not iso:
		var arm := cpos.distance_to(ppos)
		if _prev_arm >= 0.0:
			var d := absf(arm - _prev_arm)
			_m.arm += d
			if d > 0.25:
				_m.jumps += 1
		_prev_arm = arm
		_m.arm_sum += arm
		if arm < rig.distance * 0.6:
			var back := (cpos - ppos).normalized()
			var q2 := PhysicsRayQueryParameters3D.create(ppos, ppos + back * rig.distance, V3D.MASK_CAMERA, rig._arm_exclude)
			var h2 := space.intersect_ray(q2)
			_tally("short", (h2.collider as Node).name if not h2.is_empty() else "(tilt/none)")
		_m.arm_min = minf(_m.arm_min, arm)
	# Turn rate.
	var fwd := -cam.global_basis.z
	if _prev_fwd != Vector3.ZERO:
		var rate := rad_to_deg(_prev_fwd.angle_to(fwd)) * 120.0
		_m.spin_max = maxf(_m.spin_max, rate)
		if rate > 200.0:
			_m.spin += 1
	_prev_fwd = fwd
	# Occlusion: walk the ray from the camera to the blob through hidden (cut away) hits.
	var cut: float = level._cut if iso else INF
	var from := cpos
	if iso:
		from = ppos - fwd * 30.0
	var excl: Array[RID] = [p.get_rid()]
	var occluded := false
	for i in 6:
		var q := PhysicsRayQueryParameters3D.create(from, ppos, VIS_MASK, excl)
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			break
		var hp: Vector3 = hit.position
		var col := hit.collider as Node3D
		if iso and hp.y > cut + 0.02:
			excl.append(hit.rid)
			continue
		if col and not col.visible:
			excl.append(hit.rid)
			continue
		occluded = true
		_tally("occ", col.name if col else "?")
		break
	if occluded:
		_m.occl += 1
	# On screen.
	var vp := cam.get_viewport().get_visible_rect().size
	var behind := cam.is_position_behind(ppos)
	var sp := cam.unproject_position(ppos)
	var nx := sp.x / vp.x * 2.0 - 1.0
	var ny := sp.y / vp.y * 2.0 - 1.0
	if behind or absf(nx) > 0.8 or absf(ny) > 0.8:
		_m.off += 1
	_m.ndc_y += ny
	# Near-plane clipping (perspective only).
	if not iso:
		var sq := PhysicsShapeQueryParameters3D.new()
		var s := SphereShape3D.new()
		s.radius = 0.12
		sq.shape = s
		sq.transform = Transform3D(Basis(), cpos)
		sq.collision_mask = VIS_MASK
		if not space.intersect_shape(sq, 1).is_empty():
			_m.clip += 1
	if iso:
		if _prev_cut < INF and absf(cut - _prev_cut) > 0.3:
			_m.cuts += 1
		_prev_cut = cut
	if _shot_dir != "" and _frame % _every == 0:
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png(_shot_dir.path_join("ch%02d_f%05d.png" % [_cur_level, _frame]))
