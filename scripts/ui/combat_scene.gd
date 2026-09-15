# CombatScene
# Press-turn combat. Layout:
#   top    – combat log (slim strip)
#   middle – enemy sprite + name + HP bar (fills remaining space)
#   strip  – press-turn icons for both sides
#   bottom – [party roster] | [action buttons] | [item/magic submenu]
#
# A side opens its phase with one icon per living combatant and keeps acting
# until the icons run out, so weakness hits and criticals buy extra actions for
# whoever landed them — see PressTurn for the exact economy. The detective and
# his bound demons share the player side; summoning binds one into the party,
# which is what raises the icon count on the following phase.
class_name CombatScene extends Control

signal combat_ended(result: String)

var player: PlayerCharacter

# Every demon in this encounter. `enemy` is whichever one the player currently
# has targeted — it is kept as a plain field because the CombatNeg* handlers
# all address the demon they are talking to through it.
var foes: Array[Enemy] = []
var enemy: Enemy

# One row widget per foe: {foe, portrait, name_lbl, bar, hp_lbl, marker}.
var _foe_rows: Array[Dictionary] = []
var _foe_turn_idx: int = 0

# Demons removed by a successful negotiation rather than killed.
var _departed: Array[Enemy] = []

# Bound demons that fell in this battle. Read by Main before the scene is
# freed, so the loss can be reported where the player will actually see it.
var lost_demons: Array[String] = []

# The detective plus every demon he has bound this battle. Index 0 is always
# the detective; _actor is the member currently holding the turn.
const MAX_PARTY: int = 4
var party: Array[CharacterSheet] = []
var _actor_idx: int = 0

var _press:     PressTurn
var _foe_press: PressTurn

var _negotiation: CombatNegotiation

# When set, enemy actions ignore target selection and swing at this member.
# Used by the negotiation handlers, where the detective is the one talking.
var _force_target: CharacterSheet = null

var _log_label:      RichTextLabel
var _log_first_line: bool = true

# The detective's portrait, kept as its own reference because the CombatNeg*
# handlers shake it directly.
var _player_portrait: TextureRect

var _icon_lbl:     Label   # player-side press-turn icons
var _foe_icon_lbl: Label   # enemy-side press-turn icons
var _party_box:   HBoxContainer
# One slot per party member, mirroring _foe_rows so both sides read the same.
var _party_slots: Array[Dictionary] = []


# The menu strip is a fixed row of MENU_SLOTS cells. The action bar fills all
# of them; a submenu drops its entries into the same cells, so slot 3 is in the
# same place whichever is showing. Both menus are capped at MENU_SLOTS, which
# is why nothing here ever needs to scroll.
const MENU_SLOTS: int = 6
# The strip is exactly this tall in every state. Left to its own devices it
# measured 282 on the main actions, 261 in Skills and 224 in Items, so the
# whole bottom of the screen jumped by nearly sixty pixels every time you
# opened a submenu. Six slots are always drawn, empty ones included.
const MENU_STRIP_H:  int = 302
const MENU_SLOT_H:   int = 88
# The header is this tall whether or not Back is showing. A Button that comes
# and goes takes 15px of layout with it, which moved every slot underneath.
const MENU_HEADER_H: int = 39
var _action_bar: GridContainer
var _sub_bar:    GridContainer
var _sub_slots:  Array[MarginContainer] = []
var _actor_banner: Label
var _buttons: Dictionary = {}

var _right_title:    Label
var _right_back_btn: Button
var _back_target:    Callable



func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if foes.is_empty() and enemy != null:
		foes = [enemy]      # single-foe callers still work unchanged
	_assign_battle_tags()
	enemy = foes[0]
	_form_party()
	for member: CharacterSheet in party:
		member.reset_stages()
	for foe: Enemy in foes:
		foe.reset_stages()
	_press     = PressTurn.new()
	_foe_press = PressTurn.new()
	_build_ui()
	_rebuild_party_slots()
	_refresh_hp()
	_negotiation = CombatNegotiation.new(self)
	_log("[color=yellow]%s[/color]" % _encounter_line())
	_begin_player_phase()


# ── UI construction ───────────────────────────────────────────────────────────

func _build_ui() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.04, 0.02, 0.08, 0.78)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root: VBoxContainer = VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	_build_log_strip(root)
	_build_enemy_area(root)
	_build_party_area(root)
	_build_menu_panel(root)
	# Added to the scene rather than the column so it floats over the corner.
	_build_icon_overlay()


# The press-turn readout. Both sides are always visible so the player can see a
# phase about to snowball against them, not just their own banked halves.

func _build_log_strip(parent: Control) -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 65)
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	parent.add_child(panel)

	var m: MarginContainer = MarginContainer.new()
	for s: String in ["margin_left", "margin_top", "margin_bottom"]:
		m.add_theme_constant_override(s, 8)
	# Wide enough that a long log line never runs under the press-turn corner.
	m.add_theme_constant_override("margin_right", 196)
	panel.add_child(m)

	_log_label = RichTextLabel.new()
	_log_label.bbcode_enabled   = true
	_log_label.scroll_active    = true
	_log_label.scroll_following = true
	_log_label.add_theme_color_override("default_color", Color(0.88, 0.84, 0.74))
	m.add_child(_log_label)






# ── Party roster ──────────────────────────────────────────────────────────────

# One compact row per bound demon, rebuilt whenever the party changes.


# ── Helpers ───────────────────────────────────────────────────────────────────

func _make_bar(max_val: int) -> ProgressBar:
	var bar: ProgressBar = ProgressBar.new()
	bar.min_value           = 0
	bar.max_value           = max(1, max_val)
	bar.value               = max_val
	bar.show_percentage     = false
	bar.custom_minimum_size = Vector2(0, 14)
	return bar


# Health reads the same wherever it appears: green while it is fine, orange
# under half, red under a fifth. Styleboxes are shared rather than rebuilt every
# refresh, which happens several times a turn.
const HP_OK:   Color = Color(0.30, 0.74, 0.34)
const HP_LOW:  Color = Color(0.95, 0.60, 0.15)
const HP_DIRE: Color = Color(0.88, 0.18, 0.18)

static var _hp_styles: Dictionary = {}


static func hp_tint(current: int, maximum: int) -> Color:
	var frac: float = float(current) / float(maxi(1, maximum))
	if frac <= 0.2:
		return HP_DIRE
	if frac <= 0.5:
		return HP_LOW
	return HP_OK


func _apply_hp_bar(bar: ProgressBar, current: int, maximum: int) -> void:
	var tint: Color = hp_tint(current, maximum)
	if not _hp_styles.has(tint):
		var box: StyleBoxFlat = StyleBoxFlat.new()
		box.bg_color = tint
		_hp_styles[tint] = box
	bar.add_theme_stylebox_override("fill", _hp_styles[tint] as StyleBoxFlat)


func _bar_fill(color: Color) -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = color
	return s


func _shake_portrait(node: TextureRect) -> void:
	node.pivot_offset = node.size / 2.0
	var tween: Tween = create_tween()
	tween.tween_property(node, "scale", Vector2(1.18, 0.82), 0.05)
	tween.tween_property(node, "scale", Vector2(0.88, 1.14), 0.06)
	tween.tween_property(node, "scale", Vector2(1.07, 0.94), 0.05)
	tween.tween_property(node, "scale", Vector2(1.0,  1.0),  0.05)


func _log(line: String) -> void:
	if not _log_first_line:
		_log_label.append_text("\n")
	_log_first_line = false
	_log_label.append_text(line)


func _format_statuses(statuses: Array[String]) -> String:
	if statuses.is_empty():
		return ""
	var names: Array[String] = []
	for s: String in statuses:
		names.append(Status.get_data(s).get("name", s))
	return "  ".join(names)


func _set_buttons(enabled: bool) -> void:
	for btn: Button in _buttons.values():
		btn.disabled = not enabled



# ── Submenus ──────────────────────────────────────────────────────────────────

func _set_back(cb: Callable) -> void:
	_back_target = cb
	_right_back_btn.show()


func _on_back_pressed() -> void:
	if _back_target.is_valid():
		_back_target.call()





func _show_item_submenu() -> void:
	_hide_actions()
	_set_back(_show_main_actions)
	_right_title.text = "Items"
	_right_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.40))
	_submenu_clear()

	var belt: Array[Dictionary] = player.belt()
	if belt.is_empty():
		_submenu_add(_dim_label("Nothing on your belt."))
		return
	for item: Dictionary in belt:
		var is_throwable: bool = item.has("inflicts_status") \
			or (item.has("element") and item.get("dmg", 0) > 0)
		var btn: Button = _big_button(item["name"] as String,
				"x%d" % int(item.get("qty", 1)),
				not is_throwable and not player.can_use_item(item))
		btn.pressed.connect(_on_use_item.bind(item))
		_submenu_add(btn)


func _show_talk_submenu() -> void:
	_hide_actions()
	_set_back(_show_main_actions)
	_right_title.text = "Talk to %s" % enemy.display_name()
	_right_title.add_theme_color_override("font_color", Color(0.50, 1.0, 0.70))
	_submenu_clear()

	var opts: Array[Array] = [
		["Reason",   "Negotiate"],
		["Bribe",    "Bribe"],
		["Threaten", "Threaten"],
		["Recruit",  "Recruit"],
	]
	for opt: Array in opts:
		var have: bool = (opt[0] == "Recruit" and enemy.enemy_name in player.recruited)
		var btn: Button = _big_button(opt[1] as String, "bound" if have else "", have)
		btn.pressed.connect(_on_talk.bind(opt[0] as String))
		_submenu_add(btn)



func _on_talk(approach: String) -> void:
	_negotiation.start(approach)


func _dim_label(text: String) -> Label:
	var lbl: Label = Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", Color(0.40, 0.40, 0.40))
	return lbl


# ── Action handler ────────────────────────────────────────────────────────────




# ── Round resolution ──────────────────────────────────────────────────────────





# ── Damage helpers ────────────────────────────────────────────────────────────

func _apply_variance(dmg: int) -> int:
	return max(1, roundi(dmg * randf_range(0.8, 1.2)))

func _roll_crit() -> bool:
	return randi() % 10 == 0


# ── Individual action logic ───────────────────────────────────────────────────



# Returns { msg, cost }. A thrown flask is scored against the chart like any
# other elemental hit, which means it can be drunk or turned back — and that
# has to end the phase the same way a spell does. It used to cost one icon
# whatever happened, which made a throwable the safe way to probe a chart.
func _use_item_by_id(item_id: String) -> Dictionary:
	for item: Dictionary in player.inventory:
		if item["id"] == item_id and item["type"] == "consumable":
			var inflicts: String = item.get("inflicts_status", "")
			if inflicts != "":
				var sname: String = Status.get_data(inflicts).get("name", inflicts)
				player.remove_item(item, 1)
				if enemy.has_status(inflicts):
					return {msg = "[color=aqua]Used %s.[/color] %s is already %s." % [
							item["name"], enemy.enemy_name, sname],
							cost = PressTurn.COST_FULL}
				enemy.apply_status(inflicts)
				return {msg = "[color=aqua]Used %s![/color]  [color=violet]%s is now %s.[/color]" % [
						item["name"], enemy.enemy_name, sname], cost = PressTurn.COST_FULL}
			var element: String = item.get("element", "")
			var base_dmg: int = item.get("dmg", 0)
			if element != "" and base_dmg > 0:
				var state: String = enemy.affinity_of(element)
				var dmg: int = base_dmg
				player.remove_item(item, 1)
				if state == Affinity.DRAIN:
					enemy.heal(dmg)
					return {msg = "[color=aqua]Used %s![/color]  [color=lime]%s absorbs it and recovers %d HP![/color]" % [
							item["name"], enemy.enemy_name, dmg], cost = PressTurn.COST_LOST}
				if state == Affinity.REPEL:
					player.take_damage(dmg)
					return {msg = "[color=aqua]Used %s![/color]  [color=#d070ff]Repelled! You take %d damage![/color]" % [
							item["name"], dmg], cost = PressTurn.COST_LOST}
				if state == Affinity.NULL:
					return {msg = "[color=aqua]Used %s![/color]  [color=#999999]%s does not feel it.[/color]" % [
							item["name"], enemy.enemy_name], cost = PressTurn.COST_MISS}
				dmg = max(1, roundi(dmg * Affinity.multiplier(state)))
				var weak: bool = state == Affinity.WEAK
				var weak_tag: String = "  [color=yellow]Weak![/color]" if weak else ""
				enemy.take_damage(dmg)
				return {msg = "[color=aqua]Used %s![/color]%s  [color=violet]%s takes %d damage.[/color]" % [
						item["name"], weak_tag, enemy.enemy_name, dmg],
						cost = PressTurn.COST_HALF if weak else PressTurn.COST_FULL}
			var result: String = player.use_item(item)
			return {msg = "[color=aqua]Used %s. %s[/color]" % [item["name"], result],
					cost = PressTurn.COST_FULL}
	return {msg = "[color=gray]Item not found.[/color]", cost = PressTurn.COST_FULL}



func _check_counter() -> String:
	if "counter" not in player.passive_skills or not player.is_alive() or randi() % 4 != 0:
		return ""
	var dmg: int = _apply_variance(player.effective_str() - enemy.def / 2)
	var crit: bool = _roll_crit()
	if crit:
		dmg = int(dmg * 1.75)
	dmg = max(1, dmg)
	enemy.take_damage(dmg)
	var crit_tag: String = " [CRITICAL!]" if crit else ""
	return "\n[color=orange]Counter! You strike back for %d damage!%s[/color]" % [dmg, crit_tag]



# A bound demon that goes down is struck off here — off the rolodex, not just
# out of this fight — which is the whole reason the compendium is there. It is
# struck off at this moment and not the one it dropped in, so everything up to
# the last enemy is a window in which Revive can still pull it back.
func _end_combat(result: String) -> void:
	# Not cleared: a body swapped off the field was already struck off and
	# already recorded, and the tally afterwards has to name it too.
	for i: int in range(1, party.size()):
		var demon: Enemy = party[i] as Enemy
		if demon.is_alive():
			continue
		_strike_off(demon)
	combat_ended.emit(result)
	queue_free()


# ── Phase flow ────────────────────────────────────────────────────────────────

func _living_party() -> Array[CharacterSheet]:
	var out: Array[CharacterSheet] = []
	for m: CharacterSheet in party:
		if m.is_alive():
			out.append(m)
	return out


func _actor() -> CharacterSheet:
	return party[clampi(_actor_idx, 0, party.size() - 1)]


func _actor_is_player() -> bool:
	return _actor_idx == 0


func _member_name(member: CharacterSheet) -> String:
	if member == player:
		return PlayerCharacter.DISPLAY_NAME
	return (member as Enemy).enemy_name


func _actor_name() -> String:
	return _member_name(_actor())


func _next_living(from_idx: int) -> int:
	for step: int in range(1, party.size() + 1):
		var idx: int = (from_idx + step) % party.size()
		if party[idx].is_alive():
			return idx
	return from_idx


# One icon per living party member. A demon bound during this phase does not
# add its icon until the next one, which is what stops summoning from looping.
func _begin_player_phase() -> void:
	# A brace covers the enemy phase it was raised against and expires here,
	# rather than being spent on the first hit that lands.
	for member: CharacterSheet in party:
		member.defending = false
	_phases += 1
	if _try_begging():
		return
	_press.begin(_living_party().size())
	_actor_idx = 0 if party[0].is_alive() else _next_living(0)
	_prompt_actor()


# ── A demon losing its nerve ──────────────────────────────────────────────────
#
# One fight in twenty, something on the other side decides it would rather be
# on this one. It happens before the phase opens and costs no icon: it is luck,
# not a move, and making the player pay a turn to accept a gift would teach them
# to dread the prompt. Only demons that can be talked to break this way — a
# lattice of tendon with nothing behind it doing the thinking has no nerve to
# lose.
const BEG_CHANCE: int = 5
const BEG_PHASE: int = 2

var _beg_used: bool = false
var _phases: int = 0


func _begging_candidates() -> Array[Enemy]:
	var out: Array[Enemy] = []
	for foe: Enemy in _living_foes():
		if foe.negotiable:
			out.append(foe)
	return out


# Returns true when a plea took over the phase, so the caller stands down.
func _try_begging() -> bool:
	if _beg_used or _phases != BEG_PHASE:
		return false
	_beg_used = true
	if randi() % 100 >= BEG_CHANCE:
		return false
	var pool: Array[Enemy] = _begging_candidates()
	if pool.is_empty():
		return false

	enemy = pool[randi() % pool.size()]
	_refresh_hp()

	# Already bound: it has nothing to offer that he has not got, and it knows
	# it. It pays its way out instead.
	if enemy.enemy_name in player.recruited:
		_log("[color=#ffd479]%s throws itself down — and sees its own face already standing with you.[/color]"
				% enemy.display_name())
		_prompt_tribute()
		return true

	_log("[color=#ffd479]%s stops fighting and begs to be taken with you.[/color]"
			% enemy.display_name())
	_prompt_beg()
	return true


func _prompt_beg() -> void:
	_set_buttons(false)
	_hide_actions()
	_back_target = Callable()
	_right_back_btn.visible = false
	_right_title.text = "It is begging"
	_right_title.add_theme_color_override("font_color", Color(1.0, 0.83, 0.47))
	_submenu_clear()

	var take: Button = _big_button("Bind it",
			"%s joins the rolodex. Costs nothing." % enemy.enemy_name, false)
	take.pressed.connect(func() -> void:
		var who: String = enemy.enemy_name
		_remember_recruit(who, enemy.lv)
		_log("[color=lime]%s is bound. It walks in behind you.[/color]" % who)
		await _beg_resolved())
	_submenu_add(take)

	var refuse: Button = _big_button("Refuse it",
			"Leave it where it is. The fight goes on.", false)
	refuse.pressed.connect(func() -> void:
		_log("[color=gray]You say nothing. It picks itself back up.[/color]")
		_right_back_btn.visible = true
		_press.begin(_living_party().size())
		_actor_idx = 0 if party[0].is_alive() else _next_living(0)
		_prompt_actor())
	_submenu_add(refuse)


# A duplicate hands over whatever it was carrying and leaves. This used to
# happen on its own, with one line in the log — which from the other side of
# the screen looks exactly like an enemy vanishing for no reason. It asks now,
# even though there is only one answer, because a demon leaving the field
# should always be something the player watched happen.
func _prompt_tribute() -> void:
	_set_buttons(false)
	_hide_actions()
	_back_target = Callable()
	_right_back_btn.visible = false
	_right_title.text = "It is paying you off"
	_right_title.add_theme_color_override("font_color", Color(1.0, 0.83, 0.47))
	_submenu_clear()

	var drop: Dictionary = enemy.roll_drop()
	var coin: int = 0 if not drop.is_empty() else maxi(5, enemy.gold_reward * 2)
	var what: String = drop["name"] as String if not drop.is_empty() else "%d gold" % coin
	var who: String = enemy.display_name()

	var take: Button = _big_button("Take it",
			"%s gives up %s and leaves." % [who, what], false)
	take.pressed.connect(func() -> void:
		if drop.is_empty():
			player.gold += coin
			_log("[color=#ffd479]It empties its hands — %d gold — and goes.[/color]" % coin)
		else:
			player.add_item(drop.duplicate(), 1)
			_log("[color=#ffd479]It presses %s on you and goes.[/color]" % drop["name"])
		await _beg_resolved())
	_submenu_add(take)


# Shared tail: the demon leaves the field, and the phase opens normally on
# whatever is left. No icon is spent either way.
func _beg_resolved() -> void:
	var leaving: Enemy = enemy
	foes.erase(leaving)
	_departed.append(leaving)
	_ensure_target()
	_refresh_hp()
	_right_back_btn.visible = true

	await get_tree().create_timer(0.9).timeout
	if not is_instance_valid(self):
		return
	if foes.is_empty():
		_end_combat("talk")
		return
	_press.begin(_living_party().size())
	_actor_idx = 0 if party[0].is_alive() else _next_living(0)
	_prompt_actor()


func _prompt_actor() -> void:
	_refresh_hp()
	_show_main_actions()
	_set_buttons(true)
	_refresh_button_states()


# Every player-side action funnels through here, so the icon economy has
# exactly one owner and the phase can only end in one place.

func _do_end_of_round() -> void:
	var tick_msg: String = _do_poison_ticks()
	if not tick_msg.is_empty():
		_log(tick_msg)
		_refresh_hp()
	if _living_party().is_empty():
		await get_tree().create_timer(1.6).timeout
		if is_instance_valid(self):
			_end_combat("lose")
		return
	if not enemy.is_alive():
		_log("[color=lime]%s succumbed to poison![/color]" % enemy.enemy_name)
		await get_tree().create_timer(1.6).timeout
		if is_instance_valid(self):
			_end_combat("win")
		return
	if "meditate" in player.passive_skills:
		var mp_gain: int = min(2, player.max_mp - player.mp)
		if mp_gain > 0:
			player.mp += mp_gain
	await get_tree().create_timer(0.7).timeout
	if is_instance_valid(self):
		_begin_player_phase()



# ── Player-side actions ───────────────────────────────────────────────────────


func _commit_action(action: String) -> void:
	_show_main_actions()
	_set_buttons(false)
	var res: Dictionary = _resolve_action(action)
	_log(res["msg"] as String)
	await _after_action(res["cost"] as String)




func _on_use_item(item: Dictionary) -> void:
	var offensive: bool = item.has("inflicts_status") \
			or (item.has("element") and item.get("dmg", 0) > 0)
	if not offensive:
		await _commit_item(item)
		return
	_with_target(func() -> void: await _commit_item(item))


func _commit_item(item: Dictionary) -> void:
	_show_main_actions()
	_set_buttons(false)
	var res: Dictionary = _use_item_by_id(item["id"] as String)
	_log(res["msg"] as String)
	await _after_action(res["cost"] as String)


# Returns { msg, cost } — the log line and what the action cost in icons.
func _resolve_action(action: String) -> Dictionary:
	var actor: CharacterSheet = _actor()
	if actor.has_status(Status.PARALYZED) and randi() % 4 == 0:
		return {msg = "[color=yellow]%s is paralyzed and cannot act![/color]" % _actor_name(),
				cost = PressTurn.COST_FULL}
	if action.begins_with("Magic:"):
		return _cast_spell(action.substr(6))
	if action.begins_with("Skill:"):
		return _resolve_skill(action.substr(6))
	match action:
		"Attack":
			return _resolve_attack()
		"Analyze":
			return _resolve_analyze()
		"Skill":
			return _resolve_skill("")
		"Defend":
			# Half an icon, like a weakness read or a critical. Bracing is the
			# one defensive move in the game and a full icon made it a turn
			# thrown away — at half it buys the guard AND leaves most of the
			# action behind, so covering a demon that is about to be hit where
			# it is weak is a play rather than a forfeit.
			actor.defending = true
			return {msg = "[color=cyan]%s braces. DEF doubled until struck.[/color]" % _actor_name(),
					cost = PressTurn.COST_HALF}
	return {msg = "", cost = PressTurn.COST_FULL}



func _land_hit(res: Dictionary, element: String, prefix: String) -> Dictionary:
	var outcome: String = res["outcome"] as String
	var dmg: int        = res["dmg"] as int
	var crit: bool      = res["crit"] as bool
	var muted: bool     = bool(res.get("suppressed", false))
	var actor: CharacterSheet = _actor()

	match outcome:
		"drain":
			enemy.heal(dmg)
			return {msg = "%s  [color=lime]%s absorbs it and recovers %d HP![/color]" % [
					prefix, enemy.display_name(), dmg], cost = PressTurn.COST_LOST}
		"repel":
			actor.take_damage(dmg)
			var actor_pr: TextureRect = _member_portrait(actor)
			if actor_pr != null:
				_shake_portrait(actor_pr)
			return {msg = "%s  [color=#d070ff]Repelled! %s takes %d damage![/color]" % [
					prefix, _member_name(actor), dmg], cost = PressTurn.COST_LOST}
		"null":
			return {msg = "%s  [color=#999999]No effect.[/color]" % prefix,
					cost = PressTurn.COST_MISS}

	enemy.take_damage(dmg)
	var pr: TextureRect = _foe_portrait(enemy)
	if pr != null:
		_shake_portrait(pr)
	var extra: String = ""
	if _actor_is_player() and element == Affinity.PHYS \
			and "vampiric" in player.passive_skills:
		var heal_amt: int = max(1, dmg / 5)
		player.heal(heal_amt)
		extra = "  [color=lime]Vampiric: +%d HP.[/color]" % heal_amt
	var downed: String = ""
	if not enemy.is_alive():
		downed = "  [color=lime]%s goes down![/color]" % enemy.display_name()
	return {msg = "%s%s  [color=orange]%s takes %d damage.[/color]%s%s" % [
			prefix, CombatMath.outcome_tag(outcome, crit, muted), enemy.display_name(),
			dmg, extra, downed],
			cost = CombatMath.cost_for(outcome, crit, muted)}



# ── Enemy side ────────────────────────────────────────────────────────────────

# Picks a target and resolves one enemy action. Returns { msg, cost }.

func _pick_target(element: String) -> CharacterSheet:
	if _force_target != null and _force_target.is_alive():
		return _force_target
	var living: Array[CharacterSheet] = _living_party()
	if living.size() <= 1:
		return living[0]
	var exposed: Array[CharacterSheet] = []
	for m: CharacterSheet in living:
		if m.affinity_of(element) == Affinity.WEAK:
			exposed.append(m)
	if not exposed.is_empty() and randi() % 10 < 7:
		return exposed[randi() % exposed.size()]
	return living[randi() % living.size()]


func _defense_of(member: CharacterSheet) -> int:
	if member == player:
		return player.effective_def()
	return member.def


# ── Ailments the demons throw ─────────────────────────────────────────────────
#
# An ailment used to ride free on every hit at the template's own percentage,
# which meant a demon that poisoned you did it by accident in the middle of
# doing something else, and a demon with a low number effectively did not have
# one at all. It is a cast now: its own turn, its own MP, and a chance worth
# spending a turn on.
#
# The per-hit percentage becomes the cast's odds, tripled and floored, because
# a whole turn at five percent is an insult. A ten-turn fight lands about as
# many ailments as it used to — what changed is that you can see it coming and
# the demon paid for it.
# What a dry caster's cast is worth, against the 2.0 an paid one gets.
const CASTER_DREGS: float = 1.0

const AIL_SPELLS: Dictionary = {
	Status.POISON:     "venom",
	Status.PARALYZED:  "shock",
	Status.SILENCE:    "mute",
	Status.IMMOBILIZE: "bind",
}
const AIL_CAST_ODDS: int = 3    # in ten, while someone standing is still clean
const AIL_LAND_MULT: int = 3
const AIL_LAND_MIN:  int = 25
const AIL_LAND_MAX:  int = 85


static func ail_landing_chance(base: int) -> int:
	return clampi(base * AIL_LAND_MULT, AIL_LAND_MIN, AIL_LAND_MAX)


# Nothing to throw, nothing to throw it at, or nothing to throw it with.
func _ail_cast_ready(actor: Enemy) -> bool:
	if actor.status_attack == "" or not AIL_SPELLS.has(actor.status_attack):
		return false
	var sp: Dictionary = Spell.get_data(AIL_SPELLS[actor.status_attack] as String)
	var ail_mp: int = int(sp.get("mp", 4))
	if sp.is_empty() or actor.mp < ail_mp:
		return false
	# Same rule as support: never spend the element's MP on something else.
	if not actor.attack_elements.is_empty() and actor.mp - ail_mp < actor.skill_cost():
		return false
	# No point casting it on a side that is already carrying it.
	for m: CharacterSheet in _living_party():
		if not m.has_status(actor.status_attack):
			return true
	return false


func _enemy_cast_ailment(actor: Enemy) -> Dictionary:
	var status_id: String = actor.status_attack
	var sp: Dictionary = Spell.get_data(AIL_SPELLS[status_id] as String)
	actor.mp -= int(sp.get("mp", 4))

	# Whoever on the field is not already carrying it.
	var clean: Array[CharacterSheet] = []
	for m: CharacterSheet in _living_party():
		if not m.has_status(status_id):
			clean.append(m)
	var target: CharacterSheet = clean[randi() % clean.size()] if not clean.is_empty() \
			else _pick_target(Affinity.PHYS)

	var sname: String = Status.get_data(status_id).get("name", status_id)
	var lead: String = "[color=violet]%s casts %s![/color]" % [
			actor.display_name(), sp.get("name", sname)]

	if randi() % 100 >= ail_landing_chance(actor.ailment_chance):
		return {msg = "%s  [color=gray]%s shrugs it off.[/color]" % [
				lead, _member_name(target)], cost = PressTurn.COST_FULL}
	if target == player and "resilience" in player.passive_skills and randi() % 4 == 0:
		return {msg = "%s  [color=lime]Resilience resists %s![/color]" % [lead, sname],
				cost = PressTurn.COST_FULL}
	target.apply_status(status_id)
	return {msg = "%s  [color=violet]%s is now %s.[/color]" % [
			lead, _member_name(target), sname], cost = PressTurn.COST_FULL}


# Kept for the CombatNeg* handlers: one provoked swing at the detective, taken
# outside the icon economy because a failed negotiation is its own risk.
func _apply_enemy_turn() -> String:
	_force_target = player
	var res: Dictionary = _enemy_act(enemy)
	_force_target = null
	return res["msg"] as String


# Called by the CombatNeg* handlers when an attempt ends without a deal. The
# attempt cost the actor its turn, so the phase moves on.
func _talk_attempt_failed() -> void:
	await _after_action(PressTurn.COST_FULL)


# ── Calling demons in and out ─────────────────────────────────────────────────
#
# Three demons stand at a time and the rest wait off the field. Summon is the
# whole bench, and there are four things it can do:
#
#   revive   a demon that has fallen but is still standing in its slot
#   call     a bound demon into a slot that is free
#   swap in  a bound demon in place of one already standing, when none is
#   recall   a standing demon off the field with nothing taking its place
#
# The last of those is the one that costs you something other than a turn: the
# field is where press-turn icons come from, so pulling a demon out to save it
# is paid for in actions next phase.
#
# A fallen demon is struck off at the end of the battle, not the moment it
# drops, so the whole fight is a window in which Revive can still reach it. It
# costs what a summon costs, one icon and nothing else: MP is tight enough that
# pricing a revive in it meant never affording one in the fight that had just
# drained you, which is the only fight it matters in. It stands back up on half
# its HP with whatever put it down cleared off.
const REVIVE_HP_SHARE: float = 0.5

# Demons pulled off the field this battle. They are kept as they were — HP, MP
# and all — rather than rebuilt, so stepping one out and back in is a way to
# save it, not a way to heal it.
var bench: Array[Enemy] = []

# Which page of a long call list is showing. A run binds far more demons than
# the six slots a submenu has.
var _sub_page: int = 0


# Demons on the field with no HP left. A body keeps its slot, so reviving it or
# swapping it out are the only two things that can be done with one.
func _fallen_party() -> Array[Enemy]:
	var out: Array[Enemy] = []
	for i: int in range(1, party.size()):
		var demon: Enemy = party[i] as Enemy
		if not demon.is_alive():
			out.append(demon)
	return out


func _standing_party() -> Array[Enemy]:
	var out: Array[Enemy] = []
	for i: int in range(1, party.size()):
		var demon: Enemy = party[i] as Enemy
		if demon.is_alive():
			out.append(demon)
	return out


# Everything bound that is not currently standing. Benched demons come back as
# the instance that left; the rest are built fresh at the level they were bound.
func _available_summons() -> Array[String]:
	var standing: Array[String] = []
	for i: int in range(1, party.size()):
		standing.append((party[i] as Enemy).enemy_name)
	var out: Array[String] = []
	for name: String in player.recruited:
		if name not in standing:
			out.append(name)
	return out


func _remember_recruit(demon_name: String, lv: int = 1) -> void:
	player.remember_recruit(demon_name, lv)


func _open_summon_menu() -> void:
	_sub_page = 0
	_show_summon_submenu()


func _show_summon_submenu() -> void:
	_hide_actions()
	_set_back(_show_main_actions)
	_right_title.text = "Summon"
	_right_title.add_theme_color_override("font_color", Color(0.40, 1.0, 0.55))
	_submenu_clear()

	var entries: Array[Dictionary] = []

	# The fallen come first: one of them is on a clock that ends with the
	# battle, and everything under it will still be there afterwards.
	for demon: Enemy in _fallen_party():
		entries.append({title = demon.enemy_name, detail = "revive",
				press = _on_revive.bind(demon)})

	var room: bool = party.size() < MAX_PARTY
	for summon_name: String in _available_summons():
		if room:
			entries.append({title = summon_name, detail = "call",
					press = _on_summon.bind(summon_name)})
		else:
			entries.append({title = summon_name, detail = "swap in",
					press = _show_swap_submenu.bind(summon_name)})

	# Last, because taking a demon off the field is the only one of these that
	# leaves you with less than you had.
	for demon: Enemy in _standing_party():
		entries.append({title = demon.enemy_name,
				detail = "recall  %d/%d hp" % [demon.hp, demon.max_hp],
				press = _on_withdraw.bind(demon)})

	if entries.is_empty():
		_submenu_add(_dim_label("Nothing left to call."))
		return
	_fill_submenu(entries, _show_summon_submenu)


# One page of a list into the submenu's six slots. Anything longer keeps the
# last slot for a pager rather than dropping what does not fit — which is what
# used to happen once a run had bound seven demons.
func _fill_submenu(entries: Array[Dictionary], rebuild: Callable) -> void:
	if entries.size() <= MENU_SLOTS:
		_sub_page = 0
		for e: Dictionary in entries:
			_submenu_add(_entry_button(e))
		return

	var per: int = MENU_SLOTS - 1
	var pages: int = ceili(float(entries.size()) / float(per))
	_sub_page = clampi(_sub_page, 0, pages - 1)
	var first: int = _sub_page * per
	for i: int in range(first, mini(first + per, entries.size())):
		_submenu_add(_entry_button(entries[i]))

	var more: Button = _big_button("More", "%d / %d" % [_sub_page + 1, pages], false)
	more.pressed.connect(func() -> void:
		_sub_page = (_sub_page + 1) % pages
		rebuild.call())
	_submenu_add(more)


func _entry_button(e: Dictionary) -> Button:
	var btn: Button = _big_button(e["title"] as String, e["detail"] as String, false)
	btn.pressed.connect(e["press"] as Callable)
	return btn


# ── Swapping ──────────────────────────────────────────────────────────────────
#
# With three already standing, calling a fourth means one of them steps back.
# What that costs depends on who: a living demon goes to the bench exactly as it
# is and can be called again, while a body has nothing left to step back to and
# is struck off there and then — the same loss it was going to take when the
# battle ended, taken early.
func _show_swap_submenu(incoming: String) -> void:
	_hide_actions()
	_set_back(_show_summon_submenu)
	_right_title.text = "Who steps back?"
	_right_title.add_theme_color_override("font_color", Color(1.0, 0.80, 0.40))
	_submenu_clear()

	for i: int in range(1, party.size()):
		var demon: Enemy = party[i] as Enemy
		var note: String = "steps back" if demon.is_alive() else "struck off"
		var btn: Button = _big_button(demon.enemy_name, note, false)
		btn.pressed.connect(_on_swap.bind(demon, incoming))
		_submenu_add(btn)


func _on_swap(outgoing: Enemy, incoming: String) -> void:
	_show_main_actions()
	_set_buttons(false)

	var idx: int = party.find(outgoing)
	if idx <= 0:
		return
	var was_alive: bool = outgoing.is_alive()
	if was_alive:
		bench.append(outgoing)
	else:
		_strike_off(outgoing)

	var demon: Enemy = _take_from_bench(incoming)
	if demon == null:
		demon = player.bound_demon(incoming)
		add_child(demon)
	party[idx] = demon
	_ensure_actor_in_range()
	_rebuild_party_slots()
	if was_alive:
		_log("[color=#7fe0a0]%s steps back and %s takes the field.[/color]"
				% [outgoing.enemy_name, demon.enemy_name])
	else:
		_log("[color=#7fe0a0]%s takes the field.[/color]  [color=#d08080]%s is left where it fell.[/color]"
				% [demon.enemy_name, outgoing.enemy_name])
	await _after_action(PressTurn.COST_FULL)


# ── Recalling ─────────────────────────────────────────────────────────────────
#
# Taking a demon off the field with nothing replacing it. The slot closes, so
# the party is one icon lighter next phase — which is the whole price, and the
# reason this is worth doing anyway when the alternative is watching something
# on three HP take one more hit. It keeps everything it had; calling it back
# later returns the same demon, not a fresh one.
func _on_withdraw(demon: Enemy) -> void:
	_show_main_actions()
	_set_buttons(false)
	var idx: int = party.find(demon)
	if idx <= 0 or not demon.is_alive():
		return
	party.remove_at(idx)
	bench.append(demon)
	_ensure_actor_in_range()
	_rebuild_party_slots()
	_log("[color=#7fe0a0]%s is called back and stands down.[/color]" % demon.enemy_name)
	await _after_action(PressTurn.COST_FULL)


func _take_from_bench(demon_name: String) -> Enemy:
	for demon: Enemy in bench:
		if demon.enemy_name == demon_name:
			bench.erase(demon)
			return demon
	return null


func _strike_off(demon: Enemy) -> void:
	if demon.enemy_name not in lost_demons:
		lost_demons.append(demon.enemy_name)
	player.recruited.erase(demon.enemy_name)
	player.deactivate_demon(demon.enemy_name)


# Taking a demon off the field can leave the turn cursor pointing past the end
# of the party, so it is pulled back into range before anything reads it.
func _ensure_actor_in_range() -> void:
	_actor_idx = clampi(_actor_idx, 0, party.size() - 1)


# Binding costs a full icon and the demon joins at the level it was bound.
# Its icon arrives with the next phase, not this one.
func _on_summon(summon_name: String) -> void:
	_show_main_actions()
	_set_buttons(false)
	var demon: Enemy = _take_from_bench(summon_name)
	if demon == null:
		demon = player.bound_demon(summon_name)
		add_child(demon)
	party.append(demon)
	_rebuild_party_slots()
	_log("[color=#7fe0a0]%s answers the call.[/color]" % demon.enemy_name)
	await _after_action(PressTurn.COST_FULL)


# Costs a full icon, like a summon does, and nothing else. Whatever put the
# demon down came with it — a poisoned corpse pulled back up is still poisoned
# — so the slate is wiped along with the HP.
func _on_revive(demon: Enemy) -> void:
	if demon.is_alive():
		_show_main_actions()
		return
	_show_main_actions()
	_set_buttons(false)
	demon.active_statuses.clear()
	demon.defending = false
	demon.hp = maxi(1, roundi(float(demon.max_hp) * REVIVE_HP_SHARE))
	_rebuild_party_slots()
	_log("[color=#7fe0a0]%s is raised, and stands.[/color]" % demon.enemy_name)
	await _after_action(PressTurn.COST_FULL)


# ── Fleeing ───────────────────────────────────────────────────────────────────


# ── Button state ──────────────────────────────────────────────────────────────


# ── The party ─────────────────────────────────────────────────────────────────

# His bound demons are already on the field when the battle opens — they are
# his party, not something he builds after the first enemy phase. Each one
# carries its own press-turn icon, so who he has bound decides how many actions
# he gets. Summon is left for filling a slot that opens up mid-fight.
func _form_party() -> void:
	party = [player]
	for demon_name: String in player.active_demons:
		if party.size() >= MAX_PARTY:
			break
		var demon: Enemy = player.bound_demon(demon_name)
		add_child(demon)
		party.append(demon)


# ── The enemy line-up ─────────────────────────────────────────────────────────

# Three Bats need telling apart before anything else reads correctly.
func _assign_battle_tags() -> void:
	var counts: Dictionary = {}
	for f: Enemy in foes:
		counts[f.enemy_name] = int(counts.get(f.enemy_name, 0)) + 1
	var seen: Dictionary = {}
	const TAGS: Array[String] = ["A", "B", "C", "D"]
	for f: Enemy in foes:
		if int(counts[f.enemy_name]) > 1:
			var i: int = int(seen.get(f.enemy_name, 0))
			f.battle_tag = TAGS[mini(i, TAGS.size() - 1)]
			seen[f.enemy_name] = i + 1


func _encounter_line() -> String:
	if foes.size() == 1:
		return "%s appeared!" % foes[0].enemy_name
	var names: Array[String] = []
	for f: Enemy in foes:
		names.append(f.display_name())
	return "%s appeared!" % ", ".join(names)


func _living_foes() -> Array[Enemy]:
	var out: Array[Enemy] = []
	for f: Enemy in foes:
		if f.is_alive():
			out.append(f)
	return out


# Keeps the targeted foe on something that is still standing.
func _ensure_target() -> void:
	if enemy != null and enemy.is_alive():
		return
	var living: Array[Enemy] = _living_foes()
	if not living.is_empty():
		enemy = living[0]


func _build_enemy_area(parent: Control) -> void:
	var area: HBoxContainer = HBoxContainer.new()
	area.size_flags_vertical       = Control.SIZE_EXPAND_FILL
	area.size_flags_stretch_ratio  = 1.0
	area.add_theme_constant_override("separation", 6)
	parent.add_child(area)

	# Always MAX_PARTY columns, whatever the pack size. A lone demon used to
	# get the whole width — an HP bar across the screen — and a pack of two
	# sat at a different pitch from a pack of four, so the line-up moved every
	# encounter. Empty columns hold the grid instead.
	for f: Enemy in foes:
		area.add_child(_build_foe_column(f))
	for _i: int in range(MAX_PARTY - foes.size()):
		var blank: Control = Control.new()
		blank.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		blank.size_flags_vertical   = Control.SIZE_EXPAND_FILL
		blank.mouse_filter          = Control.MOUSE_FILTER_IGNORE
		area.add_child(blank)


# One column per demon. Identical geometry across the row so a four-strong
# pack reads as one line-up rather than four separate widgets.
func _build_foe_column(foe: Enemy) -> Control:
	var col: VBoxContainer = VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_END
	col.add_theme_constant_override("separation", 3)

	var icon: TextureRect = TextureRect.new()
	if foe.sprite_path != "":
		icon.texture        = load(foe.sprite_path) as Texture2D
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	else:
		icon.texture  = load("res://icon.svg") as Texture2D
		icon.modulate = Color(0.95, 0.28, 0.28)
	icon.stretch_mode          = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_horizontal = Control.SIZE_FILL
	icon.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	icon.modulate              = foe.tint
	col.add_child(icon)

	# The marker sits directly over the name so it reads as pointing at this
	# demon rather than floating at the top of the column.
	var marker: Label = Label.new()
	marker.text                 = "\u25bc"
	marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	marker.add_theme_font_size_override("font_size", 12)
	marker.add_theme_color_override("font_color", Color(1.0, 0.92, 0.45))
	col.add_child(marker)

	var name_lbl: Label = Label.new()
	name_lbl.text                 = foe.display_name()
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 13)
	col.add_child(name_lbl)

	# Centred and width-capped: a lone demon used to stretch its bar across the
	# whole screen, which read as a boss rather than a rat.
	var bar_wrap: CenterContainer = CenterContainer.new()
	col.add_child(bar_wrap)

	var bar: ProgressBar = _make_bar(foe.max_hp)
	bar.custom_minimum_size = Vector2(160, 10)
	bar_wrap.add_child(bar)

	var hp_lbl: Label = Label.new()
	hp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_lbl.add_theme_font_size_override("font_size", 11)
	hp_lbl.add_theme_color_override("font_color", Color(0.90, 0.60, 0.60))
	col.add_child(hp_lbl)

	var stage_lbl: Label = Label.new()
	stage_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage_lbl.add_theme_font_size_override("font_size", 10)
	col.add_child(stage_lbl)

	_foe_rows.append({foe = foe, portrait = icon, name_lbl = name_lbl,
			bar = bar, hp_lbl = hp_lbl, stage_lbl = stage_lbl, marker = marker})
	return col


func _foe_portrait(foe: Enemy) -> TextureRect:
	for r: Dictionary in _foe_rows:
		if r["foe"] == foe:
			return r["portrait"] as TextureRect
	return null


# ── Target picking ────────────────────────────────────────────────────────────

# Runs `cb` once a target is settled. With one demon left there is nothing to
# choose, so the step is skipped rather than clicked through.
func _with_target(cb: Callable) -> void:
	var living: Array[Enemy] = _living_foes()
	if living.size() <= 1:
		_ensure_target()
		cb.call()
		return
	_hide_actions()
	_set_back(_show_main_actions)
	_right_title.text = "Target"
	_right_title.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45))
	_submenu_clear()
	for foe: Enemy in living:
		var btn: Button = _big_button(foe.display_name(),
				"%d / %d" % [foe.hp, foe.max_hp], false)
		btn.pressed.connect(func() -> void:
			enemy = foe
			_refresh_hp()
			cb.call())
		_submenu_add(btn)


# ── Refresh ───────────────────────────────────────────────────────────────────


func _refresh_foe_rows() -> void:
	var multiple: bool = _living_foes().size() > 1
	for r: Dictionary in _foe_rows:
		var foe: Enemy = r["foe"] as Enemy
		if foe in _departed:
			# Ghosted rather than erased. Blanking the column outright made a
			# demon that walked away look like one that had glitched out of
			# existence — it still has a name and a place in the line.
			(r["marker"] as Label).visible = false
			(r["portrait"] as TextureRect).modulate = Color(1, 1, 1, 0.10)
			var gone_lbl: Label = r["name_lbl"] as Label
			gone_lbl.text = foe.display_name()
			gone_lbl.add_theme_color_override("font_color", Color(0.40, 0.40, 0.46))
			((r["bar"] as ProgressBar).get_parent() as Control).visible = false
			(r["hp_lbl"] as Label).text = "Left"
			(r["hp_lbl"] as Label).add_theme_color_override("font_color",
					Color(0.45, 0.45, 0.52))
			(r["stage_lbl"] as Label).text = ""
			continue
		var alive: bool = foe.is_alive()
		var targeted: bool = (foe == enemy) and alive
		(r["marker"] as Label).visible = targeted and multiple
		(r["portrait"] as TextureRect).modulate.a = 1.0 if alive else 0.18
		var name_lbl: Label = r["name_lbl"] as Label
		if not alive:
			name_lbl.add_theme_color_override("font_color", Color(0.38, 0.30, 0.30))
		elif targeted:
			name_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.45))
		else:
			name_lbl.add_theme_color_override("font_color", Color(0.95, 0.35, 0.35))
		var bar: ProgressBar = r["bar"] as ProgressBar
		bar.max_value = foe.max_hp
		bar.value     = foe.hp
		_apply_hp_bar(bar, foe.hp, foe.max_hp)
		var wrap: Control = bar.get_parent() as Control
		# Never wider than a comfortable read, never wider than its own column.
		bar.custom_minimum_size.x = minf(maxf(wrap.size.x, 120.0) * 0.82, 190.0)
		wrap.visible = alive
		var hp_lbl: Label = r["hp_lbl"] as Label
		hp_lbl.text = "%d / %d" % [foe.hp, foe.max_hp] if alive else "Down"
		hp_lbl.add_theme_color_override("font_color",
				hp_tint(foe.hp, foe.max_hp) if alive else Color(0.55, 0.38, 0.38))

		var stage_lbl: Label = r["stage_lbl"] as Label
		var bits: Array[String] = []
		var chart: String = _foe_chart_text(foe)
		if chart != "":
			bits.append(chart)
		var stg: String = _format_stages(foe)
		if stg != "":
			bits.append(stg)
		stage_lbl.text = "   ".join(bits) if alive else ""
		# Green when the stack favours them, amber when it favours you.
		var net: int = foe.stage(CharacterSheet.STAT_ATK) \
				+ foe.stage(CharacterSheet.STAT_DEF) + foe.stage(CharacterSheet.STAT_AGL)
		stage_lbl.add_theme_color_override("font_color",
				Color(1.0, 0.55, 0.35) if net > 0 else Color(0.55, 0.90, 0.70))


# ── Phase flow ────────────────────────────────────────────────────────────────

func _after_action(cost: String) -> void:
	var collapsed: bool = (cost == PressTurn.COST_LOST and _press.total() > 0)
	_press.spend(cost)
	_ensure_target()
	_refresh_hp()

	if _living_foes().is_empty():
		await get_tree().create_timer(1.6).timeout
		if is_instance_valid(self):
			_end_combat("win")
		return

	if _living_party().is_empty():
		_log("[color=red]You were defeated...[/color]")
		await get_tree().create_timer(1.8).timeout
		if is_instance_valid(self):
			_end_combat("lose")
		return

	if collapsed:
		_log("[color=#d070ff]Your phase collapses.[/color]")

	if _press.has_turns():
		await get_tree().create_timer(0.5).timeout
		if is_instance_valid(self):
			_actor_idx = _next_living(_actor_idx)
			_prompt_actor()
		return

	await _enemy_phase()


func _enemy_phase() -> void:
	_set_buttons(false)
	_show_main_actions()
	# One icon per demon still standing — the same rule the player side runs on,
	# which is what makes a pack of four genuinely dangerous.
	var living: Array[Enemy] = _living_foes()
	var total: int = 0
	for f: Enemy in living:
		total += maxi(1, f.icons)
	_foe_press.begin(maxi(1, total))
	_foe_turn_idx = 0
	_refresh_hp()
	await get_tree().create_timer(0.6).timeout

	while is_instance_valid(self) and _foe_press.has_turns() \
			and not _living_foes().is_empty() and not _living_party().is_empty():
		var actors: Array[Enemy] = _living_foes()
		var actor: Enemy = actors[_foe_turn_idx % actors.size()]
		_foe_turn_idx += 1
		var res: Dictionary = _enemy_act(actor)
		_log(res["msg"] as String)
		# Their phase ends on a repel or a drain exactly as yours does, and it
		# is worth saying out loud — the reason the pack stopped is a read the
		# player just made, not the clock running out.
		var lost: bool = (res["cost"] as String) == PressTurn.COST_LOST \
				and _foe_press.total() > 0
		_foe_press.spend(res["cost"] as String)
		if lost:
			_log("[color=#7fd4ff]Their phase collapses.[/color]")
		_refresh_hp()
		if _foe_press.has_turns() and not _living_party().is_empty() \
				and not _living_foes().is_empty():
			await get_tree().create_timer(0.8).timeout

	if not is_instance_valid(self):
		return
	if _living_party().is_empty():
		_log("[color=red]You were defeated...[/color]")
		await get_tree().create_timer(1.8).timeout
		if is_instance_valid(self):
			_end_combat("lose")
		return
	if _living_foes().is_empty():
		await get_tree().create_timer(1.6).timeout
		if is_instance_valid(self):
			_end_combat("win")
		return

	await _do_end_of_round()


func _do_poison_ticks() -> String:
	var msgs: Array[String] = []
	for m: CharacterSheet in party:
		if not m.is_alive():
			continue
		var dmg: int = m.poison_tick()
		if dmg > 0:
			msgs.append("[color=chartreuse]Poison deals %d damage to %s![/color]" % [
					dmg, _member_name(m)])
	for f: Enemy in foes:
		if not f.is_alive():
			continue
		var e_dmg: int = f.poison_tick()
		if e_dmg > 0:
			msgs.append("[color=violet]Poison deals %d damage to %s![/color]" % [
					e_dmg, f.display_name()])
			if not f.is_alive():
				msgs.append("[color=lime]%s succumbed to poison![/color]" % f.display_name())
	return "\n".join(msgs)


# ── Enemy actions ─────────────────────────────────────────────────────────────


# ── Fleeing ───────────────────────────────────────────────────────────────────

func _do_flee() -> void:
	var fastest: int = 0
	for f: Enemy in _living_foes():
		fastest = maxi(fastest, f.agl)
	if player.effective_agl() >= fastest or randi() % 2 == 0:
		_log("You slip away into the dark.")
		await get_tree().create_timer(0.9).timeout
		if is_instance_valid(self):
			_end_combat("flee")
		return
	_log("[color=yellow]Failed to escape![/color]")
	await _after_action(PressTurn.COST_FULL)


# ── A demon leaving the fight ─────────────────────────────────────────────────

# A successful negotiation removes one demon, not the encounter. The battle
# only ends here if it was the last one standing.
func _foe_departs(reason: String) -> void:
	var leaving: Enemy = enemy
	foes.erase(leaving)
	_departed.append(leaving)
	_ensure_target()
	_refresh_hp()
	if foes.is_empty():
		await get_tree().create_timer(0.4).timeout
		if is_instance_valid(self):
			_end_combat(reason)
		return
	_refresh_hp()
	await _after_action(PressTurn.COST_FULL)


# ── Button state ──────────────────────────────────────────────────────────────


# ── Actions ───────────────────────────────────────────────────────────────────

func _on_action(action: String) -> void:
	match action:
		"Skills":
			_show_skills_submenu()
			return
		"Item":
			_show_item_submenu()
			return
		"Talk":
			_with_target(func() -> void:
				if not enemy.negotiable:
					_log("[color=gray]%s won't listen.[/color]" % enemy.display_name())
					_prompt_actor()
					return
				_show_talk_submenu())
			return
		"Summon":
			_open_summon_menu()
			return
		"Defend":
			# Bracing is not aimed at anybody — no target step.
			await _commit_action(action)
			return
		"Flee":
			_set_buttons(false)
			await _do_flee()
			return

	_with_target(func() -> void: await _commit_action(action))


# Everything the acting member can swing lives in one list: the plain attack
# first, then whatever they carry. For the detective that is his equipped
# spells; for a bound demon it is its own element.



# ── Button state ──────────────────────────────────────────────────────────────

# Talk, Item, Summon and Flee are the detective's alone. On a demon's turn they
# are hidden rather than greyed — there is not much room on a phone, and a row
# of dead buttons reads as a bug.
func _refresh_button_states() -> void:
	var is_p: bool = _actor_is_player()
	for key: String in ["Item", "Talk", "Summon", "Flee"]:
		(_buttons[key] as Button).visible = is_p

	_buttons["Skills"].disabled = false
	# Bracing on top of a brace does nothing but spend the icon, and at half an
	# icon it is cheap enough to do by accident.
	_buttons["Defend"].disabled = _actor().defending
	_buttons["Item"].disabled   = not is_p
	_buttons["Talk"].disabled   = not is_p or _living_foes().is_empty()
	# Live whenever there is anything to move: a body to raise, a demon waiting
	# off the field, or one standing that would rather not be.
	_buttons["Summon"].disabled = not is_p or (_fallen_party().is_empty() \
			and _available_summons().is_empty() and _standing_party().is_empty())
	_buttons["Flee"].disabled   = not is_p


# ── The party line-up ─────────────────────────────────────────────────────────

# The player's side is built the same way as the enemy's — a row of portraits
# with a name and a bar under each — so the two halves of the screen read as
# one fight rather than as a roster facing a picture.
func _build_party_area(parent: Control) -> void:
	var panel: PanelContainer = PanelContainer.new()
	# Same stretch ratio as the enemy row, so the two sides get equal height.
	panel.size_flags_vertical      = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 1.0
	parent.add_child(panel)

	var m: MarginContainer = MarginContainer.new()
	for side: String in ["margin_left", "margin_right"]:
		m.add_theme_constant_override(side, 8)
	for side2: String in ["margin_top", "margin_bottom"]:
		m.add_theme_constant_override(side2, 5)
	panel.add_child(m)

	_party_box = HBoxContainer.new()
	_party_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_party_box.add_theme_constant_override("separation", 6)
	m.add_child(_party_box)




# A coat-and-hat silhouette standing in until the detective has real art. Drawn
# rather than loaded because the engine icon at portrait size reads as a bug.
# Flat shapes only — a shading trick here turned the whole figure into a cross.
static func _hero_placeholder() -> ImageTexture:
	const W: int = 48
	const H: int = 64
	var img: Image = Image.create(W, H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var coat: Color = Color(0.28, 0.33, 0.47, 1.0)
	var skin: Color = Color(0.52, 0.57, 0.72, 1.0)

	for y: int in range(H):
		for x: int in range(W):
			var col: Color = Color(0, 0, 0, 0)
			if y >= 5 and y < 15 and x >= 17 and x < 31:
				col = coat                                   # crown
			elif y >= 15 and y < 19 and x >= 7 and x < 41:
				col = coat                                   # brim
			elif y >= 19 and y < 31 and Vector2(x - 24, y - 25).length() < 6.2:
				col = skin                                   # face under the brim
			elif y >= 31 and y < 35 and x >= 22 and x < 27:
				col = coat                                   # collar
			elif y >= 35:
				var t: float = float(y - 35) / float(H - 35)
				if absf(x - 24.0) < lerpf(9.0, 18.0, t):
					col = coat                               # coat, flaring out
			if col.a > 0.0:
				img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


func _member_portrait(member: CharacterSheet) -> TextureRect:
	for slot: Dictionary in _party_slots:
		if slot["member"] == member:
			return slot["portrait"] as TextureRect
	return null


# ── The menu ──────────────────────────────────────────────────────────────────

# Actions and submenus share one column: a submenu replaces the action list
# instead of sitting beside it, which is most of the width back on a phone.




# ── Refresh ───────────────────────────────────────────────────────────────────

func _refresh_hp() -> void:
	if _actor_banner != null:
		if _press != null and _press.has_turns():
			_actor_banner.text = "%s's turn" % _actor_name()
			_actor_banner.add_theme_color_override("font_color",
					Color(1.0, 0.92, 0.45) if _actor_is_player()
					else Color(0.62, 1.0, 0.78))
		else:
			_actor_banner.text = "Enemy phase"
			_actor_banner.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))

	_refresh_party_slots()
	_refresh_foe_rows()
	_refresh_icons()



# ── Press-turn corner ─────────────────────────────────────────────────────────

# Both sides' icons live in the top-right corner, out of the fight rather than
# wedged between the two line-ups.
func _build_icon_overlay() -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.anchor_left   = 1.0
	panel.anchor_right  = 1.0
	panel.anchor_top    = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_left   = -186.0
	panel.offset_right  = -10.0
	panel.offset_top    = 8.0
	panel.offset_bottom = 66.0
	panel.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	add_child(panel)

	var m: MarginContainer = MarginContainer.new()
	for side: String in ["margin_left", "margin_right"]:
		m.add_theme_constant_override(side, 10)
	for side2: String in ["margin_top", "margin_bottom"]:
		m.add_theme_constant_override(side2, 5)
	panel.add_child(m)

	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 1)
	m.add_child(col)

	_icon_lbl = Label.new()
	_icon_lbl.add_theme_color_override("font_color", Color(0.55, 0.95, 1.0))
	col.add_child(_icon_lbl)

	_foe_icon_lbl = Label.new()
	_foe_icon_lbl.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
	col.add_child(_foe_icon_lbl)


func _refresh_icons() -> void:
	if _press == null or _foe_press == null:
		return
	_icon_lbl.text = "You  %s" % (_press.icons_string() if _press.has_turns() else "\u2014")
	_foe_icon_lbl.text = "Foe  %s" % (
			_foe_press.icons_string() if _foe_press.has_turns() else "\u2014")


# ── Skills ────────────────────────────────────────────────────────────────────

func _show_skills_submenu() -> void:
	_hide_actions()
	_set_back(_show_main_actions)
	_right_title.text = "%s's skills" % _actor_name()
	_right_title.add_theme_color_override("font_color", Color(0.80, 0.62, 1.0))
	_submenu_clear()

	var actor: CharacterSheet = _actor()

	_submenu_add(_make_skill_button("Attack", "Attack",
			Affinity.element_name(Affinity.PHYS), "\u2014",
			actor.has_status(Status.IMMOBILIZE)))

	if _actor_is_player():
		# Free, always carried, and the only way to see a chart before spending
		# turns finding it out the hard way.
		_submenu_add(_make_skill_button("Analyze", "Analyze", "Read", "\u2014", false))
		if player.equipped_spells.is_empty():
			_submenu_add(_dim_label("No spells equipped."))
			return
		var silenced: bool = player.has_status(Status.SILENCE)
		for spell_id: String in player.equipped_spells:
			var data: Dictionary = Spell.get_data(spell_id)
			if data.is_empty():
				continue
			var element: String = data.get("element", "")
			var tag: String = Affinity.element_name(element) if element != "" \
					else (data.get("type", "dmg") as String).capitalize()
			# How far it reaches is the thing a player most needs to know
			# before spending 22 MP, so it rides next to the element.
			if element != "":
				tag += "  " + Spell.reach_tag(spell_id)
			var cost: int = int(data.get("mp", 0))
			_submenu_add(_make_skill_button("Magic:" + spell_id,
					data["name"] as String, tag, "%d MP" % cost,
					silenced or player.mp < cost))
		return

	var demon: Enemy = actor as Enemy
	if demon.attack_elements.is_empty():
		return
	var demon_cost: int = demon.skill_cost()
	var blocked: bool = demon.has_status(Status.SILENCE) or demon.mp < demon_cost
	# One button per line it carries, so a demon bound with three is worth
	# three buttons rather than one that silently picks for you.
	var reach: String = Spell.reach_tag_for(demon.attack_reach)
	for e: String in demon.attack_elements:
		_submenu_add(_make_skill_button("Skill:" + e,
				"%s Strike" % Affinity.element_name(e),
				"%s  %s" % [Affinity.element_name(e), reach],
				"%d MP" % demon_cost, blocked))


# A bound demon's own element, paid for out of its own pool.
func _resolve_skill(chosen: String) -> Dictionary:
	var actor: Enemy = _actor() as Enemy
	var element: String = chosen
	if element == "" or element not in actor.attack_elements:
		element = actor.attack_element
	if element == "":
		return {msg = "[color=gray]%s has nothing to call on.[/color]" % actor.display_name(),
				cost = PressTurn.COST_FULL}
	var price: int = actor.skill_cost()
	if actor.mp < price:
		return {msg = "[color=gray]%s: not enough MP![/color]" % actor.display_name(),
				cost = PressTurn.COST_FULL}
	actor.mp -= price
	var power: float = float(actor.mag) * actor.stage_mult(CharacterSheet.STAT_MAG)
	var banishing: bool = Affinity.is_banishing(element)

	# A bound demon casts exactly what it cast at you — same lines, same width.
	# The single-target case keeps the target you picked; anything wider draws
	# its own, which is why the menu does not ask.
	if actor.attack_reach != Spell.SHAPE_ONE:
		return _demon_spread(actor, element, power * 2.0, banishing)

	if banishing:
		return _demon_banish_one(actor, enemy, element, power)

	var crit: bool = CombatMath.roll_crit(actor)
	var res: Dictionary = CombatMath.resolve(int(power * 2.0) - _guarded_def(enemy),
			element, enemy, crit, enemy.defending)
	return _land_hit(res, element, "%s calls up %s!" % [
			actor.display_name(), Affinity.element_name(element)])


# One demon of yours, one line, one foe. Light and dark expel rather than burn,
# the same as they do out of the detective's own hands.
func _demon_banish_one(actor: Enemy, foe: Enemy, element: String,
		power: float) -> Dictionary:
	var res: Dictionary = CombatMath.resolve_banish(foe, element,
			maxi(1, int(power)), false, actor)
	var lead: String = "%s calls the %s!" % [
			actor.display_name(), Affinity.element_name(element)]
	match res["outcome"]:
		"banished":
			foe.take_damage(foe.max_hp * 2)
			return {msg = "[color=#c9a6ff]%s %s is taken, whole.[/color]" % [
					lead, foe.display_name()],
					cost = PressTurn.COST_HALF if foe.affinity_of(element) == Affinity.WEAK
						else PressTurn.COST_FULL}
		"null":
			return {msg = "[color=#999999]%s %s does not feel it.[/color]" % [
					lead, foe.display_name()], cost = PressTurn.COST_MISS}
		"repel":
			actor.take_damage(int(res["dmg"]))
			return {msg = "[color=#d070ff]%s Turned back — %s takes %d.[/color]" % [
					lead, actor.display_name(), int(res["dmg"])], cost = PressTurn.COST_LOST}
		"drain":
			foe.heal(int(res["dmg"]))
			return {msg = "[color=lime]%s %s drinks it and recovers %d HP.[/color]" % [
					lead, foe.display_name(), int(res["dmg"])], cost = PressTurn.COST_LOST}
	return {msg = "[color=gray]%s %s holds.[/color]" % [lead, foe.display_name()],
			cost = PressTurn.COST_FULL}


# A bound demon's wide cast. Same arithmetic as the detective's own spread —
# what it gains in width it gives up on each target.
func _demon_spread(actor: Enemy, element: String, base: float,
		banishing: bool) -> Dictionary:
	var spread: float = actor.reach_spread(banishing)
	var targets: Array[Enemy] = _spread_targets(actor.attack_reach)
	var lines: Array[String] = ["[color=#9ad0ff]%s calls up %s over %d of them![/color]" % [
			actor.display_name(), Affinity.element_name(element), targets.size()]]
	var outcomes: Array[String] = []
	var reflected: int = 0
	var took_weak: bool = false

	for foe: Enemy in targets:
		if banishing:
			var br: Dictionary = CombatMath.resolve_banish(
					foe, element, maxi(1, int(base * spread)), false, actor, spread)
			match br["outcome"]:
				"banished":
					var was_weak: bool = foe.affinity_of(element) == Affinity.WEAK
					took_weak = took_weak or was_weak
					foe.take_damage(foe.max_hp * 2)
					outcomes.append("weak" if was_weak else "hit")
					lines.append("[color=#c9a6ff]%s is taken.[/color]" % foe.display_name())
				"drain":
					foe.heal(int(br["dmg"]))
					outcomes.append("drain")
					lines.append("[color=lime]%s drinks it.[/color]" % foe.display_name())
				"repel":
					reflected += int(br["dmg"])
					outcomes.append("repel")
					lines.append("[color=#d070ff]%s turns it back.[/color]" % foe.display_name())
				"null":
					outcomes.append("null")
					lines.append("[color=#999999]%s does not feel it.[/color]" % foe.display_name())
				_:
					outcomes.append("hit")
					lines.append("[color=gray]%s holds.[/color]" % foe.display_name())
			continue

		var res: Dictionary = CombatMath.resolve(
				int(base * spread) - _guarded_def(foe), element, foe,
				CombatMath.roll_crit(actor), foe.defending)
		var outcome: String = res["outcome"] as String
		var dmg: int = int(res["dmg"])
		outcomes.append(outcome)
		match outcome:
			"drain":
				foe.heal(dmg)
				lines.append("[color=lime]%s drinks it and recovers %d.[/color]" % [
						foe.display_name(), dmg])
			"repel":
				reflected += dmg
				lines.append("[color=#d070ff]%s turns it back.[/color]" % foe.display_name())
			"null":
				lines.append("[color=#999999]%s does not feel it.[/color]" % foe.display_name())
			_:
				foe.take_damage(dmg)
				lines.append("[color=orange]%s takes %d.[/color]%s" % [
						foe.display_name(), dmg,
						CombatMath.outcome_tag(outcome, false, bool(res.get("suppressed", false)))])

	if reflected > 0:
		actor.take_damage(reflected)
		lines.append("[color=red]%s takes %d from what came back.[/color]" % [
				actor.display_name(), reflected])

	_ensure_target()
	var cost: String = _spread_cost(outcomes)
	if cost == PressTurn.COST_FULL and took_weak:
		cost = PressTurn.COST_HALF
	return {msg = " ".join(lines), cost = cost}


# ── Enemy actions ─────────────────────────────────────────────────────────────


# ── The menu ──────────────────────────────────────────────────────────────────

# Top-level actions run across the bottom as an icon bar — six thumb targets in
# a row rather than a stack where Flee sits on the screen edge. Submenus are
# lists of variable-length text, so those stay vertical and replace the bar.



# ── Action icons ──────────────────────────────────────────────────────────────

# Small flat glyphs drawn in code — six shapes is less weight than six PNGs,
# and they stay legible against the wireframe palette. Labels sit under them:
# a shield and a speech bubble are guessable, Summon and Skills are not.
static func _action_icon(action: String) -> ImageTexture:
	const N: int = 26
	var img: Image = Image.create(N, N, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c: Color = Color(0.86, 0.88, 0.94, 1.0)

	match action:
		"Skills":                                   # a blade with a crossguard
			# Three parallel strokes — a one-pixel diagonal reads as a scratch.
			_px_line(img, 7, 18, 19, 6, c)
			_px_line(img, 8, 19, 20, 7, c)
			_px_line(img, 6, 17, 18, 5, c)
			_px_line(img, 19, 5, 21, 7, c)
			_px_line(img, 4, 14, 11, 21, c)
			_px_line(img, 5, 13, 12, 20, c)
			_px_rect(img, 2, 20, 6, 24, c)
		"Item":                                     # a flask
			_px_rect(img, 10, 3, 16, 6, c)
			_px_line(img, 11, 6, 6, 17, c)
			_px_line(img, 15, 6, 20, 17, c)
			_px_line(img, 6, 17, 20, 17, c)
			_px_rect(img, 7, 17, 19, 21, c)
		"Defend":                                   # a shield
			_px_rect(img, 5, 4, 21, 7, c)
			_px_line(img, 5, 4, 5, 12, c)
			_px_line(img, 20, 4, 20, 12, c)
			_px_line(img, 5, 12, 13, 22, c)
			_px_line(img, 20, 12, 13, 22, c)
		"Talk":                                     # a speech bubble
			_px_rect(img, 3, 4, 23, 6, c)
			_px_rect(img, 3, 15, 23, 17, c)
			_px_line(img, 3, 4, 3, 16, c)
			_px_line(img, 22, 4, 22, 16, c)
			_px_line(img, 8, 17, 7, 23, c)
			_px_line(img, 7, 23, 13, 17, c)
		"Summon":                                   # a sigil: ring plus star
			_px_ring(img, 13.0, 13.0, 10.0, c)
			var pts: Array[Vector2] = []
			for i: int in range(5):
				var a: float = -PI / 2.0 + float(i) * TAU / 5.0
				pts.append(Vector2(13.0 + cos(a) * 8.0, 13.0 + sin(a) * 8.0))
			for i2: int in range(5):
				var q: Vector2 = pts[i2]
				var r: Vector2 = pts[(i2 + 2) % 5]
				_px_line(img, int(q.x), int(q.y), int(r.x), int(r.y), c)
		"Flee":                                     # a double chevron
			_px_line(img, 6, 5, 14, 13, c)
			_px_line(img, 14, 13, 6, 21, c)
			_px_line(img, 13, 5, 21, 13, c)
			_px_line(img, 21, 13, 13, 21, c)
	return ImageTexture.create_from_image(img)


static func _px_set(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)


static func _px_line(img: Image, x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
	var dx: int = absi(x1 - x0)
	var dy: int = -absi(y1 - y0)
	var sx: int = 1 if x0 < x1 else -1
	var sy: int = 1 if y0 < y1 else -1
	var err: int = dx + dy
	var x: int = x0
	var y: int = y0
	while true:
		_px_set(img, x, y, c)
		if x == x1 and y == y1:
			return
		var e2: int = err * 2
		if e2 >= dy:
			err += dy
			x += sx
		if e2 <= dx:
			err += dx
			y += sy


static func _px_rect(img: Image, x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
	for y: int in range(y0, y1 + 1):
		for x: int in range(x0, x1 + 1):
			_px_set(img, x, y, c)


static func _px_ring(img: Image, cx: float, cy: float, r: float, c: Color) -> void:
	for y: int in range(img.get_height()):
		for x: int in range(img.get_width()):
			var d: float = Vector2(float(x) - cx, float(y) - cy).length()
			if absf(d - r) < 0.9:
				_px_set(img, x, y, c)


# A thumb-sized submenu entry: title on top, the detail that decides the choice
# underneath. Built from child Labels because a Button's own text is one line.

func _make_skill_button(action: String, label: String, element: String,
		cost: String, disabled: bool) -> Button:
	var btn: Button = _big_button(label, "%s   %s" % [element, cost], disabled)
	btn.pressed.connect(func() -> void: await _on_skill_chosen(action))
	return btn


# Always MAX_PARTY columns, filled or not. Sizing the row to the head count
# would shuffle everyone sideways the moment a demon is bound or falls.
func _rebuild_party_slots() -> void:
	for child: Node in _party_box.get_children():
		child.queue_free()
	_party_slots.clear()
	for i: int in range(MAX_PARTY):
		var member: CharacterSheet = party[i] if i < party.size() else null
		_party_box.add_child(_build_party_slot(member))


func _build_party_slot(member: CharacterSheet) -> Control:
	var col: VBoxContainer = VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_stretch_ratio = 1.0
	col.add_theme_constant_override("separation", 2)

	if member == null:
		# An empty slot still holds its ground so the filled ones never move.
		var spacer: Control = Control.new()
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		col.add_child(spacer)
		var empty_lbl: Label = Label.new()
		empty_lbl.text                 = "\u2014"
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_font_size_override("font_size", 12)
		empty_lbl.add_theme_color_override("font_color", Color(0.28, 0.28, 0.34))
		col.add_child(empty_lbl)
		_party_slots.append({member = null})
		return col

	var is_hero: bool = (member == player)

	var icon: TextureRect = TextureRect.new()
	icon.expand_mode           = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode          = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size   = Vector2(0, 54)
	icon.size_flags_horizontal = Control.SIZE_FILL
	icon.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	if is_hero:
		icon.texture     = _hero_placeholder()
		_player_portrait = icon
	else:
		var demon: Enemy = member as Enemy
		if demon.sprite_path != "":
			icon.texture        = load(demon.sprite_path) as Texture2D
			icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		else:
			icon.texture  = load("res://icon.svg") as Texture2D
			icon.modulate = Color(0.55, 0.85, 0.65)
	col.add_child(icon)

	var marker: Label = Label.new()
	marker.text                 = "\u25b2"
	marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	marker.add_theme_font_size_override("font_size", 11)
	marker.add_theme_color_override("font_color", Color(1.0, 0.92, 0.45))
	col.add_child(marker)

	var name_lbl: Label = Label.new()
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 12)
	col.add_child(name_lbl)

	var bar_wrap: MarginContainer = MarginContainer.new()
	for side: String in ["margin_left", "margin_right"]:
		bar_wrap.add_theme_constant_override(side, 6)
	col.add_child(bar_wrap)

	var bars: VBoxContainer = VBoxContainer.new()
	bars.add_theme_constant_override("separation", 2)
	bar_wrap.add_child(bars)

	var hp_bar: ProgressBar = _make_bar(member.max_hp)
	hp_bar.custom_minimum_size = Vector2(0, 9)
	bars.add_child(hp_bar)

	var mp_bar: ProgressBar = _make_bar(maxi(1, member.max_mp))
	mp_bar.custom_minimum_size = Vector2(0, 6)
	mp_bar.add_theme_stylebox_override("fill", _bar_fill(Color(0.32, 0.46, 0.95)))
	bars.add_child(mp_bar)

	var val_lbl: Label = Label.new()
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val_lbl.add_theme_font_size_override("font_size", 11)
	val_lbl.add_theme_color_override("font_color", Color(0.62, 0.82, 0.68))
	col.add_child(val_lbl)

	var sts_lbl: Label = Label.new()
	sts_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sts_lbl.add_theme_font_size_override("font_size", 10)
	sts_lbl.add_theme_color_override("font_color", Color(0.90, 0.78, 0.30))
	col.add_child(sts_lbl)

	_party_slots.append({member = member, portrait = icon, name_lbl = name_lbl,
			hp_bar = hp_bar, mp_bar = mp_bar, val_lbl = val_lbl,
			sts_lbl = sts_lbl, marker = marker})
	return col


func _refresh_party_slots() -> void:
	var acting: CharacterSheet = _actor() if _press != null and _press.has_turns() else null
	for slot: Dictionary in _party_slots:
		var member: CharacterSheet = slot["member"] as CharacterSheet
		if member == null:
			continue
		var alive: bool    = member.is_alive()
		var is_hero: bool  = (member == player)
		var is_actor: bool = (member == acting) and alive

		(slot["marker"] as Label).visible = is_actor
		(slot["portrait"] as TextureRect).modulate.a = 1.0 if alive else 0.18

		var name_lbl: Label = slot["name_lbl"] as Label
		name_lbl.text = _member_name(member)
		if is_hero:
			name_lbl.text += "  LV%d" % member.lv
		if not alive:
			name_lbl.add_theme_color_override("font_color", Color(0.40, 0.32, 0.32))
		elif is_actor:
			name_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.45))
		elif is_hero:
			name_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 1.0))
		else:
			name_lbl.add_theme_color_override("font_color", Color(0.62, 0.92, 0.74))

		var hp_bar: ProgressBar = slot["hp_bar"] as ProgressBar
		hp_bar.max_value = member.max_hp
		hp_bar.value     = member.hp
		_apply_hp_bar(hp_bar, member.hp, member.max_hp)
		(hp_bar.get_parent() as Control).visible = alive

		var val_lbl: Label = slot["val_lbl"] as Label
		if not alive:
			val_lbl.text = "Down"
			val_lbl.add_theme_color_override("font_color", Color(0.55, 0.38, 0.38))
		else:
			val_lbl.add_theme_color_override("font_color", hp_tint(member.hp, member.max_hp))
			var mp_bar: ProgressBar = slot["mp_bar"] as ProgressBar
			mp_bar.max_value = maxi(1, member.max_mp)
			mp_bar.value     = member.mp
			val_lbl.text = "%d/%d   %d MP" % [member.hp, member.max_hp, member.mp]

		var tags: Array[String] = []
		var ail: String = _format_statuses(member.active_statuses)
		if ail != "":
			tags.append(ail)
		var stg: String = _format_stages(member)
		if stg != "":
			tags.append(stg)
		(slot["sts_lbl"] as Label).text = "  ".join(tags)


# ── The menu strip ────────────────────────────────────────────────────────────

func _build_menu_panel(parent: Control) -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_SHRINK_END
	panel.custom_minimum_size = Vector2(0, MENU_STRIP_H)
	parent.add_child(panel)

	var m: MarginContainer = MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		m.add_theme_constant_override(side, 8)
	panel.add_child(m)

	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 5)
	m.add_child(col)

	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	header.custom_minimum_size = Vector2(0, MENU_HEADER_H)
	col.add_child(header)

	_right_back_btn = Button.new()
	_right_back_btn.text = "< Back"
	_right_back_btn.custom_minimum_size = Vector2(72, 26)
	_right_back_btn.pressed.connect(_on_back_pressed)
	_right_back_btn.hide()
	header.add_child(_right_back_btn)

	_actor_banner = Label.new()
	_actor_banner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_actor_banner.add_theme_font_size_override("font_size", 16)
	_actor_banner.add_theme_color_override("font_color", Color(1.0, 0.92, 0.45))
	header.add_child(_actor_banner)

	_right_title = Label.new()
	_right_title.text = "\u2014"
	_right_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_right_title.add_theme_color_override("font_color", Color(0.50, 0.50, 0.55))
	header.add_child(_right_title)

	col.add_child(HSeparator.new())

	var body: MarginContainer = MarginContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)

	# Both rows live in the same cell, one visible at a time, and both divide
	# the width into the same MENU_SLOTS columns.
	_action_bar = _make_slot_row()
	body.add_child(_action_bar)

	for action: String in ["Skills", "Item", "Defend", "Talk", "Summon", "Flee"]:
		var btn: Button = Button.new()
		btn.icon                    = _action_icon(action)
		btn.text                    = action
		btn.icon_alignment          = HORIZONTAL_ALIGNMENT_CENTER
		btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		btn.add_theme_font_size_override("font_size", 11)
		btn.add_theme_constant_override("h_separation", 0)
		# Without this a Button's minimum width grows to fit its label, so
		# SUMMON would claim a wider column than TALK and the six slots would
		# stop being six equal slots.
		btn.clip_text             = true
		# No minimum of its own: Main's hook multiplies a Button's minimum
		# height by 1.5, so any figure set here comes out half again taller
		# than the submenu's slots and the bar grows when you back out of a
		# submenu. It fills the body instead, exactly as a slot does.
		btn.custom_minimum_size   = Vector2(0, 0)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.size_flags_vertical   = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_on_action.bind(action))
		_action_bar.add_child(btn)
		_buttons[action] = btn

	_sub_bar = _make_slot_row()
	_sub_bar.hide()
	body.add_child(_sub_bar)

	for _i: int in range(MENU_SLOTS):
		var slot: MarginContainer = MarginContainer.new()
		slot.size_flags_horizontal   = Control.SIZE_EXPAND_FILL
		slot.size_flags_vertical     = Control.SIZE_EXPAND_FILL
		slot.size_flags_stretch_ratio = 1.0
		# An empty slot still holds its ground, so a three-entry submenu is the
		# same shape as a six-entry one.
		slot.custom_minimum_size = Vector2(0, MENU_SLOT_H)
		_sub_bar.add_child(slot)
		_sub_slots.append(slot)


# Six thumb targets in one line on a 540-wide screen truncates every label to
# three letters, so the six slots sit two rows of three deep — wider per slot
# than a landscape strip managed, and still one grid the eye reads in one go.
func _make_slot_row() -> GridContainer:
	var row: GridContainer = GridContainer.new()
	row.columns = MENU_SLOTS / 2
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 6)
	return row


func _show_actions() -> void:
	_action_bar.show()
	_sub_bar.hide()


func _hide_actions() -> void:
	_action_bar.hide()
	_sub_bar.show()


func _show_main_actions() -> void:
	_show_actions()
	_right_back_btn.hide()
	_right_title.text = "\u2014"
	_right_title.add_theme_color_override("font_color", Color(0.50, 0.50, 0.55))
	_submenu_clear()


# Detaches immediately rather than waiting on queue_free, so the very next
# _submenu_add sees the slots as empty.
func _submenu_clear() -> void:
	for slot: MarginContainer in _sub_slots:
		for child: Node in slot.get_children():
			slot.remove_child(child)
			child.queue_free()


# Drops one entry into the next free slot. Both menus are capped at MENU_SLOTS,
# so overflow is a bug rather than something to scroll past.
func _submenu_add(control: Control) -> void:
	for slot: MarginContainer in _sub_slots:
		if slot.get_child_count() == 0:
			control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			control.size_flags_vertical   = Control.SIZE_EXPAND_FILL
			slot.add_child(control)
			return
	push_warning("combat submenu overflowed %d slots" % MENU_SLOTS)
	control.queue_free()


# A slot-sized submenu entry: title on top, the detail that decides the choice
# underneath. Built from child Labels because a Button's own text is one line.
func _big_button(title: String, subtitle: String, disabled: bool) -> Button:
	var btn: Button = Button.new()
	btn.custom_minimum_size = Vector2(0, 0)
	btn.disabled = disabled

	var box: VBoxContainer = VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.alignment    = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 1)
	# Child labels do not inherit a Button's disabled tint, so dim them by hand.
	box.modulate = Color(1, 1, 1, 0.38) if disabled else Color(1, 1, 1, 1)
	btn.add_child(box)

	var title_lbl: Label = Label.new()
	title_lbl.text                 = title
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.autowrap_mode        = TextServer.AUTOWRAP_WORD_SMART
	title_lbl.add_theme_font_size_override("font_size", 13)
	title_lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	box.add_child(title_lbl)

	if subtitle != "":
		var sub_lbl: Label = Label.new()
		sub_lbl.text                 = subtitle
		sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub_lbl.autowrap_mode        = TextServer.AUTOWRAP_WORD_SMART
		sub_lbl.add_theme_font_size_override("font_size", 10)
		sub_lbl.add_theme_color_override("font_color", Color(0.66, 0.68, 0.78))
		sub_lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
		box.add_child(sub_lbl)

	return btn


# ── Casting ───────────────────────────────────────────────────────────────────

func _on_skill_chosen(action: String) -> void:
	# Healing and buffs choose no target — buffs take the whole party, debuffs
	# take every enemy. Neither does a spell that reaches more than one demon:
	# it picks its own, so asking which one would be a lie.
	if action.begins_with("Magic:"):
		var spell_id: String = action.substr(6)
		var data: Dictionary = Spell.get_data(spell_id)
		var kind: String = data.get("type", "dmg") as String
		if kind == "heal" or kind == "buff" or Spell.is_multi(spell_id):
			await _commit_action(action)
			return
	_with_target(func() -> void: await _commit_action(action))


# Once read, a demon wears its chart under its name for the rest of the fight.
func _foe_chart_text(foe: Enemy) -> String:
	if not player.has_analyzed(foe.enemy_name):
		return ""
	var parts: Array[String] = []
	for element: String in Affinity.ELEMENTS:
		var state: String = foe.affinity_of(element)
		if state != Affinity.NORMAL:
			parts.append("%s%s" % [Affinity.element_name(element).substr(0, 1).to_upper(),
					Affinity.label(state).substr(0, 1)])
	return " ".join(parts)


func _cast_spell(spell_id: String) -> Dictionary:
	var data: Dictionary = Spell.DATA.get(spell_id, {name = "Spell", mp = 8})
	var mp_cost: int = data.get("mp", 8)
	if player.mp < mp_cost:
		return {msg = "[color=gray]Not enough MP![/color]", cost = PressTurn.COST_FULL}
	player.mp -= mp_cost

	var spell_type: String = data.get("type", "dmg")

	if spell_type == "buff":
		return _apply_stage_spell(data)

	if spell_type == "dispel":
		return _cast_dispel(data, true)

	if spell_type == "ailment":
		var target_status: String = data.get("status", "")
		if target_status == "" or enemy.has_status(target_status):
			return {msg = "[color=gray]Nothing happened.[/color]", cost = PressTurn.COST_FULL}
		enemy.apply_status(target_status)
		return {msg = "You cast %s!  [color=violet]%s is now %s.[/color]" % [
				data["name"], enemy.display_name(),
				Status.get_data(target_status).get("name", target_status)],
				cost = PressTurn.COST_FULL}

	if spell_type == "banish":
		var bd: Dictionary = data.duplicate()
		bd["id"] = spell_id
		return _cast_banish(bd)

	if spell_type == "heal":
		var heal_amt: int = data.get("heal", 30)
		var before: int = player.hp
		var bonus: int = int(float(player.effective_mag())
				* player.stage_mult(CharacterSheet.STAT_MAG))
		player.heal(max(1, heal_amt + bonus))
		return {msg = "[color=lime]You cast %s! Restored %d HP.[/color]" % [
				data["name"], player.hp - before], cost = PressTurn.COST_FULL}

	if Spell.is_multi(spell_id):
		return _cast_spread(data)

	var element: String = data.get("element", "")
	var power: float = float(player.effective_mag()) \
			* player.stage_mult(CharacterSheet.STAT_MAG)
	var base: int = int(power * float(data.get("power", Spell.POWER_I))) - _guarded_def(enemy)
	if "scholar" in player.passive_skills:
		base = int(base * 1.25)
	var crit: bool = CombatMath.roll_crit(player)
	var res: Dictionary = CombatMath.resolve(base, element, enemy, crit, enemy.defending)
	return _land_hit(res, element, "You cast %s!" % data["name"])


# ── Spells that reach more than one demon ─────────────────────────────────────
#
# Which demons a wide cast touches: everything standing for an ALL spell, two
# or three at random for a FEW. Fewer demons than that on the field means it
# simply takes all of them — the spell is not wasted, it just has less to do.
func _spread_targets(shape: String) -> Array[Enemy]:
	var living: Array[Enemy] = _living_foes()
	if shape == Spell.SHAPE_ALL or living.size() <= 2:
		return living
	living.shuffle()
	return living.slice(0, 2 + (randi() % 2))


# The press-turn cost of a cast that landed on several demons at once. The
# worst thing that happened decides, with one exception: a single null among
# demons that otherwise took it is not worth two icons, so only a cast that
# every demon nulled pays that. This is what makes an ALL spell a gamble
# against a mixed line rather than a strict upgrade.
static func _spread_cost(outcomes: Array[String]) -> String:
	for o: String in outcomes:
		if o == "repel" or o == "drain":
			return PressTurn.COST_LOST
	var nulled: int = 0
	for o: String in outcomes:
		if o == "null":
			nulled += 1
	if nulled == outcomes.size():
		return PressTurn.COST_MISS
	if "weak" in outcomes:
		return PressTurn.COST_HALF
	return PressTurn.COST_FULL


func _cast_spread(data: Dictionary) -> Dictionary:
	var element: String = data.get("element", "") as String
	var spread: float = float(data.get("spread", 1.0))
	var targets: Array[Enemy] = _spread_targets(data.get("shape", Spell.SHAPE_ALL) as String)
	var power: float = float(player.effective_mag()) \
			* player.stage_mult(CharacterSheet.STAT_MAG)

	var lines: Array[String] = ["You cast %s!" % data["name"]]
	var outcomes: Array[String] = []
	var reflected: int = 0

	var rung: float = float(data.get("power", Spell.POWER_I))
	for foe: Enemy in targets:
		var base: int = int(power * rung * spread) - _guarded_def(foe)
		if "scholar" in player.passive_skills:
			base = int(base * 1.25)
		var crit: bool = CombatMath.roll_crit(player)
		var res: Dictionary = CombatMath.resolve(base, element, foe, crit, foe.defending)
		var outcome: String = res["outcome"] as String
		outcomes.append(outcome)
		var dmg: int = int(res["dmg"])

		match outcome:
			"drain":
				foe.heal(dmg)
				lines.append("[color=lime]%s drinks it and recovers %d.[/color]" % [
						foe.display_name(), dmg])
			"repel":
				reflected += dmg
				lines.append("[color=#d070ff]%s turns it back for %d.[/color]" % [
						foe.display_name(), dmg])
			"null":
				lines.append("[color=#999999]%s does not feel it.[/color]" % foe.display_name())
			_:
				foe.take_damage(dmg)
				lines.append("[color=orange]%s takes %d.[/color]%s" % [
						foe.display_name(), dmg,
						CombatMath.outcome_tag(outcome, bool(res["crit"]),
								bool(res.get("suppressed", false)))])
				if not foe.is_alive():
					lines.append("[color=lime]%s is destroyed![/color]" % foe.display_name())

	if reflected > 0:
		_actor().take_damage(reflected)
		lines.append("[color=red]%s takes %d from what came back.[/color]" % [
				_actor_name(), reflected])

	_ensure_target()
	return {msg = " ".join(lines), cost = _spread_cost(outcomes)}


# Buffs stack across the party, debuffs across the enemy line. Reporting how
# many actually moved is what tells the player they have hit the cap.
func _apply_stage_spell(data: Dictionary) -> Dictionary:
	var stat: String = data.get("stat", CharacterSheet.STAT_ATK) as String
	var delta: int   = int(data.get("delta", 1))
	var on_party: bool = (data.get("scope", "party") == "party")

	var moved: int = 0
	var total: int = 0
	if on_party:
		for member: CharacterSheet in _living_party():
			total += 1
			if member.shift_stage(stat, delta) != 0:
				moved += 1
	else:
		for foe: Enemy in _living_foes():
			total += 1
			if foe.shift_stage(stat, delta) != 0:
				moved += 1

	var who: String = "the party" if on_party else "every enemy"
	if moved == 0:
		return {msg = "[color=gray]You cast %s — %s is already at the limit.[/color]" % [
				data["name"], who], cost = PressTurn.COST_FULL}
	var tint: String = "aqua" if delta > 0 else "orange"
	return {msg = "[color=%s]You cast %s!  %s %s on %d of %d.[/color]" % [
			tint, data["name"], _stat_name(stat),
			"rises" if delta > 0 else "falls", moved, total],
			cost = PressTurn.COST_FULL}


# ── Dispels ───────────────────────────────────────────────────────────────────
#
# Dekaja and dekunda by another name. Both read from where the caster stands:
# "foes" is the other side and "party" is the caster's own, so one function
# serves the detective and the demon that casts it back at him. All or nothing
# across a whole side — there is no picking which stage to take.
# Is there anything on that side for this cast to take? The player is allowed
# to waste the turn; a demon deciding its own move is not.
func _dispel_would_bite(data: Dictionary, by_player: bool) -> bool:
	var hits_other: bool = (data.get("scope", "foes") == "foes")
	var take_buffs: bool = (data.get("clears", "buffs") == "buffs")
	var targets: Array[CharacterSheet] = []
	if hits_other != by_player:
		targets = _living_party()
	else:
		for foe: Enemy in _living_foes():
			targets.append(foe)
	for t: CharacterSheet in targets:
		for key: String in CharacterSheet.STAT_KEYS:
			var st: int = t.stage(key)
			if (take_buffs and st > 0) or (not take_buffs and st < 0):
				return true
	return false


func _cast_dispel(data: Dictionary, by_player: bool) -> Dictionary:
	var hits_other: bool = (data.get("scope", "foes") == "foes")
	var take_buffs: bool = (data.get("clears", "buffs") == "buffs")

	var targets: Array[CharacterSheet] = []
	var on_party: bool = hits_other != by_player
	if on_party:
		targets = _living_party()
	else:
		for foe: Enemy in _living_foes():
			targets.append(foe)

	var moved: int = 0
	for t: CharacterSheet in targets:
		var before: Dictionary = t.stages.duplicate()
		if take_buffs:
			t.clear_buffs()
		else:
			t.clear_debuffs()
		if t.stages != before:
			moved += 1

	var side: String = "the party" if on_party else "every enemy"
	var what: String = "had raised" if take_buffs else "was carrying"
	if moved == 0:
		return {msg = "[color=gray]%s — %s has nothing it %s.[/color]" % [
				data["name"], side, what], cost = PressTurn.COST_FULL}
	return {msg = "[color=#c9a6ff]%s!  %d of %s stripped back to level.[/color]" % [
			data["name"], moved, "them" if not on_party else "the party"],
			cost = PressTurn.COST_FULL}


static func _stat_name(stat: String) -> String:
	match stat:
		CharacterSheet.STAT_ATK: return "Attack"
		CharacterSheet.STAT_MAG: return "Magic"
		CharacterSheet.STAT_DEF: return "Defence"
		CharacterSheet.STAT_AGL: return "Agility"
	return stat


# Defence as it counts right now: the stat, the guard stance, and the stage.
func _guarded_def(target: CharacterSheet) -> int:
	var base: float = float(_defense_of(target)) * target.stage_mult(CharacterSheet.STAT_DEF)
	if target.defending:
		base *= 2.0
	return int(base / 2.0)


# Light and dark take the target or they do not. Nothing in between, which is
# why they are worth a slot: one icon for a whole demon, at odds its own nature
# decides.
func _cast_banish(data: Dictionary) -> Dictionary:
	if Spell.is_multi(data.get("id", "") as String) \
			or data.get("shape", Spell.SHAPE_ONE) != Spell.SHAPE_ONE:
		return _cast_banish_spread(data)

	var element: String = data.get("element", Affinity.LIGHT) as String
	var power: int = maxi(1, int(float(player.effective_mag())
			* player.stage_mult(CharacterSheet.STAT_MAG)))
	var res: Dictionary = CombatMath.resolve_banish(enemy, element, power, false, player,
			1.0, float(data.get("boost", Spell.BOOST_I)))
	var name: String = data["name"] as String
	var who: String  = enemy.display_name()

	match res["outcome"]:
		"banished":
			enemy.take_damage(enemy.max_hp * 2)
			return {msg = "[color=#c9a6ff]%s! %s is taken, whole.[/color]" % [name, who],
					cost = PressTurn.COST_HALF if
						enemy.affinity_of(element) == Affinity.WEAK else PressTurn.COST_FULL}
		"failed":
			return {msg = "[color=gray]%s! %s holds.[/color]" % [name, who],
					cost = PressTurn.COST_FULL}
		"null":
			return {msg = "[color=#999999]%s! %s does not feel it at all.[/color]" % [name, who],
					cost = PressTurn.COST_MISS}
		"repel":
			var back: int = int(res["dmg"])
			_actor().take_damage(back)
			return {msg = "[color=#d070ff]%s! Turned back — %s takes %d.[/color]" % [
					name, _actor_name(), back], cost = PressTurn.COST_LOST}
		"drain":
			enemy.heal(int(res["dmg"]))
			return {msg = "[color=lime]%s! %s drinks it and recovers %d HP.[/color]" % [
					name, who, int(res["dmg"])], cost = PressTurn.COST_LOST}
	return {msg = "[color=gray]%s does nothing.[/color]" % name, cost = PressTurn.COST_FULL}


# Light or dark thrown across a line. Each demon is judged on its own chart and
# rolled separately at reduced odds, so a full room is a real bet rather than an
# end to the fight: the more demons it reaches, the less firmly it holds any of
# them, and one that repels it still ends the phase for everyone.
func _cast_banish_spread(data: Dictionary) -> Dictionary:
	var element: String = data.get("element", Affinity.LIGHT) as String
	var spread: float = float(data.get("spread", 1.0))
	var boost: float = float(data.get("boost", Spell.BOOST_I))
	var power: int = maxi(1, int(float(player.effective_mag())
			* player.stage_mult(CharacterSheet.STAT_MAG)))
	var targets: Array[Enemy] = _spread_targets(
			data.get("shape", Spell.SHAPE_ALL) as String)

	var lines: Array[String] = ["[color=#c9a6ff]You cast %s![/color]" % data["name"]]
	var outcomes: Array[String] = []
	var reflected: int = 0
	var took_weak: bool = false

	for foe: Enemy in targets:
		var res: Dictionary = CombatMath.resolve_banish(
				foe, element, power, false, player, spread, boost)
		var outcome: String = res["outcome"] as String
		match outcome:
			"banished":
				var was_weak: bool = (foe.affinity_of(element) == Affinity.WEAK)
				took_weak = took_weak or was_weak
				foe.take_damage(foe.max_hp * 2)
				outcomes.append("weak" if was_weak else "hit")
				lines.append("[color=#c9a6ff]%s is taken.[/color]" % foe.display_name())
			"drain":
				foe.heal(int(res["dmg"]))
				outcomes.append("drain")
				lines.append("[color=lime]%s drinks it.[/color]" % foe.display_name())
			"repel":
				reflected += int(res["dmg"])
				outcomes.append("repel")
				lines.append("[color=#d070ff]%s turns it back.[/color]" % foe.display_name())
			"null":
				outcomes.append("null")
				lines.append("[color=#999999]%s does not feel it.[/color]" % foe.display_name())
			_:
				outcomes.append("hit")
				lines.append("[color=gray]%s holds.[/color]" % foe.display_name())

	if reflected > 0:
		_actor().take_damage(reflected)
		lines.append("[color=red]%s takes %d from what came back.[/color]" % [
				_actor_name(), reflected])

	_ensure_target()
	# Only an expulsion off a weakness pays an icon back; a lucky one against an
	# ordinary demon was luck, not a read.
	var cost: String = _spread_cost(outcomes)
	if cost == PressTurn.COST_FULL and took_weak:
		cost = PressTurn.COST_HALF
	return {msg = " ".join(lines), cost = cost}


# ── Physical swings ───────────────────────────────────────────────────────────

# Reads the target's chart, writes it into the bestiary for good, and prints it
# into the log. Costs a turn, which is the whole tension: scouting is an action
# you are not spending on damage.
func _resolve_analyze() -> Dictionary:
	var already: bool = player.has_analyzed(enemy.enemy_name)
	player.record_analysis(enemy.enemy_name)
	var chart: String = _affinity_line(enemy)
	var lead: String = "You read %s again." if already else "You read %s."
	return {msg = "[color=#9ad0ff]%s  %s[/color]" % [lead % enemy.display_name(), chart],
			cost = PressTurn.COST_FULL}


# "PHYS weak · FIRE drain · ICE null" — every element that is not ordinary.
static func _affinity_line(sheet: CharacterSheet) -> String:
	var parts: Array[String] = []
	for element: String in Affinity.ELEMENTS:
		var state: String = sheet.affinity_of(element)
		if state != Affinity.NORMAL:
			parts.append("%s %s" % [Affinity.element_name(element),
					Affinity.label(state)])
	if parts.is_empty():
		return "no affinities at all."
	return "  ".join(parts)


func _resolve_attack() -> Dictionary:
	var actor: CharacterSheet = _actor()
	if not CombatMath.lands(actor, enemy):
		return {msg = "[color=#9aa0aa]%s swings at %s and misses![/color]" % [
				_actor_name(), enemy.display_name()], cost = PressTurn.COST_MISS}
	var atk: float = float(player.effective_str() if _actor_is_player() else actor.str)
	atk *= actor.stage_mult(CharacterSheet.STAT_ATK)
	if _actor_is_player() and "last_stand" in player.passive_skills \
			and player.hp * 4 < player.max_hp:
		atk *= 2.0
	var crit: bool = CombatMath.roll_crit(_actor())
	var res: Dictionary = CombatMath.resolve(int(atk) - _guarded_def(enemy),
			Affinity.PHYS, enemy, crit, enemy.defending)
	return _land_hit(res, Affinity.PHYS, "%s strikes!" % _actor_name())


# ── Enemy actions ─────────────────────────────────────────────────────────────

# A demon spends on support only while the pool still covers its element
# afterwards. One that carries no element has nothing to save for.
func _can_spare_support(actor: Enemy) -> bool:
	var sup: Dictionary = Spell.get_data(actor.support_skill)
	if sup.is_empty():
		return false
	var sup_mp: int = int(sup.get("mp", 8))
	if actor.mp < sup_mp:
		return false
	if actor.attack_elements.is_empty():
		return true
	return actor.mp - sup_mp >= actor.skill_cost()


func _enemy_act(actor: Enemy) -> Dictionary:
	if actor.has_status(Status.PARALYZED) and randi() % 4 == 0:
		return {msg = "[color=yellow]%s is paralyzed and cannot act![/color]" % actor.display_name(),
				cost = PressTurn.COST_FULL}

	# The ailment goes out early or not at all: it is worth most on a full party
	# and worthless once everyone standing already has it, which is also what
	# keeps it to a cast or two a fight rather than a loop.
	if randi() % 10 < AIL_CAST_ODDS and _ail_cast_ready(actor):
		return _enemy_cast_ailment(actor)

	# Support next: a demon that can stack a buff will, while it still has
	# room and the MP to pay for it — but never at the price of its element.
	# Both come out of the one pool, and Mire costs ten against a Cave Bat's
	# twenty-four, so a demon carrying both used to spend everything on buffs
	# and never once cast the thing it is named for.
	if actor.support_skill != "" and randi() % 10 < 3 and _can_spare_support(actor):
		var sup: Dictionary = Spell.get_data(actor.support_skill)
		# A dispel against a side with nothing stacked is a wasted phase, so a
		# demon carrying one holds it until there is something to take.
		if sup.get("type", "buff") == "dispel":
			# Nothing stacked to take means the phase would be wasted, so the
			# demon holds it and attacks instead. It must not fall through to
			# the branch below either: a dispel carries no stat or delta, so
			# read as a buff it came out as a free +1 ATK for the whole line.
			if _dispel_would_bite(sup, false):
				actor.mp -= int(sup.get("mp", 8))
				var out: Dictionary = _cast_dispel(sup, false)
				out["msg"] = "[color=#c9a6ff]%s casts[/color] %s" % [
						actor.display_name(), out["msg"]]
				return out
		elif not sup.is_empty() and actor.mp >= int(sup.get("mp", 8)):
			var stat: String = sup.get("stat", CharacterSheet.STAT_ATK) as String
			var delta: int   = int(sup.get("delta", 1))
			var on_party: bool = (sup.get("scope", "party") == "party")
			var moved: int = 0
			if on_party:
				for f: Enemy in _living_foes():
					if f.shift_stage(stat, delta) != 0:
						moved += 1
			else:
				for m: CharacterSheet in _living_party():
					if m.shift_stage(stat, delta) != 0:
						moved += 1
			if moved > 0:
				actor.mp -= int(sup.get("mp", 8))
				return {msg = "[color=%s]%s casts %s! %s %s on %d.[/color]" % [
						"orange" if delta > 0 else "aqua", actor.display_name(),
						sup["name"], _stat_name(stat),
						"rises" if delta > 0 else "falls", moved],
						cost = PressTurn.COST_FULL}

	var element: String = Affinity.PHYS
	var base: float = float(actor.str)
	var dry: String = ""
	# An element is what a demon is for, so it reaches for one every turn it can
	# pay for it and swings only once the pool is gone. MP is a magazine, not a
	# dice modifier: a demon opens with what it has and finishes the fight with
	# its hands, which is a shape a player can read and play around.
	#
	# A demon carrying several picks between them at random, so there is no one
	# resistance that answers it — which is the point of giving a wizard three.
	#
	# A banishing line is the exception, and only joins the pool one turn in
	# five. A demon it takes from the detective does not come back, so those
	# stay something that happens rather than the opening move of every fight.
	var paid: bool = false
	var pool: Array[String] = actor.affordable_elements(randi() % 10 < 2)
	if not pool.is_empty():
		actor.mp -= actor.skill_cost()
		element = pool[randi() % pool.size()]
		base    = float(actor.mag) * actor.stage_mult(CharacterSheet.STAT_MAG) * 2.0
		paid    = true
	elif actor.caster:
		# A caster does not throw punches. Out of MP it scrapes what is left of
		# its cheapest ordinary line — free, half strength, and never banishing.
		element = actor.dregs_element()
		if element == "":
			element = Affinity.PHYS
		else:
			base = float(actor.mag) * actor.stage_mult(CharacterSheet.STAT_MAG) * CASTER_DREGS
			if not actor.announced_dry:
				actor.announced_dry = true
				dry = "[color=gray]%s is running on fumes.[/color]\n" % actor.display_name()
	elif not actor.attack_elements.is_empty() and not actor.announced_dry:
		# Said once, the turn the pool runs out, and not again.
		actor.announced_dry = true
		dry = "[color=gray]%s is out of MP.[/color]\n" % actor.display_name()

	# A wide line takes the whole row rather than one of them. Only a cast it
	# actually paid for spreads: the dregs a dry caster scrapes together are a
	# single-target consolation, and a swing is a swing.
	if paid and actor.attack_reach != Spell.SHAPE_ONE:
		return _enemy_spread(actor, element, base, dry)

	var target: CharacterSheet = _pick_target(element)

	if Affinity.is_banishing(element):
		return _enemy_banish(actor, target, element, dry)

	# Only a swing can miss. Whatever it calls up always arrives. A miss does not
	# spend the target's brace — it never had to absorb anything.
	if element == Affinity.PHYS and not CombatMath.lands(actor, target):
		return {msg = dry + "[color=#9aa0aa]%s lunges at %s and misses![/color]" % [
				actor.display_name(), _member_name(target)], cost = PressTurn.COST_MISS}

	if element == Affinity.PHYS:
		base *= actor.stage_mult(CharacterSheet.STAT_ATK)
	var guarding: bool = target.defending
	var eff_def: int = _guarded_def(target)

	var crit: bool = CombatMath.roll_crit(actor)
	var res: Dictionary = CombatMath.resolve(int(base) - eff_def, element, target,
			crit, guarding)
	var outcome: String = res["outcome"] as String
	var dmg: int        = res["dmg"] as int
	var muted: bool     = bool(res.get("suppressed", false))
	var tname: String   = _member_name(target)
	var ename: String   = actor.display_name()
	var verb: String    = "attacks" if element == Affinity.PHYS \
			else "uses %s on" % Affinity.element_name(element)

	match outcome:
		"drain":
			target.heal(dmg)
			return {msg = dry + "[color=lime]%s %s %s — absorbed! %s recovers %d HP.[/color]" % [
					ename, verb, tname, tname, dmg], cost = PressTurn.COST_LOST}
		"repel":
			actor.take_damage(dmg)
			var pr: TextureRect = _foe_portrait(actor)
			if pr != null:
				_shake_portrait(pr)
			return {msg = dry + "[color=#d070ff]%s %s %s — repelled! %s takes %d damage.[/color]" % [
					ename, verb, tname, ename, dmg], cost = PressTurn.COST_LOST}
		"null":
			return {msg = dry + "[color=#999999]%s %s %s — no effect.[/color]" % [ename, verb, tname],
					cost = PressTurn.COST_MISS}

	target.take_damage(dmg)
	var hit_pr: TextureRect = _member_portrait(target)
	if hit_pr != null:
		_shake_portrait(hit_pr)
	var msg: String = dry + "[color=red]%s %s %s for %d damage.[/color]%s" % [
			ename, verb, tname, dmg, CombatMath.outcome_tag(outcome, crit, muted)]
	if target == player:
		msg += _check_counter()
	return {msg = msg, cost = CombatMath.cost_for(outcome, crit, muted)}


# ── Wide casts from the other side ────────────────────────────────────────────
#
# The mirror of the detective's own 2-3 and all-reach spells, and priced the
# same way: what it gains in width it gives up on each target. Which of the
# detective's line a FEW cast catches is drawn fresh each time, so covering the
# demon on three HP is a hope rather than a plan.
func _enemy_spread_targets(actor: Enemy) -> Array[CharacterSheet]:
	var standing: Array[CharacterSheet] = _living_party()
	if actor.attack_reach == Spell.SHAPE_ALL or standing.size() <= 2:
		return standing
	standing.shuffle()
	return standing.slice(0, 2 + (randi() % 2))


func _enemy_spread(actor: Enemy, element: String, base: float,
		dry: String) -> Dictionary:
	var banishing: bool = Affinity.is_banishing(element)
	var spread: float = actor.reach_spread(banishing)
	var targets: Array[CharacterSheet] = _enemy_spread_targets(actor)
	var reach_word: String = "across" if actor.attack_reach == Spell.SHAPE_FEW else "over"

	var lines: Array[String] = [dry + "[color=#ff9a6a]%s calls up %s %s %d of you![/color]" % [
			actor.display_name(), Affinity.element_name(element),
			reach_word, targets.size()]]
	var outcomes: Array[String] = []
	var reflected: int = 0

	for who: CharacterSheet in targets:
		if banishing:
			var br: Dictionary = CombatMath.resolve_banish(who, element,
					maxi(1, int(base * spread)), who == player, actor, spread)
			outcomes.append(_apply_enemy_banish_one(actor, who, element, br, lines))
			continue
		var res: Dictionary = CombatMath.resolve(
				int(base * spread) - _guarded_def(who), element, who,
				CombatMath.roll_crit(actor), who.defending)
		var outcome: String = res["outcome"] as String
		var dmg: int = int(res["dmg"])
		outcomes.append(outcome)
		match outcome:
			"drain":
				who.heal(dmg)
				lines.append("[color=lime]%s drinks it — %d HP.[/color]" % [
						_member_name(who), dmg])
			"repel":
				reflected += dmg
				lines.append("[color=#d070ff]%s turns it back.[/color]" % _member_name(who))
			"null":
				lines.append("[color=#999999]%s does not feel it.[/color]" % _member_name(who))
			_:
				who.take_damage(dmg)
				var pr: TextureRect = _member_portrait(who)
				if pr != null:
					_shake_portrait(pr)
				lines.append("[color=red]%s takes %d.[/color]%s" % [
						_member_name(who), dmg,
						CombatMath.outcome_tag(outcome, false, bool(res.get("suppressed", false)))])

	if reflected > 0:
		actor.take_damage(reflected)
		lines.append("[color=#d070ff]%s takes %d from what came back.[/color]" % [
				actor.display_name(), reflected])

	# The demons' side pays the same press-turn arithmetic the detective does.
	return {msg = " ".join(lines), cost = _spread_cost(outcomes)}


# One target of a wide banishing cast, written out so the single-target path and
# this one cannot drift apart on what an expulsion actually costs.
func _apply_enemy_banish_one(actor: Enemy, who: CharacterSheet, element: String,
		res: Dictionary, lines: Array[String]) -> String:
	match res["outcome"]:
		"banished":
			who.take_damage(who.max_hp * 2)
			lines.append("[color=#c9a6ff]%s is taken.[/color]" % _member_name(who))
			return "hit"
		"drain":
			who.heal(int(res["dmg"]))
			lines.append("[color=lime]%s drinks it.[/color]" % _member_name(who))
			return "drain"
		"repel":
			actor.take_damage(int(res["dmg"]))
			lines.append("[color=#d070ff]%s turns it back.[/color]" % _member_name(who))
			return "repel"
		"null":
			lines.append("[color=#999999]%s does not feel it.[/color]" % _member_name(who))
			return "null"
		"weak":
			who.take_damage(int(res["dmg"]))
			lines.append("[color=red]%s is torn for %d.[/color]" % [
					_member_name(who), int(res["dmg"])])
			return "weak"
		"hit":
			who.take_damage(int(res["dmg"]))
			lines.append("[color=red]%s is torn for %d.[/color]" % [
					_member_name(who), int(res["dmg"])])
			return "hit"
	lines.append("[color=gray]%s holds.[/color]" % _member_name(who))
	return "hit"


# A demon reaching for light or dark is reaching for one of yours. The detective
# cannot be expelled, so it tears at him instead; a bound demon it takes is gone
# for good, which is what makes these the frightening ones to meet.
func _enemy_banish(actor: Enemy, target: CharacterSheet, element: String,
		dry: String) -> Dictionary:
	var power: int = maxi(1, int(float(actor.mag)
			* actor.stage_mult(CharacterSheet.STAT_MAG)))
	var is_hero: bool = (target == player)
	var res: Dictionary = CombatMath.resolve_banish(target, element, power, is_hero)
	var ename: String = actor.display_name()
	var tname: String = _member_name(target)
	var word: String  = "Light" if element == Affinity.LIGHT else "Dark"

	match res["outcome"]:
		"banished":
			target.take_damage(target.max_hp * 2)
			var pr: TextureRect = _member_portrait(target)
			if pr != null:
				_shake_portrait(pr)
			return {msg = dry + "[color=#c9a6ff]%s calls the %s — %s is taken.[/color]" % [
					ename, word, tname],
					cost = PressTurn.COST_HALF if
						target.affinity_of(element) == Affinity.WEAK else PressTurn.COST_FULL}
		"failed":
			return {msg = dry + "[color=gray]%s calls the %s — %s holds.[/color]" % [
					ename, word, tname], cost = PressTurn.COST_FULL}
		"null":
			return {msg = dry + "[color=#999999]%s calls the %s — nothing.[/color]" % [
					ename, word], cost = PressTurn.COST_MISS}
		"repel":
			actor.take_damage(int(res["dmg"]))
			return {msg = dry + "[color=#d070ff]%s calls the %s — turned back for %d.[/color]" % [
					ename, word, int(res["dmg"])], cost = PressTurn.COST_LOST}
		"drain":
			target.heal(int(res["dmg"]))
			return {msg = dry + "[color=lime]%s calls the %s — %s drinks it.[/color]" % [
					ename, word, tname], cost = PressTurn.COST_LOST}

	# The detective takes it as a wound rather than an expulsion.
	var hurt: int = int(res["dmg"])
	target.take_damage(hurt)
	var hit_pr: TextureRect = _member_portrait(target)
	if hit_pr != null:
		_shake_portrait(hit_pr)
	var tag: String = "  [color=yellow]Weak![/color]" if res["outcome"] == "weak" else ""
	return {msg = dry + "[color=red]%s calls the %s — %s takes %d.[/color]%s" % [
			ename, word, tname, hurt, tag],
			cost = PressTurn.COST_HALF if res["outcome"] == "weak" else PressTurn.COST_FULL}


# A compact readout of what is stacked on someone: "ATK+2 AGL-1".
static func _format_stages(member: CharacterSheet) -> String:
	var parts: Array[String] = []
	for key: String in CharacterSheet.STAT_KEYS:
		var st: int = member.stage(key)
		if st != 0:
			parts.append("%s%+d" % [key.to_upper(), st])
	return "  ".join(parts)

