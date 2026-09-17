# OrbUI
# What a save orb offers. Three things, and they are the only places each one
# happens: a run can be written down, a demon can be bought into the rolodex,
# and gold can be spent on supplies. Everywhere else, gold does nothing and the
# run is unsaved — which is what makes finding an orb matter.
class_name OrbUI extends Control

signal closed
signal save_requested

var player: PlayerCharacter
var floor_num: int = 1

# Which tab the orb opens on. Walking onto the tile lands on Rest; the HUD's
# Save shortcut goes straight to the Save tab.
var start_tab: String = "rest"

var _tab: String = "rest"
var _content: VBoxContainer
var _status: Label
var _gold_lbl: Label
var _tab_btns: Dictionary = {}
# Which page each of the long lists is showing.
var _page: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tab = start_tab
	_build()
	_switch(_tab)


func _build() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.03, 0.05, 0.08, 0.97)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var m: MarginContainer = MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		m.add_theme_constant_override(side, 20)
	add_child(m)

	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	m.add_child(col)

	var head: HBoxContainer = HBoxContainer.new()
	head.add_theme_constant_override("separation", 18)
	col.add_child(head)

	var title: Label = Label.new()
	title.text = "Save Orb"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.70, 0.92, 1.0))
	head.add_child(title)

	_gold_lbl = Label.new()
	_gold_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_gold_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	head.add_child(_gold_lbl)

	col.add_child(HSeparator.new())

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Fills the pane, so a tab with one button can push it down to the thumb.
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 5)
	scroll.add_child(_content)

	_status = Label.new()
	_status.add_theme_color_override("font_color", Color(0.65, 0.90, 0.70))
	col.add_child(_status)

	col.add_child(HSeparator.new())

	# The tabs and the way out sit along the bottom, under the lists. Named in
	# words they are wider than the screen in one line, so they go two by two.
	var tabs: GridContainer = GridContainer.new()
	tabs.columns = 2
	tabs.add_theme_constant_override("h_separation", 6)
	tabs.add_theme_constant_override("v_separation", 6)
	col.add_child(tabs)
	for pair: Array in [["rest", "Rest"], ["bind", "Bind"],
			["sell", "Sell"], ["buy", "Supplies"],
			["gear", "Gear"], ["scrolls", "Scrolls"], ["save", "Save"]]:
		var btn: Button = Button.new()
		btn.text = pair[1] as String
		btn.toggle_mode = true
		btn.custom_minimum_size = Vector2(0, 34)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_switch.bind(pair[0] as String))
		tabs.add_child(btn)
		_tab_btns[pair[0]] = btn

	var close_btn: Button = Button.new()
	close_btn.text = "Leave"
	close_btn.custom_minimum_size = Vector2(0, 32)
	close_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_btn.pressed.connect(func() -> void: closed.emit())
	col.add_child(close_btn)


func _switch(tab: String) -> void:
	_tab = tab
	for id: String in _tab_btns:
		(_tab_btns[id] as Button).button_pressed = (id == tab)
	for child: Node in _content.get_children():
		child.queue_free()
	_gold_lbl.text = "Gold:  %d" % player.gold
	match tab:
		"rest": _build_rest()
		"bind": _build_bind()
		"sell": _build_sell()
		"buy":  _build_buy()
		"gear": _build_gear()
		"scrolls": _build_scrolls()
		"save": _build_save()


func _refresh() -> void:
	_switch(_tab)


func _set_status(msg: String) -> void:
	_status.text = msg


# ── Rest ──────────────────────────────────────────────────────────────────────
#
# Paid, and priced on what is actually missing, so limping into an orb with one
# HP costs real money while topping off after a scratch costs almost nothing.
# Free healing at two or three orbs a floor would make attrition meaningless.

static func hp_price(p: PlayerCharacter) -> int:
	var missing: int = p.max_hp - p.hp
	return 0 if missing <= 0 else maxi(10, roundi(missing * 0.8))


static func mp_price(p: PlayerCharacter) -> int:
	var missing: int = p.max_mp - p.mp
	return 0 if missing <= 0 else maxi(10, missing * 2)


const CURE_PRICE: int = 40


func _build_rest() -> void:
	var vitals: Label = Label.new()
	vitals.text = "HP  %d / %d        MP  %d / %d" % [
			player.hp, player.max_hp, player.mp, player.max_mp]
	vitals.add_theme_color_override("font_color",
			CombatScene.hp_tint(player.hp, player.max_hp))
	_content.add_child(vitals)

	if not player.active_statuses.is_empty():
		var names: Array[String] = []
		for st: String in player.active_statuses:
			names.append(Status.get_data(st).get("name", st) as String)
		var ail: Label = Label.new()
		ail.text = "Afflicted:  %s" % "  ".join(names)
		ail.add_theme_color_override("font_color", Color(0.90, 0.78, 0.30))
		_content.add_child(ail)

	_content.add_child(HSeparator.new())

	var list: SlotList = SlotList.new(_content)
	_rest_offer(list, "Mend wounds", "Restores every point of HP.",
			hp_price(player), player.hp >= player.max_hp,
			func() -> void:
				player.hp = player.max_hp
				_set_status("Your wounds close."))
	_rest_offer(list, "Refill the well", "Restores every point of MP.",
			mp_price(player), player.mp >= player.max_mp,
			func() -> void:
				player.mp = player.max_mp
				_set_status("The well is full again."))
	_rest_offer(list, "Draw off the poison", "Clears every ailment.",
			CURE_PRICE, player.active_statuses.is_empty(),
			func() -> void:
				player.active_statuses.clear()
				_set_status("Whatever was in you is gone."))


# ── Offers ────────────────────────────────────────────────────────────────────

func _rest_offer(list: SlotList, title: String, desc: String, price: int,
		nothing_to_do: bool, apply: Callable) -> void:
	list.add(title,
			Color(0.50, 0.52, 0.58) if nothing_to_do else Color(0.85, 0.85, 0.92),
			desc,
			"\u2014" if nothing_to_do else "%d g" % price, Color(1.0, 0.85, 0.35),
			"\u2014" if nothing_to_do else "Pay",
			nothing_to_do or player.gold < price,
			func() -> void:
				if player.gold < price:
					_set_status("Not enough gold.")
				else:
					player.gold -= price
					apply.call()
				_refresh())


# ── Binding ───────────────────────────────────────────────────────────────────

# What a demon costs to bind here. Talking one down in battle is free; this is
# the price of not having managed it.
static func bind_price(demon: Enemy) -> int:
	return 40 + demon.lv * 35


func _build_bind() -> void:
	var offered: Array = []
	for enemy_name: String in player.encountered_enemies:
		var demon: Enemy = Enemy.make_from_name(enemy_name)
		var can_bind: bool = demon.negotiable   # a mindless thing cannot be bound
		demon.free()
		if can_bind:
			offered.append(enemy_name)

	if offered.is_empty():
		_content.add_child(_note("You have not met anything that would come when called."))
		SlotList.new(_content)
		return
	SlotList.paged(_content, _page, "bind", offered, _bind_offer, _refresh)


func _bind_offer(list: SlotList, enemy_name: String) -> void:
	var demon: Enemy = Enemy.make_from_name(enemy_name, floor_num)
	var owned: bool = enemy_name in player.recruited
	var full: bool = not player.can_bind(enemy_name)
	var price: int = bind_price(demon)
	var lines: Array[String] = []
	for e: String in demon.attack_elements:
		lines.append(Affinity.element_name(e))
	var element: String = "/".join(lines) if not lines.is_empty() else "no element"
	var about: String = "LV %d   HP %d   MP %d   %s" % [
			demon.lv, demon.max_hp, demon.max_mp, element]
	var offered_lv: int = demon.lv
	demon.free()

	list.add(enemy_name,
			Color(0.62, 0.92, 0.74) if owned else Color(0.85, 0.85, 0.92),
			about,
			"bound" if owned else "%d g" % price,
			Color(0.55, 0.75, 0.60) if owned else Color(1.0, 0.85, 0.35),
			"Bound" if owned else ("Full" if full else "Bind"),
			owned or full or player.gold < price,
			func() -> void:
				if player.gold < price:
					_set_status("Not enough gold.")
				else:
					player.gold -= price
					player.remember_recruit(enemy_name, offered_lv)
					_set_status("%s answers to you now." % enemy_name)
				_refresh())


# ── Selling ───────────────────────────────────────────────────────────────────
#
# Demons never level, so a floor-two demon is a floor-two demon for the rest of
# the run. This is the way out of that: it goes back for exactly what binding
# one at its level costs, which makes the rolodex a ladder rather than a
# collection — sell what you have outgrown and put the gold into something from
# the floor you are standing on.
static func sell_price(demon_name: String, lv: int) -> int:
	var demon: Enemy = Enemy.make_at_level(demon_name, lv)
	var price: int = bind_price(demon)
	demon.free()
	return price


func _build_sell() -> void:
	if player.recruited.is_empty():
		SlotList.new(_content).add_note("Nothing bound to you.")
		return
	SlotList.paged(_content, _page, "sell", player.recruited.duplicate(),
			_sell_offer, _refresh)


func _sell_offer(list: SlotList, enemy_name: String) -> void:
	var lv: int = int(player.bound_level.get(enemy_name, 1))
	var demon: Enemy = player.bound_demon(enemy_name)
	var lines: Array[String] = []
	for e: String in demon.attack_elements:
		lines.append(Affinity.element_name(e))
	var element: String = "/".join(lines) if not lines.is_empty() else "no element"
	var about: String = "LV %d   HP %d   MP %d   %s%s" % [
			demon.lv, demon.max_hp, demon.max_mp, element,
			"   summoned" if enemy_name in player.active_demons else ""]
	demon.free()
	var price: int = sell_price(enemy_name, lv)

	list.add(enemy_name, Color(0.85, 0.85, 0.92), about,
			"%d g" % price, Color(1.0, 0.85, 0.35),
			"Sell", false,
			func() -> void:
				player.release_demon(enemy_name)
				player.gold += price
				_set_status("%s is released. %d gold." % [enemy_name, price])
				_refresh())


# ── Supplies ──────────────────────────────────────────────────────────────────

# What this orb stocks in the way of supplies. Priced off the item's own floor
# tier so a Hi-Potion never costs the same as an antidote.
func _supplies() -> Array[Dictionary]:
	var out: Array[Dictionary] = [
		Item.health_potion(), Item.hi_potion(), Item.ether(),
		Item.antidote(), Item.stimulant(), Item.echo_gem(),
		Item.venom_flask(), Item.fire_bomb(), Item.ice_shard(), Item.thunder_bead(),
	]
	if floor_num >= 2:
		out.append(Item.panacea())
		out.append(Item.elixir_motion())
	return out


# Gear for the depth reached, which is the main thing gold is for once the belt
# is full. Trinkets included, so the two accessory slots are a purchase rather
# than a run of luck.
#
# Deepest tier first, and within a tier: weapon, worn piece, trinket. A shelf
# this long is read from the front, and what a player wants at floor twenty is
# the tier-IV row — walked forward it sat ten pages in, behind every rusty
# dagger the run had already outgrown.
func _gear() -> Array[Dictionary]:
	var weapons: Array[Dictionary] = Weapon.for_floor(floor_num)
	var worn: Array[Dictionary] = Armor.for_floor(floor_num)
	var trinkets: Array[Dictionary] = Accessory.for_floor(floor_num)
	var out: Array[Dictionary] = []
	for tier: int in [4, 3, 2, 1]:
		for shelf: Array[Dictionary] in [weapons, worn, trinkets]:
			for g: Dictionary in shelf:
				if int(g["floor"]) == tier:
					out.append(g)
	return out


# Price follows the item's depth tier, unless it carries one of its own — the
# dispel scrolls do, because what they are worth has nothing to do with how far
# down you have to be to be offered one.
static func item_price(item: Dictionary) -> int:
	return int(item.get("price", 20 + int(item.get("floor", 1)) * 25))


func _build_buy() -> void:
	SlotList.paged(_content, _page, "buy", _supplies(), _buy_offer, _refresh)


func _build_gear() -> void:
	SlotList.paged(_content, _page, "gear", _gear(), _buy_offer, _refresh)


# ── Scrolls ───────────────────────────────────────────────────────────────────
#
# The elemental grid is too central to leave to a drop roll, and nothing else in
# the game teaches a spell — so an orb sells every scroll the depth reached has
# opened, wide ones and higher rungs included. What gates them is how far down
# you have been and what they cost, not luck. They get their own tab because
# there are forty-five of them and six fit on a page.
func _build_scrolls() -> void:
	# A scroll you have already read teaches nothing, so the shelf drops it
	# rather than selling the same spell twice.
	var stock: Array[Dictionary] = []
	for scroll: Dictionary in Item.scrolls_for_floor(floor_num):
		if scroll.get("teaches", "") not in player.known_spells:
			stock.append(scroll)
	if stock.is_empty():
		SlotList.new(_content).add_note("Nothing here you have not already been taught.")
		return
	SlotList.paged(_content, _page, "scrolls", stock, _buy_offer, _refresh)


func _buy_offer(list: SlotList, item: Variant) -> void:
	var entry: Dictionary = item as Dictionary
	var price: int = item_price(entry)
	list.add(entry["name"] as String, Color(0.85, 0.85, 0.92),
			entry.get("desc", "") as String,
			"%d g" % price, Color(1.0, 0.85, 0.35),
			"Buy", player.gold < price,
			func() -> void:
				if player.gold < price:
					_set_status("Not enough gold.")
				else:
					player.gold -= price
					player.add_item(entry.duplicate(), 1)
					_set_status("Bought %s." % entry["name"])
				_refresh())


# ── Saving ────────────────────────────────────────────────────────────────────

func _build_save() -> void:
	var push: Control = Control.new()
	push.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(push)

	var btn: Button = Button.new()
	btn.text = "Save the run"
	btn.custom_minimum_size = Vector2(240, 40)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(func() -> void: save_requested.emit())
	_content.add_child(btn)


func _note(text: String) -> Label:
	var lbl: Label = Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.62))
	return lbl
