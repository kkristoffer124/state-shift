extends Node
## Placeholder synth SFX generated at startup. Autoload "Sfx".
## Swap these for real sounds later: put AudioStreams in `overrides`.

const RATE := 22050

## name -> AudioStream. Fill from the inspector/code to replace synth sounds.
var overrides: Dictionary = {}
var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 10:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_players.append(p)
	_streams["heat"] = _sweep([[260.0, 620.0, 0.16]], "sine", 0.35)
	_streams["cool"] = _sweep([[620.0, 240.0, 0.16]], "sine", 0.35)
	_streams["jump"] = _sweep([[360.0, 700.0, 0.09]], "square", 0.12)
	_streams["land"] = _sweep([[200.0, 90.0, 0.08]], "sine", 0.35, 0.25)
	_streams["land_ice"] = _sweep([[150.0, 55.0, 0.14]], "square", 0.18, 0.55)
	_streams["shatter"] = _sweep([[1200.0, 180.0, 0.35]], "noise", 0.45)
	_streams["die"] = _sweep([[520.0, 70.0, 0.4]], "square", 0.18, 0.35)
	_streams["blocked"] = _sweep([[140.0, 130.0, 0.09], [140.0, 130.0, 0.09]], "square", 0.14)
	_streams["win"] = _sweep([[523.0, 523.0, 0.09], [659.0, 659.0, 0.09], [784.0, 784.0, 0.09], [1047.0, 1047.0, 0.22]], "square", 0.14)
	_streams["select"] = _sweep([[600.0, 900.0, 0.07]], "sine", 0.3)
	# Cutscene sounds (typewriter blips, lab machinery, alarm, rain).
	_streams["blip"] = _sweep([[980.0, 940.0, 0.025]], "square", 0.06)
	_streams["blip_low"] = _sweep([[420.0, 400.0, 0.03]], "square", 0.07)
	_streams["pop"] = _sweep([[320.0, 980.0, 0.06]], "sine", 0.35)
	_streams["bubble"] = _sweep([[380.0, 760.0, 0.05], [460.0, 900.0, 0.05]], "sine", 0.22)
	_streams["hum"] = _sweep([[110.0, 118.0, 0.7]], "square", 0.06, 0.15)
	_streams["zap"] = _sweep([[2400.0, 300.0, 0.18], [1800.0, 120.0, 0.3]], "noise", 0.4)
	_streams["thud"] = _sweep([[120.0, 40.0, 0.22]], "sine", 0.5, 0.35)
	_streams["alarm"] = _sweep([[660.0, 660.0, 0.22], [520.0, 520.0, 0.22]], "square", 0.09)
	_streams["door"] = _sweep([[90.0, 70.0, 1.2]], "square", 0.07, 0.5)
	_streams["chime"] = _sweep([[784.0, 784.0, 0.12], [988.0, 988.0, 0.12], [1175.0, 1175.0, 0.3]], "sine", 0.22)
	_streams["rain"] = _sweep([[3000.0, 2000.0, 1.8]], "noise", 0.06)
	_streams["poof"] = _sweep([[1600.0, 500.0, 0.16]], "noise", 0.18)


## Sound -> bus (the volume groups in Settings; all send to SFX). Unlisted sounds use SFX.
const BUSES := {
	"select": &"UI", "ui_move": &"UI",
	"blip": &"Cutscene", "blip_low": &"Cutscene", "pop": &"Cutscene", "bubble": &"Cutscene",
	"hum": &"Cutscene", "zap": &"Cutscene", "thud": &"Cutscene", "alarm": &"Cutscene",
	"door": &"Cutscene", "rain": &"Cutscene", "poof": &"Cutscene",
	"jump": &"Movement", "land": &"Movement", "land_ice": &"Movement", "die": &"Movement",
	"heat": &"Shift", "cool": &"Shift", "blocked": &"Shift",
	"win": &"Jingles", "chime": &"Jingles", "shatter": &"Jingles",
}


static func bus_for(sound: String) -> StringName:
	var b: StringName = BUSES.get(sound, &"SFX")
	return b if AudioServer.get_bus_index(b) != -1 else &"SFX"


func play(sound: String, pitch_variation := 0.08) -> void:
	var stream: AudioStream = overrides.get(sound, _streams.get(sound))
	if stream == null:
		return
	for p in _players:
		if not p.playing:
			p.stream = stream
			p.bus = bus_for(sound)
			# Settings.pitch_variation scales the per-call variation (0 = always exact pitch).
			var pv := pitch_variation * Settings.pitch_variation
			p.pitch_scale = clampf(randf_range(1.0 - pv, 1.0 + pv), 0.25, 4.0)
			p.play()
			return


## segments: [[start_hz, end_hz, seconds], ...] played back to back.
func _sweep(segments: Array, wave: String, volume: float, noise_mix := 0.0) -> AudioStreamWAV:
	var data := PackedByteArray()
	for seg in segments:
		var n := int(RATE * float(seg[2]))
		var start := data.size()
		data.resize(start + n * 2)
		var phase := 0.0
		for i in n:
			var t := float(i) / n
			phase += lerpf(seg[0], seg[1], t) / RATE
			var s := 0.0
			match wave:
				"sine": s = sin(phase * TAU)
				"square": s = 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
				_: s = randf_range(-1.0, 1.0)
			if noise_mix > 0.0:
				s = lerpf(s, randf_range(-1.0, 1.0), noise_mix)
			var env := minf(1.0, t * 40.0) * pow(1.0 - t, 2.0)
			data.encode_s16(start + i * 2, int(clampf(s * env * volume, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w
