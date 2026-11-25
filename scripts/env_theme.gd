@tool
class_name EnvTheme
extends RefCounted
## Per-level environment art sets (assets/env_<theme>/). Each theme folder holds
## same-named replacements for assets/env/*; anything missing falls back to
## assets/env/. Sets are loaded once per theme and cached in a static dictionary.

const THEMES: PackedStringArray = ["lab", "cryo", "boiler", "sewer", "rooftop"]
const DEFAULT := "lab"

## Wall decals per theme (frost_patch is left out: it reads as static noise on plain walls).
const DECALS := {
	"lab": ["cable_bundle", "number_plate", "pipe_elbow", "vent_slit", "warning_stripe"],
	"cryo": ["icicles", "number_plate", "pipe_elbow", "snow_plate", "vent_slit"],
	"boiler": ["gauge", "number_plate", "pipe_elbow", "soot_stain", "valve", "vent_slit"],
	"sewer": ["cable_bundle", "drain", "moss", "number_plate", "pipe_elbow", "vent_slit"],
	"rooftop": ["cable_bundle", "junction_box", "number_plate", "pipe_elbow", "tar_patch", "vent_slit", "warning_stripe"],
}

static var _cache := {}


## Texture set for `theme`: keys wall, grate, cracked, spike, spike_plate, heat_vent,
## freeze_emitter, fan_housing, fan_blade (Texture2D) and decals (Array[Texture2D]).
static func textures(theme: String) -> Dictionary:
	if not THEMES.has(theme):
		theme = DEFAULT
	if _cache.has(theme):
		return _cache[theme]
	var dir := "res://assets/env_%s/" % theme
	var out := {
		"wall": _tex(dir, "e1a_wall_9s32"),
		"grate": _tex(dir, "e2a_grate_9s3"),
		"cracked": _tex(dir, "e3a_cracked_block_9s8"),
		"spike": _tex(dir, "e4a_spike"),
		"spike_plate": _tex(dir, "e4b_spike_plate"),
		"heat_vent": _tex(dir, "e5a_heat_vent"),
		"freeze_emitter": _tex(dir, "e6a_freeze_emitter"),
		"fan_housing": _tex(dir, "e7a_fan_housing_9s8"),
		"fan_blade": _tex(dir, "e7b_fan_blade_4f"),
	}
	var decals: Array[Texture2D] = []
	for d in DECALS[theme]:
		var t := _tex(dir, "e1c_decal_" + d)
		if t:
			decals.append(t)
	out["decals"] = decals
	_cache[theme] = out
	return out


static func _tex(dir: String, file: String) -> Texture2D:
	var p := dir + file + ".png"
	if ResourceLoader.exists(p):
		return load(p)
	p = "res://assets/env/" + file + ".png"
	if ResourceLoader.exists(p):
		return load(p)
	return null


## Theme of the level `node` belongs to: the nearest ancestor (or owner) whose
## `theme` property is a String. Works in the editor too.
static func find_theme(node: Node) -> String:
	var n := node.get_parent() if node else null
	while n:
		var t = n.get("theme")
		if t is String and THEMES.has(t):
			return t
		n = n.get_parent()
	if node and node.owner:
		var t = node.owner.get("theme")
		if t is String and THEMES.has(t):
			return t
	return DEFAULT
