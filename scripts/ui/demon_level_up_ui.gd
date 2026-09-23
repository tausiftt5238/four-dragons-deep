# DemonLevelUpUI
# One bound demon's level-up, shown on its own after the result screen. A demon
# places its own points, so there is nothing to choose here — it says what grew
# and what it picked up, and waits for a tap.
class_name DemonLevelUpUI extends Control

signal dismissed

var demon_name: String = ""
var before:     Dictionary     # {lv, max_hp, max_mp, str, def, mag, agl}
var after:      Dictionary
var learned:    Array = []     # names of skills gained or raised this fight

const STATS: Array[Array] = [
	["HP", "max_hp"], ["MP", "max_mp"],
	["STR", "str"], ["DEF", "def"], ["MAG", "mag"], ["AGL", "agl"],
]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()


func _build() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.04, 0.03, 0.06, 0.88)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Everything tappable lives in the lower pane, under where the map sits.
	var lower: Control = Control.new()
	lower.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lower.offset_top = Main.MAP_PANE_H
	lower.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lower)

	var panel: Panel = Panel.new()
	panel.anchor_left   = 0.5;  panel.anchor_right  = 0.5
	panel.anchor_top    = 0.5;  panel.anchor_bottom = 0.5
	panel.offset_left   = -210; panel.offset_right  = 210
	panel.offset_top    = -220; panel.offset_bottom = 220
	lower.add_child(panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for s: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(s, 20)
	panel.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var header: Label = Label.new()
	header.text = demon_name
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_color_override("font_color", Color(0.80, 0.62, 1.00))
	header.add_theme_font_size_override("font_size", 24)
	vbox.add_child(header)

	var lv_lbl: Label = Label.new()
	lv_lbl.text = "LEVEL  %d  ->  %d" % [int(before.get("lv", 1)), int(after.get("lv", 1))]
	lv_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lv_lbl.add_theme_color_override("font_color", Color(0.90, 0.82, 0.50))
	vbox.add_child(lv_lbl)

	vbox.add_child(HSeparator.new())

	var grid: GridContainer = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 6)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(grid)
	for row: Array in STATS:
		var key: String = row[1] as String
		var was: int = int(before.get(key, 0))
		var now: int = int(after.get(key, 0))
		_cell(grid, row[0] as String, Color(0.68, 0.68, 0.68))
		_cell(grid, "%d  ->  %d" % [was, now], Color(0.90, 0.90, 0.90))
		_cell(grid, "+%d" % (now - was) if now > was else "",
				Color(0.55, 0.90, 0.55))

	if not learned.is_empty():
		vbox.add_child(HSeparator.new())
		for skill: Variant in learned:
			var lbl: Label = Label.new()
			lbl.text = "Learns  %s" % str(skill)
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			lbl.add_theme_color_override("font_color", Color(0.50, 0.85, 1.00))
			vbox.add_child(lbl)

	vbox.add_child(HSeparator.new())

	var btn: Button = Button.new()
	btn.text = "Continue"
	btn.custom_minimum_size   = Vector2(130, 36)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(func(): dismissed.emit())
	vbox.add_child(btn)


func _cell(grid: GridContainer, text: String, color: Color) -> void:
	var lbl: Label = Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", color)
	grid.add_child(lbl)
