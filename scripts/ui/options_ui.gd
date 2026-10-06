# OptionsUI
# The Options page, shared by the title screen and the in-game System page.
# Covers whatever opened it and emits `closed` when the player backs out;
# every change is saved the moment it is made, so there is nothing to confirm.
class_name OptionsUI extends Control

signal closed

const _FONT := preload("res://resources/misc/OldSchoolAdventures-42j9.ttf") as FontFile

# Sizes: a phone's for a thumb, a wide screen's the windows' own (SidePanel).
var _wide: bool = false
# The mapping row waiting for a press: {action, pad, btn}; empty when none is.
var _capture: Dictionary = {}
var _map_btns: Array[Dictionary] = []
var _map_note: Label


func _sz(phone: int, wide: int) -> int:
	return wide if _wide else phone


func _ready() -> void:
	_wide = Build.steam()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	if _wide:
		_focus_first.call_deferred()


func _focus_first() -> void:
	var f: Control = SidePanel._first_focusable(self)
	if f != null:
		f.grab_focus()


func _build() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.04, 0.03, 0.07, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 18)
	add_child(margin)

	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", _sz(14, 6))
	if _wide:
		# The windows' look, and room to scroll: the mapping makes it long.
		theme = SidePanel._theme()
		var sc: ScrollContainer = TouchScroll.new()
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		sc.follow_focus = true
		margin.add_child(sc)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sc.add_child(col)
	else:
		margin.add_child(col)

	col.add_child(_label("Options", _sz(30, 14), Color(0.90, 0.75, 0.30)))
	col.add_child(HSeparator.new())
	if _wide:
		col.add_child(_label("Display", 11, Color(0.55, 0.50, 0.62)))
		_add_toggle(col, "Fullscreen", "F11 or Alt+Enter switches it too.",
				Settings.fullscreen(), Settings.set_fullscreen)
		col.add_child(HSeparator.new())
		_add_mapping(col)
		col.add_child(HSeparator.new())
	col.add_child(_label("Swipes" if _wide else "Controls", _sz(18, 11), Color(0.55, 0.50, 0.62)))

	_add_toggle(col, "Invert turn",
			"Swipe left to turn right, and right to turn left.",
			Settings.invert_turn(), Settings.set_invert_turn)
	_add_toggle(col, "Invert movement",
			"Swipe down to step forward, and up to step back.",
			Settings.invert_move(), Settings.set_invert_move)

	if not _wide:
		col.add_child(_label("These change swipes only. Arrow keys and WASD stay as they are.",
				15, Color(0.50, 0.47, 0.56), true))

	col.add_child(HSeparator.new())
	col.add_child(_label("Sound", _sz(18, 11), Color(0.55, 0.50, 0.62)))
	_add_slider(col, "Music", Settings.music_volume(), Settings.set_music_volume)
	_add_slider(col, "Sound effects", Settings.sfx_volume(), Settings.set_sfx_volume,
			func() -> void: Sfx.play("hit"))

	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)

	var back: Button = Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(0, _sz(52, 0))
	back.add_theme_font_override("font", _FONT)
	back.add_theme_font_size_override("font_size", _sz(20, 14))
	back.pressed.connect(func() -> void: closed.emit())
	col.add_child(back)


# One row: the name and its current state on a wide button, what it does
# underneath. A tap flips it and says the new state on the button itself.
func _add_toggle(parent: Control, title: String, desc: String, on: bool,
		apply: Callable) -> void:
	var btn: Button = Button.new()
	btn.toggle_mode = true
	btn.button_pressed = on
	btn.custom_minimum_size = Vector2(0, _sz(56, 0))
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.add_theme_font_override("font", _FONT)
	btn.add_theme_font_size_override("font_size", _sz(22, 14))
	var paint: Callable = func(state: bool) -> void:
		btn.text = "  %s:  %s" % [title, "ON" if state else "OFF"]
		btn.add_theme_color_override("font_color",
				Color(0.45, 1.0, 0.60) if state else Color(0.85, 0.85, 0.88))
		btn.add_theme_color_override("font_pressed_color", Color(0.45, 1.0, 0.60))
	paint.call(on)
	btn.toggled.connect(func(state: bool) -> void:
		apply.call(state)
		paint.call(state))
	parent.add_child(btn)
	parent.add_child(_label(desc, _sz(17, 11), Color(0.70, 0.68, 0.76), true))


# One volume: its name and percent above a slider. Dragging is heard as it
# goes; letting go saves it and plays `sample`, if there is one, at the new level.
func _add_slider(parent: Control, title: String, pct: int, apply: Callable,
		sample: Callable = Callable()) -> void:
	var lbl: Label = _label("", _sz(20, 14), Color(0.85, 0.85, 0.88))
	parent.add_child(lbl)
	var slider: HSlider = HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 5
	slider.value = pct
	# Tall, so a thumb finds it on a phone.
	slider.custom_minimum_size = Vector2(0, _sz(44, 24))
	slider.add_theme_icon_override("grabber", _grabber(Color(0.90, 0.75, 0.30)))
	slider.add_theme_icon_override("grabber_highlight", _grabber(Color(1.0, 0.88, 0.45)))
	var paint: Callable = func(v: float) -> void:
		lbl.text = "%s:  %d%%" % [title, roundi(v)] if v > 0 else "%s:  OFF" % title
	paint.call(float(pct))
	slider.value_changed.connect(func(v: float) -> void:
		apply.call(roundi(v), false)
		paint.call(v))
	slider.drag_ended.connect(func(_changed: bool) -> void:
		apply.call(roundi(slider.value), true)
		if sample.is_valid():
			sample.call())
	parent.add_child(slider)


# A round handle big enough to grab; the stock one is a few pixels wide.
func _grabber(color: Color) -> ImageTexture:
	var r: int = 14
	var img: Image = Image.create(r * 2, r * 2, false, Image.FORMAT_RGBA8)
	for y: int in r * 2:
		for x: int in r * 2:
			var d: float = Vector2(x - r + 0.5, y - r + 0.5).length()
			img.set_pixel(x, y, Color(color, clampf(r - d, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)


func _label(text: String, size: int, color: Color, wrap: bool = false) -> Label:
	var lbl: Label = Label.new()
	lbl.text = text
	lbl.add_theme_font_override("font", _FONT)
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	if wrap:
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return lbl


# ── Button mapping (wide screen) ─────────────────────────────────────────────
#
# A row per action: its name, then the key and the pad button on it. Choose
# one and press what it should be; Escape leaves it as it was. A key
# another action had swaps over to that action (Controls.set_key).

func _add_mapping(col: VBoxContainer) -> void:
	col.add_child(_label("Button mapping", 11, Color(0.55, 0.50, 0.62)))
	var grid: GridContainer = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 3)
	col.add_child(grid)
	for head: String in ["", "Keyboard", "Pad"]:
		grid.add_child(_label(head, 11, Color(0.50, 0.50, 0.58)))
	for a: Array in Controls.ACTIONS:
		var id: String = a[0] as String
		var name_lbl: Label = _label(a[1] as String, 14, Color(0.84, 0.86, 0.92))
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(name_lbl)
		for pad: bool in [false, true]:
			var b: Button = Button.new()
			b.custom_minimum_size = Vector2(110, 0)
			b.add_theme_font_override("font", _FONT)
			b.pressed.connect(_start_capture.bind(id, pad, b))
			grid.add_child(b)
			b.add_theme_font_size_override("font_size", 14)
			_map_btns.append({action = id, pad = pad, btn = b})
	_map_note = _label("Arrow keys, Enter and Escape always work as well.", 11,
			Color(0.50, 0.50, 0.58), true)
	col.add_child(_map_note)
	var reset: Button = Button.new()
	reset.text = "Reset to defaults"
	reset.add_theme_font_override("font", _FONT)
	reset.pressed.connect(func() -> void:
		Controls.reset()
		_say("Back to the defaults.")
		_paint_mapping())
	col.add_child(reset)
	reset.add_theme_font_size_override("font_size", 14)
	_paint_mapping()


func _paint_mapping() -> void:
	for m: Dictionary in _map_btns:
		var b: Button = m["btn"] as Button
		var id: String = m["action"] as String
		b.text = Controls.pad_name(Controls.pad_of(id)) if bool(m["pad"]) \
				else Controls.key_name(Controls.key_of(id))


func _start_capture(action: String, pad: bool, btn: Button) -> void:
	_paint_mapping()
	_capture = {action = action, pad = pad, btn = btn}
	btn.text = "press a button" if pad else "press a key"


func _say(text: String) -> void:
	if _map_note != null:
		_map_note.text = text


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if _capture.is_empty():
		# Backing out of Options is Options' to handle, not the page under it.
		if _wide and event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			closed.emit()
		return
	var pad: bool = bool(_capture["pad"])
	var id: String = _capture["action"] as String
	if event is InputEventKey and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		var k: int = (event as InputEventKey).keycode
		if k == KEY_ESCAPE or pad:
			_say("Left as it was.")
		elif Controls.reserved(k):
			_say("%s is kept for the menus and cannot be bound." % Controls.key_name(k))
		else:
			Controls.set_key(id, k)
			_say("%s is now %s." % [_action_name(id), Controls.key_name(k)])
		_end_capture()
	elif event is InputEventJoypadButton and event.pressed:
		get_viewport().set_input_as_handled()
		var b: int = (event as InputEventJoypadButton).button_index
		# Any button binds, the one on × included; Escape is the way out.
		if not pad:
			_say("Left as it was.")
		else:
			Controls.set_pad(id, b)
			_say("%s is now %s." % [_action_name(id), Controls.pad_name(b)])
		_end_capture()


func _end_capture() -> void:
	var btn: Button = _capture.get("btn") as Button
	_capture = {}
	_paint_mapping()
	if btn != null:
		btn.grab_focus()


func _action_name(id: String) -> String:
	for a: Array in Controls.ACTIONS:
		if a[0] == id:
			return a[1] as String
	return id

