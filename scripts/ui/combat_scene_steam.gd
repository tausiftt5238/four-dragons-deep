# CombatSceneSteam
# The fight laid out for a wide screen (Build.steam), Final Fantasy fashion:
# the party in a ring on the right and the foes in a ring on the left, a strip
# along the top for whose phase it is and the log, and along the bottom the
# command window (tabs across, the open tab's list under them, Digital Devil
# Saga fashion) and the party window. Everything that is not layout lives in
# CombatScene.
class_name CombatSceneSteam extends CombatScene


# Live and at the top of a tab: a step deeper (a target, the talk window) is
# already an answer under way.
func player_to_act() -> bool:
	return _buttons_on and not _actions_locked and _at_top


# The wide-screen layout: strips, the field, the formations, the cards.
const TOP_STRIP_H: float = 30.0
const BOTTOM_STRIP_H: float = 162.0
const CARD_W: float = 170.0
const CARD_H: float = 230.0
const PORTRAIT: float = 120.0
const PORTRAIT_ZOOM: float = 2.6
const PORTRAIT_TOP: float = 24.0
# Where the feet sit in a zoomed portrait, as a share of its height.
const FEET: float = 0.74
const RING_RX: float = 140.0
const RING_RY: float = 76.0
const RING_TILT: float = 0.0
const FLY_LIFT: float = 26.0
const LIST_ROW_H: float = 26.0
var _field: Control
var _top_row: HBoxContainer
var _turn_lbl: Label
var _party_rows: VBoxContainer
var _buttons_on: bool = false
var _actions_locked: bool = false
# The command tabs across the top of the menu window, Digital Devil Saga
# fashion: left and right walk the tabs, up and down walk the open tab's list.
const TABS: Array[String] = ["Skills", "Item", "Defend", "Talk", "Summon", "Flee"]
var _tab: String = "Skills"
# True while the list shows a tab's own entries; false a step deeper (a target,
# who to heal, the talk), where left and right no longer change the tab.
var _at_top: bool = false
# Talk opens a smaller window stacked over the menu, and the whole conversation
# runs in it. The list functions write to whichever list is current, so the
# window swaps its own title, back button and slots in while it is up.
var _main_list: Dictionary = {}
var _stack_list: Dictionary = {}
var _stack_win: PanelContainer
const MENU_WIN_W: float = 464.0
const STACK_STEP: float = 10.0


# ── UI construction ───────────────────────────────────────────────────────────

func _build_ui() -> void:
	# The Steam build's battle screen, laid out for a wide screen in the
	# Final Fantasy way: the fight across the middle, a strip along the top
	# for whose phase it is and the log, and three windows along the bottom.
	var bg: _Backdrop = _Backdrop.new()
	bg.see_through = see_through
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_build_log_strip(self)
	_build_battlefield(self)
	_build_menu_panel(self)
	_build_icon_overlay()


func _build_log_strip(parent: Control) -> void:
	var strip: PanelContainer = PanelContainer.new()
	strip.anchor_right = 1.0
	strip.offset_bottom = TOP_STRIP_H
	strip.add_theme_stylebox_override("panel", _flat(Color(0.024, 0.02, 0.047, 0.92), Color(0, 0, 0, 0)))
	# Over the field: a card's draw order is its depth, and a flier at the top
	# of its oval must not paint over the strip.
	strip.z_index = 1000
	parent.add_child(strip)
	_top_row = HBoxContainer.new()
	_top_row.add_theme_constant_override("separation", 10)
	strip.add_child(_top_row)
	# The press-turn side and its icons go first (_build_icon_overlay), the log
	# takes the rest, its newest line to the right.
	_log_label = RichTextLabel.new()
	_log_label.bbcode_enabled   = true
	_log_label.scroll_active    = false
	_log_label.scroll_following = true
	_log_label.fit_content      = false
	_log_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_label.custom_minimum_size = Vector2(0, TOP_STRIP_H - 4)
	_log_label.mouse_filter     = Control.MOUSE_FILTER_IGNORE
	_log_label.add_theme_font_size_override("normal_font_size", 13)
	_log_label.add_theme_color_override("default_color", Color(0.88, 0.84, 0.74))


# Nobody leaves the formation: whoever's turn it is walks on the spot until it
# is someone else's.
func _step_forward(card: Control, _is_enemy: bool) -> void:
	_step_back_immediate()
	_stepped_node = card
	var portrait: TextureRect = _card_portrait(card)
	if portrait is AnimatedPortrait:
		(portrait as AnimatedPortrait).play("walk")


func _step_back_immediate() -> void:
	if _stepped_node != null and is_instance_valid(_stepped_node):
		var portrait: TextureRect = _card_portrait(_stepped_node)
		if portrait is AnimatedPortrait and (portrait as AnimatedPortrait)._current_anim == "walk":
			(portrait as AnimatedPortrait).play("idle")
	_stepped_node = null


func _set_buttons(enabled: bool) -> void:
	_buttons_on = enabled
	_close_stack()
	_apply_buttons()
	if enabled:
		_open_tab()
	else:
		_at_top = false
		_right_back_btn.hide()
		_right_title.text = ""
		_submenu_clear()


func _apply_buttons() -> void:
	for btn: Button in _buttons.values():
		btn.disabled = not _buttons_on or _actions_locked
	if _buttons_on and not _actions_locked:
		_refresh_button_states()
	_paint_tabs()


func _focus_list() -> void:
	for slot: MarginContainer in _sub_slots:
		for c: Node in slot.get_children():
			if c is Button and not (c as Button).disabled:
				(c as Button).grab_focus()
				return


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _right_back_btn != null \
			and _right_back_btn.visible:
		_on_back_pressed()
		get_viewport().set_input_as_handled()


# Left and right are taken before the focused list entry can turn them into a
# sideways focus hop: on the top of a tab they change the tab.
func _input(event: InputEvent) -> void:
	if not (_at_top and _buttons_on and not _actions_locked):
		return
	var step: int = 0
	if event.is_action_pressed("ui_left", true):
		step = -1
	elif event.is_action_pressed("ui_right", true):
		step = 1
	if step == 0:
		return
	get_viewport().set_input_as_handled()
	var open: Array[String] = _open_tabs()
	if open.is_empty():
		return
	var i: int = open.find(_tab)
	_tab = open[posmod((i if i >= 0 else 0) + step, open.size())]
	_open_tab()


# The tabs this actor can use now: hidden ones (the hero's alone, on a demon's
# turn) and greyed ones (Defend while braced) are stepped over.
func _open_tabs() -> Array[String]:
	var out: Array[String] = []
	for key: String in TABS:
		var btn: Button = _buttons[key] as Button
		if btn.visible and not btn.disabled:
			out.append(key)
	return out


# Shows the current tab's list in the list window, ready for up and down.
func _open_tab() -> void:
	_close_stack()
	_actions_locked = false
	_apply_buttons()
	var open: Array[String] = _open_tabs()
	if not _tab in open:
		_tab = "Skills" if "Skills" in open else (open[0] if not open.is_empty() else "Skills")
	match _tab:
		"Skills":
			_show_skills_submenu()
		"Item":
			_show_item_submenu()
		"Summon":
			_show_summon_submenu()
		"Talk":
			_show_talk_targets()
		_:
			_show_command_entry(_tab)
	# The submenu took the tabs out of reach as though it were a step deeper;
	# this is the top, so give them back.
	_actions_locked = false
	_apply_buttons()
	_right_back_btn.hide()
	_at_top = true
	_focus_list.call_deferred()


# Defend and Flee have nothing to list, so their tab holds the one
# command, said plainly, to confirm with Enter.
func _show_command_entry(key: String) -> void:
	_hide_actions()
	_right_title.text = key
	_right_title.add_theme_color_override("font_color", Color(0.80, 0.84, 0.95))
	_submenu_clear()
	var note: String = {
		"Defend": "brace until your next turn",
		"Flee": "run from the fight",
	}.get(key, "") as String
	var btn: Button = _big_button(key, note, false)
	btn.pressed.connect(_on_action.bind(key))
	_submenu_add(btn)


func _select_tab(key: String) -> void:
	if not (_buttons_on and not _actions_locked):
		return
	_tab = key
	_open_tab()


# The open tab is lit; the rest sit dim, and a tab out of reach dimmer still.
func _paint_tabs() -> void:
	for key: String in _buttons:
		var btn: Button = _buttons[key] as Button
		var lit: bool = key == _tab and _buttons_on
		var c: Color = Color(1.0, 0.86, 0.42) if lit else Color(0.70, 0.73, 0.85)
		btn.add_theme_color_override("font_color", c)
		btn.add_theme_color_override("font_disabled_color",
				Color(c, 0.75) if lit else Color(0.70, 0.73, 0.85, 0.30))
		btn.add_theme_stylebox_override("normal", _tab_box(lit))
		btn.add_theme_stylebox_override("disabled", _tab_box(lit))
		btn.add_theme_stylebox_override("hover", _tab_box(lit))
		btn.add_theme_stylebox_override("pressed", _tab_box(lit))


func _tab_box(lit: bool) -> StyleBoxFlat:
	var st: StyleBoxFlat = _flat(Color(0.20, 0.24, 0.48) if lit else Color(0, 0, 0, 0),
			Color(1.0, 0.86, 0.42))
	st.border_width_bottom = 2 if lit else 0
	st.set_corner_radius_all(3)
	st.set_content_margin_all(3)
	return st


# The Talk tab: everyone standing on their side, the ones that will not talk
# greyed with the reason. Choosing one opens the talk over the menu.
func _show_talk_targets() -> void:
	_hide_actions()
	_right_title.text = "Talk to"
	_right_title.add_theme_color_override("font_color", Color(0.50, 1.0, 0.70))
	_submenu_clear()
	for foe: Enemy in _living_foes():
		var note: String = "" if foe.negotiable else "won't listen"
		if foe.negotiable and foe.enemy_name in player.recruited:
			note = "already with you"
		var btn: Button = _big_button(foe.display_name(), note, not foe.negotiable)
		btn.pressed.connect(_talk_to.bind(foe))
		_submenu_add(btn)


func _talk_to(foe: Enemy) -> void:
	enemy = foe
	_refresh_hp()
	# It looks past you at its own face standing in your line. There is
	# nothing left to negotiate about — you already have one, and it knows
	# what that means. It pays its way out instead.
	if enemy.enemy_name in player.recruited:
		_log("[color=#ffd479]%s looks past you — and sees its own face already standing with you.[/color]"
				% enemy.display_name())
		_prompt_tribute(false)
		return
	_show_talk_submenu()


func _build_battlefield(parent: Control) -> void:
	_field = Control.new()
	_field.anchor_right = 1.0
	_field.offset_top = TOP_STRIP_H
	_field.anchor_bottom = 1.0
	_field.offset_bottom = -BOTTOM_STRIP_H
	_field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(_field)
	_enemy_side = Control.new()
	_enemy_side.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_enemy_side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_field.add_child(_enemy_side)
	_party_box = Control.new()
	_party_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_party_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_field.add_child(_party_box)
	for f: Enemy in foes:
		_enemy_side.add_child(_build_foe_card(f))
	_field.resized.connect(_fit_columns)


# A monster on the field: its name and HP over it, the target caret above
# that, its chart and its buffs under its feet. Laid out by hand, around the
# point its feet stand on (_fit_columns places that).
func _build_foe_card(foe: Enemy) -> Control:
	var card: Control = Control.new()
	card.size = Vector2(CARD_W, CARD_H)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var icon: AnimatedPortrait = AnimatedPortrait.new()
	if foe.sprite_id != "":
		icon.load_sprite_id(foe.sprite_id)
	elif foe.sprite_path != "":
		icon.load_static(load(foe.sprite_path) as Texture2D)
	else:
		icon.load_static(load("res://icon.svg") as Texture2D)
		icon.modulate = Color(0.95, 0.28, 0.28)
	icon.position = Vector2((CARD_W - PORTRAIT) / 2.0, PORTRAIT_TOP)
	icon.size = Vector2(PORTRAIT, PORTRAIT)
	icon.set_zoom(PORTRAIT_ZOOM)
	icon.self_modulate = foe.tint
	if foe.abyss_element != "":
		icon.material = Abyss.palette_material(foe.abyss_element, foe.sprite_id)
	icon.add_child(StatusOverlay.new(foe))
	card.add_child(icon)

	var name_lbl: Label = Label.new()
	name_lbl.text = foe.display_name()
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 11)
	# Under its feet: name, HP, then its chart and its buffs.
	var under: float = PORTRAIT_TOP + PORTRAIT * FEET + 2.0
	name_lbl.position = Vector2(0, under)
	name_lbl.size = Vector2(CARD_W, 14)
	card.add_child(name_lbl)

	var marker: UIGlyph = UIGlyph.caret(true, Color(1.0, 0.92, 0.45))
	marker.position = Vector2(CARD_W / 2.0 - 8, PORTRAIT_TOP - 16)
	marker.size = Vector2(16, 14)
	card.add_child(marker)

	var bar: ProgressBar = _make_bar(foe.max_hp)
	bar.custom_minimum_size = Vector2(80, 5)
	bar.position = Vector2(CARD_W / 2.0 - 40, under + 17)
	bar.size = Vector2(80, 5)
	card.add_child(bar)

	# Kept for _refresh_foe_rows, which writes to it; the field shows no
	# numbers for a monster, only its bar.
	var hp_lbl: Label = Label.new()
	hp_lbl.visible = false
	card.add_child(hp_lbl)

	var chart: AffinityChart = AffinityChart.new()
	chart.foe = foe
	chart.knows = func(element: String) -> bool:
		return player.knows_affinity(foe.lore_name(), element)
	chart.position = Vector2(CARD_W / 2.0 - 52, under + 26)
	chart.size = Vector2(104, 24)
	card.add_child(chart)

	var stages: StageArrows = StageArrows.new()
	stages.member = foe
	stages.position = Vector2(CARD_W / 2.0 - 34, under + 52)
	stages.size = Vector2(68, 16)
	card.add_child(stages)

	_watch_hp(foe)
	_foe_rows.append({foe = foe, portrait = icon, name_lbl = name_lbl,
			bar = bar, hp_lbl = hp_lbl, stages = stages, marker = marker,
			chart = chart, card = card})
	_fit_columns.call_deferred()
	return card


# ── Press-turn corner ─────────────────────────────────────────────────────────

# Both sides' icons live in the top-right corner, out of the fight rather than
# wedged between the two line-ups.
# Only the side whose phase it is: "YOU" and the party's icons now, "FOE" and
# theirs when the monsters' phase comes round.
func _build_icon_overlay() -> void:
	_turn_lbl = Label.new()
	_turn_lbl.add_theme_font_size_override("font_size", 13)
	_top_row.add_child(_turn_lbl)
	_icon_pips = UIGlyph.pips(Color(0.55, 0.95, 1.0))
	_top_row.add_child(_icon_pips)
	_foe_icon_pips = UIGlyph.pips(Color(1.0, 0.45, 0.45))
	_top_row.add_child(_foe_icon_pips)
	_top_row.add_child(_log_label)


func _refresh_icons() -> void:
	if _press == null or _foe_press == null:
		return
	var ours: bool = _press.has_turns() or not _foe_press.has_turns()
	_turn_lbl.text = "YOU" if ours else "FOE"
	_turn_lbl.add_theme_color_override("font_color",
			Color(0.55, 0.95, 1.0) if ours else Color(1.0, 0.45, 0.45))
	_icon_pips.visible = ours
	_foe_icon_pips.visible = not ours
	_icon_pips.set_pips(_press.full if _press.has_turns() else 0,
			_press.blink if _press.has_turns() else 0)
	_foe_icon_pips.set_pips(_foe_press.full if _foe_press.has_turns() else 0,
			_foe_press.blink if _foe_press.has_turns() else 0)


# Rebuild the party side only. Foes are built once in _build_battlefield.
func _rebuild_party_slots() -> void:
	for child: Node in _party_box.get_children():
		child.queue_free()
	for child: Node in _party_rows.get_children():
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
# Stands each side on its own oval: its first member at the front, the side
# facing the other, the rest going round from there, the party counter-
# clockwise and the monsters clockwise, so the two mirror. One alone stands in
# the middle of its oval. Called whenever a side changes or the field resizes.
func _fit_columns() -> void:
	if not is_inside_tree() or _field == null:
		return
	var h: float = _field.size.y
	var w: float = _field.size.x
	# Low enough that the top of the oval (a flier, name and all) clears the
	# strip above, high enough that the bottom's chart clears the windows.
	var cy: float = h * 0.58
	var foe_cards: Array[Control] = []
	for r: Dictionary in _foe_rows:
		if is_instance_valid(r["card"]):
			foe_cards.append(r["card"] as Control)
	var party_cards: Array[Control] = []
	for slot: Dictionary in _party_slots:
		if is_instance_valid(slot["card"]):
			party_cards.append(slot["card"] as Control)
	_ring(foe_cards, Vector2(w * 0.24, cy), 0.0, true, -1.0)
	_ring(party_cards, Vector2(w * 0.76, cy), 180.0, false, 1.0)


# `back`: which way is away from the other side (-1 left, +1 right). The oval
# leans that way at the top, so the one standing at the top is not straight
# above the one at the bottom, with its chart over the other's name.
func _ring(cards: Array[Control], centre: Vector2, front_deg: float, clockwise: bool,
		back: float) -> void:
	var n: int = cards.size()
	var spots: Array[Vector2] = []
	for i: int in n:
		if n == 1:
			spots.append(centre)
			continue
		var step: float = 360.0 / float(n) * float(i)
		var a: float = deg_to_rad(front_deg + (step if clockwise else -step))
		spots.append(centre + Vector2(cos(a) * RING_RX - sin(a) * RING_TILT * back,
				sin(a) * RING_RY))
	for i: int in n:
		var card: Control = cards[i]
		var feet: Vector2 = spots[i]
		var portrait: TextureRect = _card_portrait(card)
		var lift: float = 0.0
		if portrait is AnimatedPortrait and (portrait as AnimatedPortrait)._anims.has("flying") \
				and not (portrait as AnimatedPortrait)._anims.has("walk"):
			lift = FLY_LIFT
		card.position = feet - Vector2(CARD_W / 2.0, PORTRAIT_TOP + PORTRAIT * FEET + lift)
		# Further back is further up the screen, and is drawn behind.
		card.z_index = int(feet.y)


# One of the party: a figure on the field (flipped to face the monsters, its
# ailments drawn on it, a caret over it on its turn), and a row in the party
# window with its name, HP over MP, its buffs as chevrons and its ailments.
func _build_party_slot(member: CharacterSheet) -> Control:
	var card: Control = Control.new()
	card.size = Vector2(CARD_W, CARD_H)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var is_hero: bool = (member == player)
	var icon: AnimatedPortrait = AnimatedPortrait.new()
	icon.position = Vector2((CARD_W - PORTRAIT) / 2.0, PORTRAIT_TOP)
	icon.size = Vector2(PORTRAIT, PORTRAIT)
	icon.set_zoom(PORTRAIT_ZOOM)
	icon.flip_h = true
	if is_hero:
		icon.load_sprite_id(player.hero_sprite_id())
		_player_portrait = icon
	else:
		var demon: Enemy = member as Enemy
		if demon.abyss_element != "":
			icon.material = Abyss.palette_material(demon.abyss_element, demon.sprite_id)
		if demon.sprite_id != "":
			icon.load_sprite_id(demon.sprite_id)
		elif demon.sprite_path != "":
			icon.load_static(load(demon.sprite_path) as Texture2D)
		else:
			icon.load_static(load("res://icon.svg") as Texture2D)
			icon.modulate = Color(0.55, 0.85, 0.65)
	icon.add_child(StatusOverlay.new(member))
	card.add_child(icon)

	var marker: UIGlyph = UIGlyph.caret(true, Color(1.0, 0.92, 0.45))
	marker.position = Vector2(CARD_W / 2.0 - 8, PORTRAIT_TOP - 16)
	marker.size = Vector2(16, 14)
	card.add_child(marker)

	# Its row in the party window.
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.custom_minimum_size = Vector2(0, 34)
	_party_rows.add_child(row)

	var name_lbl: Label = Label.new()
	name_lbl.custom_minimum_size = Vector2(118, 0)
	name_lbl.clip_text = true
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(name_lbl)

	var bars: VBoxContainer = VBoxContainer.new()
	bars.add_theme_constant_override("separation", 2)
	bars.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bars)
	var hp_line: HBoxContainer = HBoxContainer.new()
	hp_line.add_theme_constant_override("separation", 6)
	bars.add_child(hp_line)
	var hp_bar: ProgressBar = _make_bar(member.max_hp)
	hp_bar.custom_minimum_size = Vector2(104, 6)
	hp_bar.size = Vector2(104, 6)
	hp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hp_line.add_child(hp_bar)
	var val_lbl: Label = Label.new()
	val_lbl.custom_minimum_size = Vector2(62, 0)
	val_lbl.add_theme_font_size_override("font_size", 11)
	hp_line.add_child(val_lbl)
	var mp_line: HBoxContainer = HBoxContainer.new()
	mp_line.add_theme_constant_override("separation", 6)
	bars.add_child(mp_line)
	var mp_bar: ProgressBar = _make_bar(maxi(1, member.max_mp))
	mp_bar.custom_minimum_size = Vector2(104, 6)
	mp_bar.size = Vector2(104, 6)
	mp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mp_bar.add_theme_stylebox_override("fill", _bar_fill(Color(0.32, 0.46, 0.95)))
	mp_line.add_child(mp_bar)
	var mp_lbl: Label = Label.new()
	mp_lbl.custom_minimum_size = Vector2(62, 0)
	mp_lbl.add_theme_font_size_override("font_size", 11)
	mp_lbl.add_theme_color_override("font_color", Color(0.59, 0.73, 1.0))
	mp_line.add_child(mp_lbl)

	var stages: StageArrows = StageArrows.new()
	stages.member = member
	stages.custom_minimum_size = Vector2(72, 24)
	stages.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(stages)

	var ails: _AilmentIcons = _AilmentIcons.new()
	ails.member = member
	ails.custom_minimum_size = Vector2(100, 22)
	ails.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ails)

	_party_slots.append({member = member, portrait = icon, name_lbl = name_lbl,
			hp_bar = hp_bar, mp_bar = mp_bar, val_lbl = val_lbl, mp_lbl = mp_lbl,
			sts_lbl = null, stages = stages, ails = ails, marker = marker,
			card = card, row = row})
	return card


func _refresh_party_slots() -> void:
	var acting: CharacterSheet = _actor() if _press != null and _press.has_turns() else null
	for slot: Dictionary in _party_slots:
		var member: CharacterSheet = slot["member"] as CharacterSheet
		if member == null:
			continue
		var alive: bool    = member.is_alive()
		var is_actor: bool = (member == acting) and alive

		(slot["marker"] as UIGlyph).visible = is_actor
		(slot["portrait"] as TextureRect).modulate.a = 1.0 if alive else 0.18
		if not alive and not slot.get("_death_played", false):
			_play_anim(slot["portrait"] as TextureRect, "death")
			slot["_death_played"] = true

		var name_lbl: Label = slot["name_lbl"] as Label
		name_lbl.text = ("> " if is_actor else "  ") + _member_name(member)
		if not alive:
			name_lbl.add_theme_color_override("font_color", Color(0.40, 0.32, 0.32))
		elif is_actor:
			name_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.45))
		else:
			name_lbl.add_theme_color_override("font_color", Color(0.85, 0.86, 0.93))

		var hp_bar: ProgressBar = slot["hp_bar"] as ProgressBar
		hp_bar.max_value = member.max_hp
		hp_bar.value     = member.hp
		_apply_hp_bar(hp_bar, member.hp, member.max_hp)
		var val_lbl: Label = slot["val_lbl"] as Label
		val_lbl.text = "%d/%d" % [member.hp, member.max_hp] if alive else "Down"
		val_lbl.add_theme_color_override("font_color",
				hp_tint(member.hp, member.max_hp) if alive else Color(0.55, 0.38, 0.38))
		var mp_bar: ProgressBar = slot["mp_bar"] as ProgressBar
		mp_bar.max_value = maxi(1, member.max_mp)
		mp_bar.value     = member.mp
		(slot["mp_lbl"] as Label).text = "%d/%d" % [member.mp, member.max_mp]

		var stages: StageArrows = slot["stages"] as StageArrows
		stages.visible = alive
		stages.queue_redraw()
		(slot["ails"] as Control).queue_redraw()


# ── The menu strip ────────────────────────────────────────────────────────────

# The three windows along the bottom: the commands, the list a command opens
# (skills, items, targets, the talk), and the party.
func _build_menu_panel(parent: Control) -> void:
	var strip: HBoxContainer = HBoxContainer.new()
	strip.anchor_top = 1.0
	strip.anchor_right = 1.0
	strip.anchor_bottom = 1.0
	strip.offset_top = -BOTTOM_STRIP_H + 4
	strip.offset_left = 8
	strip.offset_right = -8
	strip.offset_bottom = -8
	strip.add_theme_constant_override("separation", 8)
	strip.z_index = 1000
	parent.add_child(strip)

	# The commands as tabs along the top, and under them the open tab's list,
	# its title and a way back. Attack is the first entry of Skills.
	var list_win: PanelContainer = _window()
	list_win.custom_minimum_size = Vector2(MENU_WIN_W, 0)
	strip.add_child(list_win)
	var list_col: VBoxContainer = VBoxContainer.new()
	list_col.add_theme_constant_override("separation", 2)
	list_win.add_child(list_col)
	_action_bar = GridContainer.new()
	_action_bar.columns = TABS.size()
	_action_bar.add_theme_constant_override("h_separation", 2)
	list_col.add_child(_action_bar)
	for action: String in TABS:
		var btn: Button = Button.new()
		btn.text = action
		btn.flat = false
		btn.focus_mode = Control.FOCUS_NONE
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_select_tab.bind(action))
		_action_bar.add_child(btn)
		# After add_child: Main sets every new Button's font as it enters.
		btn.add_theme_font_size_override("font_size", 14)
		_buttons[action] = btn
	_paint_tabs()
	var rule: ColorRect = ColorRect.new()
	rule.color = Color(0.78, 0.80, 0.90, 0.35)
	rule.custom_minimum_size = Vector2(0, 1)
	list_col.add_child(rule)
	_main_list = _list_column(list_col)
	_use_list(_main_list)

	# The party, a row each.
	var party_win: PanelContainer = _window()
	party_win.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strip.add_child(party_win)
	_party_rows = VBoxContainer.new()
	_party_rows.add_theme_constant_override("separation", 0)
	_party_rows.alignment = BoxContainer.ALIGNMENT_CENTER
	party_win.add_child(_party_rows)

	# The talk window: the menu window's own size, laid over it a step up and
	# to the right, the way one window stacks on another.
	_stack_win = _window()
	_stack_win.anchor_top = 1.0
	_stack_win.anchor_bottom = 1.0
	_stack_win.offset_left = 8 + STACK_STEP
	_stack_win.offset_right = 8 + MENU_WIN_W + STACK_STEP
	_stack_win.offset_top = -BOTTOM_STRIP_H + 4 - STACK_STEP
	_stack_win.offset_bottom = -8 - STACK_STEP
	_stack_win.z_index = 1001
	_stack_win.hide()
	parent.add_child(_stack_win)
	var stack_col: VBoxContainer = VBoxContainer.new()
	stack_col.add_theme_constant_override("separation", 2)
	_stack_win.add_child(stack_col)
	_stack_list = _list_column(stack_col, false)


# A list's title row (a way back and the title) and its scrolling slots, built
# into `col`. Returned as the refs _use_list points the list functions at.
func _list_column(col: VBoxContainer, with_back: bool = true) -> Dictionary:
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	col.add_child(header)
	var back: Button = Button.new()
	back.text = "<"
	back.flat = true
	back.focus_mode = Control.FOCUS_NONE
	back.custom_minimum_size = Vector2(26, 0)
	back.pressed.connect(_on_back_pressed)
	back.hide()
	# The talk window keeps its back button out of sight: Escape still works
	# (it reads the button's visibility), and the window's corner stays clean.
	if with_back:
		header.add_child(back)
	else:
		col.tree_exiting.connect(back.queue_free)
	var title: Label = Label.new()
	title.clip_text = true
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 14)
	header.add_child(title)
	var scroll: TouchScroll = TouchScroll.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	col.add_child(scroll)
	var bar: GridContainer = _make_slot_row()
	scroll.add_child(bar)
	var refs: Dictionary = {title = title, back = back, scroll = scroll, bar = bar, header = header,
			slots = [] as Array[MarginContainer]}
	var was: Dictionary = {bar = _sub_bar, slots = _sub_slots}
	_sub_bar = bar
	_sub_slots = refs["slots"]
	for _i: int in range(MENU_SLOTS):
		_add_sub_slot()
	_sub_bar = was["bar"]
	_sub_slots = was["slots"]
	return refs


func _use_list(refs: Dictionary) -> void:
	_right_title = refs["title"]
	_right_back_btn = refs["back"]
	_sub_scroll = refs["scroll"]
	_sub_bar = refs["bar"]
	_sub_slots = refs["slots"]


# Puts the talk window up and sends the lists to it. What the menu was showing
# stays under it, greyed, so the arrows cannot wander back down there.
func _open_stack() -> void:
	if _stack_win.visible:
		return
	_lock_submenu()
	_main_list["bar"].modulate = Color(1, 1, 1, 0.45)
	_main_list["back"].hide()
	_use_list(_stack_list)
	_submenu_clear()
	_stack_win.show()


# The talk window's title row only takes room while a talk has a title for
# it (a round count); the approaches themselves need none.
func _process(_delta: float) -> void:
	if _stack_win != null and _stack_win.visible:
		(_stack_list["header"] as Control).visible = (_stack_list["title"] as Label).text != ""


func _close_stack() -> void:
	if _stack_win == null or not _stack_win.visible:
		return
	_submenu_clear()
	_right_back_btn.hide()
	_stack_win.hide()
	_use_list(_main_list)
	_sub_bar.modulate = Color.WHITE


func _window() -> PanelContainer:
	var w: PanelContainer = PanelContainer.new()
	var st: StyleBoxFlat = _flat(Color(0.063, 0.07, 0.18), Color(0.78, 0.80, 0.90))
	st.set_corner_radius_all(6)
	st.set_border_width_all(2)
	st.set_content_margin_all(8)
	w.add_theme_stylebox_override("panel", st)
	return w


func _flat(bg: Color, edge: Color) -> StyleBoxFlat:
	var st: StyleBoxFlat = StyleBoxFlat.new()
	st.bg_color = bg
	st.border_color = edge
	return st


# An empty slot still holds its ground, so a three-entry submenu is the same
# shape as a six-entry one. Slots past the sixth are made as a list needs them
# and dropped again on clear.
func _add_sub_slot() -> MarginContainer:
	var slot: MarginContainer = MarginContainer.new()
	slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot.custom_minimum_size = Vector2(0, LIST_ROW_H)
	_sub_bar.add_child(slot)
	_sub_slots.append(slot)
	return slot


# Six thumb targets in one line on a 540-wide screen truncates every label to
# three letters, so the six slots sit two rows of three deep — wider per slot
# than a landscape strip managed, and still one grid the eye reads in one go.
func _make_slot_row() -> GridContainer:
	var row: GridContainer = GridContainer.new()
	row.columns = 1
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("v_separation", 2)
	return row


# The command window never goes away on a wide screen. "Hidden" means its
# choices are out of reach while a list or a question has the turn.
func _show_actions() -> void:
	_actions_locked = false
	_apply_buttons()


func _hide_actions() -> void:
	_actions_locked = true
	_apply_buttons()
	_focus_list.call_deferred()


func _show_main_actions() -> void:
	_close_stack()
	_show_actions()
	_right_back_btn.hide()
	_right_title.text = ""
	_submenu_clear()
	if _buttons_on:
		_open_tab()


func _big_button(title: String, subtitle: String, disabled: bool,
		icon: String = "", tint: Color = Color.TRANSPARENT) -> Button:
	# One line in the list window: the element's picture, the name, and the
	# detail (cost, reach, what it moves) to the right.
	var btn: Button = Button.new()
	btn.flat = true
	btn.disabled = disabled
	var row: HBoxContainer = HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 4
	row.offset_right = -4
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	row.modulate = Color(1, 1, 1, 0.38) if disabled else Color(1, 1, 1, 1)
	btn.add_child(row)
	var path: String = ItemInfo.ICONS.get(icon, "") as String
	if path != "":
		var pic: TextureRect = TextureRect.new()
		pic.texture = load(path) as Texture2D
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		pic.custom_minimum_size = Vector2(ICON_PX, ICON_PX)
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(pic)
	var title_lbl: Label = Label.new()
	title_lbl.text = title
	title_lbl.clip_text = true
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(title_lbl)
	if subtitle != "":
		var sub: Label = Label.new()
		sub.text = subtitle
		sub.add_theme_font_size_override("font_size", 14)
		sub.add_theme_color_override("font_color", tint if tint.a > 0.0 else Color(0.66, 0.70, 0.86))
		sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sub.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(sub)
	return btn


# The backdrop behind the fight: the dungeon dimmed to a stage, a floor running
# away to a horizon line in the first band's wire colour.
class _Backdrop extends Control:
	var see_through: bool = false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		# Over the battle room: only a shade toward the top, under the log.
		if see_through:
			for i: int in 20:
				var t: float = float(i) / 20.0
				draw_rect(Rect2(0, h * 0.3 * t, w, h * 0.3 / 20.0 + 1.0),
						Color(0.02, 0.02, 0.05, 0.55 * (1.0 - t)))
			return
		for i: int in 60:
			var t: float = float(i) / 60.0
			var a: float = 0.14 * (1.0 - t)
			draw_rect(Rect2(0, h * t, w, h / 60.0 + 1.0),
					Color(0.06 + a * 0.3, 0.05 + a * 0.25, 0.09 + a * 0.5))
		var hz: float = h * 0.30
		var floor_b: float = h - CombatSceneSteam.BOTTOM_STRIP_H
		draw_rect(Rect2(0, hz, w, floor_b - hz), Color(0.067, 0.059, 0.094))
		for k: int in range(1, 9):
			var y: float = hz + (floor_b - hz) * pow(float(k) / 8.0, 1.6)
			draw_line(Vector2(0, y), Vector2(w, y), Color(0.13, 0.125, 0.18), 1.0)
		var x: float = -600.0
		while x < w + 600.0:
			draw_line(Vector2(w / 2.0 + (x - w / 2.0) * 0.25, hz), Vector2(x, floor_b),
					Color(0.12, 0.12, 0.165), 1.0)
			x += 70.0
		draw_line(Vector2(0, hz), Vector2(w, hz), Color(0.24, 0.47, 0.55), 1.0)


# A member's ailments, small, in its row of the party window: the same marks
# its figure wears on the field (StatusOverlay), side by side.
class _AilmentIcons extends Control:
	var member: CharacterSheet

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if member == null:
			return
		var x: float = 0.0
		var y: float = (size.y - 18.0) / 2.0
		for kind: String in [Status.POISON, Status.PARALYZED, Status.SILENCE, Status.BLIND]:
			if not member.has_status(kind):
				continue
			_mark(kind, Vector2(x, y))
			x += 24.0

	func _mark(kind: String, o: Vector2) -> void:
		match kind:
			Status.POISON:
				for b: Array in [[3, 12, 3.5], [9, 6, 2.8], [13, 13, 2.2]]:
					var c: Vector2 = o + Vector2(float(b[0]), float(b[1]))
					draw_circle(c, float(b[2]), StatusOverlay.POISON_FILL)
					draw_arc(c, float(b[2]), 0.0, TAU, 12, StatusOverlay.POISON_EDGE, 1.0)
			Status.PARALYZED:
				draw_polyline(PackedVector2Array([o + Vector2(2, 1), o + Vector2(9, 7),
						o + Vector2(4, 9), o + Vector2(13, 17)]), StatusOverlay.SPARK_GLOW, 2.0)
			Status.SILENCE:
				draw_rect(Rect2(o + Vector2(0, 2), Vector2(17, 11)), StatusOverlay.BUBBLE_FILL)
				draw_rect(Rect2(o + Vector2(0, 2), Vector2(17, 11)), StatusOverlay.BUBBLE_EDGE, false, 1.0)
				draw_colored_polygon(PackedVector2Array([o + Vector2(4, 13), o + Vector2(8, 13),
						o + Vector2(3, 17)]), StatusOverlay.BUBBLE_FILL)
				for k: int in 3:
					draw_rect(Rect2(o + Vector2(4 + k * 4, 7), Vector2(2, 2)), StatusOverlay.BUBBLE_EDGE)
			Status.BLIND:
				draw_rect(Rect2(o + Vector2(0, 6), Vector2(7, 5)), StatusOverlay.SHADES)
				draw_rect(Rect2(o + Vector2(9, 6), Vector2(7, 5)), StatusOverlay.SHADES)
				draw_line(o + Vector2(7, 7), o + Vector2(9, 7), StatusOverlay.SHADES_SHINE, 1.0)

# ── Layout hooks (see CombatScene) ────────────────────────────────────────────

func _on_step_deeper() -> void:
	_at_top = false


# A step under a tab comes back to the tab itself.
func _back_to(_list: Callable) -> Callable:
	return _show_main_actions


# Talk is a tab of its own: who to talk to, then the talk over it.
func _on_talk_chosen() -> void:
	_tab = "Talk"
	_open_tab()


# The talk runs in a window stacked over the menu. No title: the marker over
# the monster already says who this is with.
func _open_talk_window() -> void:
	_open_stack()
	_set_back(_show_main_actions)
	_right_title.text = ""


func _open_tribute_window(from_beg: bool) -> void:
	if not from_beg:
		_open_stack()

