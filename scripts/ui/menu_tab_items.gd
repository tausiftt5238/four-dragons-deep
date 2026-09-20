# MenuTabItems
# The pack, and the belt. Only consumables on the belt reach a battle, and the
# belt is capped so the in-battle menu never needs scrolling.
class_name MenuTabItems extends RefCounted

var _m

func _init(menu) -> void:
	_m = menu


func build() -> void:
	var sort_row: HBoxContainer = HBoxContainer.new()
	sort_row.add_theme_constant_override("separation", 6)
	_m._content.add_child(sort_row)

	var sort_lbl: Label = Label.new()
	sort_lbl.text = "Sort:"
	sort_row.add_child(sort_lbl)

	for mode: String in ["type", "name"]:
		var btn: Button = Button.new()
		btn.text = mode.capitalize()
		btn.custom_minimum_size = Vector2(70, 26)
		btn.pressed.connect(func():
			_m.player.sort_inventory(mode)
			_m._refresh()
		)
		sort_row.add_child(btn)

	var belt_lbl: Label = Label.new()
	belt_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	belt_lbl.text = "Belt:  %d / %d" % [
			_m.player.equipped_items.size(), PlayerCharacter.ITEM_SLOTS]
	belt_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	belt_lbl.add_theme_color_override("font_color",
		Color(1.0, 0.85, 0.35) if _m.player.has_free_item_slot() else Color(0.60, 0.62, 0.68))
	sort_row.add_child(belt_lbl)

	_m._content.add_child(HSeparator.new())

	if _m.player.inventory.is_empty():
		SlotList.new(_m._content).add_note("Your pack is empty.")
		return

	var ids: Array[String] = []
	for item: Dictionary in _m.player.inventory:
		ids.append(item["id"] as String)
	_m.add_paged_list(_m._content, "items", ids,
			func(list: SlotList, item_id: String) -> void: _add_item(list, item_id))


func _add_item(list: SlotList, item_id: String) -> void:
	var p: PlayerCharacter = _m.player
	var item: Dictionary = {}
	for candidate: Dictionary in p.inventory:
		if candidate["id"] == item_id:
			item = candidate
			break
	if item.is_empty():
		return

	var kind: String = item["type"] as String
	var belted: bool = kind == "consumable" and p.is_item_equipped(item_id)
	var qty: int = int(item.get("qty", 1))

	var actions: Array[Dictionary] = []
	if kind == "consumable":
		actions.append({
			text = "Off" if belted else "Belt",
			disabled = not belted and not p.has_free_item_slot(),
			press = func() -> void:
				if belted:
					p.unequip_item(item_id)
					_m._set_status("Took %s off the belt." % item["name"])
				else:
					p.equip_item(item_id)
					_m._set_status("Put %s on the belt." % item["name"])
				_m._refresh()})
		# Ailments end with the fight, so an item that only cures one has nothing
		# to do out here. It still lists and still belts — the player wants to
		# see what they are carrying — but the field offers no Use for it.
		if int(item.get("hp_restore", 0)) > 0 or int(item.get("mp_restore", 0)) > 0:
			actions.append({
				text = "Use", disabled = not p.can_use_item(item),
				press = func() -> void:
					_m._set_status(p.use_item(item))
					_m._refresh()})
	elif kind == "scroll":
		actions.append({
			text = "Read", disabled = not p.can_use_item(item),
			press = func() -> void:
				_m._set_status(p.use_item(item))
				_m._refresh()})
	elif kind == "weapon":
		actions.append({
			text = "Wield", disabled = p.equipped_weapon.get("id", "") == item_id,
			press = func() -> void:
				p.equip_weapon(item)
				_m._set_status("Wielding %s." % item["name"])
				_m._refresh()})
	elif kind == "armor":
		actions.append({
			text = "Wear", disabled = p.equipped_armor.get("id", "") == item_id,
			press = func() -> void:
				p.equip_armor(item)
				_m._set_status("Wearing %s." % item["name"])
				_m._refresh()})
	elif kind == "accessory":
		var worn: bool = p.is_accessory_equipped(item_id)
		actions.append({
			text = "Worn" if worn else "Wear",
			disabled = worn or not p.has_free_accessory_slot(),
			press = func() -> void:
				if p.equip_accessory(item):
					_m._set_status("Put on %s." % item["name"])
				else:
					_m._set_status("Both slots are taken.")
				_m._refresh()})

	actions.append({
		text = "Drop", disabled = false,
		press = func() -> void:
			p.remove_item(item, 1)
			_m._set_status("Discarded %s." % item["name"])
			_m._refresh()})

	var about: String = item.get("desc", "") as String
	if kind in ["accessory", "weapon", "armor"]:
		about = "%s%s" % [about, GearTooltip.bonus_string(item)]

	list.add_entry("%s%s" % ["* " if belted else "", item["name"]],
			Color(0.85, 0.85, 0.92) if belted else Color(0.72, 0.72, 0.78),
			about,
			"x%d" % qty if qty > 1 else "", Color(0.66, 0.66, 0.74),
			actions)
