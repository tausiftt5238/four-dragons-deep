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
	slots_lbl.text = "Equipped:  %d / %d" % [p.equipped_spells.size(), PlayerCharacter.SPELL_SLOTS]
	slots_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slots_lbl.add_theme_color_override("font_color",
		Color(1.0, 0.85, 0.35) if p.has_free_slot() else Color(0.60, 0.62, 0.68))
	header.add_child(slots_lbl)

	_m._content.add_child(HSeparator.new())

	if p.known_spells.is_empty():
		var none_lbl: Label = Label.new()
		none_lbl.text = "No spells known."
		none_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		_m._content.add_child(none_lbl)
		return

	# Equipped first, so the loadout reads as a block rather than being hunted
	# for among everything he has ever learned.
	var ordered: Array[String] = []
	for spell_id: String in p.equipped_spells:
		if not Spell.get_data(spell_id).is_empty():
			ordered.append(spell_id)
	for spell_id2: String in p.known_spells:
		if not p.is_equipped(spell_id2) and not Spell.get_data(spell_id2).is_empty():
			ordered.append(spell_id2)

	_m.add_paged_list(_m._content, "magic", ordered,
			func(list: SlotList, spell_id: String) -> void:
				_add_spell(list, spell_id))


func _add_spell(list: SlotList, spell_id: String) -> void:
	var p: PlayerCharacter = _m.player
	var spell: Dictionary = Spell.get_data(spell_id)
	var equipped: bool = p.is_equipped(spell_id)
	var element: String = spell.get("element", "")
	var kind: String = Affinity.element_name(element) if element != "" \
			else (spell.get("type", "dmg") as String).capitalize()

	var title_color: Color = Color(0.52, 0.52, 0.56)
	if equipped:
		title_color = Color(0.5, 0.8, 1.0) if spell["type"] == "heal" \
				else Color(1.0, 0.55, 0.2)

	# Element and reach ride in the detail line rather than the title: at font
	# size 20 the button already claims a third of the row, and a title that
	# has to hold four things ends up clipped mid-word.
	var about: String = spell.get("desc", "") as String
	if element != "":
		about = "%s %s  —  %s" % [kind, Spell.reach_tag(spell_id), about]
	list.add("%s%s" % ["* " if equipped else "", spell["name"]],
			title_color, about,
			"%d MP" % int(spell["mp"]), Color(0.4, 0.55, 0.95),
			"Drop" if equipped else "Equip",
			not equipped and not p.has_free_slot(),
			func() -> void:
				if equipped:
					p.unequip_spell(spell_id)
					_m._set_status("Unequipped %s." % spell["name"])
				elif p.equip_spell(spell_id):
					_m._set_status("Equipped %s." % spell["name"])
				else:
					_m._set_status("All %d slots are full." % PlayerCharacter.SPELL_SLOTS)
				_m._refresh())
