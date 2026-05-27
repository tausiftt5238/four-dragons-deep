class_name MenuTabEquipment extends RefCounted

var _m

func _init(menu) -> void:
	_m = menu


func build() -> void:
	_m._content.add_child(_make_header("EQUIPPED GEAR"))
	_m._content.add_child(HSeparator.new())

	var slots_hbox: HBoxContainer = HBoxContainer.new()
	slots_hbox.add_theme_constant_override("separation", 0)
	_m._content.add_child(slots_hbox)

	var weapon_col: VBoxContainer = _build_slot_section("Weapon", "weapon",
		_m.player.equipped_weapon,
		func(): _m.player.unequip_weapon(); _m._set_status("Weapon removed."); _m._refresh(),
		func(it: Dictionary): _m.player.equip_weapon(it); _m._set_status("Equipped %s." % it["name"]); _m._refresh()
	)
	weapon_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slots_hbox.add_child(weapon_col)

	slots_hbox.add_child(VSeparator.new())

	var armor_col: VBoxContainer = _build_slot_section("Armor", "armor",
		_m.player.equipped_armor,
		func(): _m.player.unequip_armor(); _m._set_status("Armor removed."); _m._refresh(),
		func(it: Dictionary): _m.player.equip_armor(it); _m._set_status("Equipped %s." % it["name"]); _m._refresh()
	)
	armor_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slots_hbox.add_child(armor_col)

	_m._content.add_child(HSeparator.new())
	_m._content.add_child(_make_section_label("EFFECTIVE STATS"))

	var grid: GridContainer = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 5)
	_m._content.add_child(grid)

	_add_cmp_row(grid, "STR", _m.player.str, _m.player.effective_str())
	_add_cmp_row(grid, "DEF", _m.player.def, _m.player.effective_def())
	_add_cmp_row(grid, "MAG", _m.player.mag, _m.player.effective_mag())
	_add_cmp_row(grid, "AGL", _m.player.agl, _m.player.effective_agl())


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

	var slot_lbl: Label = Label.new()
	slot_lbl.text = slot_name.to_upper()
	slot_lbl.add_theme_color_override("font_color", Color(0.70, 0.65, 0.50))
	inner.add_child(slot_lbl)

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
		item_lbl.tooltip_text = GearTooltip.build(equipped, _m.player)
		item_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
		eq_row.add_child(item_lbl)

		var unequip_btn: Button = Button.new()
		unequip_btn.text = "Unequip"
		unequip_btn.custom_minimum_size = Vector2(70, 26)
		unequip_btn.pressed.connect(on_unequip)
		eq_row.add_child(unequip_btn)

	var available: Array[Dictionary] = []
	for it: Dictionary in _m.player.inventory:
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
		name_lbl.tooltip_text = GearTooltip.build(it, _m.player)
		name_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
		avail_row.add_child(name_lbl)

		var equip_btn: Button = Button.new()
		equip_btn.text = "Equip"
		equip_btn.custom_minimum_size = Vector2(60, 26)
		equip_btn.pressed.connect(on_equip.bind(it))
		avail_row.add_child(equip_btn)

	return col


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
