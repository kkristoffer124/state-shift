class_name SettingsPanel
extends Control
## Settings screen (title menu and pause menu). Tabs and pages are nodes in
## settings_panel.tscn (one ScrollContainer/List per Settings category); the rows inside
## are built from Settings.DEFS. Up/down moves through rows, left/right changes values,
## Q/E, PgUp/PgDn or LB/RB switch tabs. The focused row's description shows underneath.
## Key rows: press, then press the new key (Esc cancels, Backspace restores the default).

signal closed

const LABEL_W := 300.0
const CONTROL_W := 300.0
const VALUE_W := 96.0

@onready var tabs: HBoxContainer = %Tabs
@onready var pages: Control = %Pages
@onready var desc: Label = %Desc
@onready var reset_cat_btn: Button = %ResetCat
@onready var reset_btn: Button = %ResetAll
@onready var back_btn: Button = %Back

## Generated controls by setting key, and their row label / value label.
var controls := {}
var _labels := {}
var _values := {}
var _tab_buttons: Array[Button] = []
var _pages: Array[ScrollContainer] = []
var _page_controls := {} # category -> Array[Control]
var _category := "audio"
var _syncing := false
var _capturing := ""

## Shortcuts used by menu_test / older callers.
var master: HSlider:
	get: return controls.get("master_volume")
var shake: CheckButton:
	get: return controls.get("screen_shake")
var zoom: CycleButton:
	get: return controls.get("room_zoom")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for b in tabs.get_children():
		_tab_buttons.append(b as Button)
	for p in pages.get_children():
		_pages.append(p as ScrollContainer)
	for i in _tab_buttons.size():
		var cat: String = _tab_buttons[i].get_meta("category")
		_build_page(cat, _pages[i].get_node("List"))
		_tab_buttons[i].focus_entered.connect(show_category.bind(cat))
		_tab_buttons[i].pressed.connect(show_category.bind(cat))
	reset_cat_btn.pressed.connect(func() -> void: Settings.reset_category(_category))
	reset_btn.pressed.connect(func() -> void: Settings.reset_defaults())
	back_btn.pressed.connect(close)
	for b in [reset_cat_btn, reset_btn, back_btn]:
		b.focus_entered.connect(_show_desc.bind(b))
	UiUtil.chain(_tab_buttons, false)
	UiUtil.chain([reset_cat_btn, reset_btn, back_btn], false)
	UiUtil.wire(self)
	Settings.changed.connect(func(_k: String) -> void: _sync())
	show_category("audio")
	_sync()


func open() -> void:
	_sync()
	show()
	show_category(_category)
	var first: Array = _page_controls.get(_category, [])
	UiUtil.focus_quiet(first[0] if not first.is_empty() else back_btn)


func close() -> void:
	if not visible:
		return
	_capturing = ""
	hide()
	closed.emit()


# --- Building -------------------------------------------------------------------------

func _build_page(cat: String, list: VBoxContainer) -> void:
	var ctrls: Array[Control] = []
	for key in Settings.keys_in(cat, true):
		var m := Settings.meta(key)
		var row := HBoxContainer.new()
		row.name = key
		row.add_theme_constant_override("separation", 14)
		var label := Label.new()
		label.name = "Label"
		label.text = m.label
		label.custom_minimum_size = Vector2(LABEL_W, 0)
		label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(label)
		var c := _make_control(key, m)
		c.name = "Control"
		if not c is CheckButton:
			c.custom_minimum_size.x = CONTROL_W
		c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(c)
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(spacer)
		var val := Label.new()
		val.name = "Value"
		val.theme_type_variation = &"DimLabel"
		val.custom_minimum_size = Vector2(VALUE_W, 0)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(val)
		list.add_child(row)
		controls[key] = c
		_labels[key] = label
		_values[key] = val
		c.focus_entered.connect(_on_row_focus.bind(key, true))
		c.focus_exited.connect(_on_row_focus.bind(key, false))
		ctrls.append(c)
	_page_controls[cat] = ctrls
	if ctrls.is_empty():
		return
	UiUtil.chain(ctrls, true, false)
	var ti := Settings.CATEGORIES.find(cat)
	if ti >= 0 and ti < _tab_buttons.size():
		ctrls[0].focus_neighbor_top = ctrls[0].get_path_to(_tab_buttons[ti])
		ctrls[0].focus_previous = ctrls[0].get_path_to(_tab_buttons[ti])
	ctrls[-1].focus_neighbor_bottom = ctrls[-1].get_path_to(reset_cat_btn)
	ctrls[-1].focus_next = ctrls[-1].get_path_to(reset_cat_btn)
	for c in ctrls:
		if not c is Slider and not c is CycleButton:
			c.focus_neighbor_left = c.get_path_to(c)
			c.focus_neighbor_right = c.get_path_to(c)


func _make_control(key: String, m: Dictionary) -> Control:
	match m.type:
		"bool":
			var cb := CheckButton.new()
			cb.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			cb.toggled.connect(func(on: bool) -> void:
				if not _syncing:
					Settings.set_value(key, on))
			if key == "fullscreen" and not Settings.can_fullscreen():
				cb.disabled = true
			return cb
		"range":
			var s := HSlider.new()
			var k := _slider_scale(m)
			s.min_value = m.min * k
			s.max_value = m.max * k
			s.step = m.step * k
			s.custom_minimum_size.y = 20
			s.value_changed.connect(func(v: float) -> void:
				if _syncing:
					return
				Settings.set_value(key, v / k)
				_values[key].text = Settings.format_value(key))
			return s
		"choice":
			var cyc := CycleButton.new()
			cyc.labels = PackedStringArray(m.labels)
			cyc.alignment = HORIZONTAL_ALIGNMENT_CENTER
			cyc.value_changed.connect(func(i: int) -> void:
				if not _syncing:
					Settings.set_value(key, m.values[i]))
			return cyc
		"key":
			var b := Button.new()
			b.set_meta("no_click_sfx", true)
			b.pressed.connect(_begin_capture.bind(key))
			return b
	return Control.new()


static func _slider_scale(m: Dictionary) -> float:
	return 100.0 if m.get("fmt", "") == "pct" else 1.0


# --- Tabs ---------------------------------------------------------------------------------

func show_category(cat: String) -> void:
	var i := Settings.CATEGORIES.find(cat)
	if i < 0 or i >= _pages.size():
		return
	var changed_page := cat != _category
	_category = cat
	for j in _pages.size():
		_pages[j].visible = j == i
	for j in _tab_buttons.size():
		_tab_buttons[j].set_pressed_no_signal(j == i)
	reset_cat_btn.text = "Reset %s" % Settings.CATEGORY_NAMES[cat].to_lower()
	var ctrls: Array = _page_controls.get(cat, [])
	# Up from the bottom buttons goes to this page's last row; down from the tabs to its first.
	for b in [reset_cat_btn, reset_btn, back_btn]:
		b.focus_neighbor_top = b.get_path_to(ctrls[-1] if not ctrls.is_empty() else _tab_buttons[i])
		b.focus_neighbor_bottom = b.get_path_to(_tab_buttons[i])
	for t in _tab_buttons:
		t.focus_neighbor_bottom = t.get_path_to(ctrls[0] if not ctrls.is_empty() else reset_cat_btn)
		t.focus_neighbor_top = t.get_path_to(back_btn)
	if changed_page and visible and Settings.ui_animations and not Settings.reduce_motion:
		_pages[i].modulate.a = 0.0
		create_tween().tween_property(_pages[i], "modulate:a", 1.0, 0.15)
	else:
		_pages[i].modulate.a = 1.0
	if changed_page:
		_pages[i].scroll_vertical = 0
	desc.text = "%d settings in %s." % [ctrls.size(), Settings.CATEGORY_NAMES[cat]]


## Next / previous tab, focusing its first row (or the tab itself when focus was on the tabs).
func cycle_category(dir: int) -> void:
	var i := wrapi(Settings.CATEGORIES.find(_category) + dir, 0, _tab_buttons.size())
	var on_tabs := get_viewport().gui_get_focus_owner() in _tab_buttons
	show_category(Settings.CATEGORIES[i])
	var ctrls: Array = _page_controls.get(_category, [])
	if on_tabs or ctrls.is_empty():
		_tab_buttons[i].grab_focus()
	else:
		ctrls[0].grab_focus()


func current_category() -> String:
	return _category


# --- Input ----------------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if _capturing != "":
		if event is InputEventKey and event.pressed and not event.echo:
			var k := event as InputEventKey
			var code := k.physical_keycode if k.physical_keycode != 0 else k.keycode
			var key := _capturing
			_capturing = ""
			if code == KEY_BACKSPACE or code == KEY_DELETE:
				Settings.set_value(key, 0)
			elif code != KEY_ESCAPE:
				Settings.set_value(key, int(code))
			Sfx.play("select", 0.0)
			_sync()
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and event.pressed:
			_capturing = ""
			_sync()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var code := (event as InputEventKey).physical_keycode
		if code in [KEY_Q, KEY_PAGEUP]:
			cycle_category(-1)
			get_viewport().set_input_as_handled()
		elif code in [KEY_E, KEY_PAGEDOWN]:
			cycle_category(1)
			get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and event.pressed:
		var bi := (event as InputEventJoypadButton).button_index
		if bi == JOY_BUTTON_LEFT_SHOULDER:
			cycle_category(-1)
			get_viewport().set_input_as_handled()
		elif bi == JOY_BUTTON_RIGHT_SHOULDER:
			cycle_category(1)
			get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		Sfx.play("select", 0.0)
		close()


func _begin_capture(key: String) -> void:
	_capturing = key
	(controls[key] as Button).text = "Press a key..."
	desc.text = "Press the new key for '%s'.  Esc cancels, Backspace restores the default." % Settings.meta(key).label
	Sfx.play("select", 0.0)


func is_capturing() -> bool:
	return _capturing != ""


# --- Sync / focus -----------------------------------------------------------------------------

func _sync() -> void:
	_syncing = true
	for key in controls:
		var c: Control = controls[key]
		var m := Settings.meta(key)
		var v: Variant = Settings.get(key)
		match m.type:
			"bool":
				(c as CheckButton).set_pressed_no_signal(bool(v))
			"range":
				(c as HSlider).set_value_no_signal(float(v) * _slider_scale(m))
			"choice":
				var cyc := c as CycleButton
				var i := maxi(Settings.choice_index(key, v), 0)
				if cyc.index != i:
					cyc.index = i
			"key":
				if key != _capturing:
					(c as Button).text = Settings.format_value(key)
		_values[key].text = _value_note(key)
	_syncing = false


## Right-hand note: the value for sliders, a "changed" marker otherwise, conflicts for keys.
func _value_note(key: String) -> String:
	var m := Settings.meta(key)
	if m.type == "range":
		return Settings.format_value(key)
	if m.type == "key":
		var mine := _bound_key(key)
		for other in Settings.BINDS:
			if other != key and _bound_key(other) == mine:
				return "clash!"
	return "" if Settings.get(key) == Settings.default_of(key) else "changed"


func _bound_key(key: String) -> int:
	var v := int(Settings.get(key))
	return v if v != 0 else Settings.default_key(key)


func _on_row_focus(key: String, on: bool) -> void:
	# The first row's focus frame pokes above the list: keep that page scrolled to the top.
	var page: Array = _page_controls.get(Settings.meta(key).category, [])
	if on and not page.is_empty() and page[0] == controls[key]:
		var sc := _pages[Settings.CATEGORIES.find(Settings.meta(key).category)]
		sc.set_deferred("scroll_vertical", 0)
	_labels[key].theme_type_variation = &"AccentLabel" if on else &""
	if on and _capturing == "":
		var m := Settings.meta(key)
		desc.text = m.description
		if m.type != "key" and Settings.get(key) != Settings.default_of(key):
			desc.text += "  (default: %s)" % Settings.format_value(key, Settings.default_of(key))


func _show_desc(b: Button) -> void:
	if b == reset_cat_btn:
		desc.text = "Restore the defaults of the %s tab only." % Settings.CATEGORY_NAMES[_category]
	elif b == reset_btn:
		desc.text = "Restore every setting in every tab to its default."
	else:
		desc.text = "Close settings (changes are saved immediately)."
