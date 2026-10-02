# MenuTabItems
# The pack. Everything consumable in it reaches a battle; the battle's item
# menu scrolls when the pack runs past six.
class_name MenuTabItems extends RefCounted

var _m

func _init(menu) -> void:
	_m = menu


# The menu remembers which seed or stone is being handed out, since this tab is
# rebuilt on every refresh.
const GIVING: StringName = &"giving_item_id"


func build() -> void:
	var giving: String = _m.get_meta(GIVING, "") as String
	if giving != "":
		_build_give(giving)
		return
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

	_m._content.add_child(HSeparator.new())

	var has_any: bool = false
	for item: Dictionary in _m.player.inventory:
		if not (item.get("type", "") in ["weapon", "armor", "accessory"]):
			has_any = true
			break
	if not has_any:
		SlotList.new(_m._content).add_note("Your pack is empty.")
		return

	# One shelf per kind. Weapons, armour and trinkets live on the Equipment tab,
	# where they can be compared against what is worn, so they are left out
	# here. Anything of a kind not named still lists, under Other.
	# Throwables get their own shelf, by the same test the orb's shop and the
	# battle's item menu use: anything that inflicts an ailment or deals an
	# element's damage is thrown at a foe rather than used on yourself.
	var shelves: Array[Array] = [["consumable", "Consumables"], ["throwable", "Throwables"],
			["scroll", "Scrolls"]]
	var by_type: Dictionary = {}
	var other: Array = []
	for shelf: Array in shelves:
		by_type[shelf[0]] = []
	for item: Dictionary in _m.player.inventory:
		var kind: String = item.get("type", "") as String
		if kind in ["weapon", "armor", "accessory"]:
			continue
		if kind == "consumable" and (item.has("inflicts_status") \
				or (item.has("element") and int(item.get("dmg", 0)) > 0)):
			kind = "throwable"
		if by_type.has(kind):
			(by_type[kind] as Array).append(item["id"] as String)
		else:
			other.append(item["id"] as String)
	var groups: Array = []
	for shelf: Array in shelves:
		groups.append({title = shelf[1], entries = by_type[shelf[0]]})
	groups.append({title = "Other", entries = other})
	_m.add_sections(_m._content, "items", groups,
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
	var qty: int = int(item.get("qty", 1))

	var actions: Array[Dictionary] = []
	if kind == "consumable":
		# Ailments end with the fight, so an item that only cures one has nothing
		# to do out here. It still lists — the player wants to see what they are
		# carrying — but the field offers no Use for it.
		# A seed or a stone can go to anyone on the roster, so Use asks who.
		if PlayerCharacter.is_keepsake(item) and not p.recruited.is_empty():
			actions.append({
				text = "Use", disabled = false,
				press = func() -> void:
					_m.set_meta(GIVING, item_id)
					_m._refresh()})
		# A stone raises a ceiling and refills it, so it is always worth using.
		elif int(item.get("hp_restore", 0)) > 0 or int(item.get("mp_restore", 0)) > 0 \
				or PlayerCharacter.is_keepsake(item):
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
			text = "Equip", disabled = p.equipped_weapon.get("id", "") == item_id,
			press = func() -> void:
				p.equip_weapon(item)
				_m._set_status("Equipped %s." % item["name"])
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

	var about: String = ItemInfo.item(item)

	list.add_entry(item["name"] as String, Color(0.85, 0.85, 0.92),
			about,
			"x%d" % qty if qty > 1 else "", Color(0.66, 0.66, 0.74),
			actions)


# Who gets the seed or stone: the hero, or any demon on the roster, the
# benched ones included. Each row shows what it would raise, from what.
func _build_give(item_id: String) -> void:
	var p: PlayerCharacter = _m.player
	var item: Dictionary = {}
	for candidate: Dictionary in p.inventory:
		if candidate["id"] == item_id:
			item = candidate
			break
	if item.is_empty():
		_m.set_meta(GIVING, "")
		build()
		return

	var head: Label = Label.new()
	head.text = "Give %s to:" % item["name"]
	head.add_theme_font_size_override("font_size", 18)
	head.add_theme_color_override("font_color", Color(0.70, 0.92, 1.0))
	_m._content.add_child(head)
	var back: Button = Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(0, 32)
	back.pressed.connect(func() -> void:
		_m.set_meta(GIVING, "")
		_m._refresh())
	_m._content.add_child(back)
	_m._content.add_child(HSeparator.new())

	var list: SlotList = SlotList.new(_m._content)
	list.add_entry(PlayerCharacter.DISPLAY_NAME, Color(0.85, 0.85, 0.92),
			_now_line(item, p), "LV %d" % p.lv, Color(0.66, 0.66, 0.74),
			[{text = "Give", disabled = not p.can_use_item(item),
				press = func() -> void: _give(item, "")}])
	for demon_name: String in p.recruited:
		var e: Enemy = p.bound_demon(demon_name)
		var line: String = _now_line(item, e)
		var lv: int = e.lv
		e.free()
		var ok: bool = PlayerCharacter.demon_can_take(item)
		list.add_entry(demon_name, Color(0.62, 0.92, 0.74),
				line if ok else "Demons have no Luck.", "LV %d" % lv,
				Color(0.66, 0.66, 0.74),
				[{text = "Give", disabled = not ok,
					press = func() -> void: _give(item, demon_name)}])


# What the item would raise on this one, as it stands now.
static func _now_line(item: Dictionary, who: CharacterSheet) -> String:
	if item.has("stat_up"):
		var stat: String = item["stat_up"] as String
		return "%s %d" % [stat.to_upper(), int(who.get(stat))]
	if int(item.get("max_hp_gain", 0)) > 0:
		return "Max HP %d" % who.max_hp
	return "Max MP %d" % who.max_mp


func _give(item: Dictionary, demon_name: String) -> void:
	var p: PlayerCharacter = _m.player
	var msg: String = p.use_item(item) if demon_name == "" else p.give_keepsake(item, demon_name)
	_m._set_status(msg)
	# Stay on the list while there are more of it to hand out.
	if p.item_qty(item["id"] as String) <= 0:
		_m.set_meta(GIVING, "")
	_m._refresh()
