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
		_flash_top()
		if d > 0:
			_drip_deaths())


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
		if l.modulate.a < 0.05 and UiFx.full():
			# Labels condense back in: slide a few pixels from the screen edge.
			var dx := 10.0 if l == deaths_label else -10.0
			l.position.x += dx
			UiFx.tw(l, "slide").tween_property(l, "position:x", l.position.x - dx, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
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
			_morph_pop(icon, i)
		else:
			icon.texture = ICONS_INACTIVE[i]
			if icon.scale != Vector2.ONE:
				UiFx.tw(icon, "morph").tween_property(icon, "scale", Vector2.ONE, 0.12)
	_place_lock.call_deferred()


## The new state's icon pops with that state's personality:
## ice snaps rigidly with shards, water wobbles like jelly and splashes, steam stretches up and puffs.
func _morph_pop(icon: Control, state: int) -> void:
	var t := UiFx.tw(icon, "morph")
	if not UiFx.full():
		icon.scale = Vector2.ONE
		return
	var ctr := icon.get_global_rect().get_center()
	match state:
		0:
			icon.scale = Vector2(1.35, 1.35)
			t.tween_property(icon, "scale", Vector2(0.92, 0.92), 0.07).set_trans(Tween.TRANS_QUAD)
			t.tween_property(icon, "scale", Vector2.ONE, 0.08)
			UiFx.frost_burst(icon, ctr, 10)
		1:
			icon.scale = Vector2(1.35, 0.75)
			t.tween_property(icon, "scale", Vector2(0.9, 1.15), 0.09).set_trans(Tween.TRANS_SINE)
			t.tween_property(icon, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			UiFx.splash(icon, ctr + Vector2(0, 10), 0.7)
		_:
			icon.scale = Vector2(0.8, 1.35)
			t.tween_property(icon, "scale", Vector2(1.08, 0.95), 0.12).set_trans(Tween.TRANS_SINE)
			t.tween_property(icon, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_SINE)
			UiFx.puff(icon, ctr - Vector2(0, 10), 5, 12.0, 5.0)


## A drop falls off the "Puddles lost" counter as it ticks up.
func _drip_deaths() -> void:
	deaths_label.pivot_offset = Vector2(deaths_label.size.x, deaths_label.size.y / 2.0).round()
	if not UiFx.full():
		return
	deaths_label.scale = Vector2(1.12, 0.85)
	UiFx.tw(deaths_label, "drip").tween_property(deaths_label, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	var r := deaths_label.get_global_rect()
	UiFx.drip(deaths_label, Vector2(r.end.x - 8.0, r.end.y - 4.0), 2)
	UiFx.ripple(deaths_label, Vector2(r.end.x - 8.0, r.end.y + 16.0), 10.0)


## Shows the padlock over the active state icon while a zone forces the player's state.
func set_locked(locked: bool) -> void:
	if locked == _locked:
		return
	_locked = locked
	lock.visible = locked
	var p := lock.get_global_rect().get_center()
	if locked:
		_place_lock()
		lock.scale = LOCK_SCALE * 1.5
		create_tween().tween_property(lock, "scale", LOCK_SCALE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		# Frozen in place: frost shards + a glint.
		p = lock.get_global_rect().get_center()
		UiFx.frost_burst(lock, p, 8)
	else:
		# The lock cracks open.
		UiFx.frost_burst(lock, p, 12)
		UiFx.glint(lock, p.round(), 4.0)


func _place_lock() -> void:
	if _state < 0 or _state >= icons.size():
		return
	var icon := icons[_state]
	# Top-right corner of the active icon (Icons container offset + icon slot).
	var corner: Vector2 = (icon.get_parent() as Control).position + icon.position + Vector2(icon.custom_minimum_size.x, 0)
	lock.position = (corner - Vector2(12, 10)).round()
