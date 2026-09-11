# MenuTabEquipment
# Two slots and a drawer of trinkets. There is no weapon and no armour: what
# the detective carries is small objects with a history, and the only real
# decision is which two of them come with him.
class_name MenuTabEquipment extends RefCounted

var _m

func _init(menu) -> void:
	_m = menu


func build() -> void:
	_m._content.add_child(_make_header("WHAT HE IS CARRYING"))
	_m._content.add_child(HSeparator.new())

	var p: PlayerCharacter = _m.player

	var slots_hbox: HBoxContainer = HBoxContainer.new()
	slots_hbox.add_theme_constant_override("separation", 0)
	_m._content.add_child(slots_hbox)

	for i: int in PlayerCharacter.ACCESSORY_SLOTS:
		if i > 0:
			slots_hbox.add_child(VSeparator.new())
		var col: VBoxContainer = _build_slot(i)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slots_hbox.add_child(col)

	_m._content.add_child(HSeparator.new())
	_m._content.add_child(_make_section_label("IN THE COAT"))

	var spare: Array[Dictionary] = []
	for item: Dictionary in p.inventory:
		if item.get("type", "") == "accessory":
			spare.append(item)

	if spare.is_empty():
		var none: Label = Label.new()
		none.text = "Nothing else worth carrying."
		none.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		_m._content.add_child(none)
	else:
		for item: Dictionary in spare:
			_m._content.add_child(_spare_row(item))

	_m._content.add_child(HSeparator.new())
	_m._content.add_child(_make_section_label("WITH THEM ON"))

	var grid: GridContainer = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 5)
	_m._content.add_child(grid)

	_add_cmp_row(grid, "STR", p.str, p.effective_str())
	_add_cmp_row(grid, "DEF", p.def, p.effective_def())
	_add_cmp_row(grid, "MAG", p.mag, p.effective_mag())
	_add_cmp_row(grid, "AGL", p.agl, p.effective_agl())
	_add_cmp_row(grid, "LUK", p.luk, p.effective_luk())


func _build_slot(idx: int) -> VBoxContainer:
	var p: PlayerCharacter = _m.player
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)

	var m: MarginContainer = MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		m.add_theme_constant_override(side, 8)
	col.add_child(m)

	var inner: VBoxContainer = VBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)
	m.add_child(inner)

	var slot_lbl: Label = Label.new()
	slot_lbl.text = "SLOT %d" % (idx + 1)
	slot_lbl.add_theme_color_override("font_color", Color(0.70, 0.65, 0.50))
	inner.add_child(slot_lbl)

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	inner.add_child(row)

	if idx >= p.equipped_accessories.size():
		var none: Label = Label.new()
		none.text = "(empty)"
		none.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		none.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(none)
		return col

	var worn: Dictionary = p.equipped_accessories[idx]
	var name_lbl: Label = Label.new()
	name_lbl.text = "%s%s" % [worn["name"], GearTooltip.bonus_string(worn)]
	name_lbl.tooltip_text = GearTooltip.build(worn, p)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_color_override("font_color", Color(0.62, 0.92, 0.74))
	row.add_child(name_lbl)

	var off: Button = Button.new()
	off.text = "Take off"
	off.custom_minimum_size = Vector2(78, 26)
	off.pressed.connect(func() -> void:
		p.unequip_accessory(worn.get("id", "") as String)
		_m._set_status("Took off %s." % worn["name"])
		_m._refresh()
	)
	row.add_child(off)

	var desc: Label = Label.new()
	desc.text = worn.get("desc", "")
	desc.add_theme_font_size_override("font_size", 11)
	desc.add_theme_color_override("font_color", Color(0.55, 0.55, 0.60))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(desc)
	return col


func _spare_row(item: Dictionary) -> HBoxContainer:
	var p: PlayerCharacter = _m.player
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var name_lbl: Label = Label.new()
	name_lbl.text = "%s%s" % [item["name"], GearTooltip.bonus_string(item)]
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.tooltip_text = GearTooltip.build(item, p)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(name_lbl)

	var btn: Button = Button.new()
	btn.text = "Wear"
	btn.custom_minimum_size = Vector2(66, 26)
	btn.disabled = not p.has_free_accessory_slot()
	btn.pressed.connect(func() -> void:
		if p.equip_accessory(item):
			_m._set_status("Put on %s." % item["name"])
		else:
			_m._set_status("Both slots are taken.")
		_m._refresh()
	)
	row.add_child(btn)
	return row


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
