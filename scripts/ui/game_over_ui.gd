# GameOverUI
# Shown when the player's HP reaches zero. Blocks all input until the player
# chooses to try again. Emits try_again when the button is pressed.
class_name GameOverUI extends Control

signal load_game
signal main_menu


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()


func _build() -> void:
	# Full-screen very dark red veil
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.06, 0.01, 0.01, 0.96)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Centred in the lower pane, under where the map sits — no panel border,
	# just floating text.
	var lower: Control = Control.new()
	lower.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lower.offset_top = Main.MAP_PANE_H
	lower.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lower)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.anchor_left   = 0.5
	vbox.anchor_right  = 0.5
	vbox.anchor_top    = 0.5
	vbox.anchor_bottom = 0.5
	vbox.offset_left   = -200
	vbox.offset_right  = 200
	vbox.offset_top    = -140
	vbox.offset_bottom = 140
	vbox.add_theme_constant_override("separation", 18)
	lower.add_child(vbox)

	var title: Label = Label.new()
	title.text = "GAME  OVER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.85, 0.10, 0.10))
	title.add_theme_font_size_override("font_size", 36)
	vbox.add_child(title)

	var sub: Label = Label.new()
	sub.text = "You fall into darkness..."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", Color(0.60, 0.45, 0.45))
	vbox.add_child(sub)

	#vbox.add_child(HSeparator.new())
#
	#var note: Label = Label.new()
	#note.text = "You wake at the entrance, wounds tended\nby some unseen hand."
	#note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	#note.add_theme_color_override("font_color", Color(0.55, 0.50, 0.50))
	#note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	#vbox.add_child(note)

	var btn_row: HBoxContainer = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	var any_save: bool = false
	for i: int in range(1, 4):
		if not SaveSystem.slot_info(i).is_empty():
			any_save = true
			break

	var load_btn: Button = Button.new()
	load_btn.text = "Load Game"
	load_btn.custom_minimum_size = Vector2(160, 38)
	load_btn.disabled = not any_save
	load_btn.pressed.connect(func(): load_game.emit())
	btn_row.add_child(load_btn)

	var main_menu_btn: Button = Button.new()
	main_menu_btn.text = "Main Menu"
	main_menu_btn.custom_minimum_size = Vector2(160, 38)
	main_menu_btn.pressed.connect(func(): main_menu.emit())
	btn_row.add_child(main_menu_btn)
