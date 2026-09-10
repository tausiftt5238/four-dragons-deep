# MenuTabMagic
# The spell loadout. Every spell he has learned is listed; only the ones he
# equips here are offered in battle, and there are fewer slots than spells on
# purpose — carrying Fire means not carrying Blizzard.
class_name MenuTabMagic extends RefCounted

var _m


func _init(menu) -> void:
	_m = menu


func build() -> void:
	var p: PlayerCharacter = _m.player

	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 20)
	_m._content.add_child(header)

	var mp_lbl: Label = Label.new()
	mp_lbl.text = "MP:  %d / %d" % [p.mp, p.max_mp]
	mp_lbl.add_theme_color_override("font_color", Color(0.4, 0.6, 1.0))
	header.add_child(mp_lbl)

	var slots_lbl: Label = Label.new()
	slots_lbl.text = "EQUIPPED:  %d / %d" % [p.equipped_spells.size(), PlayerCharacter.SPELL_SLOTS]
	slots_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slots_lbl.add_theme_color_override("font_color",
		Color(1.0, 0.85, 0.35) if p.has_free_slot() else Color(0.60, 0.62, 0.68))
	header.add_child(slots_lbl)

	var hint: Label = Label.new()
	hint.text = "Only equipped spells appear in battle."
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.55, 0.55, 0.60))
	_m._content.add_child(hint)

	_m._content.add_child(HSeparator.new())

	if p.known_spells.is_empty():
		var none_lbl: Label = Label.new()
		none_lbl.text = "No spells known."
		none_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		_m._content.add_child(none_lbl)
		return

	# Equipped first, so the loadout reads as a block rather than being hunted
	# for among everything he has ever learned.
	for spell_id: String in p.equipped_spells:
		var eq: Dictionary = Spell.get_data(spell_id)
		if not eq.is_empty():
			_m._content.add_child(_make_spell_row(spell_id, eq, true))

	for spell_id2: String in p.known_spells:
		if p.is_equipped(spell_id2):
			continue
		var sp: Dictionary = Spell.get_data(spell_id2)
		if not sp.is_empty():
			_m._content.add_child(_make_spell_row(spell_id2, sp, false))


func _make_spell_row(spell_id: String, spell: Dictionary, equipped: bool) -> HBoxContainer:
	var p: PlayerCharacter = _m.player

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var mark: Label = Label.new()
	mark.text = "*" if equipped else " "
	mark.custom_minimum_size = Vector2(12, 0)
	mark.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	row.add_child(mark)

	var name_lbl: Label = Label.new()
	name_lbl.text = spell["name"]
	name_lbl.custom_minimum_size = Vector2(78, 0)
	if not equipped:
		name_lbl.add_theme_color_override("font_color", Color(0.52, 0.52, 0.56))
	else:
		name_lbl.add_theme_color_override("font_color",
			Color(0.5, 0.8, 1.0) if spell["type"] == "heal" else Color(1.0, 0.55, 0.2))
	row.add_child(name_lbl)

	var element: String = spell.get("element", "")
	var el_lbl: Label = Label.new()
	el_lbl.text = Affinity.element_name(element) if element != "" \
			else (spell.get("type", "dmg") as String).capitalize()
	el_lbl.custom_minimum_size = Vector2(56, 0)
	el_lbl.add_theme_color_override("font_color", Color(0.62, 0.58, 0.72))
	row.add_child(el_lbl)

	var mp_lbl: Label = Label.new()
	mp_lbl.text = "%d MP" % spell["mp"]
	mp_lbl.custom_minimum_size = Vector2(52, 0)
	mp_lbl.add_theme_color_override("font_color", Color(0.4, 0.55, 0.95))
	row.add_child(mp_lbl)

	var desc_lbl: Label = Label.new()
	desc_lbl.text = spell.get("desc", "")
	desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	row.add_child(desc_lbl)

	# Heals are the only thing worth casting outside a fight.
	if spell["type"] == "heal":
		var cast_btn: Button = Button.new()
		cast_btn.text = "Cast"
		cast_btn.custom_minimum_size = Vector2(52, 26)
		cast_btn.disabled = (p.mp < spell["mp"])
		cast_btn.pressed.connect(func() -> void:
			p.mp -= spell["mp"]
			var before: int = p.hp
			p.heal(int(spell.get("heal", 0)))
			_m._set_status("Cast %s — restored %d HP." % [spell["name"], p.hp - before])
			_m._refresh()
		)
		row.add_child(cast_btn)

	var slot_btn: Button = Button.new()
	slot_btn.custom_minimum_size = Vector2(78, 26)
	if equipped:
		slot_btn.text = "Unequip"
		slot_btn.pressed.connect(func() -> void:
			p.unequip_spell(spell_id)
			_m._set_status("Unequipped %s." % spell["name"])
			_m._refresh()
		)
	else:
		slot_btn.text = "Equip"
		slot_btn.disabled = not p.has_free_slot()
		slot_btn.pressed.connect(func() -> void:
			if p.equip_spell(spell_id):
				_m._set_status("Equipped %s." % spell["name"])
			else:
				_m._set_status("All %d slots are full." % PlayerCharacter.SPELL_SLOTS)
			_m._refresh()
		)
	row.add_child(slot_btn)

	return row
