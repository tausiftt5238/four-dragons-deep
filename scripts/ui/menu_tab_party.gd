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
	slots_lbl.text = "Summoned %d/%d" % [p.active_demons.size(), PlayerCharacter.ACTIVE_SLOTS]
	slots_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slots_lbl.add_theme_color_override("font_color",
		Color(1.0, 0.85, 0.35) if p.has_free_demon_slot() else Color(0.60, 0.62, 0.68))
	header.add_child(slots_lbl)

	var bound_lbl: Label = Label.new()
	bound_lbl.text = "Bound %d/%d" % [p.recruited.size(), PlayerCharacter.ROSTER_SIZE]
	bound_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bound_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.92))
	header.add_child(bound_lbl)

	var icons_lbl: Label = Label.new()
	icons_lbl.text = "Press turns %d" % (p.active_demons.size() + 1)
	icons_lbl.add_theme_color_override("font_color", Color(0.55, 0.95, 1.0))
	header.add_child(icons_lbl)

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
	var demon: Enemy = p.bound_demon(demon_name)
	var about: String = "Lv %d   HP %d   MP %d\n%s" % [
			demon.lv, demon.max_hp, demon.max_mp, _skill_text(p, demon_name)]
	var chart: AffinityChart = AffinityChart.compact(demon)
	demon.free()

	list.add_entry("%s%s" % ["* " if active else "", demon_name],
			Color(0.62, 0.92, 0.74) if active else Color(0.52, 0.52, 0.56),
			about, "", Color.WHITE,
			[{text = "Dismiss" if active else "Summon",
				disabled = not active and not p.has_free_demon_slot(),
				press = func() -> void:
					if active:
						p.deactivate_demon(demon_name)
						_m._set_status("Dismissed %s." % demon_name)
					elif p.activate_demon(demon_name):
						_m._set_status("%s will walk in with you." % demon_name)
					else:
						_m._set_status("All %d slots are taken." % PlayerCharacter.ACTIVE_SLOTS)
					_m._refresh()}] as Array[Dictionary],
			null, chart)


# ── Row pieces ───────────────────────────────────

# Everything it can call on, which is the only place outside a fight that a
# demon's growth is visible: a rung it has climbed and a buff it has picked up
# both show up here by name.
func _skill_text(p: PlayerCharacter, demon_name: String) -> String:
	var known: Array = p.skills_of(demon_name)
	if known.is_empty():
		return "[color=#8b8f99]knows nothing it can call on[/color]"
	var names: Array[String] = []
	for skill: Dictionary in known:
		var colour: String = "c9a6ff" if skill.get("kind", "") == "support" else "7fd4ff"
		names.append("[color=#%s]%s[/color]" % [colour,
				PlayerCharacter.skill_name(skill)])
	return "%s   [color=#8b8f99]%d/%d[/color]" % [
			"  ".join(names), known.size(), PlayerCharacter.DEMON_SKILL_CAP]

