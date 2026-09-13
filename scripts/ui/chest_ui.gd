# ChestUI
# What a cache in the wall offers. Two choices and no arithmetic: a cache is
# not a shop, it is a thing you found, and the only real decision is whether
# to put your hand in it.
class_name ChestUI extends Control

signal closed
signal opened

var contents: Dictionary = {}   # the item inside, or empty for gold only
var gold: int = 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.04, 0.88)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var centre: CenterContainer = CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centre)

	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(440, 0)
	centre.add_child(panel)

	var m: MarginContainer = MarginContainer.new()
	for side: String in ["margin_left", "margin_right"]:
		m.add_theme_constant_override(side, 22)
	for side2: String in ["margin_top", "margin_bottom"]:
		m.add_theme_constant_override(side2, 20)
	panel.add_child(m)

	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	m.add_child(col)

	var title: Label = Label.new()
	title.text = "A cache in the wall"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.40))
	col.add_child(title)

	var note: Label = Label.new()
	note.text = "Something was left here. It has not been opened."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 13)
	note.add_theme_color_override("font_color", Color(0.62, 0.64, 0.70))
	col.add_child(note)

	col.add_child(HSeparator.new())

	var take: Button = Button.new()
	take.text = "Open it"
	take.custom_minimum_size = Vector2(0, 38)
	take.pressed.connect(func() -> void: opened.emit())
	col.add_child(take)

	var leave: Button = Button.new()
	leave.text = "Leave it"
	leave.custom_minimum_size = Vector2(0, 34)
	leave.pressed.connect(func() -> void: closed.emit())
	col.add_child(leave)
