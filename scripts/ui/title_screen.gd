# TitleScreen
# Shown at game launch. Transitions to the main game scene on button press.
class_name TitleScreen extends Control

const _FONT := preload("res://resources/misc/OldSchoolAdventures-42j9.ttf") as FontFile


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()


func _build() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.04, 0.03, 0.07, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox: VBoxContainer = VBoxContainer.new()
	# The screen is 540 wide; leave a margin either side rather than filling it.
	vbox.custom_minimum_size = Vector2(460, 0)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 18)
	center.add_child(vbox)

	# One word per line. Fifteen characters at this size is far wider than a
	# phone held upright, and shrinking the type to fit would waste the only
	# place in the game with room for a big word.
	var title: Label = _make_lbl("DUNGEON\nCRAWLER", 54, Color(0.90, 0.75, 0.30))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var subtitle: Label = _make_lbl("descend. survive. conquer.", 15, Color(0.50, 0.45, 0.55))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(subtitle)

	vbox.add_child(HSeparator.new())

	var new_btn: Button = _make_btn("NEW GAME", Vector2(220, 46))
	new_btn.pressed.connect(_on_new_game)
	vbox.add_child(new_btn)

	var any_save: bool = false
	for i: int in range(1, 4):
		if not SaveSystem.slot_info(i).is_empty():
			any_save = true
			break

	var load_btn: Button = _make_btn("LOAD GAME", Vector2(220, 46))
	load_btn.disabled = not any_save
	load_btn.pressed.connect(_on_load_game)
	vbox.add_child(load_btn)

	var test_btn: Button = _make_btn("COMBAT TEST", Vector2(220, 40))
	test_btn.add_theme_color_override("font_color", Color(0.55, 0.75, 1.0))
	test_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/combat_test.tscn"))
	vbox.add_child(test_btn)

	vbox.add_child(HSeparator.new())

	# The keyboard hints were desktop-only and are a lie on a phone, which is
	# what this is now. Swipe is the real control.
	var hint: Label = _make_lbl(
			"swipe to move and turn  ·  tap MENU for party, gear and magic",
			12, Color(0.35, 0.32, 0.40))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(hint)


func _on_new_game() -> void:
	GameBoot.pending_slot = 0
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_load_game() -> void:
	var picker: SaveSlotUI = SaveSlotUI.new()
	picker.mode = "load"
	picker.slot_chosen.connect(func(slot: int) -> void:
		GameBoot.pending_slot = slot
		get_tree().change_scene_to_file("res://scenes/main.tscn")
	)
	picker.cancelled.connect(func() -> void:
		picker.queue_free()
	)
	add_child(picker)


func _make_lbl(text: String, size: int, color: Color) -> Label:
	var lbl: Label = Label.new()
	lbl.text = text
	lbl.add_theme_font_override("font", _FONT)
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	return lbl


func _make_btn(text: String, min_size: Vector2) -> Button:
	var btn: Button = Button.new()
	btn.text = text
	btn.custom_minimum_size = min_size
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.add_theme_font_override("font", _FONT)
	return btn
