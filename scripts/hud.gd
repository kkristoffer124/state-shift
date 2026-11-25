extends CanvasLayer
## In-level overlay. Autoload "Hud" (scenes/hud.tscn).

const ICONS_ACTIVE: Array[Texture2D] = [
	preload("res://assets/ui/u2_icon_ice_active.png"),
	preload("res://assets/ui/u2_icon_water_active.png"),
	preload("res://assets/ui/u2_icon_steam_active.png"),
]
const ICONS_INACTIVE: Array[Texture2D] = [
	preload("res://assets/ui/u2_icon_ice_inactive.png"),
	preload("res://assets/ui/u2_icon_water_inactive.png"),
	preload("res://assets/ui/u2_icon_steam_inactive.png"),
]
const LOCK_SCALE := Vector2(2, 2)

@onready var level_label: Label = $LevelLabel
@onready var deaths_label: Label = $DeathsLabel
@onready var progress_label: Label = $ProgressLabel
@onready var icons: Array[TextureRect] = [$StateBar/Icons/Ice, $StateBar/Icons/Water, $StateBar/Icons/Steam]
@onready var lock: TextureRect = $StateBar/Lock

var _state := 1
var _locked := false


func _ready() -> void:
	visible = false
	lock.pivot_offset = lock.size / 2.0
	lock.scale = LOCK_SCALE
	Game.state_changed.connect(_on_state_changed)
	Game.level_changed.connect(_on_level_changed)
	Game.deaths_changed.connect(func(d: int) -> void:
		deaths_label.text = "Puddles lost: %d" % d
		_flash_top())


func _on_level_changed(level_name: String, index: int, total: int) -> void:
	level_label.text = "Chapter %d — %s" % [index + 1, Game.title_from_level_name(level_name)]
	progress_label.text = "%d / %d" % [index + 1, total]
	set_locked(false)
	_flash_top()


var _top_tween: Tween

## The top labels show for a few seconds, then fade so they never cover the level.
func _flash_top() -> void:
	if _top_tween:
		_top_tween.kill()
	for l in [level_label, deaths_label, progress_label]:
		l.modulate.a = 1.0
	_top_tween = create_tween().set_parallel()
	for l in [level_label, deaths_label, progress_label]:
		_top_tween.tween_property(l, "modulate:a", 0.0, 0.8).set_delay(3.5)


func _on_state_changed(s: int) -> void:
	_state = s
	for i in icons.size():
		var icon := icons[i]
		icon.pivot_offset = icon.custom_minimum_size / 2.0
		if i == s:
			icon.texture = ICONS_ACTIVE[i]
			icon.scale = Vector2(1.25, 1.25)
			create_tween().tween_property(icon, "scale", Vector2.ONE, 0.2)
		else:
			icon.texture = ICONS_INACTIVE[i]
			icon.scale = Vector2.ONE
	_place_lock.call_deferred()


## Shows the padlock over the active state icon while a zone forces the player's state.
func set_locked(locked: bool) -> void:
	if locked == _locked:
		return
	_locked = locked
	lock.visible = locked
	if locked:
		_place_lock()
		lock.scale = LOCK_SCALE * 1.5
		create_tween().tween_property(lock, "scale", LOCK_SCALE, 0.15)


func _place_lock() -> void:
	if _state < 0 or _state >= icons.size():
		return
	var icon := icons[_state]
	# Top-right corner of the active icon (Icons container offset + icon slot).
	var corner: Vector2 = (icon.get_parent() as Control).position + icon.position + Vector2(icon.custom_minimum_size.x, 0)
	lock.position = (corner - Vector2(12, 10)).round()
