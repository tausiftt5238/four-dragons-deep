class_name MenuTabStats extends RefCounted

var _m

func _init(menu) -> void:
	_m = menu


func build() -> void:
	var p: PlayerCharacter = _m.player

	_m._content.add_child(_make_header("%s   LV %d" % [PlayerCharacter.DISPLAY_NAME.to_upper(), p.lv]))
	_m._content.add_child(HSeparator.new())

	var portrait_row: HBoxContainer = HBoxContainer.new()
	portrait_row.add_theme_constant_override("separation", 16)
	_m._content.add_child(portrait_row)

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

	_m._content.add_child(HSeparator.new())

	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 5)
	_m._content.add_child(grid)

	_add_stat_row(grid, "STR", p.str, p.effective_str())
	_add_stat_row(grid, "DEF", p.def, p.effective_def())
	_add_stat_row(grid, "MAG", p.mag, p.effective_mag())
	_add_stat_row(grid, "AGL", p.agl, p.effective_agl())

	_m._content.add_child(HSeparator.new())

	var gold_lbl: Label = Label.new()
	gold_lbl.text = "Gold:  %d gp" % p.gold
	gold_lbl.add_theme_color_override("font_color", Color(0.95, 0.82, 0.25))
	_m._content.add_child(gold_lbl)

	if not p.active_statuses.is_empty():
		_m._content.add_child(HSeparator.new())
		_m._content.add_child(_make_section_label("ACTIVE AILMENTS"))
		for s_id: String in p.active_statuses:
			var sdata: Dictionary = Status.get_data(s_id)
			var s_lbl: Label = Label.new()
			s_lbl.text = "%s — %s" % [sdata.get("name", s_id), sdata.get("desc", "")]
			s_lbl.add_theme_color_override("font_color", sdata.get("color", Color(0.9, 0.9, 0.9)))
			_m._content.add_child(s_lbl)


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
