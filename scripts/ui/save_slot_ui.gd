class_name SaveSlotUI extends Control

signal slot_chosen(slot: int)
signal cancelled

var mode: String = "save"  # "save" or "load"


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()


func _build() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.72)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var panel: Panel = Panel.new()
	panel.anchor_left   = 0.5
	panel.anchor_right  = 0.5
	panel.anchor_top    = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left   = -290
	panel.offset_right  = 290
	panel.offset_top    = -210
	panel.offset_bottom = 210
	add_child(panel)

	var m: MarginContainer = MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		m.add_theme_constant_override(side, 22)
	panel.add_child(m)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	m.add_child(vbox)

	var title: Label = Label.new()
	title.text = "SAVE GAME" if mode == "save" else "LOAD GAME"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.95, 0.88, 0.60))
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	for i: int in range(1, 4):
		vbox.add_child(_make_slot_row(i))

	vbox.add_child(HSeparator.new())

	var cancel_row: HBoxContainer = HBoxContainer.new()
	cancel_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(cancel_row)

	var cancel_btn: Button = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(100, 34)
	cancel_btn.pressed.connect(func(): cancelled.emit())
	cancel_row.add_child(cancel_btn)


func _make_slot_row(slot: int) -> HBoxContainer:
	var info: Dictionary = SaveSystem.slot_info(slot)
	var has_save: bool   = not info.is_empty()

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)

	var slot_lbl: Label = Label.new()
	slot_lbl.text = "Slot %d" % slot
	slot_lbl.custom_minimum_size = Vector2(55, 0)
	slot_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slot_lbl)

	var info_lbl: Label = Label.new()
	info_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_lbl.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
	if has_save:
		info_lbl.text = "Floor %d  |  LV %d  |  %s" % [info["floor"], info["lv"], info["timestamp"]]
	else:
		info_lbl.text = "— Empty —"
		info_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	row.add_child(info_lbl)

	var btn: Button = Button.new()
	btn.text = "Save" if mode == "save" else "Load"
	btn.custom_minimum_size = Vector2(72, 30)
	if mode == "load" and not has_save:
		btn.disabled = true
	btn.pressed.connect(func(): slot_chosen.emit(slot))
	row.add_child(btn)

	return row
