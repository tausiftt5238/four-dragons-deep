# OptionsUI
# The Options page, shared by the title screen and the in-game System page.
# Covers whatever opened it and emits `closed` when the player backs out;
# every change is saved the moment it is made, so there is nothing to confirm.
class_name OptionsUI extends Control

signal closed

const _FONT := preload("res://resources/misc/OldSchoolAdventures-42j9.ttf") as FontFile


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()


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
	col.add_theme_constant_override("separation", 14)
	margin.add_child(col)

	col.add_child(_label("Options", 30, Color(0.90, 0.75, 0.30)))
	col.add_child(HSeparator.new())
	col.add_child(_label("Controls", 18, Color(0.55, 0.50, 0.62)))

	_add_toggle(col, "Invert turn",
			"Swipe left to turn right, and right to turn left.",
			Settings.invert_turn(), Settings.set_invert_turn)
	_add_toggle(col, "Invert movement",
			"Swipe down to step forward, and up to step back.",
			Settings.invert_move(), Settings.set_invert_move)

	col.add_child(_label("These change swipes only. Arrow keys and WASD stay as they are.",
			15, Color(0.50, 0.47, 0.56), true))

	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)

	var back: Button = Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(0, 52)
	back.add_theme_font_override("font", _FONT)
	back.add_theme_font_size_override("font_size", 20)
	back.pressed.connect(func() -> void: closed.emit())
	col.add_child(back)


# One row: the name and its current state on a wide button, what it does
# underneath. A tap flips it and says the new state on the button itself.
func _add_toggle(parent: Control, title: String, desc: String, on: bool,
		apply: Callable) -> void:
	var btn: Button = Button.new()
	btn.toggle_mode = true
	btn.button_pressed = on
	btn.custom_minimum_size = Vector2(0, 56)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.add_theme_font_override("font", _FONT)
	btn.add_theme_font_size_override("font_size", 22)
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
	parent.add_child(_label(desc, 17, Color(0.70, 0.68, 0.76), true))


func _label(text: String, size: int, color: Color, wrap: bool = false) -> Label:
	var lbl: Label = Label.new()
	lbl.text = text
	lbl.add_theme_font_override("font", _FONT)
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	if wrap:
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return lbl
