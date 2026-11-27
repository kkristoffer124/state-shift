extends Node
## Windowed (off-screen) run that saves PNGs of the 3D chapters: each level's start,
## a few staged mid-play moments (player teleported + state set), and the same rooms
## through the other camera modes (incl. ISOMETRIC).
##   godot --position -20000,-20000 --resolution 960x540 --path . res://tests/v3d_shots.tscn -- --bg-test --out=<dir> [--only=3]

const M := V3D.CameraMode

var out := "user://v3d_shots"
var only := ""


func _ready() -> void:
	Game.testing = true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--only="):
			only = a.substr(7)
	DirAccess.make_dir_recursive_absolute(out)
	Hud.visible = false
	# [level, camera mode override (-1 = level's own), shot list]
	# shot = [name, player pos, state, yaw deg, pitch deg, frames]
	var plan := [
		[3, -1, [
			["start", null, 1, null, null, 50],
			["bench", Vector3(5.5, 1.4, 6.6), 1, 200.0, -12.0, 30],
			["grate1", Vector3(6, 3.2, 2.4), 2, 160.0, -10.0, 12],
			["mezz", Vector3(3.0, 8.2, 6.0), 2, 30.0, -8.0, 14],
			["top", Vector3(6.5, 13.4, 7.5), 2, 300.0, -28.0, 14],
			["tank", Vector3(11.5, 10.0, 8.2), 1, 0.0, -38.0, 6],
			["ice", Vector3(4.0, 0.6, 7.0), 0, 30.0, -15.0, 30],
		]],
		[3, M.ISOMETRIC, [["iso", null, 1, null, null, 40], ["iso_top", Vector3(6.5, 13.4, 7.5), 2, null, null, 14]]],
		[6, -1, [
			["start", null, 1, null, null, 50],
			["freeze", Vector3(9.6, 2.6, 0), 0, null, null, 40],
			["launch", Vector3(15.0, 2.9, 0), 2, null, null, 20],
			["wind", Vector3(23.0, 5.0, 0), 2, null, null, 30],
			["goal", Vector3(32.5, 4.4, 0), 1, null, null, 40],
		]],
		[6, M.ISOMETRIC, [["iso", Vector3(14.0, 2.4, 0), 1, null, null, 50]]],
		[8, -1, [
			["start", null, 1, null, null, 50],
			["spikes", Vector3(7.6, 0.4, 2.2), 1, 100.0, -8.0, 20],
			["vent", Vector3(4.4, 0.4, 1.6), 1, 90.0, 5.0, 20],
			["shaft", Vector3(1.6, 6.5, 1.6), 2, 90.0, 20.0, 12],
			["duct", Vector3(4.5, 11.5, 1.5), 2, 270.0, -5.0, 14],
			["well", Vector3(13.4, 11.3, 1.5), 0, 270.0, -70.0, 4],
			["water_fp", Vector3(9.0, 0.4, 3.0), 1, 160.0, -5.0, 30],
		]],
		[8, M.THIRD_PERSON, [["tp_room", Vector3(8.6, 0.4, 3.5), 1, 70.0, -20.0, 60], ["tp_ice", Vector3(6.8, 0.6, 2.0), 0, 80.0, -20.0, 40]]],
		[8, M.ISOMETRIC, [["iso", Vector3(8.0, 0.4, 4.0), 1, null, null, 50]]],
	]
	for entry in plan:
		if only != "" and str(entry[0]) != only:
			continue
		await _shoot_level(entry[0], entry[1], entry[2])
	get_tree().quit()


func _shoot_level(n: int, mode_override: int, shots: Array) -> void:
	var level: Level3D = load("res://levels/level_%02d_3d.tscn" % n).instantiate()
	if mode_override >= 0:
		level.camera_mode = mode_override
	add_child(level)
	var p: Player3D = level.get_node("Player")
	var rig: CameraRig3D = level.get_node("CameraRig")
	var mode_name: String = M.keys()[level.camera_mode].to_lower()
	for s in shots:
		if s[1] != null:
			p.global_position = s[1]
			p.velocity = Vector3.ZERO
		if s[2] != p.state:
			p.try_shift(s[2], true)
		if s[3] != null and rig.mode != M.SIDE_25D and rig.mode != M.ISOMETRIC:
			rig.yaw = deg_to_rad(s[3])
		if s[4] != null and rig.mode != M.SIDE_25D and rig.mode != M.ISOMETRIC:
			rig.pitch = deg_to_rad(s[4])
		rig._snap = true
		for i in s[5]:
			if s[1] != null and p.state == Player3D.State.STEAM:
				p.velocity.y = minf(p.velocity.y, 0.5)
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var file := "ch%02d_%s_%s.png" % [n, mode_name, s[0]]
		img.save_png(out.path_join(file))
		print("saved %s  draw calls=%d  objects=%d" % [file,
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)])
	level.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
