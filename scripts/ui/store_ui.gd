# StoreUI
# Buy/Sell shop screen. Set .player before adding to the scene tree,
# then listen for store_closed to clean up.
class_name StoreUI extends Control

signal store_closed

var player:    PlayerCharacter
var floor_num: int = 1

var _active_tab:  String = "buy"
var _tab_btns:    Dictionary = {}
var _content:     VBoxContainer
var _gold_label:  Label
var _status_line: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_shell()
	_switch_tab("buy")


# ── Catalog & pricing ─────────────────────────────────────────────────────────

static var PRICES: Dictionary = {
	"health_potion": 50,  "hi_potion": 120,  "ether": 80,
	"antidote": 30,       "stimulant": 30,   "echo_gem": 30,
	"elixir_motion": 40,  "panacea": 150,
	"venom_flask": 40,    "flash_powder": 40, "silence_dust": 40, "binding_web": 40,
	"fire_bomb": 60,      "ice_shard": 60,    "thunder_bead": 60,
	"scroll_cure": 100,   "scroll_venom": 80, "scroll_shock": 100,
	"scroll_mute": 80,    "scroll_bind": 80,
	"scroll_fira": 200,   "scroll_thundara": 200, "scroll_blizzara": 200,
	"rusty_dagger": 30,   "iron_sword": 200,  "battle_axe": 300,  "magic_rod": 350,
	"leather_armor": 80,  "leather_vest": 80, "chain_mail": 250,  "plate_armor": 450,
}

static func sell_price(item: Dictionary) -> int:
	var id: String = item.get("id", "")
	if PRICES.has(id):
		return int(PRICES[id]) / 2
	match item.get("type", ""):
		"weapon": return 60
		"armor":  return 50
		"scroll": return 30
		_:        return 10


# Returns catalog grouped into named sections: [{label, entries:[{item,price}]}]
static func get_sections() -> Array[Dictionary]:
	var sections: Array[Dictionary] = []

	sections.append({label="CONSUMABLES", entries=[
		{item=Item.health_potion(), price=50},
		{item=Item.hi_potion(),     price=120},
		{item=Item.ether(),         price=80},
		{item=Item.antidote(),      price=30},
		{item=Item.stimulant(),     price=30},
		{item=Item.echo_gem(),      price=30},
		{item=Item.elixir_motion(), price=40},
		{item=Item.panacea(),       price=150},
	]})

	sections.append({label="THROWABLES", entries=[
		{item=Item.venom_flask(),   price=40},
		{item=Item.flash_powder(),  price=40},
		{item=Item.silence_dust(),  price=40},
		{item=Item.binding_web(),   price=40},
		{item=Item.fire_bomb(),     price=60},
		{item=Item.ice_shard(),     price=60},
		{item=Item.thunder_bead(),  price=60},
	]})

	sections.append({label="SCROLLS", entries=[
		{item=Item.scroll_cure(),      price=100},
		{item=Item.scroll_venom(),     price=80},
		{item=Item.scroll_shock(),     price=100},
		{item=Item.scroll_mute(),      price=80},
		{item=Item.scroll_bind(),      price=80},
		{item=Item.scroll_fira(),      price=200},
		{item=Item.scroll_thundara(),  price=200},
		{item=Item.scroll_blizzara(),  price=200},
	]})

	sections.append({label="WEAPONS", entries=[
		{item=Weapon.rusty_dagger(), price=30},
		{item=Weapon.iron_sword(),   price=200},
		{item=Weapon.battle_axe(),   price=300},
		{item=Weapon.magic_rod(),    price=350},
	]})

	sections.append({label="ARMOR", entries=[
		{item=Armor.leather_armor(), price=80},
		{item=Armor.leather_vest(),  price=80},
		{item=Armor.chain_mail(),    price=250},
		{item=Armor.plate_armor(),   price=450},
	]})

	return sections


# ── Shell ─────────────────────────────────────────────────────────────────────

func _build_shell() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.03, 0.03, 0.05, 0.93)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var panel: Panel = Panel.new()
	panel.anchor_left   = 0.5;  panel.anchor_right  = 0.5
	panel.anchor_top    = 0.5;  panel.anchor_bottom = 0.5
	panel.offset_left   = -340; panel.offset_right  = 340
	panel.offset_top    = -300; panel.offset_bottom = 300
	add_child(panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for s: String in ["margin_left","margin_right","margin_top","margin_bottom"]:
		margin.add_theme_constant_override(s, 14)
	panel.add_child(margin)

	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	margin.add_child(root)

	# Header
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	root.add_child(header)

	var title: Label = Label.new()
	title.text = "SHOP"
	title.add_theme_color_override("font_color", Color(0.95, 0.82, 0.25))
	header.add_child(title)

	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	_gold_label = Label.new()
	_gold_label.add_theme_color_override("font_color", Color(0.95, 0.82, 0.25))
	header.add_child(_gold_label)

	root.add_child(HSeparator.new())

	# Tab row
	var tab_row: HBoxContainer = HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 4)
	root.add_child(tab_row)

	for tab_id: String in ["buy", "sell"]:
		var btn: Button = Button.new()
		btn.text        = tab_id.capitalize()
		btn.toggle_mode = true
		btn.custom_minimum_size = Vector2(120, 32)
		btn.pressed.connect(_switch_tab.bind(tab_id))
		tab_row.add_child(btn)
		_tab_btns[tab_id] = btn

	var spacer2: Control = Control.new()
	spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_row.add_child(spacer2)

	var close_btn: Button = Button.new()
	close_btn.text = "Close  [ESC]"
	close_btn.custom_minimum_size = Vector2(110, 32)
	close_btn.pressed.connect(func(): store_closed.emit())
	tab_row.add_child(close_btn)

	root.add_child(HSeparator.new())

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 5)
	scroll.add_child(_content)

	root.add_child(HSeparator.new())

	_status_line = Label.new()
	_status_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_line.add_theme_color_override("font_color", Color(0.9, 0.85, 0.45))
	_status_line.custom_minimum_size = Vector2(0, 22)
	root.add_child(_status_line)


# ── Tab routing ───────────────────────────────────────────────────────────────

func _switch_tab(tab_id: String) -> void:
	_active_tab = tab_id
	_status_line.text = ""
	_gold_label.text  = "Gold:  %d gp" % player.gold
	for id: String in _tab_btns:
		_tab_btns[id].button_pressed = (id == tab_id)
	for child: Node in _content.get_children():
		child.queue_free()
	match tab_id:
		"buy":  _build_buy()
		"sell": _build_sell()


func _refresh() -> void:
	_switch_tab(_active_tab)


func _set_status(msg: String) -> void:
	_status_line.text = msg


# ── Buy tab ───────────────────────────────────────────────────────────────────

func _build_buy() -> void:
	for section: Dictionary in get_sections():
		var available: Array = (section["entries"] as Array).filter(
			func(e: Variant) -> bool:
				return ((e as Dictionary)["item"] as Dictionary).get("floor", 1) <= floor_num
		)
		if available.is_empty():
			continue

		var hdr: Label = Label.new()
		hdr.text = section["label"] as String
		hdr.add_theme_color_override("font_color", Color(0.70, 0.65, 0.50))
		_content.add_child(hdr)

		for entry: Variant in available:
			_content.add_child(_make_buy_row((entry as Dictionary)["item"] as Dictionary, (entry as Dictionary)["price"] as int))

		_content.add_child(HSeparator.new())


func _make_buy_row(item: Dictionary, price: int) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var name_lbl: Label = Label.new()
	name_lbl.text = item["name"]
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.tooltip_text = _gear_tooltip(item) if item["type"] in ["weapon", "armor"] else item.get("desc", "")
	name_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(name_lbl)

	var owned: int = _owned_qty(item.get("id", ""))
	var own_lbl: Label = Label.new()
	own_lbl.text = "Own ×%d" % owned if owned > 0 else ""
	own_lbl.custom_minimum_size = Vector2(62, 0)
	own_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	own_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	row.add_child(own_lbl)

	var price_lbl: Label = Label.new()
	price_lbl.text = "%d gp" % price
	price_lbl.custom_minimum_size     = Vector2(72, 0)
	price_lbl.horizontal_alignment    = HORIZONTAL_ALIGNMENT_RIGHT
	price_lbl.add_theme_color_override("font_color", Color(0.95, 0.82, 0.25))
	row.add_child(price_lbl)

	var teaches: String = item.get("teaches", "")
	var already_known: bool = teaches != "" and teaches in player.known_spells

	if already_known:
		var tag: Label = Label.new()
		tag.text = "Known"
		tag.custom_minimum_size = Vector2(60, 0)
		tag.add_theme_color_override("font_color", Color(0.50, 0.50, 0.50))
		row.add_child(tag)
	else:
		var buy_btn: Button = Button.new()
		buy_btn.text = "Buy"
		buy_btn.custom_minimum_size = Vector2(60, 26)
		buy_btn.disabled = player.gold < price
		buy_btn.pressed.connect(func():
			player.gold -= price
			player.add_item(item.duplicate(), 1)
			_set_status("Bought %s." % item["name"])
			_refresh()
		)
		row.add_child(buy_btn)

	return row


# ── Sell tab ──────────────────────────────────────────────────────────────────

func _build_sell() -> void:
	var sort_row: HBoxContainer = HBoxContainer.new()
	sort_row.add_theme_constant_override("separation", 6)
	_content.add_child(sort_row)

	var sort_lbl: Label = Label.new()
	sort_lbl.text = "Sort:"
	sort_row.add_child(sort_lbl)

	for mode: String in ["type", "name"]:
		var btn: Button = Button.new()
		btn.text = mode.capitalize()
		btn.custom_minimum_size = Vector2(70, 26)
		btn.pressed.connect(func():
			player.sort_inventory(mode)
			_refresh()
		)
		sort_row.add_child(btn)

	_content.add_child(HSeparator.new())

	if player.inventory.is_empty():
		var lbl: Label = Label.new()
		lbl.text = "Nothing to sell."
		lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		_content.add_child(lbl)
		return

	for item: Dictionary in player.inventory.duplicate():
		_content.add_child(_make_sell_row(item))


func _make_sell_row(item: Dictionary) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var qty: int = item.get("qty", 1)
	var name_lbl: Label = Label.new()
	name_lbl.text = item["name"] + (" ×%d" % qty if qty > 1 else "")
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.tooltip_text = _gear_tooltip(item) if item["type"] in ["weapon", "armor"] else item.get("desc", "")
	name_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(name_lbl)

	var sp: int = sell_price(item)
	var price_lbl: Label = Label.new()
	price_lbl.text = "%d gp" % sp
	price_lbl.custom_minimum_size     = Vector2(72, 0)
	price_lbl.horizontal_alignment    = HORIZONTAL_ALIGNMENT_RIGHT
	price_lbl.add_theme_color_override("font_color", Color(0.95, 0.82, 0.25))
	row.add_child(price_lbl)

	var sell_btn: Button = Button.new()
	sell_btn.text = "Sell"
	sell_btn.custom_minimum_size = Vector2(60, 26)
	sell_btn.pressed.connect(func():
		player.gold += sp
		player.remove_item(item, 1)
		_set_status("Sold %s for %d gp." % [item["name"], sp])
		_refresh()
	)
	row.add_child(sell_btn)

	return row


# ── Helpers ──────────────────────────────────────────────────────────────────

func _owned_qty(item_id: String) -> int:
	var total: int = 0
	for it: Dictionary in player.inventory:
		if it.get("id", "") == item_id:
			total += it.get("qty", 1)
	if player.equipped_weapon.get("id", "") == item_id:
		total += 1
	if player.equipped_armor.get("id", "") == item_id:
		total += 1
	return total


# ── Gear tooltip helpers ──────────────────────────────────────────────────────

func _gear_tooltip(item: Dictionary) -> String:
	var p: PlayerCharacter = player
	var lines: Array[String] = []

	var desc: String = item.get("desc", "")
	if not desc.is_empty():
		lines.append(desc)
		lines.append("")

	match item["type"]:
		"weapon":
			var new_str: int = p.str + item.get("str_bonus", 0)
			var new_mag: int = p.mag + item.get("mag_bonus", 0)
			var new_agl: int = p.agl + p.equipped_armor.get("agl_pen", 0) + item.get("agl_pen", 0)
			lines.append(_cmp_line("STR", p.effective_str(), new_str))
			if new_mag != p.effective_mag() or item.get("mag_bonus", 0) != 0:
				lines.append(_cmp_line("MAG", p.effective_mag(), new_mag))
			if new_agl != p.effective_agl() or item.get("agl_pen", 0) != 0:
				lines.append(_cmp_line("AGL", p.effective_agl(), new_agl))
		"armor":
			var new_def: int = p.def + item.get("def_bonus", 0)
			var new_agl: int = p.agl + p.equipped_weapon.get("agl_pen", 0) + item.get("agl_pen", 0)
			lines.append(_cmp_line("DEF", p.effective_def(), new_def))
			if new_agl != p.effective_agl() or item.get("agl_pen", 0) != 0:
				lines.append(_cmp_line("AGL", p.effective_agl(), new_agl))

	return "\n".join(lines)


func _cmp_line(stat: String, cur: int, nxt: int) -> String:
	var diff: int = nxt - cur
	if diff == 0:
		return "%s  %d" % [stat, nxt]
	return "%s  %d → %d  (%s%d)" % [stat, cur, nxt, ("+" if diff > 0 else ""), diff]
