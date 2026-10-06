class_name MenuTabStats extends RefCounted

var _m

func _init(menu) -> void:
	_m = menu


# One card per member, hero first then the demons in slot order. The chosen
# card is open (bars, stats, what is worn, the element chart); the rest fold
# to their name and bars. Up and down move the choice, and a click opens the
# card clicked. Which one is open survives a rebuild of the page.
const OPEN_META: String = "stats_open"

var _cards: Array[Dictionary] = []


func build() -> void:
	# The cards call back into this page as the cursor moves, so the menu
	# holds on to it while it is up (MenuTabs makes and drops it otherwise).
	_m.set_meta("stats_page", self)
	var p: PlayerCharacter = _m.player
	var members: Array = [""]
	members.append_array(p.active_demons)
	var open_i: int = clampi(int(_m.get_meta(OPEN_META, 0)), 0, members.size() - 1)
	for i: int in members.size():
		var card: Dictionary = _hero_card(p) if i == 0 else _demon_card(p, members[i] as String)
		_cards.append(card)
		(card["box"] as Control).focus_entered.connect(_open.bind(i))
		(card["box"] as Control).focus_exited.connect(_paint.bind(i))
	_open(open_i)


func _open(i: int) -> void:
	_m.set_meta(OPEN_META, i)
	for j: int in _cards.size():
		(_cards[j]["detail"] as Control).visible = (j == i)
		_paint(j)


# The open card is lit; the one under the cursor has a gold edge.
func _paint(i: int) -> void:
	if i >= _cards.size():
		return
	var box: PanelContainer = _cards[i]["box"] as PanelContainer
	if not is_instance_valid(box):
		return
	var open: bool = (_cards[i]["detail"] as Control).visible
	var st: StyleBoxFlat = StyleBoxFlat.new()
	st.bg_color = Color(1, 1, 1, 0.06) if open else Color(1, 1, 1, 0.02)
	st.border_color = Color(1.0, 0.86, 0.42)
	st.set_border_width_all(2 if box.has_focus() else 0)
	st.set_corner_radius_all(4)
	st.set_content_margin_all(8)
	box.add_theme_stylebox_override("panel", st)


# The card's frame, its always-shown head (portrait, name, bars) and the part
# that folds away.
func _card_shell(title: String, title_color: Color, portrait: AnimatedPortrait) -> Dictionary:
	var box: PanelContainer = PanelContainer.new()
	box.focus_mode = Control.FOCUS_ALL
	box.set_meta("card", true)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_m._content.add_child(box)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(col)
	var head: HBoxContainer = HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(head)
	var side: float = 56.0 if Layout.landscape() else 72.0
	portrait.custom_minimum_size = Vector2(side, side)
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(portrait)
	var bars: VBoxContainer = VBoxContainer.new()
	bars.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bars.add_theme_constant_override("separation", 3)
	head.add_child(bars)
	var name_lbl: Label = Label.new()
	name_lbl.text = title
	name_lbl.add_theme_color_override("font_color", title_color)
	bars.add_child(name_lbl)
	var detail: VBoxContainer = VBoxContainer.new()
	detail.add_theme_constant_override("separation", 6)
	col.add_child(detail)
	return {box = box, bars = bars, detail = detail}


func _hero_card(p: PlayerCharacter) -> Dictionary:
	var portrait: AnimatedPortrait = AnimatedPortrait.new()
	portrait.load_sprite_id(p.hero_sprite_id())
	portrait.set_zoom(3.0)
	var card: Dictionary = _card_shell("%s   LV %d" % [PlayerCharacter.DISPLAY_NAME, p.lv],
			Color(0.95, 0.88, 0.60), portrait)
	var bars: VBoxContainer = card["bars"] as VBoxContainer
	bars.add_child(_make_bar_row("HP",  p.hp,  p.max_hp,      Color(0.20, 0.78, 0.25)))
	bars.add_child(_make_bar_row("MP",  p.mp,  p.max_mp,      Color(0.28, 0.50, 1.00)))
	bars.add_child(_make_bar_row("EXP", p.exp, p.exp_to_next, Color(0.90, 0.70, 0.10)))

	var detail: VBoxContainer = card["detail"] as VBoxContainer
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 5)
	_add_stat_row(grid, "STR", p.str, p.effective_str())
	_add_stat_row(grid, "DEF", p.def, p.effective_def())
	_add_stat_row(grid, "MAG", p.mag, p.effective_mag())
	_add_stat_row(grid, "AGL", p.agl, p.effective_agl())
	_add_stat_row(grid, "LUK", p.luk, p.effective_luk())
	# A wide screen has the room to say what he is wearing beside the numbers
	# it moves; a phone leaves that to the Equipment tab.
	if Layout.landscape():
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 40)
		detail.add_child(row)
		row.add_child(grid)
		row.add_child(_worn(p))
	else:
		detail.add_child(grid)

	# What he takes from each line, gear included — the same chart a demon gets
	# in a fight once it has been read.
	detail.add_child(AffinityChart.snapshot(p))

	var gold_lbl: Label = Label.new()
	gold_lbl.text = "Gold:  %d gp" % p.gold
	gold_lbl.add_theme_color_override("font_color", Color(0.95, 0.82, 0.25))
	detail.add_child(gold_lbl)

	if not p.active_statuses.is_empty():
		detail.add_child(_make_section_label("Active ailments"))
		for s_id: String in p.active_statuses:
			var sdata: Dictionary = Status.get_data(s_id)
			var s_lbl: Label = Label.new()
			s_lbl.text = "%s — %s" % [sdata.get("name", s_id), sdata.get("desc", "")]
			s_lbl.add_theme_color_override("font_color", sdata.get("color", Color(0.9, 0.9, 0.9)))
			detail.add_child(s_lbl)
	return card


# A demon is rebuilt whole for every fight, so its bars read full: what
# matters here is its ceiling.
func _demon_card(p: PlayerCharacter, demon_name: String) -> Dictionary:
	var demon: Enemy = p.bound_demon(demon_name)
	var portrait: AnimatedPortrait = AnimatedPortrait.new()
	if demon.abyss_element != "":
		portrait.material = Abyss.palette_material(demon.abyss_element)
	if demon.sprite_id != "":
		portrait.load_sprite_id(demon.sprite_id)
	else:
		var ptex: Texture2D = demon.static_portrait()
		if ptex != null:
			portrait.load_static(ptex)
	portrait.set_zoom(3.0)
	var card: Dictionary = _card_shell("%s   LV %d" % [demon_name, demon.lv],
			Color(0.80, 0.62, 1.00), portrait)
	var bars: VBoxContainer = card["bars"] as VBoxContainer
	bars.add_child(_make_bar_row("HP", demon.max_hp, demon.max_hp, Color(0.20, 0.78, 0.25)))
	bars.add_child(_make_bar_row("MP", demon.max_mp, demon.max_mp, Color(0.28, 0.50, 1.00)))
	# A demon stops banking exp at the hero's level, so there is no bar to
	# fill until he climbs.
	if demon.lv >= p.lv:
		var capped: Label = Label.new()
		capped.text = "EXP   at your level"
		capped.add_theme_color_override("font_color", Color(0.55, 0.55, 0.60))
		bars.add_child(capped)
	else:
		bars.add_child(_make_bar_row("EXP", int(p.demon_exp.get(demon_name, 0)),
				PlayerCharacter.demon_exp_to_next(demon.lv), Color(0.90, 0.70, 0.10)))

	var detail: VBoxContainer = card["detail"] as VBoxContainer
	var grid: GridContainer = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 5)
	detail.add_child(grid)
	for pair: Array in [["STR", demon.str], ["DEF", demon.def],
			["MAG", demon.mag], ["AGL", demon.agl]]:
		_add_stat_row(grid, pair[0] as String, int(pair[1]), int(pair[1]))
	detail.add_child(AffinityChart.snapshot(demon))
	demon.free()
	return card


# Weapon, armour and trinkets, named under small headings.
func _worn(p: PlayerCharacter) -> VBoxContainer:
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var trinkets: Array[String] = []
	for acc: Dictionary in p.equipped_accessories:
		trinkets.append(acc.get("name", "") as String)
	for part: Array in [["Weapon", [p.equipped_weapon.get("name", "-")]],
			["Armour", [p.equipped_armor.get("name", "-")]],
			["Trinkets", trinkets if not trinkets.is_empty() else ["-"]]]:
		col.add_child(_make_section_label(part[0] as String))
		for n: Variant in part[1]:
			var l: Label = Label.new()
			l.text = str(n)
			l.clip_text = true
			col.add_child(l)
	return col


func _add_stat_row(grid: GridContainer, stat_name: String, base: int, eff: int) -> void:
	var name_lbl: Label = Label.new()
	name_lbl.text = stat_name
	name_lbl.add_theme_color_override("font_color",
			StageArrows.tint_for(stat_name, Color(0.85, 0.85, 0.88)))
	grid.add_child(name_lbl)

	var val_lbl: Label = Label.new()
	var diff: int = eff - base
	if diff != 0:
		val_lbl.text = "%d  (%+d)" % [eff, diff]
		val_lbl.add_theme_color_override("font_color",
			Color(0.35, 0.90, 0.35) if diff > 0 else Color(0.90, 0.35, 0.35))
	else:
		val_lbl.text = str(base)
	grid.add_child(val_lbl)


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
	bar.custom_minimum_size = Vector2(0, 10 if Layout.landscape() else 20)
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
