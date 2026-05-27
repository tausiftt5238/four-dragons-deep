class_name MenuTabBestiary extends RefCounted

var _m

func _init(menu) -> void:
	_m = menu


func build() -> void:
	_m._content.add_child(_make_header("BESTIARY"))
	_m._content.add_child(HSeparator.new())

	if _m.player.encountered_enemies.is_empty():
		var none_lbl: Label = Label.new()
		none_lbl.text = "No enemies recorded yet."
		none_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		_m._content.add_child(none_lbl)
		return

	for enemy_name: String in _m.player.encountered_enemies:
		var tmpl: Dictionary = {}
		for t: Dictionary in Enemy.TEMPLATES:
			if t["name"] == enemy_name:
				tmpl = t
				break
		if tmpl.is_empty():
			continue
		_m._content.add_child(_make_bestiary_entry(tmpl))
		_m._content.add_child(HSeparator.new())


func _make_bestiary_entry(tmpl: Dictionary) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

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
	_add_info_line(info, "Talk: %s" % ("Yes" if neg else "No"),
		Color(0.50, 0.90, 0.60) if neg else Color(0.65, 0.35, 0.35))

	if tmpl["name"] in _m.player.recruited:
		_add_info_line(info, "[RECRUITED]", Color(0.30, 1.0, 0.55))

	return row


func _add_info_line(parent: VBoxContainer, text: String, color: Color) -> void:
	var lbl: Label = Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", 12)
	parent.add_child(lbl)


func _make_header(text: String) -> Label:
	var lbl: Label = Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", Color(0.95, 0.88, 0.60))
	return lbl
