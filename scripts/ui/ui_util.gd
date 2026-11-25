class_name UiUtil
extends RefCounted
## Shared menu helpers: focus = hover look, mouse hover grabs focus, navigation/confirm sounds.

static var _quiet_until := 0


## Wires every BaseButton/Slider under `root` (call once from the owner's _ready).
static func wire(root: Node) -> void:
	for c in root.find_children("*", "Control", true, false):
		if c is BaseButton or c is Slider:
			wire_control(c)


static func wire_control(c: Control) -> void:
	if c.has_meta("_ui_wired"):
		return
	c.set_meta("_ui_wired", true)
	c.focus_entered.connect(_on_focus.bind(c, true))
	c.focus_exited.connect(_on_focus.bind(c, false))
	c.mouse_entered.connect(func() -> void:
		if c.is_visible_in_tree() and c.focus_mode != Control.FOCUS_NONE and not c.has_focus():
			c.grab_focus())
	if c is BaseButton and not c.has_meta("no_click_sfx"):
		(c as BaseButton).pressed.connect(func() -> void: Sfx.play("select", 0.0))


## Focuses `c` without the navigation blip (opening a screen).
static func focus_quiet(c: Control) -> void:
	if c == null or not c.is_inside_tree():
		return
	_quiet_until = Engine.get_process_frames() + 1
	c.grab_focus.call_deferred()


static func _on_focus(c: Control, focused: bool) -> void:
	if c is Button and not c is CheckButton:
		# Keyboard/gamepad focus uses the same look as mouse hover.
		if focused:
			c.add_theme_stylebox_override("normal", c.get_theme_stylebox("hover"))
		else:
			c.remove_theme_stylebox_override("normal")
	if focused and Engine.get_process_frames() > _quiet_until:
		Sfx.play("ui_move", 0.04)


## Links `controls` into a loop for one navigation axis (vertical: up/down, else left/right).
static func chain(controls: Array, vertical: bool, wrap := true) -> void:
	var vis: Array = controls.filter(func(c: Control) -> bool: return c.visible)
	for i in vis.size():
		var c: Control = vis[i]
		var prev: Control = vis[i - 1] if (i > 0 or wrap) else c
		var next: Control = vis[(i + 1) % vis.size()] if (i < vis.size() - 1 or wrap) else c
		if vertical:
			c.focus_neighbor_top = c.get_path_to(prev)
			c.focus_neighbor_bottom = c.get_path_to(next)
			c.focus_previous = c.get_path_to(prev)
			c.focus_next = c.get_path_to(next)
		else:
			c.focus_neighbor_left = c.get_path_to(prev)
			c.focus_neighbor_right = c.get_path_to(next)
			c.focus_previous = c.get_path_to(prev)
			c.focus_next = c.get_path_to(next)


static func format_time(seconds: float) -> String:
	return Save.format_time(seconds)
