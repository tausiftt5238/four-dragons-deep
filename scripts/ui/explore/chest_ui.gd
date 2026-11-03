# ChestUI
# What a cache in the wall offers. Two choices and no arithmetic: a cache is
# not a shop, it is a thing you found, and the only real decision is whether
# to put your hand in it. Once opened, the same panel says what was inside —
# a two-second line at the top of the screen was too easy to miss, and an item
# that went into the pack unseen might as well not have been there.
class_name ChestUI extends Control

signal closed
signal opened

var _col: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.04, 0.88)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	# Centred in the lower pane, under where the map sits.
	var centre: CenterContainer = CenterContainer.new()
	Layout.lower_pane(centre)
	add_child(centre)

	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(440, 0)
	centre.add_child(panel)
	Layout.dress(panel)

	var m: MarginContainer = MarginContainer.new()
	for side: String in ["margin_left", "margin_right"]:
		m.add_theme_constant_override(side, 22)
	for side2: String in ["margin_top", "margin_bottom"]:
		m.add_theme_constant_override(side2, 20)
	panel.add_child(m)

	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	m.add_child(col)
	_col = col

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


# The panel turned over to what was found: the gold, then each item with the
# same one-line summary the menus use, and a single button to carry on.
func show_found(gold: int, items: Array) -> void:
	for c: Node in _col.get_children():
		_col.remove_child(c)
		c.queue_free()

	var title: Label = Label.new()
	title.text = "You found"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.40))
	_col.add_child(title)

	var coin: Label = Label.new()
	coin.text = "%d gold" % gold
	coin.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coin.add_theme_font_size_override("font_size", 18)
	coin.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	_col.add_child(coin)

	for it: Variant in items:
		var item: Dictionary = it as Dictionary
		_col.add_child(HSeparator.new())
		var name_lbl: Label = Label.new()
		name_lbl.text = item.get("name", "?") as String
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 18)
		name_lbl.add_theme_color_override("font_color", Color(0.62, 0.92, 0.74))
		_col.add_child(name_lbl)
		var info: RichTextLabel = RichTextLabel.new()
		info.bbcode_enabled = true
		info.fit_content = true
		info.scroll_active = false
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.text = "[center]%s[/center]" % ItemInfo.item(item)
		info.add_theme_color_override("default_color", Color(0.70, 0.72, 0.80))
		_col.add_child(info)

	if items.is_empty():
		var none: Label = Label.new()
		none.text = "Nothing else."
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		none.add_theme_font_size_override("font_size", 13)
		none.add_theme_color_override("font_color", Color(0.55, 0.57, 0.63))
		_col.add_child(none)

	_col.add_child(HSeparator.new())
	var done: Button = Button.new()
	done.text = "Close"
	done.custom_minimum_size = Vector2(0, 38)
	done.pressed.connect(func() -> void: closed.emit())
	_col.add_child(done)
	# The buttons it was opened with are gone; the keyboard gets this one.
	Layout.focus_first.call_deferred(self)
