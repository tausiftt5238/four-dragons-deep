# CombatResultUI
# Victory screen shown after winning a combat encounter.
# Set fields before adding to the tree, then listen for dismissed.
class_name CombatResultUI extends Control

signal dismissed

var exp_gained:  int = 0
var gold_gained: int = 0
var item_drop:   Dictionary = {}
# One entry per demon that gained a level in that fight, already formatted.
var demons_leveled: Array[String] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()


func _build_ui() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.78)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Everything tappable lives in the lower pane, under where the map sits.
	var lower: Control = Control.new()
	lower.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lower.offset_top = Main.MAP_PANE_H
	lower.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lower)

	var panel: Panel = Panel.new()
	panel.anchor_left   = 0.5
	panel.anchor_right  = 0.5
	panel.anchor_top    = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left   = -210
	panel.offset_right  = 210
	panel.offset_top    = -170
	panel.offset_bottom = 170
	lower.add_child(panel)

	var m: MarginContainer = MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for s: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		m.add_theme_constant_override(s, 22)
	panel.add_child(m)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	m.add_child(vbox)

	var title: Label = Label.new()
	title.text = "Victory!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.28))
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	_add_row(vbox, "EXP",   "+%d"    % exp_gained,  Color(0.55, 0.90, 0.55))
	_add_row(vbox, "Gold",  "+%d gp" % gold_gained, Color(0.95, 0.82, 0.25))

	if not item_drop.is_empty():
		_add_row(vbox, "Found", item_drop["name"], Color(0.50, 0.85, 1.00))
	else:
		_add_row(vbox, "Found", "Nothing", Color(0.38, 0.38, 0.38))

	# One row however many climbed, so the panel never has to grow.
	# One demon per line. Joined with commas this was a single run-on row —
	# "Bat Lv 5 STR+4 AGL+2 learns Blaze, Skeleton Lv 7 DEF+3" — where the commas
	# inside a demon's own gains and the commas between demons looked the same.
	# Only the first line carries the label; the rest sit under it.
	for i: int in demons_leveled.size():
		_add_row(vbox, "Grew" if i == 0 else "", demons_leveled[i],
				Color(0.80, 0.62, 1.00))

	vbox.add_child(HSeparator.new())

	var btn: Button = Button.new()
	btn.text = "Continue"
	btn.custom_minimum_size    = Vector2(130, 36)
	btn.size_flags_horizontal  = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(func(): dismissed.emit())
	vbox.add_child(btn)


func _add_row(parent: Control, label: String, value: String, color: Color) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)

	var lbl: Label = Label.new()
	# An empty label still holds the column open, so a continuation line indents
	# to exactly where the first one's value started.
	lbl.text = label + ":" if label != "" else ""
	lbl.custom_minimum_size = Vector2(56, 0)
	lbl.add_theme_color_override("font_color", Color(0.68, 0.68, 0.68))
	row.add_child(lbl)

	var val: Label = Label.new()
	val.text = value
	val.add_theme_color_override("font_color", color)
	row.add_child(val)
