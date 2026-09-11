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

var _tab: String = "rest"
var _content: VBoxContainer
var _status: Label
var _gold_lbl: Label
var _tab_btns: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	title.text = "SAVE ORB"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.70, 0.92, 1.0))
	head.add_child(title)

	_gold_lbl = Label.new()
	_gold_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_gold_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	head.add_child(_gold_lbl)

	var close_btn: Button = Button.new()
	close_btn.text = "Leave [ESC]"
	close_btn.custom_minimum_size = Vector2(150, 32)
	close_btn.pressed.connect(func() -> void: closed.emit())
	head.add_child(close_btn)

	var tabs: HBoxContainer = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	col.add_child(tabs)
	for pair: Array in [["rest", "Rest"], ["bind", "Bind a demon"],
			["buy", "Supplies"], ["save", "Record the run"]]:
		var btn: Button = Button.new()
		btn.text = pair[1] as String
		btn.toggle_mode = true
		btn.custom_minimum_size = Vector2(0, 34)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_switch.bind(pair[0] as String))
		tabs.add_child(btn)
		_tab_btns[pair[0]] = btn

	col.add_child(HSeparator.new())

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 5)
	scroll.add_child(_content)

	_status = Label.new()
	_status.add_theme_color_override("font_color", Color(0.65, 0.90, 0.70))
	col.add_child(_status)


func _switch(tab: String) -> void:
	_tab = tab
	for id: String in _tab_btns:
		(_tab_btns[id] as Button).button_pressed = (id == tab)
	for child: Node in _content.get_children():
		child.queue_free()
	_gold_lbl.text = "GOLD:  %d" % player.gold
	match tab:
		"rest": _build_rest()
		"bind": _build_bind()
		"buy":  _build_buy()
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
	_content.add_child(_note(
		"The orb will mend what it can, for a price. Your demons come back whole on their own."))

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

	_content.add_child(_rest_row("Mend wounds", "Restores every point of HP.",
			hp_price(player), player.hp >= player.max_hp,
			func() -> void:
				player.hp = player.max_hp
				_set_status("Your wounds close.")))

	_content.add_child(_rest_row("Refill the well", "Restores every point of MP.",
			mp_price(player), player.mp >= player.max_mp,
			func() -> void:
				player.mp = player.max_mp
				_set_status("The well is full again.")))

	_content.add_child(_rest_row("Draw off the poison", "Clears every ailment.",
			CURE_PRICE, player.active_statuses.is_empty(),
			func() -> void:
				player.active_statuses.clear()
				_set_status("Whatever was in you is gone.")))


func _rest_row(title: String, desc: String, price: int, nothing_to_do: bool,
		apply: Callable) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var name_lbl: Label = Label.new()
	name_lbl.text = title
	name_lbl.custom_minimum_size = Vector2(190, 0)
	name_lbl.add_theme_color_override("font_color",
		Color(0.50, 0.52, 0.58) if nothing_to_do else Color(0.85, 0.85, 0.92))
	row.add_child(name_lbl)

	var desc_lbl: Label = Label.new()
	desc_lbl.text = desc
	desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_lbl.add_theme_color_override("font_color", Color(0.66, 0.66, 0.74))
	row.add_child(desc_lbl)

	var price_lbl: Label = Label.new()
	price_lbl.text = "—" if nothing_to_do else "%d g" % price
	price_lbl.custom_minimum_size = Vector2(80, 0)
	price_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	row.add_child(price_lbl)

	var btn: Button = Button.new()
	btn.custom_minimum_size = Vector2(96, 28)
	btn.text = "Nothing to do" if nothing_to_do else "Pay"
	btn.disabled = nothing_to_do or player.gold < price
	if not nothing_to_do:
		btn.pressed.connect(func() -> void:
			if player.gold < price:
				_set_status("Not enough gold.")
			else:
				player.gold -= price
				apply.call()
			_refresh()
		)
	row.add_child(btn)
	return row


# ── Binding ───────────────────────────────────────────────────────────────────

# What a demon costs to bind here. Talking one down in battle is free; this is
# the price of not having managed it.
static func bind_price(demon: Enemy) -> int:
	return 40 + demon.lv * 35


func _build_bind() -> void:
	_content.add_child(_note(
		"Demons you have met can be bound here for gold. Talking one down in battle costs nothing — and a demon that falls in battle is struck off, so this is how you get it back."))

	var offered: int = 0
	for enemy_name: String in player.encountered_enemies:
		var demon: Enemy = Enemy.make_from_name(enemy_name)
		if not demon.negotiable:
			demon.free()
			continue      # a mindless thing cannot be bound at any price
		offered += 1
		_content.add_child(_bind_row(enemy_name, demon))
		demon.free()

	if offered == 0:
		_content.add_child(_note("You have not met anything that would come when called."))


func _bind_row(enemy_name: String, demon: Enemy) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var owned: bool = enemy_name in player.recruited
	var price: int = bind_price(demon)

	var name_lbl: Label = Label.new()
	name_lbl.text = "%s   LV %d" % [enemy_name, demon.lv]
	name_lbl.custom_minimum_size = Vector2(190, 0)
	name_lbl.add_theme_color_override("font_color",
		Color(0.62, 0.92, 0.74) if owned else Color(0.85, 0.85, 0.92))
	row.add_child(name_lbl)

	var stat_lbl: Label = Label.new()
	stat_lbl.text = "HP %d   MP %d" % [demon.max_hp, demon.max_mp]
	stat_lbl.custom_minimum_size = Vector2(140, 0)
	stat_lbl.add_theme_color_override("font_color", Color(0.62, 0.72, 0.68))
	row.add_child(stat_lbl)

	var elem_lbl: Label = Label.new()
	elem_lbl.text = Affinity.element_name(demon.attack_element) if demon.attack_element != "" \
			else "no element"
	elem_lbl.custom_minimum_size = Vector2(110, 0)
	elem_lbl.add_theme_color_override("font_color",
		Color(1.0, 0.72, 0.35) if demon.attack_element != "" else Color(0.45, 0.45, 0.50))
	row.add_child(elem_lbl)

	var price_lbl: Label = Label.new()
	price_lbl.text = "bound" if owned else "%d g" % price
	price_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	price_lbl.add_theme_color_override("font_color",
		Color(0.55, 0.75, 0.60) if owned else Color(1.0, 0.85, 0.35))
	row.add_child(price_lbl)

	var btn: Button = Button.new()
	btn.custom_minimum_size = Vector2(96, 28)
	btn.text = "Bound" if owned else "Bind"
	btn.disabled = owned or player.gold < price
	if not owned:
		btn.pressed.connect(func() -> void:
			if player.gold < price:
				_set_status("Not enough gold.")
			else:
				player.gold -= price
				player.remember_recruit(enemy_name)
				_set_status("%s answers to you now." % enemy_name)
			_refresh()
		)
	row.add_child(btn)
	return row


# ── Supplies ──────────────────────────────────────────────────────────────────

# What this orb stocks. Priced off the item's own floor tier so a Hi-Potion
# never costs the same as an antidote.
func _stock() -> Array[Dictionary]:
	var out: Array[Dictionary] = [
		Item.health_potion(), Item.hi_potion(), Item.ether(),
		Item.antidote(), Item.stimulant(), Item.echo_gem(),
		Item.venom_flask(), Item.fire_bomb(), Item.ice_shard(), Item.thunder_bead(),
	]
	if floor_num >= 2:
		out.append(Item.panacea())
		out.append(Item.elixir_motion())
		# The elemental grid is too central to leave to a drop roll. From the
		# second floor on, an orb always sells the way into every element at
		# single-target reach; the wide versions stay something you find.
		for spell_id: String in ["rime", "arc", "banish", "consign"]:
			out.append(Item.spell_scroll(spell_id,
					int(Item.ELEMENTAL_SCROLLS.get(spell_id, 3))))
	return out


static func item_price(item: Dictionary) -> int:
	return 20 + int(item.get("floor", 1)) * 25


func _build_buy() -> void:
	_content.add_child(_note("Supplies. Only what is on your belt reaches a battle."))
	for item: Dictionary in _stock():
		_content.add_child(_buy_row(item))


func _buy_row(item: Dictionary) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var price: int = item_price(item)

	var name_lbl: Label = Label.new()
	name_lbl.text = item["name"]
	name_lbl.custom_minimum_size = Vector2(190, 0)
	row.add_child(name_lbl)

	var desc_lbl: Label = Label.new()
	desc_lbl.text = item.get("desc", "")
	desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_lbl.add_theme_color_override("font_color", Color(0.66, 0.66, 0.74))
	row.add_child(desc_lbl)

	var price_lbl: Label = Label.new()
	price_lbl.text = "%d g" % price
	price_lbl.custom_minimum_size = Vector2(80, 0)
	price_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	row.add_child(price_lbl)

	var btn: Button = Button.new()
	btn.text = "Buy"
	btn.custom_minimum_size = Vector2(80, 28)
	btn.disabled = player.gold < price
	btn.pressed.connect(func() -> void:
		if player.gold < price:
			_set_status("Not enough gold.")
		else:
			player.gold -= price
			player.add_item(item.duplicate(), 1)
			_set_status("Bought %s." % item["name"])
		_refresh()
	)
	row.add_child(btn)
	return row


# ── Saving ────────────────────────────────────────────────────────────────────

func _build_save() -> void:
	_content.add_child(_note(
		"An orb is the only place a run can be written down. There is no saving in the dark."))
	var btn: Button = Button.new()
	btn.text = "Record the run"
	btn.custom_minimum_size = Vector2(240, 40)
	btn.pressed.connect(func() -> void: save_requested.emit())
	_content.add_child(btn)


func _note(text: String) -> Label:
	var lbl: Label = Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.62))
	return lbl
