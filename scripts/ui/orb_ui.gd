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


func _build_rest() -> void:
	var vitals: Label = Label.new()
	vitals.text = "HP  %d / %d        MP  %d / %d" % [
			player.hp, player.max_hp, player.mp, player.max_mp]
	vitals.add_theme_color_override("font_color",
			CombatScene.hp_tint(player.hp, player.max_hp))
	_content.add_child(vitals)

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
	# The same rule the recruit menu keeps: nothing above the detective's level
	# answers to him, bought or talked down. Without it an orb is a way around it.
	var outranks: bool = demon.lv > player.lv
	demon.free()

	list.add(enemy_name,
			Color(0.62, 0.92, 0.74) if owned else Color(0.85, 0.85, 0.92),
			about,
			"bound" if owned else "%d g" % price,
			Color(0.55, 0.75, 0.60) if owned else Color(1.0, 0.85, 0.35),
			"Bound" if owned else ("Full" if full
					else ("Lv %d" % offered_lv if outranks else "Bind")),
			owned or full or outranks or player.gold < price,
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
# A demon goes back for exactly what binding one at its level costs, which makes
# the rolodex a ladder rather than a collection — sell what you have outgrown
# and put the gold into something from the floor you are standing on. A demon
# you raised yourself fetches the level it reached, not the one it was caught at.
static func sell_price(demon_name: String, lv: int) -> int:
	var demon: Enemy = Enemy.make_at_level(demon_name, lv)
	var price: int = bind_price(demon)
	demon.free()
	return price


# What a piece of gear is actually worth. `item_price` reads `floor`, which for
# a consumable is the depth it turns up at but for gear is its TIER — so through
# that formula a Hazel Wand and Diamond Armour both came out at 45 gold. Gear is
# priced off what it gives instead.
static func gear_value(item: Dictionary) -> int:
	var tier: int = clampi(int(item.get("floor", 1)), 1, 4)
	var bonus: int = int(item.get("str_bonus", 0)) + int(item.get("def_bonus", 0)) \
			+ int(item.get("mag_bonus", 0)) + int(item.get("agl_bonus", 0)) \
			+ int(item.get("luk_bonus", 0))
	return 50 * tier + 18 * maxi(0, bonus)


# What the counter charges for anything, buying or selling. ONE function on
# purpose: with gear bought off `item_price` and sold off `gear_value`, Diamond
# Armour cost 120 and sold back for 343, and the orb was a money printer.
static func price_of(item: Dictionary) -> int:
	var kind: String = item.get("type", "") as String
	if kind == "weapon" or kind == "armor" or kind == "accessory":
		return gear_value(item)
	return item_price(item)


# Half what the same thing costs across the counter. Gear worn right now is not
# in the pack at all — equipping moves it out of inventory — so the list never
# offers to sell what you are standing in.
static func resale_price(item: Dictionary) -> int:
	return maxi(1, price_of(item) / 2)


func _build_sell() -> void:
	# Demons first, then the pack, in one paged list: the counter is the same
	# counter and splitting it into two tabs would only add a tap.
	var rows: Array = []
	for demon_name: String in player.recruited:
		rows.append({kind = "demon", name = demon_name})
	for item: Dictionary in player.inventory:
		rows.append({kind = "item", item = item})
	if rows.is_empty():
		SlotList.new(_content).add_note("Nothing to sell.")
		return
	SlotList.paged(_content, _page, "sell", rows, _sell_offer, _refresh)


func _sell_offer(list: SlotList, row: Dictionary) -> void:
	if row.get("kind", "") == "item":
		_sell_item(list, row["item"] as Dictionary)
	else:
		_sell_demon(list, row["name"] as String)


func _sell_item(list: SlotList, item: Dictionary) -> void:
	var price: int = resale_price(item)
	var qty: int = int(item.get("qty", 1))
	var about: String = item.get("desc", "") as String
	if qty > 1:
		about = "x%d   %s" % [qty, about]
	list.add(item["name"] as String, Color(0.85, 0.85, 0.92), about,
			"%d g" % price, Color(1.0, 0.85, 0.35),
			"Sell", false,
			func() -> void:
				# The belt holds an id, not the item, and belt() only skips a
				# dead one — the slot itself would stay spent. So the last one
				# sold comes off the belt with it.
				if qty <= 1:
					player.unequip_item(item["id"] as String)
				player.remove_item(item, 1)
				player.gold += price
				_set_status("Sold %s. %d gold." % [item["name"], price])
				_refresh())


func _sell_demon(list: SlotList, enemy_name: String) -> void:
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
	# rather than selling the same spell twice — and so does one already in the
	# pack, because buying a scroll and reading it are two steps and between
	# them the shelf was still offering the copy you had just paid for.
	var stock: Array[Dictionary] = []
	for scroll: Dictionary in Item.scrolls_for_floor(floor_num):
		var teaches: String = scroll.get("teaches", "") as String
		if teaches in player.known_spells:
			continue
		if player.has_item(scroll.get("id", "") as String):
			continue
		stock.append(scroll)
	if stock.is_empty():
		SlotList.new(_content).add_note("Nothing here you have not already been taught.")
		return
	SlotList.paged(_content, _page, "scrolls", stock, _buy_offer, _refresh)


func _buy_offer(list: SlotList, item: Variant) -> void:
	var entry: Dictionary = item as Dictionary
	var price: int = price_of(entry)
	# What it would change, above its own description: a shop that only names a
	# piece leaves the player no way to tell whether it is an upgrade at all.
	var deltas: String = GearTooltip.delta_markup(entry, player)

	# What you already have of it. Without this the only way to answer "do I own
	# this dagger, and how many potions am I carrying?" was to leave the orb and
	# open the menu, which is the one thing a shop should never make you do.
	# Worn pieces count — see PlayerCharacter.owns.
	var item_id: String = entry.get("id", "") as String
	var held: String = _owned_tag(entry, item_id, player.item_qty(item_id))
	var title_color: Color = Color(0.62, 0.92, 0.74) if held != "" \
			else Color(0.85, 0.85, 0.92)

	# Shares the line the stat deltas are on rather than taking one of its own:
	# a slot is a fixed height and the description is already the second line,
	# so a third would simply push it out of the row.
	var lead: Array[String] = []
	if held != "":
		lead.append("[color=#9ee8b8]%s[/color]" % held)
	if deltas != "":
		lead.append(deltas)
	var detail: String = entry.get("desc", "") as String
	if not lead.is_empty():
		detail = "%s\n%s" % ["  ·  ".join(lead), detail]

	list.add(entry["name"] as String, title_color,
			detail,
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


# The one-line "you have this" marker on a shop row. Says the useful thing for
# each kind: a stack of potions is a count, a worn piece is where it is worn,
# and a spare piece in the pack is neither.
func _owned_tag(entry: Dictionary, item_id: String, carried: int) -> String:
	if player.equipped_weapon.get("id", "") == item_id:
		return "Wielding one."
	if player.equipped_armor.get("id", "") == item_id:
		return "Wearing one."
	if player.is_accessory_equipped(item_id):
		return "Worn."
	if carried <= 0:
		return ""
	if entry.get("type", "") == "consumable":
		return "Carrying %d." % carried
	return "In the pack."


func _note(text: String) -> Label:
	var lbl: Label = Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.62))
	return lbl
