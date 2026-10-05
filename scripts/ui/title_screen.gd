# TitleScreen
# Shown at game launch. Transitions to the main game scene on button press.
class_name TitleScreen extends Control

const _FONT := preload("res://resources/misc/OldSchoolAdventures-42j9.ttf") as FontFile


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Music.play(Music.TITLE)
	Sfx.init()
	_build()


# Android's back: close whatever is open over the title, and from the bare
# title leave the app, the way a phone expects. The intro plays out; skipping
# it is its own button.
func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_GO_BACK_REQUEST:
		return
	for i: int in range(get_child_count() - 1, -1, -1):
		var c: Node = get_child(i)
		if c.name == "AbyssMenu" or c.name == "RecordsPanel":
			c.queue_free()
			return
		if c is SaveSlotUI:
			(c as SaveSlotUI).cancelled.emit()
			return
		if c is OptionsUI:
			(c as OptionsUI).closed.emit()
			return
		if c is TutorialUI:
			(c as TutorialUI).closed.emit()
			return
		if c is IntroUI:
			return
	get_tree().quit()


func _build() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.04, 0.03, 0.07, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# The name in the upper pane, where the map sits in play, and every button
	# in the lower one, where the thumb already is.
	var upper: CenterContainer = CenterContainer.new()
	upper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	upper.anchor_bottom = 0.0
	upper.offset_bottom = Main.MAP_PANE_H
	add_child(upper)

	var head: VBoxContainer = VBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override("separation", 18)
	upper.add_child(head)

	# One word per line. The whole name on one line at this size is far wider
	# than a phone held upright, and shrinking the type to fit would waste the
	# only place in the game with room for a big word. DRAGONS is the widest at
	# seven characters, which is what sets the size.
	var title: Label = _make_lbl("FOUR\nDRAGONS\nDEEP", 54, Color(0.90, 0.75, 0.30))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(title)

	head.add_child(TitleVignette.new())

	var lower: CenterContainer = CenterContainer.new()
	lower.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lower.offset_top = Main.MAP_PANE_H
	add_child(lower)

	var vbox: VBoxContainer = VBoxContainer.new()
	# The screen is 540 wide; leave a margin either side rather than filling it.
	vbox.custom_minimum_size = Vector2(460, 0)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 18)
	lower.add_child(vbox)

	var new_btn: Button = _make_btn("NEW GAME", Vector2(220, 46))
	new_btn.pressed.connect(_on_new_game)
	vbox.add_child(new_btn)

	var any_save: bool = SaveSystem.any_save()

	var load_btn: Button = _make_btn("LOAD GAME", Vector2(220, 46))
	load_btn.disabled = not any_save
	load_btn.pressed.connect(_on_load_game)
	vbox.add_child(load_btn)

	# The endless mode, once the game has been beaten (Abyss).
	if Abyss.available():
		var abyss_btn: Button = _make_btn("ABYSS", Vector2(220, 46))
		abyss_btn.add_theme_color_override("font_color", Color(0.78, 0.60, 1.0))
		abyss_btn.pressed.connect(_on_abyss)
		vbox.add_child(abyss_btn)

	var tut_btn: Button = _make_btn("TUTORIAL", Vector2(220, 46))
	tut_btn.pressed.connect(_on_tutorial)
	vbox.add_child(tut_btn)

	var opt_btn: Button = _make_btn("OPTIONS", Vector2(220, 46))
	opt_btn.pressed.connect(_on_options)
	vbox.add_child(opt_btn)


# A new run opens on the captain's briefing; loading a save skips it.
func _on_new_game() -> void:
	GameBoot.pending_slot = 0
	GameBoot.pending_abyss = ""
	var fade: ScreenFade = ScreenFade.cover(get_tree())
	await fade.covered
	var intro: IntroUI = IntroUI.new()
	intro.finished.connect(_descend_into_game)
	add_child(intro)
	fade.reveal()


# Through black to the loading screen, which carries on into the game.
func _descend_into_game() -> void:
	var fade: ScreenFade = ScreenFade.cover(get_tree())
	await fade.covered
	LoadingScreen.change_scene(get_tree(), "res://scenes/main.tscn")
	fade.reveal()


# Continue the run there is, or start a new descent with the hero who beat
# the game. Starting anew ends the run in progress: there is only ever one.
func _on_abyss() -> void:
	var panel: Control = Control.new()
	panel.name = "AbyssMenu"
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	var veil: ColorRect = ColorRect.new()
	veil.color = Color(0.03, 0.01, 0.06, 0.94)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(veil)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(center)
	var col: VBoxContainer = VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 16)
	center.add_child(col)

	var head: Label = _make_lbl("THE ABYSS", 40, Color(0.78, 0.60, 1.0))
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(head)
	var note: Label = _make_lbl("No bottom. One life. Orbs do not save.\nDeepest so far: %s" % (
			"Abyss %d" % Abyss.best_depth() if Abyss.best_depth() > 0 else "none yet"),
			16, Color(0.75, 0.72, 0.85))
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(note)

	var run: Dictionary = SaveSystem.read(SaveSystem.ABYSS_SLOT)
	if not run.is_empty():
		var cont: Button = _make_btn("CONTINUE  (ABYSS %d)" % Abyss.depth_of(int(run.get("floor_num", 26))),
				Vector2(300, 46))
		cont.pressed.connect(func() -> void: _start_abyss("continue"))
		col.add_child(cont)
	if not Abyss.cleared_hero().is_empty():
		var fresh: Button = _make_btn("NEW DESCENT" if run.is_empty() else "NEW DESCENT (ENDS THIS RUN)",
				Vector2(300, 46))
		fresh.pressed.connect(func() -> void: _start_abyss("new"))
		col.add_child(fresh)
	var rec: Button = _make_btn("RECORDS", Vector2(300, 46))
	rec.pressed.connect(_show_records)
	col.add_child(rec)
	var back: Button = _make_btn("BACK", Vector2(300, 46))
	back.pressed.connect(func() -> void: panel.queue_free())
	col.add_child(back)


# Lifetime numbers for this device (Records), over the Abyss menu.
func _show_records() -> void:
	var panel: Control = Control.new()
	panel.name = "RecordsPanel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	var veil: ColorRect = ColorRect.new()
	veil.color = Color(0.03, 0.02, 0.06, 1.0)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(veil)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(center)
	var col: VBoxContainer = VBoxContainer.new()
	col.custom_minimum_size = Vector2(460, 0)
	col.add_theme_constant_override("separation", 14)
	center.add_child(col)
	var head: Label = _make_lbl("RECORDS", 40, Color(0.90, 0.75, 0.30))
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(head)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 10)
	col.add_child(grid)
	for row: Array in Records.rows():
		var k: Label = _make_lbl(row[0] as String, 17, Color(0.72, 0.70, 0.82))
		k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(k)
		var v: Label = _make_lbl(row[1] as String, 17, Color(0.95, 0.93, 1.0))
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(v)
	var back: Button = _make_btn("BACK", Vector2(300, 46))
	back.pressed.connect(func() -> void: panel.queue_free())
	col.add_child(back)


func _start_abyss(how: String) -> void:
	GameBoot.pending_slot = 0
	GameBoot.pending_abyss = how
	if how != "new":
		_descend_into_game()
		return
	# A new descent opens with the captain sending for the hero again.
	Abyss.wipe_run()
	var fade: ScreenFade = ScreenFade.cover(get_tree())
	await fade.covered
	var menu: Node = get_node_or_null("AbyssMenu")
	if menu:
		menu.queue_free()
	var intro: IntroUI = IntroUI.new()
	intro.lines = IntroUI.ABYSS_LINES
	intro.closing_text = "And so, the Abyss begins."
	intro.finished.connect(_descend_into_game)
	add_child(intro)
	fade.reveal()


func _on_tutorial() -> void:
	var tut: TutorialUI = TutorialUI.new()
	tut.closed.connect(func() -> void: tut.queue_free())
	add_child(tut)


func _on_options() -> void:
	var ui: OptionsUI = OptionsUI.new()
	ui.closed.connect(func() -> void: ui.queue_free())
	add_child(ui)


func _on_load_game() -> void:
	var picker: SaveSlotUI = SaveSlotUI.new()
	picker.mode = "load"
	picker.slot_chosen.connect(func(slot: int) -> void:
		GameBoot.pending_abyss = ""
		GameBoot.pending_slot = slot
		_descend_into_game()
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
