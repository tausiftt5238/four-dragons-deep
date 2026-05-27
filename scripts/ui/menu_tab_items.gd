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

	_m._content.add_child(HSeparator.new())

	if _m.player.inventory.is_empty():
		var empty_lbl: Label = Label.new()
		empty_lbl.text = "Your pack is empty."
		empty_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		_m._content.add_child(empty_lbl)
		return

	for item: Dictionary in _m.player.inventory.duplicate():
		_m._content.add_child(_make_item_row(item))


func _make_item_row(item: Dictionary) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var name_lbl: Label = Label.new()
	var qty: int = item.get("qty", 1)
	name_lbl.text = item["name"] + (" ×%d" % qty if qty > 1 else "")
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.tooltip_text = GearTooltip.build(item, _m.player) if item["type"] in ["weapon", "armor"] else item.get("desc", "")
	name_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(name_lbl)

	var is_throwable: bool = item.has("inflicts_status") \
		or (item.has("element") and item.get("dmg", 0) > 0)
	match item["type"]:
		"consumable", "scroll":
			if is_throwable:
				var tag: Label = Label.new()
				tag.text = "Battle only"
				tag.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
				row.add_child(tag)
			else:
				var use_btn: Button = Button.new()
				use_btn.text = "Use"
				use_btn.custom_minimum_size = Vector2(50, 26)
				use_btn.disabled = not _m.player.can_use_item(item)
				use_btn.pressed.connect(func():
					var result: String = _m.player.use_item(item)
					_m._set_status(result)
					_m._refresh()
				)
				row.add_child(use_btn)
		"weapon":
			var is_equipped: bool = (_m.player.equipped_weapon.get("id", "") == item.get("id", "##"))
			var equip_btn: Button = Button.new()
			equip_btn.text = "Equipped" if is_equipped else "Equip"
			equip_btn.disabled = is_equipped
			equip_btn.custom_minimum_size = Vector2(70, 26)
			equip_btn.pressed.connect(func():
				_m.player.equip_weapon(item)
				_m._set_status("Equipped %s." % item["name"])
				_m._refresh()
			)
			row.add_child(equip_btn)
		"armor":
			var is_equipped: bool = (_m.player.equipped_armor.get("id", "") == item.get("id", "##"))
			var equip_btn: Button = Button.new()
			equip_btn.text = "Equipped" if is_equipped else "Equip"
			equip_btn.disabled = is_equipped
			equip_btn.custom_minimum_size = Vector2(70, 26)
			equip_btn.pressed.connect(func():
				_m.player.equip_armor(item)
				_m._set_status("Equipped %s." % item["name"])
				_m._refresh()
			)
			row.add_child(equip_btn)

	var discard_btn: Button = Button.new()
	discard_btn.text = "Discard"
	discard_btn.custom_minimum_size = Vector2(60, 26)
	discard_btn.pressed.connect(func():
		_m.player.remove_item(item, 1)
		_m._set_status("Discarded %s." % item["name"])
		_m._refresh()
	)
	row.add_child(discard_btn)

	return row
