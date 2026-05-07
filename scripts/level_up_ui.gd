# LevelUpUI
# Shown after a battle win causes a level-up. Displays stat changes and blocks
# input until the player dismisses it. Set .before and .after (snapshots from
# main.gd) before adding to the scene tree.
class_name LevelUpUI extends Control

signal dismissed

# Stat snapshots: {lv, str, def, mag, agl, max_hp, max_mp}
var before: Dictionary
var after:  Dictionary


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()


func _build() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.04, 0.03, 0.06, 0.88)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Central panel  360 × 440
	var panel: Panel = Panel.new()
	panel.anchor_left   = 0.5
	panel.anchor_right  = 0.5
	panel.anchor_top    = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left   = -180
	panel.offset_right  = 180
	panel.offset_top    = -220
	panel.offset_bottom = 220
	add_child(panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left",   20)
	margin.add_theme_constant_override("margin_right",  20)
	margin.add_theme_constant_override("margin_top",    16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	# Header
	var header: Label = Label.new()
	header.text = "✦   LEVEL UP!   ✦"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_color_override("font_color", Color(1.0, 0.88, 0.18))
	header.add_theme_font_size_override("font_size", 24)
	vbox.add_child(header)

	var lv_lbl: Label = Label.new()
	lv_lbl.text = "LEVEL  %d  →  %d" % [before["lv"], after["lv"]]
	lv_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lv_lbl.add_theme_color_override("font_color", Color(0.90, 0.82, 0.50))
	vbox.add_child(lv_lbl)

	vbox.add_child(HSeparator.new())

	# Stat change grid: Name | Before | After
	var grid: GridContainer = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 6)
	vbox.add_child(grid)

	_stat_row(grid, "STR",    before["str"],    after["str"])
	_stat_row(grid, "DEF",    before["def"],    after["def"])
	_stat_row(grid, "MAG",    before["mag"],    after["mag"])
	_stat_row(grid, "AGL",    before["agl"],    after["agl"])
	_stat_row(grid, "Max HP", before["max_hp"], after["max_hp"])
	_stat_row(grid, "Max MP", before["max_mp"], after["max_mp"])

	vbox.add_child(HSeparator.new())

	var btn: Button = Button.new()
	btn.text = "Continue"
	btn.custom_minimum_size = Vector2(120, 36)
	btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	var btn_row: HBoxContainer = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_child(btn)
	vbox.add_child(btn_row)

	btn.pressed.connect(func(): dismissed.emit())


func _stat_row(grid: GridContainer, stat: String, b: int, a: int) -> void:
	var n: Label = Label.new()
	n.text = stat
	n.custom_minimum_size = Vector2(60, 0)
	grid.add_child(n)

	var bv: Label = Label.new()
	bv.text = str(b)
	bv.add_theme_color_override("font_color", Color(0.60, 0.60, 0.60))
	bv.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bv.custom_minimum_size = Vector2(40, 0)
	grid.add_child(bv)

	var diff: int = a - b
	var av: Label = Label.new()
	av.text = "→ %d   (+%d)" % [a, diff] if diff > 0 else "→ %d" % a
	av.add_theme_color_override("font_color",
		Color(0.35, 0.95, 0.45) if diff > 0 else Color(0.80, 0.80, 0.80))
	grid.add_child(av)
