class_name DungeonEventUI extends Control

signal dismissed

var title:       String            = ""
var description: String            = ""
var choices:     Array[Dictionary] = []  # {label: String, callback: Callable}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()


func _build() -> void:
	var overlay: ColorRect = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.62)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var panel: Panel = Panel.new()
	panel.anchor_left   = 0.5; panel.anchor_right  = 0.5
	panel.anchor_top    = 0.5; panel.anchor_bottom = 0.5
	panel.offset_left   = -230; panel.offset_right  = 230
	panel.offset_top    = -170; panel.offset_bottom = 170
	add_child(panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for s: String in ["margin_left","margin_right","margin_top","margin_bottom"]:
		margin.add_theme_constant_override(s, 20)
	panel.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	var title_lbl: Label = Label.new()
	title_lbl.text = title
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.40))
	title_lbl.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title_lbl)

	vbox.add_child(HSeparator.new())

	var desc_lbl: Label = Label.new()
	desc_lbl.text = description
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_color_override("font_color", Color(0.86, 0.86, 0.86))
	vbox.add_child(desc_lbl)

	vbox.add_child(HSeparator.new())

	if choices.is_empty():
		var ok_btn: Button = Button.new()
		ok_btn.text = "Continue"
		ok_btn.custom_minimum_size = Vector2(160, 34)
		ok_btn.pressed.connect(func(): dismissed.emit())
		var row: HBoxContainer = HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_child(ok_btn)
		vbox.add_child(row)
	else:
		var btn_row: HBoxContainer = HBoxContainer.new()
		btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
		btn_row.add_theme_constant_override("separation", 12)
		vbox.add_child(btn_row)
		for choice: Dictionary in choices:
			var btn: Button = Button.new()
			btn.text = choice["label"] as String
			btn.custom_minimum_size = Vector2(140, 34)
			var cb: Callable = choice["callback"] as Callable
			btn.pressed.connect(func():
				cb.call()
				dismissed.emit()
			)
			btn_row.add_child(btn)
