# MenuUI
# In-game pause menu. Set .player before adding to the scene tree, then listen
# for menu_closed to clean up. Tabs: Stats, Items, Equipment, Magic.
class_name MenuUI extends Control

signal menu_closed
signal save_requested
signal load_requested


var player: PlayerCharacter

var _active_tab:  String = "stats"
var _tab_btns:    Dictionary = {}       # id -> Button
var _content:     VBoxContainer         # cleared and rebuilt on each tab switch
var _status_line: Label                 # one-line feedback at the bottom


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_shell()
	_switch_tab("stats")


# ── Shell (chrome that never changes) ────────────────────────────────────────

func _build_shell() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.03, 0.03, 0.05, 0.93)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var panel: Panel = Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 12)
	panel.add_child(margin)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 0)
	margin.add_child(hbox)

	# ── Left sidebar ──────────────────────────────────────────────────────────
	var sidebar: VBoxContainer = VBoxContainer.new()
	sidebar.add_theme_constant_override("separation", 4)
	sidebar.custom_minimum_size = Vector2(138, 0)
	hbox.add_child(sidebar)

	for tab_id: String in ["stats", "items", "equipment", "magic", "bestiary"]:
		var btn: Button = Button.new()
		btn.text        = tab_id.capitalize()
		btn.toggle_mode = true
		btn.custom_minimum_size     = Vector2(0, 36)
		btn.size_flags_horizontal   = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_switch_tab.bind(tab_id))
		sidebar.add_child(btn)
		_tab_btns[tab_id] = btn

	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar.add_child(spacer)

	sidebar.add_child(HSeparator.new())

	var save_btn: Button = Button.new()
	save_btn.text = "Save  [F5]"
	save_btn.custom_minimum_size   = Vector2(0, 32)
	save_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_btn.pressed.connect(func(): save_requested.emit())
	sidebar.add_child(save_btn)

	var load_btn: Button = Button.new()
	load_btn.text = "Load  [F9]"
	load_btn.custom_minimum_size   = Vector2(0, 32)
	load_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	load_btn.pressed.connect(func(): load_requested.emit())
	sidebar.add_child(load_btn)

	sidebar.add_child(HSeparator.new())

	var close_btn: Button = Button.new()
	close_btn.text = "Close  [ESC]"
	close_btn.custom_minimum_size   = Vector2(0, 32)
	close_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_btn.pressed.connect(func(): menu_closed.emit())
	sidebar.add_child(close_btn)

	# ── Vertical divider ──────────────────────────────────────────────────────
	var vsep_wrap: MarginContainer = MarginContainer.new()
	vsep_wrap.add_theme_constant_override("margin_left",  10)
	vsep_wrap.add_theme_constant_override("margin_right", 10)
	vsep_wrap.add_child(VSeparator.new())
	hbox.add_child(vsep_wrap)

	# ── Right content area ────────────────────────────────────────────────────
	var right: VBoxContainer = VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	hbox.add_child(right)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(scroll)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 8)
	scroll.add_child(_content)

	right.add_child(HSeparator.new())

	_status_line = Label.new()
	_status_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_line.add_theme_color_override("font_color", Color(0.9, 0.85, 0.45))
	_status_line.custom_minimum_size = Vector2(0, 22)
	right.add_child(_status_line)


# ── Tab routing ───────────────────────────────────────────────────────────────

func _switch_tab(tab_id: String) -> void:
	_active_tab      = tab_id
	_status_line.text = ""
	for id: String in _tab_btns:
		_tab_btns[id].button_pressed = (id == tab_id)
	for child: Node in _content.get_children():
		child.queue_free()
	match tab_id:
		"stats":     _build_stats()
		"items":     _build_items()
		"equipment": _build_equipment()
		"magic":     _build_magic()
		"bestiary":  _build_bestiary()


func _refresh() -> void:
	_switch_tab(_active_tab)


func _set_status(msg: String) -> void:
	_status_line.text = msg


# ── Stats tab ─────────────────────────────────────────────────────────────────

func _build_stats() -> void:
	var p: PlayerCharacter = player

	_content.add_child(_make_header("%s   LV %d" % [PlayerCharacter.DISPLAY_NAME.to_upper(), p.lv]))
	_content.add_child(HSeparator.new())

	var portrait_row: HBoxContainer = HBoxContainer.new()
	portrait_row.add_theme_constant_override("separation", 16)
	_content.add_child(portrait_row)

	var portrait: TextureRect = TextureRect.new()
	portrait.texture             = load("res://icon.svg") as Texture2D
	portrait.stretch_mode        = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.custom_minimum_size = Vector2(90, 90)
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	portrait.modulate            = Color(0.55, 0.60, 0.78)
	portrait_row.add_child(portrait)

	var bars: VBoxContainer = VBoxContainer.new()
	bars.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bars.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
	bars.add_theme_constant_override("separation", 6)
	portrait_row.add_child(bars)

	bars.add_child(_make_bar_row("HP",  p.hp,  p.max_hp,      Color(0.20, 0.78, 0.25)))
	bars.add_child(_make_bar_row("MP",  p.mp,  p.max_mp,      Color(0.28, 0.50, 1.00)))
	bars.add_child(_make_bar_row("EXP", p.exp, p.exp_to_next, Color(0.90, 0.70, 0.10)))

	_content.add_child(HSeparator.new())

	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 5)
	_content.add_child(grid)

	_add_stat_row(grid, "STR", p.str, p.effective_str())
	_add_stat_row(grid, "DEF", p.def, p.effective_def())
	_add_stat_row(grid, "MAG", p.mag, p.effective_mag())
	_add_stat_row(grid, "AGL", p.agl, p.effective_agl())

	_content.add_child(HSeparator.new())

	var gold_lbl: Label = Label.new()
	gold_lbl.text = "Gold:  %d gp" % p.gold
	gold_lbl.add_theme_color_override("font_color", Color(0.95, 0.82, 0.25))
	_content.add_child(gold_lbl)

	if not p.active_statuses.is_empty():
		_content.add_child(HSeparator.new())
		_content.add_child(_make_section_label("ACTIVE AILMENTS"))
		for s_id: String in p.active_statuses:
			var sdata: Dictionary = Status.get_data(s_id)
			var s_lbl: Label = Label.new()
			s_lbl.text = "%s — %s" % [sdata.get("name", s_id), sdata.get("desc", "")]
			s_lbl.add_theme_color_override("font_color", sdata.get("color", Color(0.9, 0.9, 0.9)))
			_content.add_child(s_lbl)


func _add_stat_row(grid: GridContainer, stat_name: String, base: int, eff: int) -> void:
	var name_lbl: Label = Label.new()
	name_lbl.text = stat_name
	grid.add_child(name_lbl)

	var val_lbl: Label = Label.new()
	var diff: int = eff - base
	if diff != 0:
		val_lbl.text = "%d  (%+d from gear)" % [eff, diff]
		val_lbl.add_theme_color_override("font_color",
			Color(0.35, 0.90, 0.35) if diff > 0 else Color(0.90, 0.35, 0.35))
	else:
		val_lbl.text = str(base)
	grid.add_child(val_lbl)


# ── Items tab ─────────────────────────────────────────────────────────────────

func _build_items() -> void:
	# Sort controls
	var sort_row: HBoxContainer = HBoxContainer.new()
	sort_row.add_theme_constant_override("separation", 6)
	_content.add_child(sort_row)

	var sort_lbl: Label = Label.new()
	sort_lbl.text = "Sort:"
	sort_row.add_child(sort_lbl)

	for mode: String in ["type", "name"]:
		var btn: Button = Button.new()
		btn.text = mode.capitalize()
		btn.custom_minimum_size = Vector2(70, 26)
		btn.pressed.connect(func():
			player.sort_inventory(mode)
			_refresh()
		)
		sort_row.add_child(btn)

	_content.add_child(HSeparator.new())

	if player.inventory.is_empty():
		var empty_lbl: Label = Label.new()
		empty_lbl.text = "Your pack is empty."
		empty_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		_content.add_child(empty_lbl)
		return

	for item: Dictionary in player.inventory.duplicate():
		_content.add_child(_make_item_row(item))


func _make_item_row(item: Dictionary) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	# Name + quantity
	var name_lbl: Label = Label.new()
	var qty: int = item.get("qty", 1)
	name_lbl.text = item["name"] + (" ×%d" % qty if qty > 1 else "")
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.tooltip_text = _gear_tooltip(item) if item["type"] in ["weapon", "armor"] else item.get("desc", "")
	name_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(name_lbl)

	# Action buttons depending on item type
	var is_throwable: bool = item.has("inflicts_status") \
		or (item.has("element") and item.get("dmg", 0) > 0)
	match item["type"]:
		"consumable", "scroll":
			if is_throwable:
				var tag: Label = Label.new()
				tag.text = "Battle only"
				tag.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
				row.add_child(tag)
			else:
				var use_btn: Button = Button.new()
				use_btn.text = "Use"
				use_btn.custom_minimum_size = Vector2(50, 26)
				use_btn.disabled = not player.can_use_item(item)
				use_btn.pressed.connect(func():
					var result: String = player.use_item(item)
					_set_status(result)
					_refresh()
				)
				row.add_child(use_btn)
		"weapon":
			var is_equipped: bool = (player.equipped_weapon.get("id", "") == item.get("id", "##"))
			var equip_btn: Button = Button.new()
			equip_btn.text = "Equipped" if is_equipped else "Equip"
			equip_btn.disabled = is_equipped
			equip_btn.custom_minimum_size = Vector2(70, 26)
			equip_btn.pressed.connect(func():
				player.equip_weapon(item)
				_set_status("Equipped %s." % item["name"])
				_refresh()
			)
			row.add_child(equip_btn)
		"armor":
			var is_equipped: bool = (player.equipped_armor.get("id", "") == item.get("id", "##"))
			var equip_btn: Button = Button.new()
			equip_btn.text = "Equipped" if is_equipped else "Equip"
			equip_btn.disabled = is_equipped
			equip_btn.custom_minimum_size = Vector2(70, 26)
			equip_btn.pressed.connect(func():
				player.equip_armor(item)
				_set_status("Equipped %s." % item["name"])
				_refresh()
			)
			row.add_child(equip_btn)

	# Discard button (can't discard currently-equipped items)
	var discard_btn: Button = Button.new()
	discard_btn.text = "Discard"
	discard_btn.custom_minimum_size = Vector2(60, 26)
	discard_btn.pressed.connect(func():
		player.remove_item(item, 1)
		_set_status("Discarded %s." % item["name"])
		_refresh()
	)
	row.add_child(discard_btn)

	return row


# ── Equipment tab ─────────────────────────────────────────────────────────────

func _build_equipment() -> void:
	_content.add_child(_make_header("EQUIPPED GEAR"))
	_content.add_child(HSeparator.new())

	var slots_hbox: HBoxContainer = HBoxContainer.new()
	slots_hbox.add_theme_constant_override("separation", 0)
	_content.add_child(slots_hbox)

	var weapon_col: VBoxContainer = _build_slot_section("Weapon", "weapon",
		player.equipped_weapon,
		func(): player.unequip_weapon(); _set_status("Weapon removed."); _refresh(),
		func(it: Dictionary): player.equip_weapon(it); _set_status("Equipped %s." % it["name"]); _refresh()
	)
	weapon_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slots_hbox.add_child(weapon_col)

	slots_hbox.add_child(VSeparator.new())

	var armor_col: VBoxContainer = _build_slot_section("Armor", "armor",
		player.equipped_armor,
		func(): player.unequip_armor(); _set_status("Armor removed."); _refresh(),
		func(it: Dictionary): player.equip_armor(it); _set_status("Equipped %s." % it["name"]); _refresh()
	)
	armor_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slots_hbox.add_child(armor_col)

	_content.add_child(HSeparator.new())
	_content.add_child(_make_section_label("EFFECTIVE STATS"))

	var grid: GridContainer = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 5)
	_content.add_child(grid)

	_add_cmp_row(grid, "STR", player.str, player.effective_str())
	_add_cmp_row(grid, "DEF", player.def, player.effective_def())
	_add_cmp_row(grid, "MAG", player.mag, player.effective_mag())
	_add_cmp_row(grid, "AGL", player.agl, player.effective_agl())


# Builds one slot column (currently equipped + inventory choices) and returns it.
func _build_slot_section(slot_name: String, item_type: String,
		equipped: Dictionary, on_unequip: Callable, on_equip: Callable) -> VBoxContainer:
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)

	var m: MarginContainer = MarginContainer.new()
	for s: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		m.add_theme_constant_override(s, 8)
	col.add_child(m)

	var inner: VBoxContainer = VBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)
	m.add_child(inner)

	# Slot header label
	var slot_lbl: Label = Label.new()
	slot_lbl.text = slot_name.to_upper()
	slot_lbl.add_theme_color_override("font_color", Color(0.70, 0.65, 0.50))
	inner.add_child(slot_lbl)

	# Currently equipped row
	var eq_row: HBoxContainer = HBoxContainer.new()
	eq_row.add_theme_constant_override("separation", 8)
	inner.add_child(eq_row)

	if equipped.is_empty():
		var none_lbl: Label = Label.new()
		none_lbl.text = "(none)"
		none_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		none_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		eq_row.add_child(none_lbl)
	else:
		var item_lbl: Label = Label.new()
		item_lbl.text = equipped["name"]
		item_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item_lbl.tooltip_text = _gear_tooltip(equipped)
		item_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
		eq_row.add_child(item_lbl)

		var unequip_btn: Button = Button.new()
		unequip_btn.text = "Unequip"
		unequip_btn.custom_minimum_size = Vector2(70, 26)
		unequip_btn.pressed.connect(on_unequip)
		eq_row.add_child(unequip_btn)

	# Inventory items of this type available to equip
	var available: Array[Dictionary] = []
	for it: Dictionary in player.inventory:
		if it["type"] == item_type:
			available.append(it)

	if available.is_empty():
		return col

	inner.add_child(HSeparator.new())

	var avail_lbl: Label = Label.new()
	avail_lbl.text = "In inventory:"
	avail_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	inner.add_child(avail_lbl)

	for it: Dictionary in available:
		var avail_row: HBoxContainer = HBoxContainer.new()
		avail_row.add_theme_constant_override("separation", 8)
		inner.add_child(avail_row)

		var name_lbl: Label = Label.new()
		name_lbl.text = it["name"]
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.tooltip_text = _gear_tooltip(it)
		name_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
		avail_row.add_child(name_lbl)

		var equip_btn: Button = Button.new()
		equip_btn.text = "Equip"
		equip_btn.custom_minimum_size = Vector2(60, 26)
		equip_btn.pressed.connect(on_equip.bind(it))
		avail_row.add_child(equip_btn)

	return col


func _gear_tooltip(item: Dictionary) -> String:
	var p: PlayerCharacter = player
	var lines: Array[String] = []

	var desc: String = item.get("desc", "")
	if not desc.is_empty():
		lines.append(desc)
		lines.append("")

	match item["type"]:
		"weapon":
			var new_str: int = p.str + item.get("str_bonus", 0)
			var new_mag: int = p.mag + item.get("mag_bonus", 0)
			var new_agl: int = p.agl + p.equipped_armor.get("agl_pen", 0) + item.get("agl_pen", 0)
			lines.append(_cmp_line("STR", p.effective_str(), new_str))
			if new_mag != p.effective_mag() or item.get("mag_bonus", 0) != 0:
				lines.append(_cmp_line("MAG", p.effective_mag(), new_mag))
			if new_agl != p.effective_agl() or item.get("agl_pen", 0) != 0:
				lines.append(_cmp_line("AGL", p.effective_agl(), new_agl))
		"armor":
			var new_def: int = p.def + item.get("def_bonus", 0)
			var new_agl: int = p.agl + p.equipped_weapon.get("agl_pen", 0) + item.get("agl_pen", 0)
			lines.append(_cmp_line("DEF", p.effective_def(), new_def))
			if new_agl != p.effective_agl() or item.get("agl_pen", 0) != 0:
				lines.append(_cmp_line("AGL", p.effective_agl(), new_agl))
			var w: String = item.get("weakness", "")
			if w != "":
				lines.append("Weakness: %s" % w.capitalize())
			var r: String = item.get("reflect_element", "")
			if r != "":
				lines.append("Reflects: %s" % r.capitalize())
			var a: String = item.get("absorb_element", "")
			if a != "":
				lines.append("Absorbs: %s" % a.capitalize())

	return "\n".join(lines)


func _cmp_line(stat: String, cur: int, nxt: int) -> String:
	var diff: int = nxt - cur
	if diff == 0:
		return "%s  %d" % [stat, nxt]
	return "%s  %d → %d  (%s%d)" % [stat, cur, nxt, ("+" if diff > 0 else ""), diff]


func _bonus_string(item: Dictionary) -> String:
	var parts: Array[String] = []
	if item.get("str_bonus", 0) != 0: parts.append("STR%+d" % item["str_bonus"])
	if item.get("def_bonus", 0) != 0: parts.append("DEF%+d" % item["def_bonus"])
	if item.get("mag_bonus", 0) != 0: parts.append("MAG%+d" % item["mag_bonus"])
	if item.get("agl_pen",   0) != 0: parts.append("AGL%+d" % item["agl_pen"])
	return "  (%s)" % "  ".join(parts) if not parts.is_empty() else ""


func _add_cmp_row(grid: GridContainer, stat: String, base: int, eff: int) -> void:
	var n: Label = Label.new()
	n.text = stat
	grid.add_child(n)

	var b: Label = Label.new()
	b.text = str(base)
	b.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	grid.add_child(b)

	var diff: int = eff - base
	var e: Label = Label.new()
	if diff != 0:
		e.text = "→ %d  (%+d)" % [eff, diff]
		e.add_theme_color_override("font_color",
			Color(0.35, 0.90, 0.35) if diff > 0 else Color(0.90, 0.35, 0.35))
	else:
		e.text = "→ %d" % eff
	grid.add_child(e)


# ── Magic tab ─────────────────────────────────────────────────────────────────

func _build_magic() -> void:
	var p: PlayerCharacter = player

	# MP display
	var mp_lbl: Label = Label.new()
	mp_lbl.text = "MP:  %d / %d" % [p.mp, p.max_mp]
	mp_lbl.add_theme_color_override("font_color", Color(0.4, 0.6, 1.0))
	_content.add_child(mp_lbl)

	_content.add_child(HSeparator.new())

	if p.known_spells.is_empty():
		var none_lbl: Label = Label.new()
		none_lbl.text = "No spells known."
		none_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		_content.add_child(none_lbl)
		return

	for spell_id: String in p.known_spells:
		var spell: Dictionary = Spell.get_data(spell_id)
		if spell.is_empty():
			continue
		_content.add_child(_make_spell_row(spell_id, spell))


func _make_spell_row(spell_id: String, spell: Dictionary) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var name_lbl: Label = Label.new()
	name_lbl.text = spell["name"]
	name_lbl.custom_minimum_size = Vector2(80, 0)
	name_lbl.add_theme_color_override("font_color",
		Color(0.5, 0.8, 1.0) if spell["type"] == "heal" else Color(1.0, 0.55, 0.2))
	row.add_child(name_lbl)

	var mp_lbl: Label = Label.new()
	mp_lbl.text = "%d MP" % spell["mp"]
	mp_lbl.custom_minimum_size = Vector2(55, 0)
	mp_lbl.add_theme_color_override("font_color", Color(0.4, 0.55, 0.95))
	row.add_child(mp_lbl)

	var desc_lbl: Label = Label.new()
	desc_lbl.text = spell.get("desc", "")
	desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	row.add_child(desc_lbl)

	if spell["type"] == "heal":
		var cast_btn: Button = Button.new()
		cast_btn.text = "Cast"
		cast_btn.custom_minimum_size = Vector2(52, 26)
		cast_btn.disabled = (player.mp < spell["mp"])
		cast_btn.pressed.connect(func():
			player.mp -= spell["mp"]
			var heal_amt: int = spell.get("heal", 0)
			var before: int = player.hp
			player.heal(heal_amt)
			var restored: int = player.hp - before
			_set_status("Cast %s — restored %d HP." % [spell["name"], restored])
			_refresh()
		)
		row.add_child(cast_btn)
	else:
		var tag: Label = Label.new()
		tag.text = "Battle only"
		tag.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		row.add_child(tag)

	return row


# ── Bestiary tab ──────────────────────────────────────────────────────────────

func _build_bestiary() -> void:
	_content.add_child(_make_header("BESTIARY"))
	_content.add_child(HSeparator.new())

	if player.encountered_enemies.is_empty():
		var none_lbl: Label = Label.new()
		none_lbl.text = "No enemies recorded yet."
		none_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		_content.add_child(none_lbl)
		return

	for enemy_name: String in player.encountered_enemies:
		var tmpl: Dictionary = {}
		for t: Dictionary in Enemy.TEMPLATES:
			if t["name"] == enemy_name:
				tmpl = t
				break
		if tmpl.is_empty():
			continue
		_content.add_child(_make_bestiary_entry(tmpl))
		_content.add_child(HSeparator.new())


func _make_bestiary_entry(tmpl: Dictionary) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	# Portrait / sprite
	var portrait: TextureRect = TextureRect.new()
	var sprite: String = tmpl.get("sprite", "")
	if sprite != "":
		portrait.texture        = load(sprite) as Texture2D
		portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	else:
		portrait.texture  = load("res://icon.svg") as Texture2D
		portrait.modulate = Color(0.95, 0.28, 0.28)
	portrait.stretch_mode        = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.custom_minimum_size = Vector2(56, 56)
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(portrait)

	# Info column
	var info: VBoxContainer = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 3)
	row.add_child(info)

	var name_lbl: Label = Label.new()
	name_lbl.text = tmpl["name"]
	name_lbl.add_theme_color_override("font_color", Color(0.95, 0.82, 0.45))
	info.add_child(name_lbl)

	var max_fl: int = tmpl.get("max_floor", -1)
	var floor_str: String = "Floors %d" % tmpl.get("min_floor", 1)
	floor_str += "+" if max_fl == -1 else "–%d" % max_fl
	_add_info_line(info, floor_str, Color(0.60, 0.60, 0.60))

	var weakness: String = tmpl.get("weakness", "")
	if weakness != "":
		_add_info_line(info, "Weak: %s" % weakness.capitalize(), Color(0.40, 0.85, 1.0))

	var atk_elem: String = tmpl.get("attack_element", "")
	if atk_elem != "":
		_add_info_line(info, "Attacks with: %s" % atk_elem.capitalize(), Color(1.0, 0.60, 0.25))

	var refl: String = tmpl.get("reflect_element", "")
	if refl != "":
		_add_info_line(info, "Reflects: %s" % refl.capitalize(), Color(0.70, 0.90, 1.0))

	var absorb: String = tmpl.get("absorb_element", "")
	if absorb != "":
		_add_info_line(info, "Absorbs: %s" % absorb.capitalize(), Color(0.35, 1.0, 0.55))

	var status_atk: String = tmpl.get("status_attack", "")
	if status_atk != "":
		var sdata: Dictionary = Status.get_data(status_atk)
		_add_info_line(info, "Inflicts: %s" % sdata.get("name", status_atk), Color(0.85, 0.55, 1.0))

	var neg: bool = tmpl.get("negotiable", false)
	_add_info_line(info, "Talk: %s" % ("Yes" if neg else "No"), Color(0.50, 0.90, 0.60) if neg else Color(0.65, 0.35, 0.35))

	if tmpl["name"] in player.recruited:
		_add_info_line(info, "[RECRUITED]", Color(0.30, 1.0, 0.55))

	return row


func _add_info_line(parent: VBoxContainer, text: String, color: Color) -> void:
	var lbl: Label = Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", 12)
	parent.add_child(lbl)


# ── Shared UI helpers ─────────────────────────────────────────────────────────

func _make_header(text: String) -> Label:
	var lbl: Label = Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", Color(0.95, 0.88, 0.60))
	return lbl


func _make_section_label(text: String) -> Label:
	var lbl: Label = Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", Color(0.70, 0.65, 0.50))
	return lbl


func _make_bar_row(label: String, current: int, maximum: int, color: Color) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var lbl: Label = Label.new()
	lbl.text = "%-4s" % label
	lbl.custom_minimum_size = Vector2(38, 0)
	row.add_child(lbl)

	var bar: ProgressBar = ProgressBar.new()
	bar.min_value = 0
	bar.max_value = max(1, maximum)
	bar.value     = current
	bar.show_percentage = false
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.custom_minimum_size = Vector2(0, 20)
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("fill", fill)
	row.add_child(bar)

	var num_lbl: Label = Label.new()
	num_lbl.text = "%d / %d" % [current, maximum]
	num_lbl.custom_minimum_size = Vector2(90, 0)
	num_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(num_lbl)

	return row
