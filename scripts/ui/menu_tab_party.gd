# MenuTabParty
# The rolodex. Every demon bound so far is listed; the ones summoned here are
# the ones already standing on the field when the next battle opens, each
# carrying its own press-turn icon. Summon in battle only fills a slot that
# opens up mid-fight — this is where the loadout is actually decided.
class_name MenuTabParty extends RefCounted

var _m


func _init(menu) -> void:
	_m = menu


func build() -> void:
	var p: PlayerCharacter = _m.player

	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 20)
	_m._content.add_child(header)

	var slots_lbl: Label = Label.new()
	slots_lbl.text = "Summoned:  %d / %d" % [p.active_demons.size(), PlayerCharacter.ACTIVE_SLOTS]
	slots_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slots_lbl.add_theme_color_override("font_color",
		Color(1.0, 0.85, 0.35) if p.has_free_demon_slot() else Color(0.60, 0.62, 0.68))
	header.add_child(slots_lbl)

	var icons_lbl: Label = Label.new()
	icons_lbl.text = "Press turns:  %d" % (p.active_demons.size() + 1)
	icons_lbl.add_theme_color_override("font_color", Color(0.55, 0.95, 1.0))
	header.add_child(icons_lbl)

	var hint: Label = Label.new()
	hint.text = "Summoned demons start the battle on the field — each one is another action per turn. A demon that falls is gone for good; buy it back at an orb."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.55, 0.55, 0.60))
	_m._content.add_child(hint)

	_m._content.add_child(HSeparator.new())

	if p.recruited.is_empty():
		var none_lbl: Label = Label.new()
		none_lbl.text = "No demons bound yet. Talk one down in battle."
		none_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		_m._content.add_child(none_lbl)
		return

	# Summoned first and in slot order, so the list reads as the party line-up.
	var ordered: Array[String] = []
	for demon_name: String in p.active_demons:
		ordered.append(demon_name)
	for other: String in p.recruited:
		if not p.is_active(other):
			ordered.append(other)

	_m.add_paged_list(_m._content, "party", ordered,
			func(list: SlotList, name: String) -> void: _add_demon(list, name))


func _add_demon(list: SlotList, demon_name: String) -> void:
	var p: PlayerCharacter = _m.player
	var active: bool = p.is_active(demon_name)
	var demon: Enemy = Enemy.make_from_name(demon_name)
	var about: String = "HP %d   MP %d   %s   %s" % [
			demon.max_hp, demon.max_mp, _element_text(demon), _chart(demon)]
	demon.free()

	list.add("%s%s" % ["* " if active else "", demon_name],
			Color(0.62, 0.92, 0.74) if active else Color(0.52, 0.52, 0.56),
			about, "", Color.WHITE,
			"Dismiss" if active else "Summon",
			not active and not p.has_free_demon_slot(),
			func() -> void:
				if active:
					p.deactivate_demon(demon_name)
					_m._set_status("Dismissed %s." % demon_name)
				elif p.activate_demon(demon_name):
					_m._set_status("%s will walk in with you." % demon_name)
				else:
					_m._set_status("All %d slots are taken." % PlayerCharacter.ACTIVE_SLOTS)
				_m._refresh())


# ── Row pieces ───────────────────────────────────

func _element_text(demon: Enemy) -> String:
	if demon.attack_element == "":
		return "no element"
	return "%s  %d MP" % [Affinity.element_name(demon.attack_element),
			demon.skill_cost()]


# Its affinities, written the way the battle log writes them.
func _chart(demon: Enemy) -> String:
	var parts: Array[String] = []
	for element: String in Affinity.ELEMENTS:
		var state: String = demon.affinity_of(element)
		if state != Affinity.NORMAL:
			parts.append("%s %s" % [Affinity.element_name(element), Affinity.label(state)])
	if parts.is_empty():
		return "no affinities"
	return "   ".join(parts)
