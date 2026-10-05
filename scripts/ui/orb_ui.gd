# OrbUI
# What a save orb offers. Three things, and they are the only places each one
# happens: a run can be written down, a demon can be bought into the roster,
# and gold can be spent on supplies. Everywhere else, gold does nothing and the
# run is unsaved — which is what makes finding an orb matter.
class_name OrbUI extends Control

signal closed
signal save_requested
# The lineup the player paid for, as template names. Main runs the fight.
signal gauntlet_requested(names: Array[String])
# Experience won on the slot machine. Main pays it, so a level-up gets the same
# screens a fight's would.
signal gacha_exp_won(amount: int)

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
var _scroll: ScrollContainer


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

	var scroll: ScrollContainer = TouchScroll.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_scroll = scroll

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Fills the pane, so a tab with one button can push it down to the thumb.
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 5)
	scroll.add_child(_content)

	_status = Label.new()
	_status.add_theme_color_override("font_color", Color(0.65, 0.90, 0.70))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_status)

	col.add_child(HSeparator.new())

	# The tabs and the way out sit along the bottom, under the lists. Named in
	# words they are wider than the screen in one line, so they go two by two.
	var tabs: GridContainer = GridContainer.new()
	tabs.columns = 2
	tabs.add_theme_constant_override("h_separation", 6)
	tabs.add_theme_constant_override("v_separation", 6)
	col.add_child(tabs)
	for pair: Array in [["rest", "Rest"], ["bind", "Recruit"],
			["sell", "Sell"], ["buy", "Supplies"],
			["gear", "Gear"], ["scrolls", "Scrolls"], ["gacha", "Gacha"],
			["gauntlet", "Gauntlet"]]:
		tabs.add_child(_tab_btn(pair[0] as String, pair[1] as String))

	# Save is the odd ninth tab, so it runs the full width under the grid, as
	# wide as Leave, rather than hanging off the left of a half-empty row.
	col.add_child(_tab_btn("save", "Save"))

	var close_btn: Button = Button.new()
	close_btn.text = "Leave"
	close_btn.custom_minimum_size = Vector2(0, 32)
	close_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_btn.pressed.connect(func() -> void: closed.emit())
	col.add_child(close_btn)


func _tab_btn(id: String, label: String) -> Button:
	var btn: Button = Button.new()
	btn.text = label
	btn.toggle_mode = true
	btn.custom_minimum_size = Vector2(0, 34)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.pressed.connect(_switch.bind(id))
	_tab_btns[id] = btn
	return btn


func _switch(tab: String) -> void:
	_tab = tab
	Music.play(Music.CASINO if tab == "gacha" else Music.ORB)
	_scroll.scroll_vertical = 0
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
		"gauntlet": _build_gauntlet()
		"gacha": _build_gacha()


# Rebuilds the tab after a purchase or a sale, keeping the scroll where it was.
func _refresh() -> void:
	var at: int = _scroll.scroll_vertical
	_switch(_tab)
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(_scroll):
		_scroll.scroll_vertical = at


func _set_status(msg: String) -> void:
	_status.text = msg


# ── Gacha ─────────────────────────────────────────────────────────────────────
#
# A slot machine: pay, spin three reels, keep what matches. The rules and the
# prizes live in Gacha; this is the cabinet.
# Each face's 16px icon, drawn in the same hand as the element icons.
const REEL_ICON: Dictionary = {
	"exp":     "res://resources/icons/gacha_exp.png",
	"gold":    "res://resources/icons/gacha_gold.png",
	"item":    "res://resources/icons/gacha_item.png",
	"monster": "res://resources/icons/gacha_monster.png",
}
const REEL_ICON_SIZE: float = 64.0
const PAYTABLE_ICON_SIZE: float = 28.0
const REEL_TICK: float = 0.06
# When each reel stops, counted from the pull, so they land left to right.
const REEL_STOPS: Array[float] = [0.7, 1.1, 1.5]

var _reels: Array[TextureRect] = []
var _reel_boxes: Array[PanelContainer] = []
var _spin_btn: Button
var _gacha_result: Label
var _spinning: bool = false
# Set by Main when an exp win is about to close the orb for a level-up. No new
# spin may start then: the orb would be freed under it and the stake lost.
var _gacha_locked: bool = false


func lock_gacha() -> void:
	_gacha_locked = true
	if is_instance_valid(_spin_btn):
		_spin_btn.disabled = true


func _build_gacha() -> void:
	var cost: int = Gacha.price(floor_num)
	var reels: HBoxContainer = HBoxContainer.new()
	reels.add_theme_constant_override("separation", 8)
	reels.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_child(reels)
	_reels.clear()
	_reel_boxes.clear()
	for i: int in 3:
		var box: PanelContainer = PanelContainer.new()
		box.custom_minimum_size = Vector2(120, 96)
		box.add_theme_stylebox_override("panel", _reel_style(Color(0.30, 0.34, 0.42)))
		reels.add_child(box)
		var face: TextureRect = _face_icon(REEL_ICON_SIZE)
		face.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		box.add_child(face)
		_reels.append(face)
		_reel_boxes.append(box)
		_show_face(i, [Gacha.GOLD, Gacha.MONSTER, Gacha.ITEM][i])

	_gacha_result = Label.new()
	_gacha_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gacha_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_gacha_result.custom_minimum_size = Vector2(0, 44)
	_gacha_result.add_theme_font_size_override("font_size", 18)
	_gacha_result.add_theme_color_override("font_color", Color(0.85, 0.85, 0.92))
	_gacha_result.text = "Two alike pays. Three alike is the jackpot."
	_content.add_child(_gacha_result)

	_spin_btn = Button.new()
	_spin_btn.text = "Spin  (%d g)" % cost
	_spin_btn.custom_minimum_size = Vector2(240, 48)
	_spin_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_spin_btn.disabled = player.gold < cost
	_spin_btn.pressed.connect(_spin)
	_content.add_child(_spin_btn)

	_content.add_child(HSeparator.new())
	var exp_pair: int = Gacha.exp_prize(floor_num, false)
	var gold_pair: int = Gacha.gold_prize(floor_num, false)
	for row: Array in [
			[Gacha.EXP, "%d exp" % exp_pair, "%d exp" % Gacha.exp_prize(floor_num, true)],
			[Gacha.GOLD, "%d g" % gold_pair, "%d g" % Gacha.gold_prize(floor_num, true)],
			[Gacha.ITEM, "a supply", "gear, tier %s" % _tier_name(1)],
			[Gacha.MONSTER, "tier %s monster" % _tier_name(0), "tier %s monster" % _tier_name(1)]]:
		_content.add_child(_paytable_row(row[0] as String, row[1] as String, row[2] as String))
	_content.add_child(_note("Pair pays the middle column, jackpot the right. Prizes grow with the floor; luck nudges the reels."))


# This floor's band, or the one below it, as a roman numeral.
func _tier_name(deeper: int) -> String:
	return ["I", "II", "III", "IV"][mini(4, Enemy.tier_for_floor(floor_num) + deeper) - 1]


func _paytable_row(face: String, pair: String, jackpot: String) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	var icon: TextureRect = _face_icon(PAYTABLE_ICON_SIZE)
	icon.texture = load(REEL_ICON[face]) as Texture2D
	# The pair and jackpot columns still split the rest of the row evenly.
	var icon_cell: Control = Control.new()
	icon_cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	icon_cell.custom_minimum_size = Vector2(PAYTABLE_ICON_SIZE, PAYTABLE_ICON_SIZE)
	icon_cell.add_child(icon)
	row.add_child(icon_cell)
	for cell: Array in [[pair, Color(0.80, 0.80, 0.86)],
			[jackpot, Color(1.0, 0.85, 0.35)]]:
		var lbl: Label = Label.new()
		lbl.text = cell[0] as String
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", cell[1] as Color)
		row.add_child(lbl)
	return row


static func _reel_style(edge: Color) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.08, 0.11)
	sb.border_color = edge
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(6)
	return sb


func _show_face(i: int, face: String) -> void:
	if i >= _reels.size() or not is_instance_valid(_reels[i]):
		return
	_reels[i].texture = load(REEL_ICON[face]) as Texture2D


# A face icon at a fixed size, pixels kept square.
static func _face_icon(px: float) -> TextureRect:
	var tr: TextureRect = TextureRect.new()
	tr.custom_minimum_size = Vector2(px, px)
	tr.size = Vector2(px, px)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


func _spin() -> void:
	var cost: int = Gacha.price(floor_num)
	if _spinning or _gacha_locked or player.gold < cost:
		return
	_spinning = true
	player.gold -= cost
	_gold_lbl.text = "Gold:  %d" % player.gold
	_spin_btn.disabled = true
	_gacha_result.text = "..."
	for b: PanelContainer in _reel_boxes:
		b.add_theme_stylebox_override("panel", _reel_style(Color(0.30, 0.34, 0.42)))
	var reels: Array[String] = Gacha.spin(player.battle_luck())
	# The reels flicker through faces and stop one at a time on what was rolled.
	var t: float = 0.0
	var stopped: int = 0
	while stopped < 3:
		await get_tree().create_timer(REEL_TICK).timeout
		if not is_instance_valid(self) or _tab != "gacha":
			break
		t += REEL_TICK
		while stopped < 3 and t >= REEL_STOPS[stopped]:
			_show_face(stopped, reels[stopped])
			# C, E, G: three stops spell a chord.
			Sfx.play("reel", [0.0, 4.0, 7.0][stopped])
			stopped += 1
		for i: int in range(stopped, 3):
			_show_face(i, Gacha.FACES[randi() % Gacha.FACES.size()])
	_spinning = false
	if not is_instance_valid(self):
		return
	# Paid whether or not the tab is still showing: the gold has gone.
	var said: String = _pay_out(reels)
	if _tab != "gacha":
		# Switched away mid-spin: the cabinet is gone, so say it down below.
		_set_status(said)
		return
	_gacha_result.text = said
	var won: Dictionary = Gacha.outcome(reels)
	if not won.is_empty():
		Sfx.play("jackpot" if won["jackpot"] else "pair")
		var glow: Color = Color(1.0, 0.85, 0.35) if won["jackpot"] else Color(0.55, 0.95, 0.60)
		for i: int in 3:
			if reels[i] == won["face"]:
				_reel_boxes[i].add_theme_stylebox_override("panel", _reel_style(glow))
	_gold_lbl.text = "Gold:  %d" % player.gold
	_spin_btn.disabled = _gacha_locked or player.gold < cost


# Hands over what the reels say and returns the line that says so.
func _pay_out(reels: Array[String]) -> String:
	var won: Dictionary = Gacha.outcome(reels)
	if won.is_empty():
		return "No match."
	var jackpot: bool = won["jackpot"]
	var head: String = "JACKPOT!  " if jackpot else ""
	match won["face"]:
		Gacha.GOLD:
			var g: int = Gacha.gold_prize(floor_num, jackpot)
			player.gold += g
			return "%sWon %d gold." % [head, g]
		Gacha.ITEM:
			var it: Dictionary = Gacha.item_prize(_supplies(), floor_num, jackpot)
			player.add_item(it, 1)
			return "%sWon %s." % [head, it["name"]]
		Gacha.MONSTER:
			var full: bool = player.recruited.size() >= PlayerCharacter.ROSTER_SIZE
			var mon: Dictionary = {} if full else Gacha.monster_prize(player, floor_num, jackpot)
			if mon.is_empty() or not player.can_bind(mon["name"] as String):
				# No room, or nobody left to meet: it pays as the gold face would,
				# so the win is never empty but a full roster is no gold mine.
				var g: int = Gacha.gold_prize(floor_num, jackpot)
				player.gold += g
				return "%s%s Won %d gold instead." % [head,
						"Roster full." if full else "Nobody new to meet.", g]
			player.remember_recruit(mon["name"] as String, int(mon["lv"]))
			return "%s%s (LV %d) joins you!" % [head, mon["name"], int(mon["lv"])]
		_:
			var xp: int = Gacha.exp_prize(floor_num, jackpot)
			gacha_exp_won.emit(xp)
			return "%sWon %d exp." % [head, xp]


# ── Gauntlet ──────────────────────────────────────────────────────────────────
#
# A paid practice fight, for grinding: up to four monsters out of the bestiary,
# met at this floor's level, as many of one kind as the player likes. A win
# pays experience and twice what the lineup cost (Main.GAUNTLET_PAYOUT), but no
# item drops: it is how gold is made, at the price of the risk. Only the ordinary roster is on offer: wardens and
# dragons are set pieces met once.
const GAUNTLET_MAX: int = 4

var _lineup: Array[String] = []


static func gauntlet_price(enemy_name: String, floor_num: int) -> int:
	var e: Enemy = Enemy.make_from_name(enemy_name, floor_num)
	var price: int = 10 + e.lv * 6
	e.free()
	return price


func _gauntlet_total() -> int:
	var total: int = 0
	for n: String in _lineup:
		total += gauntlet_price(n, floor_num)
	return total


func _build_gauntlet() -> void:
	var line: Label = Label.new()
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.text = "Lineup  (%d / %d):  %s" % [_lineup.size(), GAUNTLET_MAX,
			", ".join(_lineup) if not _lineup.is_empty() else "empty"]
	line.add_theme_color_override("font_color", Color(0.85, 0.85, 0.92))
	_content.add_child(line)

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_content.add_child(row)
	var clear: Button = Button.new()
	clear.text = "Clear"
	clear.disabled = _lineup.is_empty()
	clear.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clear.pressed.connect(func() -> void:
		_lineup.clear()
		_refresh())
	row.add_child(clear)
	# A full lineup of four drawn from the bestiary, repeats allowed; pressed
	# again, it draws a fresh one.
	var pool: Array[String] = _gauntlet_pool()
	var random: Button = Button.new()
	random.text = "Random"
	random.disabled = pool.is_empty()
	random.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	random.pressed.connect(func() -> void:
		_lineup.clear()
		for i: int in GAUNTLET_MAX:
			_lineup.append(pool[randi() % pool.size()])
		_set_status("A random lineup steps up.")
		_refresh())
	row.add_child(random)
	var total: int = _gauntlet_total()
	var fight: Button = Button.new()
	fight.text = "Fight  (%d g)" % total
	fight.disabled = _lineup.is_empty() or player.gold < total
	fight.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fight.pressed.connect(func() -> void:
		player.gold -= total
		var names: Array[String] = _lineup.duplicate()
		_lineup.clear()
		gauntlet_requested.emit(names))
	row.add_child(fight)

	_content.add_child(HSeparator.new())

	var tiers: Array = [[], [], [], []]
	for n: String in player.encountered_enemies:
		for t: Dictionary in Enemy.TEMPLATES:
			if t["name"] == n:
				(tiers[clampi(int(t.get("tier", 1)), 1, 4) - 1] as Array).append(n)
				break
	var groups: Array = []
	for i: int in 4:
		groups.append({title = "Tier %s" % ["I", "II", "III", "IV"][i], entries = tiers[i]})
	var any: bool = false
	for g: Dictionary in groups:
		if not (g["entries"] as Array).is_empty():
			any = true
	if not any:
		SlotList.new(_content).add_note("Meet a monster on the floor first. The gauntlet only offers what your bestiary knows.")
		return
	SlotList.sections(_content, _page, "gauntlet", groups, _gauntlet_offer)


# Everything the gauntlet lists: the ordinary monsters the bestiary knows.
func _gauntlet_pool() -> Array[String]:
	var out: Array[String] = []
	for n: String in player.encountered_enemies:
		for t: Dictionary in Enemy.TEMPLATES:
			if t["name"] == n:
				out.append(n)
				break
	return out


func _gauntlet_offer(list: SlotList, enemy_name: String) -> void:
	var e: Enemy = Enemy.make_from_name(enemy_name, floor_num)
	var about: String = "LV %d   HP %d   %d exp" % [e.lv, e.max_hp, e.exp_reward]
	e.free()
	var price: int = gauntlet_price(enemy_name, floor_num)
	var full: bool = _lineup.size() >= GAUNTLET_MAX
	list.add(enemy_name, Color(0.85, 0.85, 0.92), about,
			"%d g" % price, Color(1.0, 0.85, 0.35),
			"Full" if full else "Add", full,
			func() -> void:
				_lineup.append(enemy_name)
				_set_status("%s joins the lineup." % enemy_name)
				_refresh())


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
	# What has answered to him before, not everything he has swung at. An orb
	# calls a demon back; it does not introduce one.
	var offered: Array = []
	for enemy_name: String in player.ever_bound:
		var demon: Enemy = Enemy.make_from_name(enemy_name)
		var can_bind: bool = demon.negotiable   # a mindless thing cannot be bound
		demon.free()
		if can_bind:
			offered.append(enemy_name)

	if offered.is_empty():
		_content.add_child(_note("Nothing has answered to you yet."))
		SlotList.new(_content)
		return
	SlotList.listed(_content, offered, _bind_offer)


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
	# The same rule the recruit menu keeps: nothing above the hero's level
	# answers to him, bought or talked down. Without it an orb is a way around it.
	var outranks: bool = demon.lv > player.lv
	# Its chart, as the Party tab shows one: what you would be bringing into
	# a fight, weaknesses and all, before you pay for it.
	var chart: AffinityChart = AffinityChart.compact(demon)
	demon.free()

	list.add_entry(enemy_name,
			Color(0.62, 0.92, 0.74) if owned else Color(0.85, 0.85, 0.92),
			about,
			"recruited" if owned else "%d g" % price,
			Color(0.55, 0.75, 0.60) if owned else Color(1.0, 0.85, 0.35),
			[{text = "Owned" if owned else ("Full" if full
					else ("Lv %d" % offered_lv if outranks else "Recruit")),
				disabled = owned or full or outranks or player.gold < price,
				press = func() -> void:
					if player.gold < price:
						_set_status("Not enough gold.")
					else:
						player.gold -= price
						player.remember_recruit(enemy_name, offered_lv)
						_set_status("%s answers to you now." % enemy_name)
					_refresh()}],
			null, chart)


# ── Selling ───────────────────────────────────────────────────────────────────
#
# A demon goes back for exactly what binding one at its level costs, which makes
# the roster a ladder rather than a collection — sell what you have outgrown
# and put the gold into something from the floor you are standing on. A demon
# you raised yourself fetches the level it reached, not the one it was caught at.
static func sell_price(demon_name: String, lv: int) -> int:
	var demon: Enemy = Enemy.make_at_level(demon_name, lv)
	var price: int = bind_price(demon)
	demon.free()
	return price


# Exactly half the asking price, for everything — which is also what keeps the
# orb from being a money printer. Selling must never be derived from a
# different formula than buying: a version that priced gear off its stat
# bonuses had Diamond Armour cost 120 and sell back for 343.
#
# Gear worn right now is not in the pack at all — equipping moves it out of
# inventory — so the list never offers to sell what you are standing in.
static func resale_price(item: Dictionary) -> int:
	return maxi(1, item_price(item) / 2)


# One tab, the same shelves every other list uses: monsters, then the pack cut
# the way the Items and Gear tabs cut it, so a thing sits under the same heading
# here as it does everywhere else.
func _build_sell() -> void:
	var monsters: Array = []
	for demon_name: String in player.recruited:
		monsters.append({kind = "demon", name = demon_name})
	var mend: Array = []
	var throw: Array = []
	var scrolls: Array = []
	var gear: Dictionary = {weapon = [], armor = [], accessory = []}
	var other: Array = []
	var mirrors: Array = []
	for item: Dictionary in player.inventory:
		var row: Dictionary = {kind = "item", item = item}
		var kind: String = item.get("type", "") as String
		if kind == "consumable":
			if item.has("mirror"):
				mirrors.append(row)
			elif item.has("inflicts_status") \
					or (item.has("element") and int(item.get("dmg", 0)) > 0):
				throw.append(row)
			else:
				mend.append(row)
		elif kind == "scroll":
			scrolls.append(row)
		elif gear.has(kind):
			(gear[kind] as Array).append(row)
		else:
			other.append(row)
	var groups: Array = [
		{title = "Monsters", entries = monsters},
		{title = "Recovery", entries = mend},
		{title = "Throwables", entries = throw},
		{title = "Mirrors", entries = mirrors},
		{title = "Scrolls", entries = scrolls},
		{title = "Weapons", entries = gear["weapon"]},
		{title = "Armour", entries = gear["armor"]},
		{title = "Trinkets", entries = gear["accessory"]},
		{title = "Other", entries = other},
	]
	var any: bool = false
	for g: Dictionary in groups:
		if not (g["entries"] as Array).is_empty():
			any = true
	if not any:
		SlotList.new(_content).add_note("Nothing to sell.")
		return
	SlotList.sections(_content, _page, "sell", groups, _sell_offer)


func _sell_offer(list: SlotList, row: Dictionary) -> void:
	if row.get("kind", "") == "item":
		_sell_item(list, row["item"] as Dictionary)
	else:
		_sell_demon(list, row["name"] as String)


func _sell_item(list: SlotList, item: Dictionary) -> void:
	var price: int = resale_price(item)
	var qty: int = int(item.get("qty", 1))
	var about: String = ItemInfo.item(item)
	if qty > 1:
		about = "x%d   %s" % [qty, about]
	list.add(item["name"] as String, Color(0.85, 0.85, 0.92), about,
			"%d g" % price, Color(1.0, 0.85, 0.35),
			"Sell", false,
			func() -> void:
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
		Item.attack_mirror(), Item.magic_mirror(),
	]
	if floor_num >= 2:
		out.append(Item.panacea())
		out.append(Item.eye_drops())
		out.append(Item.revival_feather())
	if floor_num >= Item.DEEP_SUPPLIES_FLOOR:
		out.append_array(Item.deep_supplies())
	return out


# Gear for the depth reached, which is the main thing gold is for once the pack
# is stocked. Trinkets included, so the two accessory slots are a purchase rather
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


# Split the way the pack is used in a fight: what patches you up, and what you
# throw. The test is the one the battle's item menu uses.
func _build_buy() -> void:
	var mend: Array = []
	var throw: Array = []
	var mirrors: Array = []
	for item: Dictionary in _supplies():
		if item.has("mirror"):
			mirrors.append(item)
		elif item.has("inflicts_status") or (item.has("element") and int(item.get("dmg", 0)) > 0):
			throw.append(item)
		else:
			mend.append(item)
	SlotList.sections(_content, _page, "buy", [
		{title = "Recovery", entries = mend},
		{title = "Throwables", entries = throw},
		{title = "Mirrors", entries = mirrors},
	], _buy_offer)


func _build_gear() -> void:
	SlotList.sections(_content, _page, "gear", gear_groups(_gear()), _buy_offer)


# One shelf per slot it fills, each keeping the order it came in.
static func gear_groups(items: Array) -> Array:
	var by_type: Dictionary = {weapon = [], armor = [], accessory = []}
	for item: Variant in items:
		var kind: String = _item_type(item)
		if by_type.has(kind):
			(by_type[kind] as Array).append(item)
	return [
		{title = "Weapons", entries = by_type["weapon"]},
		{title = "Armour", entries = by_type["armor"]},
		{title = "Trinkets", entries = by_type["accessory"]},
	]


static func _item_type(item: Variant) -> String:
	return (item as Dictionary).get("type", "") as String if item is Dictionary else ""


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
	SlotList.sections(_content, _page, "scrolls", scroll_groups(stock), _buy_offer)


# One shelf per element the scroll teaches, then healing, then everything that
# moves a stage, lays an ailment or clears one.
static func scroll_groups(scrolls: Array) -> Array:
	var order: Array[String] = ["phys", "fire", "ice", "thunder", "light", "dark"]
	var by_key: Dictionary = {heal = [], support = []}
	for element: String in order:
		by_key[element] = []
	for scroll: Variant in scrolls:
		var data: Dictionary = Spell.get_data((scroll as Dictionary).get("teaches", "") as String)
		var element: String = data.get("element", "") as String
		if by_key.has(element):
			(by_key[element] as Array).append(scroll)
		elif data.get("type", "") == "heal":
			(by_key["heal"] as Array).append(scroll)
		else:
			(by_key["support"] as Array).append(scroll)
	var out: Array = []
	for element: String in order:
		out.append({title = Affinity.element_name(element), entries = by_key[element]})
	out.append({title = "Healing", entries = by_key["heal"]})
	out.append({title = "Support", entries = by_key["support"]})
	return out


func _buy_offer(list: SlotList, item: Variant) -> void:
	var entry: Dictionary = item as Dictionary
	var price: int = item_price(entry)
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
	var detail: String = ItemInfo.item(entry, deltas)
	if held != "":
		detail = "[font_size=%d][color=#9ee8b8]%s[/color][/font_size]\n%s" % [
				ItemInfo.FONT_SIZE - 3, held, detail]

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
		return "One equipped."
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
