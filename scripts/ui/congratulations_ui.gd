class_name CongratulationsUI extends Control

signal dismissed


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()


func _build() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.03, 0.04, 0.08, 0.96)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Everything tappable lives in the lower pane, under where the map sits.
	var lower: Control = Control.new()
	lower.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lower.offset_top = Main.MAP_PANE_H
	lower.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lower)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.anchor_left   = 0.5; vbox.anchor_right  = 0.5
	vbox.anchor_top    = 0.5; vbox.anchor_bottom = 0.5
	vbox.offset_left   = -240; vbox.offset_right  = 240
	vbox.offset_top    = -180; vbox.offset_bottom = 180
	vbox.add_theme_constant_override("separation", 16)
	lower.add_child(vbox)

	var title: Label = Label.new()
	title.text = "✦   victory!   ✦"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.18))
	title.add_theme_font_size_override("font_size", 34)
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	var boss: Label = Label.new()
	boss.text = "The Void Drake has fallen."
	boss.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss.add_theme_color_override("font_color", Color(0.90, 0.70, 0.40))
	boss.add_theme_font_size_override("font_size", 16)
	vbox.add_child(boss)

	var body: Label = Label.new()
	body.text = "The dungeon shudders as its master is slain.\nLight floods the deepest corridors\nfor the first time in an age.\n\nYour legend is complete."
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_color_override("font_color", Color(0.78, 0.78, 0.78))
	vbox.add_child(body)

	vbox.add_child(HSeparator.new())

	var note: Label = Label.new()
	note.text = "The dungeon continues to call to you..."
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_color_override("font_color", Color(0.50, 0.50, 0.55))
	note.add_theme_font_size_override("font_size", 12)
	vbox.add_child(note)

	var btn_row: HBoxContainer = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	var cont_btn: Button = Button.new()
	cont_btn.text = "Continue"
	cont_btn.custom_minimum_size = Vector2(160, 38)
	cont_btn.pressed.connect(func(): dismissed.emit())
	btn_row.add_child(cont_btn)
