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

	# Shelved the way the pack is: the loadout first as a block, then what is
	# not equipped by element, then healing, stat shifts and ailments. A known
	# list runs past forty by the deep floors, and as one list it had to be
	# scrolled end to end to find anything.
	var equipped: Array[String] = []
	for spell_id: String in p.equipped_spells:
		if not Spell.get_data(spell_id).is_empty():
			equipped.append(spell_id)
	var rest: Array[String] = []
	for spell_id2: String in p.known_spells:
		if not p.is_equipped(spell_id2) and not Spell.get_data(spell_id2).is_empty():
			rest.append(spell_id2)

	var groups: Array = [{title = "Equipped", entries = equipped}]
	groups.append_array(spell_groups(rest))
	_m.add_sections(_m._content, "magic", groups,
			func(list: SlotList, spell_id: String) -> void:
				_add_spell(list, spell_id))


const ELEMENT_ORDER: Array[String] = ["phys", "fire", "ice", "thunder", "light", "dark"]


# One shelf per element, then Healing, Buffs & Debuffs, Ailments and Other.
# Each keeps the order the spells were learned in.
static func spell_groups(ids: Array[String]) -> Array:
	var by_key: Dictionary = {heal = [], shift = [], ailment = [], other = []}
	for element: String in ELEMENT_ORDER:
		by_key[element] = []
	for spell_id: String in ids:
		var data: Dictionary = Spell.get_data(spell_id)
		var element: String = data.get("element", "") as String
		var kind: String = data.get("type", "") as String
		if by_key.has(element) and element != "":
			(by_key[element] as Array).append(spell_id)
		elif kind == "heal":
			(by_key["heal"] as Array).append(spell_id)
		elif kind in ["buff", "dispel"]:
			(by_key["shift"] as Array).append(spell_id)
		elif kind == "ailment":
			(by_key["ailment"] as Array).append(spell_id)
		else:
			(by_key["other"] as Array).append(spell_id)
	var out: Array = []
	for element: String in ELEMENT_ORDER:
		out.append({title = Affinity.element_name(element), entries = by_key[element]})
	out.append({title = "Healing", entries = by_key["heal"]})
	out.append({title = "Buffs & Debuffs", entries = by_key["shift"]})
	out.append({title = "Ailments", entries = by_key["ailment"]})
	out.append({title = "Other", entries = by_key["other"]})
	return out


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
	var about: String = ItemInfo.spell(spell_id)
	var cost: int = int(spell.get("mp", 0))
	var actions: Array[Dictionary] = [{
		text = "Unequip" if equipped else "Equip",
		disabled = not equipped and not p.has_free_slot(),
		press = func() -> void:
			if equipped:
				p.unequip_spell(spell_id)
				_m._set_status("Unequipped %s." % spell["name"])
			elif p.equip_spell(spell_id):
				_m._set_status("Equipped %s." % spell["name"])
			else:
				_m._set_status("All %d slots are full." % PlayerCharacter.SPELL_SLOTS)
			_m._refresh()}]

	# Healing is castable out here. Only healing: everything else in the grid
	# needs something to aim at, and an orb is the only other way to get HP back
	# — which made a known Cure useless between fights and cost gold to work
	# around. It does not need to be equipped to be cast here; the slots are
	# about what a battle offers, and this is not a battle.
	if spell.get("type", "") == "heal":
		actions.append({
			text = "Cast",
			disabled = p.mp < cost or p.hp >= p.max_hp,
			press = func() -> void:
				var before: int = p.hp
				p.mp -= cost
				p.heal(p.heal_amount_for(spell_id))
				_m._set_status("Cast %s. Restored %d HP." % [spell["name"], p.hp - before])
				_m._refresh()})

	list.add_entry("%s%s" % ["* " if equipped else "", spell["name"]],
			title_color, about,
			"", Color(0.4, 0.55, 0.95), actions)
