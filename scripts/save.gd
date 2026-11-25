extends Node
## Persistent progress + settings storage. Autoload "Save".
## One ConfigFile at user://save.cfg (IndexedDB on web):
##   [progress] started, unlocked (chapters playable, 1..N)
##   [chapter_N] best_time (seconds), best_deaths
##   [settings]  written by the Settings autoload via get_setting()/set_setting()

signal progress_changed

const DEFAULT_PATH := "user://save.cfg"

var path := DEFAULT_PATH
var cfg := ConfigFile.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_file()


## Points the save at another file (tests) and reloads it.
func use_path(p: String) -> void:
	path = p
	load_file()


func load_file() -> void:
	cfg = ConfigFile.new()
	if FileAccess.file_exists(path):
		var err := cfg.load(path)
		if err != OK:
			push_warning("Save: could not read %s (%s), starting fresh" % [path, error_string(err)])
			cfg = ConfigFile.new()
	progress_changed.emit()


func flush() -> void:
	var err := cfg.save(path)
	if err != OK:
		push_warning("Save: could not write %s (%s)" % [path, error_string(err)])


func chapter_count() -> int:
	return Game.LEVELS.size()


# --- Progress -----------------------------------------------------------------

## True once a new game has been started (shows "Continue" on the title screen).
func has_progress() -> bool:
	return bool(cfg.get_value("progress", "started", false))


## Number of chapters the player may play (always at least 1).
func unlocked_count() -> int:
	return clampi(int(cfg.get_value("progress", "unlocked", 1)), 1, chapter_count())


func is_unlocked(index: int) -> bool:
	return index >= 0 and index < unlocked_count()


func is_cleared(index: int) -> bool:
	return best_time(index) >= 0.0


func cleared_count() -> int:
	var n := 0
	for i in chapter_count():
		if is_cleared(i):
			n += 1
	return n


## Chapter "Continue" resumes: the furthest unlocked one.
func continue_index() -> int:
	return unlocked_count() - 1


## Best completion time in seconds, or -1 if never cleared.
func best_time(index: int) -> float:
	return float(cfg.get_value("chapter_%d" % (index + 1), "best_time", -1.0))


## Fewest puddles lost on a clear, or -1 if never cleared.
func best_deaths(index: int) -> int:
	return int(cfg.get_value("chapter_%d" % (index + 1), "best_deaths", -1))


func mark_started() -> void:
	if not has_progress():
		cfg.set_value("progress", "started", true)
		flush()
		progress_changed.emit()


## Records a clear of chapter `index`, unlocks the next one and saves.
## Returns {"best_time": bool, "best_deaths": bool, "first_clear": bool}.
func record_chapter(index: int, time: float, deaths: int) -> Dictionary:
	var sec := "chapter_%d" % (index + 1)
	var prev_t := best_time(index)
	var prev_d := best_deaths(index)
	var result := {
		"first_clear": prev_t < 0.0,
		"best_time": prev_t < 0.0 or time < prev_t,
		"best_deaths": prev_d < 0 or deaths < prev_d,
	}
	if result.best_time:
		cfg.set_value(sec, "best_time", snappedf(time, 0.01))
	if result.best_deaths:
		cfg.set_value(sec, "best_deaths", deaths)
	cfg.set_value("progress", "started", true)
	cfg.set_value("progress", "unlocked", maxi(unlocked_count(), mini(index + 2, chapter_count())))
	flush()
	progress_changed.emit()
	return result


## Wipes progress and best records; keeps settings.
func reset_progress() -> void:
	var settings := {}
	if cfg.has_section("settings"):
		for k in cfg.get_section_keys("settings"):
			settings[k] = cfg.get_value("settings", k)
	cfg = ConfigFile.new()
	for k in settings:
		cfg.set_value("settings", k, settings[k])
	flush()
	progress_changed.emit()


## Sum of best times over cleared chapters (-1 if none cleared).
func best_total_time() -> float:
	var total := 0.0
	var any := false
	for i in chapter_count():
		if is_cleared(i):
			total += best_time(i)
			any = true
	return total if any else -1.0


# --- Settings storage -----------------------------------------------------------

func get_setting(key: String, default: Variant) -> Variant:
	return cfg.get_value("settings", key, default)


func set_setting(key: String, value: Variant, write := true) -> void:
	cfg.set_value("settings", key, value)
	if write:
		flush()


static func format_time(seconds: float) -> String:
	if seconds < 0.0:
		return "--:--"
	var t := int(seconds)
	var cs := int((seconds - t) * 10.0)
	return "%d:%02d.%d" % [t / 60, t % 60, cs]
