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
	slots_lbl.text = "SUMMONED:  %d / %d" % [p.active_demons.size(), PlayerCharacter.ACTIVE_SLOTS]
	slots_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slots_lbl.add_theme_color_override("font_color",
		Color(1.0, 0.85, 0.35) if p.has_free_demon_slot() else Color(0.60, 0.62, 0.68))
	header.add_child(slots_lbl)

	var icons_lbl: Label = Label.new()
	icons_lbl.text = "PRESS TURNS:  %d" % (p.active_demons.size() + 1)
	icons_lbl.add_theme_color_override("font_color", Color(0.55, 0.95, 1.0))
	header.add_child(icons_lbl)

	var hint: Label = Label.new()
	hint.text = "Summoned demons start the battle on the field — each one is another action per turn. A demon that falls is gone for good; buy it back at an orb."
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

	# Summoned first and in slot order, so the row reads as the party line-up.
	for demon_name: String in p.active_demons:
		_m._content.add_child(_make_row(demon_name, true))

	for other: String in p.recruited:
		if not p.is_active(other):
			_m._content.add_child(_make_row(other, false))


func _make_row(demon_name: String, active: bool) -> HBoxContainer:
	var p: PlayerCharacter = _m.player
	# Built at the detective's level, which is what it would join a battle as.
	var demon: Enemy = Enemy.make_from_name(demon_name)

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var mark: Label = Label.new()
	mark.text = "*" if active else " "
	mark.custom_minimum_size = Vector2(12, 0)
	mark.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	row.add_child(mark)

	var name_lbl: Label = Label.new()
	name_lbl.text = demon_name
	name_lbl.custom_minimum_size = Vector2(120, 0)
	name_lbl.add_theme_color_override("font_color",
		Color(0.62, 0.92, 0.74) if active else Color(0.52, 0.52, 0.56))
	row.add_child(name_lbl)

	var hp_lbl: Label = Label.new()
	hp_lbl.text = "HP %d   MP %d" % [demon.max_hp, demon.max_mp]
	hp_lbl.custom_minimum_size = Vector2(128, 0)
	hp_lbl.add_theme_color_override("font_color", Color(0.62, 0.72, 0.68))
	row.add_child(hp_lbl)

	# The element it brings is the reason to pick one demon over another.
	var skill_lbl: Label = Label.new()
	if demon.attack_element != "":
		skill_lbl.text = "%s  %d MP" % [
				Affinity.element_name(demon.attack_element), demon.skill_cost()]
		skill_lbl.add_theme_color_override("font_color", Color(1.0, 0.72, 0.35))
	else:
		skill_lbl.text = "no element"
		skill_lbl.add_theme_color_override("font_color", Color(0.45, 0.45, 0.50))
	skill_lbl.custom_minimum_size = Vector2(132, 0)
	row.add_child(skill_lbl)

	var chart_lbl: Label = Label.new()
	chart_lbl.text = _chart(demon)
	chart_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chart_lbl.add_theme_font_size_override("font_size", 11)
	chart_lbl.add_theme_color_override("font_color", Color(0.66, 0.66, 0.74))
	row.add_child(chart_lbl)

	var btn: Button = Button.new()
	btn.custom_minimum_size = Vector2(88, 26)
	if active:
		btn.text = "Dismiss"
		btn.pressed.connect(func() -> void:
			p.deactivate_demon(demon_name)
			_m._set_status("Dismissed %s." % demon_name)
			_m._refresh()
		)
	else:
		btn.text     = "Summon"
		btn.disabled = not p.has_free_demon_slot()
		btn.pressed.connect(func() -> void:
			if p.activate_demon(demon_name):
				_m._set_status("%s will walk in with you." % demon_name)
			else:
				_m._set_status("All %d slots are taken." % PlayerCharacter.ACTIVE_SLOTS)
			_m._refresh()
		)
	row.add_child(btn)

	demon.free()
	return row


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
