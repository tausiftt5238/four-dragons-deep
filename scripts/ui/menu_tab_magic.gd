class_name MenuTabMagic extends RefCounted

var _m

func _init(menu) -> void:
	_m = menu


func build() -> void:
	var p: PlayerCharacter = _m.player

	var mp_lbl: Label = Label.new()
	mp_lbl.text = "MP:  %d / %d" % [p.mp, p.max_mp]
	mp_lbl.add_theme_color_override("font_color", Color(0.4, 0.6, 1.0))
	_m._content.add_child(mp_lbl)

	_m._content.add_child(HSeparator.new())

	if p.known_spells.is_empty():
		var none_lbl: Label = Label.new()
		none_lbl.text = "No spells known."
		none_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		_m._content.add_child(none_lbl)
		return

	for spell_id: String in p.known_spells:
		var spell: Dictionary = Spell.get_data(spell_id)
		if spell.is_empty():
			continue
		_m._content.add_child(_make_spell_row(spell_id, spell))


func _make_spell_row(_spell_id: String, spell: Dictionary) -> HBoxContainer:
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
		cast_btn.disabled = (_m.player.mp < spell["mp"])
		cast_btn.pressed.connect(func():
			_m.player.mp -= spell["mp"]
			var heal_amt: int = spell.get("heal", 0)
			var before: int = _m.player.hp
			_m.player.heal(heal_amt)
			var restored: int = _m.player.hp - before
			_m._set_status("Cast %s — restored %d HP." % [spell["name"], restored])
			_m._refresh()
		)
		row.add_child(cast_btn)
	else:
		var tag: Label = Label.new()
		tag.text = "Battle only"
		tag.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		row.add_child(tag)

	return row
