# CombatScenePortable
# The fight laid out for a phone held upright (Build.portable): the line-ups
# one above the other, the actions and their lists in the lower half where a
# thumb is. Everything that is not layout lives in CombatScene.
class_name CombatScenePortable extends CombatScene


func player_to_act() -> bool:
	if not _action_bar.visible:
		return false
	for b: Node in _action_bar.find_children("*", "Button", true, false):
		if (b as Button).visible and not (b as Button).disabled:
			return true
	return false


# ── UI construction ───────────────────────────────────────────────────────────

func _build_ui() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.04, 0.02, 0.08, 0.78)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root: VBoxContainer = VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	_build_log_strip(root)
	_build_battlefield(root)
	_build_menu_panel(root)
	# Added to the scene rather than the column so it floats over the corner.
	_build_icon_overlay()


func _build_log_strip(parent: Control) -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, LOG_LINES * LOG_LINE_H + LOG_PAD * 2)
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	parent.add_child(panel)

	var m: MarginContainer = MarginContainer.new()
	for s: String in ["margin_left", "margin_top", "margin_bottom"]:
		m.add_theme_constant_override(s, LOG_PAD)
	# Wide enough that a long log line never runs under the press-turn corner.
	m.add_theme_constant_override("margin_right", 196)
	panel.add_child(m)

	_log_label = RichTextLabel.new()
	_log_label.bbcode_enabled   = true
	_log_label.scroll_active    = true
	_log_label.scroll_following = true
	_log_label.mouse_filter     = Control.MOUSE_FILTER_STOP
	_log_label.add_theme_color_override("default_color", Color(0.88, 0.84, 0.74))
	_log_label.gui_input.connect(_on_log_input)
	m.add_child(_log_label)


func _step_forward(card: Control, is_enemy: bool) -> void:
	_step_back_immediate()
	_stepped_node = card
	var dir: float = STEP_DISTANCE if is_enemy else -STEP_DISTANCE
	var portrait: TextureRect = _card_portrait(card)
	if portrait != null:
		_play_anim(portrait, "walk")
	# Bound to the card, not the scene: a revive or a summon rebuilds the party
	# row mid-step, and a tween owned by the scene would then call back into a
	# portrait that no longer exists.
	var tween: Tween = card.create_tween()
	tween.tween_property(card, "position:x", dir, STEP_DURATION) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	if portrait is AnimatedPortrait:
		tween.tween_callback((portrait as AnimatedPortrait).play.bind("idle"))


func _step_back_immediate() -> void:
	if _stepped_node != null and is_instance_valid(_stepped_node):
		_stepped_node.position.x = 0.0
		var portrait: TextureRect = _card_portrait(_stepped_node)
		if portrait != null and portrait is AnimatedPortrait:
			(portrait as AnimatedPortrait).play("idle")
	_stepped_node = null


func _set_buttons(enabled: bool) -> void:
	for btn: Button in _buttons.values():
		btn.disabled = not enabled


func _build_battlefield(parent: Control) -> void:
	var field: HBoxContainer = HBoxContainer.new()
	field.size_flags_vertical      = Control.SIZE_EXPAND_FILL
	field.size_flags_stretch_ratio = 1.0
	field.add_theme_constant_override("separation", 0)
	parent.add_child(field)

	_enemy_side = VBoxContainer.new()
	_enemy_side.size_flags_horizontal    = Control.SIZE_EXPAND_FILL
	_enemy_side.size_flags_vertical      = Control.SIZE_EXPAND_FILL
	_enemy_side.size_flags_stretch_ratio = 2.0
	_enemy_side.alignment = BoxContainer.ALIGNMENT_CENTER
	_enemy_side.add_theme_constant_override("separation", CARD_SEP)
	field.add_child(_enemy_side)

	var spacer: Control = Control.new()
	spacer.size_flags_horizontal    = Control.SIZE_EXPAND_FILL
	spacer.size_flags_stretch_ratio = 1.0
	spacer.mouse_filter             = Control.MOUSE_FILTER_IGNORE
	field.add_child(spacer)

	_party_box = VBoxContainer.new()
	_party_box.size_flags_horizontal    = Control.SIZE_EXPAND_FILL
	_party_box.size_flags_vertical      = Control.SIZE_EXPAND_FILL
	_party_box.size_flags_stretch_ratio = 2.0
	_party_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_party_box.add_theme_constant_override("separation", CARD_SEP)
	field.add_child(_party_box)

	for f: Enemy in foes:
		_enemy_side.add_child(_build_foe_card(f))


func _build_foe_card(foe: Enemy) -> Control:
	var card: VBoxContainer = VBoxContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_theme_constant_override("separation", 1)

	var icon: AnimatedPortrait = AnimatedPortrait.new()
	if foe.sprite_id != "":
		icon.load_sprite_id(foe.sprite_id)
	elif foe.sprite_path != "":
		icon.load_static(load(foe.sprite_path) as Texture2D)
	else:
		icon.load_static(load("res://icon.svg") as Texture2D)
		icon.modulate = Color(0.95, 0.28, 0.28)
	icon.custom_minimum_size = Vector2(CARD_PORTRAIT, CARD_PORTRAIT)
	icon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	icon.set_zoom(3.0)
	# self_modulate, not modulate: the tint is the monster's colour, and the
	# ailment marks drawn over it should keep their own.
	icon.self_modulate = foe.tint
	if foe.abyss_element != "":
		icon.material = Abyss.palette_material(foe.abyss_element)
	icon.add_child(StatusOverlay.new(foe))
	card.add_child(icon)

	var marker: UIGlyph = UIGlyph.caret(true, Color(1.0, 0.92, 0.45))
	card.add_child(marker)

	var name_lbl: Label = FitLabel.new(9, 5)
	name_lbl.text = foe.display_name()
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(name_lbl)

	var bar: ProgressBar = _make_bar(foe.max_hp)
	bar.custom_minimum_size = Vector2(0, 5)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_child(bar)

	var hp_lbl: Label = FitLabel.new(8, 5)
	hp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_lbl.add_theme_color_override("font_color", Color(0.90, 0.60, 0.60))
	card.add_child(hp_lbl)

	var stages: StageArrows = StageArrows.new()
	stages.member = foe
	card.add_child(stages)

	var chart: AffinityChart = AffinityChart.new()
	chart.foe = foe
	chart.knows = func(element: String) -> bool:
		return player.knows_affinity(foe.lore_name(), element)
	# Fill, not shrink: the chart is drawn, so it has no width of its own to
	# shrink to, and centred it came out zero pixels wide.
	chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_child(chart)

	_watch_hp(foe)
	_foe_rows.append({foe = foe, portrait = icon, name_lbl = name_lbl,
			bar = bar, hp_lbl = hp_lbl, stages = stages, marker = marker,
			chart = chart, card = card})
	return card


# ── Press-turn corner ─────────────────────────────────────────────────────────

# Both sides' icons live in the top-right corner, out of the fight rather than
# wedged between the two line-ups.
func _build_icon_overlay() -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.anchor_left   = 1.0
	panel.anchor_right  = 1.0
	panel.anchor_top    = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_left   = -186.0
	panel.offset_right  = -10.0
	panel.offset_top    = 8.0
	panel.offset_bottom = 66.0
	panel.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	add_child(panel)

	var m: MarginContainer = MarginContainer.new()
	for side: String in ["margin_left", "margin_right"]:
		m.add_theme_constant_override(side, 10)
	for side2: String in ["margin_top", "margin_bottom"]:
		m.add_theme_constant_override(side2, 5)
	panel.add_child(m)

	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 1)
	m.add_child(col)

	_icon_pips = UIGlyph.pips(Color(0.55, 0.95, 1.0))
	col.add_child(_side_row("You", Color(0.55, 0.95, 1.0), _icon_pips))

	_foe_icon_pips = UIGlyph.pips(Color(1.0, 0.45, 0.45))
	col.add_child(_side_row("Foe", Color(1.0, 0.45, 0.45), _foe_icon_pips))


# "You" or "Foe" and that side's icons, side by side.
func _side_row(who: String, color: Color, pips: UIGlyph) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var lbl: Label = Label.new()
	lbl.text = who
	lbl.add_theme_color_override("font_color", color)
	row.add_child(lbl)
	row.add_child(pips)
	return row


func _refresh_icons() -> void:
	if _press == null or _foe_press == null:
		return
	_icon_pips.set_pips(_press.full if _press.has_turns() else 0,
			_press.blink if _press.has_turns() else 0)
	_foe_icon_pips.set_pips(_foe_press.full if _foe_press.has_turns() else 0,
			_foe_press.blink if _foe_press.has_turns() else 0)


# Rebuild the party side only. Foes are built once in _build_battlefield.
func _rebuild_party_slots() -> void:
	for child: Node in _party_box.get_children():
		child.queue_free()
	_party_slots.clear()
	for i: int in range(party.size()):
		_party_box.add_child(_build_party_slot(party[i]))
		_watch_hp(party[i])
	_fit_columns.call_deferred()


# Four cards down one side are taller than the space between the log strip and
# the menu, and a column that will not fit pushes the menu off the bottom of
# the screen — the second row of actions, Talk, Summon and Flee, with it. So a
# column that would overflow shrinks its own portraits until it fits; three or
# fewer a side never needed to and keep the full size.
func _fit_columns() -> void:
	if not is_inside_tree():
		return
	var avail: float = size.y - float(LOG_LINES * LOG_LINE_H + LOG_PAD * 2) \
			- float(MENU_STRIP_H)
	var foe_cards: Array = []
	for r: Dictionary in _foe_rows:
		foe_cards.append([r["card"], r["portrait"]])
	var party_cards: Array = []
	for slot: Dictionary in _party_slots:
		party_cards.append([slot["card"], slot["portrait"]])
	for column: Array in [foe_cards, party_cards]:
		_fit_column(column, avail)


func _fit_column(cards: Array, avail: float) -> void:
	if cards.is_empty():
		return
	# Measured at full size, so a column that has since lost a card grows back.
	for pair: Array in cards:
		(pair[1] as Control).custom_minimum_size = Vector2(CARD_PORTRAIT, CARD_PORTRAIT)
	var need: float = float(CARD_SEP * (cards.size() - 1))
	for pair: Array in cards:
		need += (pair[0] as Control).get_combined_minimum_size().y
	if need <= avail:
		return
	var cut: int = ceili((need - avail) / float(cards.size()))
	var side: int = maxi(CARD_PORTRAIT_MIN, CARD_PORTRAIT - cut)
	for pair: Array in cards:
		(pair[1] as Control).custom_minimum_size = Vector2(side, side)


func _build_party_slot(member: CharacterSheet) -> Control:
	var card: VBoxContainer = VBoxContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_theme_constant_override("separation", 1)

	var is_hero: bool = (member == player)

	var icon: AnimatedPortrait = AnimatedPortrait.new()
	icon.custom_minimum_size   = Vector2(CARD_PORTRAIT, CARD_PORTRAIT)
	icon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	icon.set_zoom(3.0)
	icon.flip_h = true
	if is_hero:
		icon.load_sprite_id(player.hero_sprite_id())
		_player_portrait = icon
	else:
		var demon: Enemy = member as Enemy
		if demon.abyss_element != "":
			icon.material = Abyss.palette_material(demon.abyss_element)
		if demon.sprite_id != "":
			icon.load_sprite_id(demon.sprite_id)
		elif demon.sprite_path != "":
			icon.load_static(load(demon.sprite_path) as Texture2D)
		else:
			icon.load_static(load("res://icon.svg") as Texture2D)
			icon.modulate = Color(0.55, 0.85, 0.65)
	icon.add_child(StatusOverlay.new(member))
	card.add_child(icon)

	var marker: UIGlyph = UIGlyph.caret(false, Color(1.0, 0.92, 0.45))
	card.add_child(marker)

	var name_lbl: Label = FitLabel.new(9, 5)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(name_lbl)

	var hp_bar: ProgressBar = _make_bar(member.max_hp)
	hp_bar.custom_minimum_size   = Vector2(0, 5)
	hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_child(hp_bar)

	var mp_bar: ProgressBar = _make_bar(maxi(1, member.max_mp))
	mp_bar.custom_minimum_size   = Vector2(0, 3)
	mp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mp_bar.add_theme_stylebox_override("fill", _bar_fill(Color(0.32, 0.46, 0.95)))
	card.add_child(mp_bar)

	var val_lbl: Label = FitLabel.new(8, 5)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val_lbl.add_theme_color_override("font_color", Color(0.62, 0.82, 0.68))
	card.add_child(val_lbl)

	var sts_lbl: RichTextLabel = FitRichText.new(8, 5, 1)
	sts_lbl.add_theme_color_override("default_color", Color(0.90, 0.78, 0.30))
	card.add_child(sts_lbl)

	var stages: StageArrows = StageArrows.new()
	stages.member = member
	card.add_child(stages)

	_party_slots.append({member = member, portrait = icon, name_lbl = name_lbl,
			hp_bar = hp_bar, mp_bar = mp_bar, val_lbl = val_lbl,
			sts_lbl = sts_lbl, stages = stages, marker = marker, card = card})
	return card


func _refresh_party_slots() -> void:
	var acting: CharacterSheet = _actor() if _press != null and _press.has_turns() else null
	for slot: Dictionary in _party_slots:
		var member: CharacterSheet = slot["member"] as CharacterSheet
		if member == null:
			continue
		var alive: bool    = member.is_alive()
		var is_hero: bool  = (member == player)
		var is_actor: bool = (member == acting) and alive

		(slot["marker"] as UIGlyph).visible = is_actor
		(slot["portrait"] as TextureRect).modulate.a = 1.0 if alive else 0.18
		if not alive and not slot.get("_death_played", false):
			_play_anim(slot["portrait"] as TextureRect, "death")
			slot["_death_played"] = true

		var name_lbl: Label = slot["name_lbl"] as Label
		name_lbl.text = _member_name(member)
		if is_hero:
			name_lbl.text += "  LV%d" % member.lv
		if not alive:
			name_lbl.add_theme_color_override("font_color", Color(0.40, 0.32, 0.32))
		elif is_actor:
			name_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.45))
		elif is_hero:
			name_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 1.0))
		else:
			name_lbl.add_theme_color_override("font_color", Color(0.62, 0.92, 0.74))

		var hp_bar: ProgressBar = slot["hp_bar"] as ProgressBar
		hp_bar.max_value = member.max_hp
		hp_bar.value     = member.hp
		_apply_hp_bar(hp_bar, member.hp, member.max_hp)
		hp_bar.visible = alive

		var val_lbl: Label = slot["val_lbl"] as Label
		if not alive:
			val_lbl.text = "Down"
			val_lbl.add_theme_color_override("font_color", Color(0.55, 0.38, 0.38))
		else:
			val_lbl.add_theme_color_override("font_color", hp_tint(member.hp, member.max_hp))
			var mp_bar: ProgressBar = slot["mp_bar"] as ProgressBar
			mp_bar.max_value = maxi(1, member.max_mp)
			mp_bar.value     = member.mp
			mp_bar.visible = alive
			val_lbl.text = "%d/%d   %d MP" % [member.hp, member.max_hp, member.mp]

		var ail: String = _format_statuses(member.active_statuses)
		(slot["sts_lbl"] as RichTextLabel).text = \
				"[color=#e6c74d]%s[/color]" % ail if ail != "" else ""
		var stages: StageArrows = slot["stages"] as StageArrows
		stages.visible = alive
		stages.queue_redraw()


# ── The menu strip ────────────────────────────────────────────────────────────

func _build_menu_panel(parent: Control) -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_SHRINK_END
	panel.custom_minimum_size = Vector2(0, MENU_STRIP_H)
	parent.add_child(panel)

	var m: MarginContainer = MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		m.add_theme_constant_override(side, 8)
	panel.add_child(m)

	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 5)
	m.add_child(col)

	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	header.custom_minimum_size = Vector2(0, MENU_HEADER_H)
	col.add_child(header)

	_right_back_btn = Button.new()
	_right_back_btn.text = "< Back"
	_right_back_btn.custom_minimum_size = Vector2(72, 26)
	_right_back_btn.pressed.connect(_on_back_pressed)
	_right_back_btn.hide()
	header.add_child(_right_back_btn)

	# No "X's turn" banner: whoever is acting already steps forward with the
	# caret over them, and a long name ("Skeleton Archer's turn") next to a long
	# title pushed the header, and the whole battle with it, off the right edge.
	# The title takes the rest of the row and trims itself instead of growing.
	_right_title = Label.new()
	_right_title.text = "\u2014"
	_right_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_right_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right_title.clip_text = true
	_right_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_right_title.add_theme_color_override("font_color", Color(0.50, 0.50, 0.55))
	header.add_child(_right_title)

	col.add_child(HSeparator.new())

	var body: MarginContainer = MarginContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)

	# Both rows live in the same cell, one visible at a time, and both divide
	# the width into the same MENU_SLOTS columns.
	_action_bar = _make_slot_row()
	body.add_child(_action_bar)

	for action: String in ["Skills", "Item", "Defend", "Talk", "Summon", "Flee"]:
		var btn: Button = Button.new()
		btn.icon                    = _action_icon(action)
		btn.text                    = action
		btn.icon_alignment          = HORIZONTAL_ALIGNMENT_CENTER
		btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		btn.add_theme_font_size_override("font_size", 11)
		btn.add_theme_constant_override("h_separation", 0)
		# Without this a Button's minimum width grows to fit its label, so
		# SUMMON would claim a wider column than TALK and the six slots would
		# stop being six equal slots.
		btn.clip_text             = true
		# No minimum of its own: Main's hook multiplies a Button's minimum
		# height by 1.5, so any figure set here comes out half again taller
		# than the submenu's slots and the bar grows when you back out of a
		# submenu. It fills the body instead, exactly as a slot does.
		btn.custom_minimum_size   = Vector2(0, 0)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.size_flags_vertical   = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_on_action.bind(action))
		_action_bar.add_child(btn)
		_buttons[action] = btn

	_sub_scroll = TouchScroll.new()
	_sub_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sub_scroll.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	_sub_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_sub_scroll.hide()
	body.add_child(_sub_scroll)
	_sub_bar = _make_slot_row()
	_sub_scroll.add_child(_sub_bar)

	for _i: int in range(MENU_SLOTS):
		_add_sub_slot()


# An empty slot still holds its ground, so a three-entry submenu is the same
# shape as a six-entry one. Slots past the sixth are made as a list needs them
# and dropped again on clear.
func _add_sub_slot() -> MarginContainer:
	var slot: MarginContainer = MarginContainer.new()
	slot.size_flags_horizontal   = Control.SIZE_EXPAND_FILL
	slot.size_flags_vertical     = Control.SIZE_EXPAND_FILL
	slot.size_flags_stretch_ratio = 1.0
	slot.custom_minimum_size = Vector2(0, MENU_SLOT_H)
	_sub_bar.add_child(slot)
	_sub_slots.append(slot)
	return slot


# Six thumb targets in one line on a 540-wide screen truncates every label to
# three letters, so the six slots sit two rows of three deep — wider per slot
# than a landscape strip managed, and still one grid the eye reads in one go.
func _make_slot_row() -> GridContainer:
	var row: GridContainer = GridContainer.new()
	row.columns = MENU_SLOTS / 2
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 6)
	return row


func _show_actions() -> void:
	_action_bar.show()
	_sub_scroll.hide()


func _hide_actions() -> void:
	_action_bar.hide()
	_sub_scroll.show()


func _show_main_actions() -> void:
	_show_actions()
	_right_back_btn.hide()
	_right_title.text = "\u2014"
	_right_title.add_theme_color_override("font_color", Color(0.50, 0.50, 0.55))
	_submenu_clear()


func _big_button(title: String, subtitle: String, disabled: bool,
		icon: String = "", tint: Color = Color.TRANSPARENT) -> Button:
	var btn: Button = Button.new()
	btn.custom_minimum_size = Vector2(0, 0)
	btn.disabled = disabled

	var box: VBoxContainer = VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.alignment    = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 1)
	# Child labels do not inherit a Button's disabled tint, so dim them by hand.
	box.modulate = Color(1, 1, 1, 0.38) if disabled else Color(1, 1, 1, 1)
	btn.add_child(box)

	var title_lbl: Label = Label.new()
	title_lbl.text                 = title
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.autowrap_mode        = TextServer.AUTOWRAP_WORD_SMART
	title_lbl.add_theme_font_size_override("font_size", 13)
	title_lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	box.add_child(title_lbl)

	if subtitle != "" or icon != "":
		var sub_lbl: Label = Label.new()
		sub_lbl.text                 = subtitle
		sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub_lbl.autowrap_mode        = TextServer.AUTOWRAP_WORD_SMART
		sub_lbl.add_theme_font_size_override("font_size", 10)
		sub_lbl.add_theme_color_override("font_color", Color(0.66, 0.68, 0.78))
		sub_lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
		var path: String = ItemInfo.ICONS.get(icon, "") as String
		if tint.a > 0.0 and " " in subtitle:
			# The stat it moves ("AGL-") in that stat's colour, the rest as usual.
			var split: HBoxContainer = HBoxContainer.new()
			split.alignment    = BoxContainer.ALIGNMENT_CENTER
			split.mouse_filter = Control.MOUSE_FILTER_IGNORE
			split.add_theme_constant_override("separation", 0)
			var head: Label = sub_lbl.duplicate() as Label
			head.text          = subtitle.get_slice(" ", 0)
			head.autowrap_mode = TextServer.AUTOWRAP_OFF
			head.add_theme_color_override("font_color", tint)
			sub_lbl.text          = subtitle.substr(head.text.length())
			sub_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
			split.add_child(head)
			split.add_child(sub_lbl)
			box.add_child(split)
		elif path == "":
			box.add_child(sub_lbl)
		else:
			# The element's picture in front of the line, in place of its name.
			var row: HBoxContainer = HBoxContainer.new()
			row.alignment    = BoxContainer.ALIGNMENT_CENTER
			row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_theme_constant_override("separation", 4)
			var pic: TextureRect = TextureRect.new()
			pic.texture             = load(path) as Texture2D
			pic.expand_mode         = TextureRect.EXPAND_IGNORE_SIZE
			pic.stretch_mode        = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			pic.texture_filter      = CanvasItem.TEXTURE_FILTER_NEAREST
			pic.custom_minimum_size = Vector2(ICON_PX, ICON_PX)
			pic.mouse_filter        = Control.MOUSE_FILTER_IGNORE
			row.add_child(pic)
			sub_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
			if subtitle != "":
				row.add_child(sub_lbl)
			box.add_child(row)

	return btn
