class_name MenuTabStats extends RefCounted

var _m

func _init(menu) -> void:
	_m = menu


# The party in fixed rows, hero first then the demons in slot order, and
# under them one fixed window with the chosen member's details. Nothing grows
# or moves as the choice changes: up and down (or a click) change whose
# details the window shows, and the rows stay as they are. The row count is
# always the party's limit, blank rows included, for the same reason.
const OPEN_META: String = "stats_open"
const ROWS: int = 4
const ROW_H: float = 60.0
const DETAIL_H: float = 176.0

var _rows: Array[PanelContainer] = []
var _members: Array = []
var _detail: VBoxContainer


func build() -> void:
	# The rows call back into this page as the cursor moves, so the menu
	# holds on to it while it is up (MenuTabs makes and drops it otherwise).
	_m.set_meta("stats_page", self)
	var p: PlayerCharacter = _m.player
	_members = [""]
	_members.append_array(p.active_demons)
	var big: bool = not Layout.landscape()
	for i: int in ROWS:
		var row: PanelContainer = _row(p, _members[i] as String if i < _members.size() else "",
				i < _members.size(), big)
		_rows.append(row)
		if i < _members.size():
			row.focus_entered.connect(_choose.bind(i))
			row.focus_exited.connect(_paint)
	var win: PanelContainer = PanelContainer.new()
	win.custom_minimum_size = Vector2(0, DETAIL_H * (1.6 if big else 1.0))
	win.clip_contents = true
	var st: StyleBoxFlat = StyleBoxFlat.new()
	st.bg_color = Color(1, 1, 1, 0.04)
	st.set_corner_radius_all(4)
	st.set_content_margin_all(8)
	win.add_theme_stylebox_override("panel", st)
	_m._content.add_child(win)
	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override("separation", 6)
	win.add_child(_detail)
	_choose(clampi(int(_m.get_meta(OPEN_META, 0)), 0, _members.size() - 1))


func _choose(i: int) -> void:
	_m.set_meta(OPEN_META, i)
	for c: Node in _detail.get_children():
		c.queue_free()
	if i == 0:
		_hero_detail(_m.player)
	else:
		_demon_detail(_m.player, _members[i] as String)
	_paint()


# The chosen row is lit; the one under the cursor has a gold edge.
func _paint() -> void:
	var chosen: int = int(_m.get_meta(OPEN_META, 0))
	for i: int in _rows.size():
		var row: PanelContainer = _rows[i]
		if not is_instance_valid(row):
			continue
		var st: StyleBoxFlat = StyleBoxFlat.new()
		st.bg_color = Color(0.20, 0.24, 0.48) if i == chosen and i < _members.size() \
				else Color(1, 1, 1, 0.03)
		st.border_color = Color(1.0, 0.86, 0.42)
		st.set_border_width_all(2 if row.has_focus() else 0)
		st.set_corner_radius_all(4)
		st.content_margin_left = 8
		st.content_margin_right = 8
		st.content_margin_top = 4
		st.content_margin_bottom = 4
		row.add_theme_stylebox_override("panel", st)


# One member's row: portrait, name and level, and the three bars. A blank
# row when there is no one in that place.
func _row(p: PlayerCharacter, demon_name: String, filled: bool, big: bool) -> PanelContainer:
	var box: PanelContainer = PanelContainer.new()
	box.custom_minimum_size = Vector2(0, ROW_H * (1.5 if big else 1.0))
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_m._content.add_child(box)
	if not filled:
		return box
	box.focus_mode = Control.FOCUS_ALL
	box.set_meta("card", true)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(row)

	var portrait: AnimatedPortrait = AnimatedPortrait.new()
	var title: String
	var color: Color
	var hp: Array
	var mp: Array
	var exp_row: Control
	var lv_text: String = ""
	if demon_name == "":
		portrait.load_sprite_id(p.hero_sprite_id())
		title = PlayerCharacter.DISPLAY_NAME
		color = Color(0.95, 0.88, 0.60)
		hp = [p.hp, p.max_hp]
		mp = [p.mp, p.max_mp]
		exp_row = _make_bar_row("EXP", p.exp, p.exp_to_next, Color(0.90, 0.70, 0.10))
		lv_text = "LV %d" % p.lv
	else:
		var demon: Enemy = p.bound_demon(demon_name)
		if demon.abyss_element != "":
			portrait.material = Abyss.palette_material(demon.abyss_element)
		if demon.sprite_id != "":
			portrait.load_sprite_id(demon.sprite_id)
		else:
			var ptex: Texture2D = demon.static_portrait()
			if ptex != null:
				portrait.load_static(ptex)
		title = demon_name
		lv_text = "LV %d" % demon.lv
		color = Color(0.80, 0.62, 1.00)
		# Rebuilt whole for every fight, so its bars read full.
		hp = [demon.max_hp, demon.max_hp]
		mp = [demon.max_mp, demon.max_mp]
		# A demon stops banking exp at the hero's level.
		if demon.lv >= p.lv:
			exp_row = _make_bar_row("EXP", 0, 0, Color(0.90, 0.70, 0.10), "at your level")
		else:
			exp_row = _make_bar_row("EXP", int(p.demon_exp.get(demon_name, 0)),
					PlayerCharacter.demon_exp_to_next(demon.lv), Color(0.90, 0.70, 0.10))
		demon.free()
	portrait.set_zoom(3.0)
	var side: float = 40.0 * (1.5 if big else 1.0)
	portrait.custom_minimum_size = Vector2(side, side)
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(portrait)

	# The name, and the level under it.
	var names: VBoxContainer = VBoxContainer.new()
	names.custom_minimum_size = Vector2(110 if not big else 170, 0)
	names.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	names.add_theme_constant_override("separation", 0)
	row.add_child(names)
	var name_lbl: Label = Label.new()
	name_lbl.text = title
	name_lbl.clip_text = true
	name_lbl.add_theme_color_override("font_color", color)
	names.add_child(name_lbl)
	var lv_lbl: Label = Label.new()
	lv_lbl.text = lv_text
	lv_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.62))
	if not big:
		lv_lbl.add_theme_font_size_override("font_size", SidePanel.SMALL)
	names.add_child(lv_lbl)

	var bars: VBoxContainer = VBoxContainer.new()
	bars.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bars.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bars.add_theme_constant_override("separation", 0)
	row.add_child(bars)
	bars.add_child(_make_bar_row("HP", int(hp[0]), int(hp[1]), Color(0.20, 0.78, 0.25)))
	bars.add_child(_make_bar_row("MP", int(mp[0]), int(mp[1]), Color(0.28, 0.50, 1.00)))
	bars.add_child(exp_row)
	return box


func _hero_detail(p: PlayerCharacter) -> void:
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 2)
	_add_stat_row(grid, "STR", p.str, p.effective_str())
	_add_stat_row(grid, "DEF", p.def, p.effective_def())
	_add_stat_row(grid, "MAG", p.mag, p.effective_mag())
	_add_stat_row(grid, "AGL", p.agl, p.effective_agl())
	_add_stat_row(grid, "LUK", p.luk, p.effective_luk())
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 40)
	_detail.add_child(row)
	row.add_child(grid)
	row.add_child(_worn(p))
	# What he takes from each line, gear included — the same chart a demon gets
	# in a fight once it has been read.
	_detail.add_child(AffinityChart.snapshot(p))


func _demon_detail(p: PlayerCharacter, demon_name: String) -> void:
	var demon: Enemy = p.bound_demon(demon_name)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 2)
	_detail.add_child(grid)
	for pair: Array in [["STR", demon.str], ["DEF", demon.def],
			["MAG", demon.mag], ["AGL", demon.agl]]:
		_add_stat_row(grid, pair[0] as String, int(pair[1]), int(pair[1]))
	_detail.add_child(AffinityChart.snapshot(demon))
	demon.free()


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


func _make_bar_row(label: String, current: int, maximum: int, color: Color,
		note: String = "") -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	# Three of these stand in one fixed row on a wide screen: the small size.
	var small: bool = Layout.landscape()
	var lbl: Label = Label.new()
	lbl.text = "%-4s" % label
	lbl.custom_minimum_size = Vector2(44 if small else 38, 0)
	if small:
		lbl.add_theme_font_size_override("font_size", SidePanel.SMALL)
	row.add_child(lbl)

	var bar: ProgressBar = ProgressBar.new()
	bar.min_value = 0
	bar.max_value = max(1, maximum)
	bar.value     = current
	bar.show_percentage = false
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.custom_minimum_size = Vector2(0, 6 if small else 20)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("fill", fill)
	row.add_child(bar)

	var num_lbl: Label = Label.new()
	num_lbl.text = note if note != "" else "%d / %d" % [current, maximum]
	num_lbl.custom_minimum_size = Vector2(90, 0)
	num_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if small:
		num_lbl.add_theme_font_size_override("font_size", SidePanel.SMALL)
		# One width for every number column, words included, so the bars
		# all end in the same place.
		num_lbl.custom_minimum_size = Vector2(100, 0)
		num_lbl.clip_text = true
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
