# SaveSlotUI
# Three slots, for both writing a run down and picking one back up.
#
# It used to be a fixed 580-wide panel floated in the middle of the screen,
# which was 40 pixels wider than the whole phone: both Save buttons hung off
# the edges and the ISO timestamp ran off with them. Nothing here is given a
# width any more — the column fills what the screen has and the rows take the
# same shape every other list in the game uses.
class_name SaveSlotUI extends Control

signal slot_chosen(slot: int)
signal cancelled

const SLOT_COUNT: int = 3

var mode: String = "save"  # "save" or "load"


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()


func _build() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.05, 0.92)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var outer: MarginContainer = MarginContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		outer.add_theme_constant_override(side, 16)
	add_child(outer)

	# Centred vertically, but full width: a VBox hands its children the whole
	# line, which a CenterContainer would not.
	var centre: VBoxContainer = VBoxContainer.new()
	centre.alignment = BoxContainer.ALIGNMENT_CENTER
	outer.add_child(centre)

	var panel: PanelContainer = PanelContainer.new()
	centre.add_child(panel)

	var pad: MarginContainer = MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		pad.add_theme_constant_override(side, 18)
	panel.add_child(pad)

	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	pad.add_child(col)

	var title: Label = Label.new()
	title.text = "Save game" if mode == "save" else "Load game"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.95, 0.88, 0.60))
	title.add_theme_font_size_override("font_size", 20)
	col.add_child(title)

	col.add_child(HSeparator.new())

	for i: int in range(1, SLOT_COUNT + 1):
		col.add_child(_make_slot_row(i))

	col.add_child(HSeparator.new())

	var cancel_btn: Button = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size   = Vector2(0, 30)
	cancel_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel_btn.pressed.connect(func() -> void: cancelled.emit())
	col.add_child(cancel_btn)


func _make_slot_row(slot: int) -> VBoxContainer:
	var info: Dictionary = SaveSystem.slot_info(slot)
	var has_save: bool   = not info.is_empty()

	var row: VBoxContainer = VBoxContainer.new()
	row.add_theme_constant_override("separation", 0)

	var head: HBoxContainer = HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	row.add_child(head)

	var slot_lbl: Label = Label.new()
	slot_lbl.text = "Slot %d" % slot
	slot_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot_lbl.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
	slot_lbl.clip_text = true
	head.add_child(slot_lbl)

	var btn: Button = Button.new()
	btn.text = "Save" if mode == "save" else "Load"
	btn.clip_text = true
	btn.custom_minimum_size = Vector2(150, 24)
	btn.disabled = mode == "load" and not has_save
	if not btn.disabled:
		btn.pressed.connect(func() -> void: slot_chosen.emit(slot))
	head.add_child(btn)

	var detail: Label = Label.new()
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_theme_font_size_override("font_size", 11)
	if has_save:
		detail.text = "Floor %d   LV %d   %s" % [
				info["floor"], info["lv"], _when(info["timestamp"] as String)]
		detail.add_theme_color_override("font_color", Color(0.60, 0.62, 0.70))
	else:
		detail.text = "Empty"
		detail.add_theme_color_override("font_color", Color(0.45, 0.45, 0.50))
	row.add_child(detail)

	return row


# Saves are stamped in ISO, which is a lot of characters for a line that also
# has to carry the floor and the level. Seconds are not worth any of them.
func _when(stamp: String) -> String:
	if stamp.length() < 16:
		return stamp
	return "%s  %s" % [stamp.substr(0, 10), stamp.substr(11, 5)]
