extends Node
## Windowed capture of both cutscenes (frames every `--every=` cutscene-seconds):
##   godot --position -20000,-20000 --path . res://tests/cutscene_shots.tscn -- --bg-test --out=<dir> [--every=1.0] [--speed=2] [--only=intro|ending]
##   [--panel=N] only save shots of panel N (1-based); [--width=1920] downscale saved frames
##   (0 = native). Dense sweep for checking joints: --every=0.1 --speed=1

var out := "user://cutscene_shots"
var every := 1.0
var speed := 2.0
var only := ""
var panel := 0
var width := 1920


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--every="):
			every = float(a.substr(8))
		elif a.begins_with("--speed="):
			speed = float(a.substr(8))
		elif a.begins_with("--only="):
			only = a.substr(7)
		elif a.begins_with("--panel="):
			panel = int(a.substr(8))
		elif a.begins_with("--width="):
			width = int(a.substr(8))
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if width > 0 and img.get_width() > width:
		img.resize(width, int(round(img.get_height() * float(width) / img.get_width())), Image.INTERPOLATE_NEAREST)
	img.save_png(out.path_join(name + ".png"))


func _play(path: String, tag: String) -> void:
	var cs := (load(path) as PackedScene).instantiate() as Cutscene
	cs.next = Cutscene.Next.NOTHING
	get_tree().root.add_child(cs)
	var t := 0.0
	var next_shot := 0.4
	var n := 0
	while not cs.done:
		await get_tree().process_frame
		t += get_process_delta_time()
		if t >= next_shot:
			next_shot += every
			n += 1
			if panel <= 0 or cs.index + 1 == panel:
				await _shot("%s_%03d_p%d" % [tag, n, cs.index + 1])
		if cs.index == cs.panels.size() - 1 and cs._pending_next:
			break
		if t > 120.0:
			break
	print("%s: %d shots, %.1f s" % [tag, n, t])
	cs.queue_free()
	await get_tree().process_frame


func _run() -> void:
	Engine.time_scale = speed
	Hud.visible = false
	if only != "ending":
		await _play(Game.INTRO_SCENE, "intro")
	if only != "intro":
		await _play(Game.ENDING_SCENE, "ending")
	get_tree().quit()
