# CombatScene
# Press-turn combat. FF side-view layout:
#   top    – combat log (slim strip)
#   field  – [enemies left | party right], each side stacked vertically
#   bottom – [action buttons] | [item/magic submenu]
# Active character steps forward toward the centre on their turn.
#
# A side opens its phase with one icon per living combatant and keeps acting
# until the icons run out, so weakness hits and criticals buy extra actions for
# whoever landed them — see PressTurn for the exact economy. The hero and
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

# One row widget per foe: {foe, portrait, name_lbl, bar, hp_lbl, marker, chart}.
var _foe_rows: Array[Dictionary] = []
var _foe_turn_idx: int = 0

# Demons removed by a successful negotiation rather than killed.
var _departed: Array[Enemy] = []

# Bound demons that fell in this battle. Read by Main before the scene is
# freed, so the loss can be reported where the player will actually see it.
var lost_demons: Array[String] = []
# Whether the monsters can get the jump on the party (CombatMath.ambush_chance).
# Main turns it off for the set pieces and for a fight the player paid for.
var can_ambush: bool = false

# The hero plus every demon he has bound this battle. Index 0 is always
# the hero; _actor is the member currently holding the turn.
const MAX_PARTY: int = 4
var party: Array[CharacterSheet] = []
var _actor_idx: int = 0

var _press:     PressTurn
var _foe_press: PressTurn

var _negotiation: CombatNegotiation

# When set, enemy actions ignore target selection and swing at this member.
# Used by the negotiation handlers, where the hero is the one talking.
var _force_target: CharacterSheet = null

var _log_label:      RichTextLabel
var _log_first_line: bool = true

# The hero's portrait, kept as its own reference because the CombatNeg*
# handlers shake it directly.
var _player_portrait: TextureRect

var _icon_pips:     UIGlyph   # player-side press-turn icons, drawn
var _foe_icon_pips: UIGlyph   # enemy-side press-turn icons, drawn
var _enemy_side: Control
var _party_box:  Control
var _party_slots: Array[Dictionary] = []

const STEP_DISTANCE: float = 60.0
const STEP_DURATION: float = 0.25
# Set by Main before the scene enters: the dungeon view is showing behind the
# fight, so the backdrop only darkens it instead of painting its own floor.
var see_through: bool = false
var _stepped_node: Control = null


# The menu strip is a fixed row of MENU_SLOTS cells. The action bar fills all
# of them; a submenu drops its entries into the same cells, so slot 3 is in the
# same place whichever is showing. A submenu longer than MENU_SLOTS scrolls.
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
# The submenu grid scrolls rather than paging: six cells show, and a longer
# list (a full roster, a crowded pack) carries on below them.
var _sub_scroll: ScrollContainer
var _sub_slots:  Array[MarginContainer] = []
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
	if can_ambush and randf() < CombatMath.ambush_chance(player, foes):
		_log("[color=#ff6a4a]%s![/color]" % _ambush_line())
		_enemy_phase()
		return
	_begin_player_phase()

func _build_ui() -> void:
	pass


# The press-turn readout. Both sides are always visible so the player can see a
# phase about to snowball against them, not just their own banked halves.

# The strip is sized in whole lines rather than in pixels, because a height
# that lands mid-line shows two and a sliver of a third, which reads as two.
const LOG_LINES:  int = 3
const LOG_LINE_H: int = 24    # the pixel font at 16, ascent and descent
const LOG_PAD:    int = 8

func _build_log_strip(parent: Control) -> void:
	pass


# Drag the log to read back through the phase. A RichTextLabel scrolls to the
# wheel on its own, which is no use on a phone, and its scrollbar is a two
# pixel target — so a drag anywhere on the text moves it.
#
# scroll_following is what pins the newest line to the bottom. Left on, an
# arriving message would yank the player back mid-read, so it is switched off
# the moment they drag away and switched back on when they reach the bottom
# again. Reading back never costs you the live feed.
func _on_log_input(event: InputEvent) -> void:
	var dy: float = 0.0
	if event is InputEventScreenDrag:
		dy = (event as InputEventScreenDrag).relative.y
	elif event is InputEventMouseMotion \
			and ((event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		dy = (event as InputEventMouseMotion).relative.y
	else:
		return
	var bar: VScrollBar = _log_label.get_v_scroll_bar()
	if bar == null:
		return
	bar.value -= dy
	_log_label.scroll_following = bar.value >= bar.max_value - bar.page - 1.0
	_log_label.accept_event()






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


func _shake_portrait(node: TextureRect, guarding: bool = false) -> void:
	_play_anim(node, "block" if guarding else "hurt")
	node.pivot_offset = node.size / 2.0
	var tween: Tween = create_tween()
	tween.tween_property(node, "scale", Vector2(1.18, 0.82), 0.05)
	tween.tween_property(node, "scale", Vector2(0.88, 1.14), 0.06)
	tween.tween_property(node, "scale", Vector2(1.07, 0.94), 0.05)
	tween.tween_property(node, "scale", Vector2(1.0,  1.0),  0.05)


func _play_anim(node: TextureRect, anim_name: String) -> void:
	if node is AnimatedPortrait:
		(node as AnimatedPortrait).play_once(anim_name)

func _step_forward(card: Control, is_enemy: bool) -> void:
	pass

func _step_back_immediate() -> void:
	pass


func _card_portrait(card: Control) -> TextureRect:
	for r: Dictionary in _foe_rows:
		if r.get("card") == card:
			return r["portrait"] as TextureRect
	for s: Dictionary in _party_slots:
		if s.get("card") == card:
			return s["portrait"] as TextureRect
	return null


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
	pass



# ── Submenus ──────────────────────────────────────────────────────────────────

func _set_back(cb: Callable) -> void:
	_back_target = cb
	_on_step_deeper()
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

	var carried: Array[Dictionary] = player.battle_items()
	if carried.is_empty():
		_submenu_add(_dim_label("Nothing in your pack."))
		return
	var entries: Array[Dictionary] = []
	for item: Dictionary in carried:
		var is_throwable: bool = item.has("inflicts_status") \
			or (item.has("element") and item.get("dmg", 0) > 0)
		var usable: bool = is_throwable or item.has("mirror") or player.can_use_item(item)
		if item.has("revive"):
			usable = not _fallen_members().is_empty()
		elif _restorative(item):
			usable = _living_party().any(func(m: CharacterSheet) -> bool: return m.could_use(item))
		entries.append({title = item["name"] as String,
				detail = "x%d" % int(item.get("qty", 1)),
				disabled = not usable,
				press = _on_use_item.bind(item)})
	_fill_submenu(entries)


func _show_talk_submenu() -> void:
	_hide_actions()
	_open_talk_window()
	_right_title.add_theme_color_override("font_color", Color(0.50, 1.0, 0.70))
	_submenu_clear()

	var opts: Array[Array] = [
		["Reason",   "Negotiate"],
		["Bribe",    "Bribe"],
		["Threaten", "Threaten"],
		["Recruit",  "Recruit"],
	]
	# Nothing above the hero's own level will answer to him, so Recruit is
	# closed rather than allowed to eat three rounds and fail. Refusing up front
	# is the honest version of the same rule.
	var outranks: bool = enemy.lv > player.lv
	# Six already answer to you: Recruit has nowhere to put it.
	var full: bool = not player.can_bind(enemy.enemy_name)
	# No "bound" state here any more: Talk never reaches this menu on a demon
	# whose name is already in the roster — that one pays you off instead.
	for opt: Array in opts:
		var recruit: bool = opt[0] == "Recruit"
		var note: String = ""
		if recruit and full:
			note = "Roster full"
		elif recruit and outranks:
			note = "Lv %d > yours" % enemy.lv
		var btn: Button = _big_button(opt[1] as String, note,
				recruit and (outranks or full))
		btn.pressed.connect(_on_talk.bind(opt[0] as String))
		_submenu_add(btn)



# Back out of the Talk menu one step: to the demon you picked it on, when there
# was a choice to make, and only otherwise all the way out.
func _talk_back() -> void:
	if _living_foes().size() > 1:
		_on_action("Talk")
	else:
		_show_main_actions()


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
		if item["id"] == item_id and item["type"] == "consumable" and item.has("revive"):
			var who: CharacterSheet = _ally_target
			if who == null or who.is_alive():
				return {msg = "[color=gray]Nobody to revive.[/color]", cost = PressTurn.COST_FULL}
			player.remove_item(item, 1)
			who.heal(maxi(1, who.max_hp * int(item["revive"]) / 100))
			_refresh_hp()
			return {msg = "[color=lime]Used %s! %s is back on their feet.[/color]" % [
					item["name"], _member_name(who)], cost = PressTurn.COST_FULL}
		if item["id"] == item_id and item["type"] == "consumable":
			var inflicts: String = item.get("inflicts_status", "")
			if inflicts != "":
				var sname: String = Status.get_data(inflicts).get("name", inflicts)
				player.remove_item(item, 1)
				if enemy.has_status(inflicts):
					return {msg = "[color=aqua]Used %s.[/color] %s is already %s." % [
							item["name"], enemy.enemy_name, sname],
							cost = PressTurn.COST_FULL}
				if enemy.resists_status(inflicts):
					return {msg = "[color=aqua]Used %s.[/color] [color=gray]%s shrugs it off.[/color]" % [
							item["name"], enemy.display_name()], cost = PressTurn.COST_FULL}
				enemy.apply_status(inflicts)
				return {msg = "[color=aqua]Used %s![/color]  [color=violet]%s is now %s.[/color]" % [
						item["name"], enemy.enemy_name, sname], cost = PressTurn.COST_FULL}
			var element: String = item.get("element", "")
			var base_dmg: int = item.get("dmg", 0)
			if element != "" and base_dmg > 0:
				_reveal(enemy, element)
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
			if item.has("mirror"):
				player.remove_item(item, 1)
				for m: CharacterSheet in _living_party():
					m.mirror = item["mirror"] as String
				return {msg = "[color=aqua]Used %s![/color]  [color=#d070ff]A mirror goes up before the party: %s attacks are turned back until your next turn.[/color]" % [
						item["name"], "physical" if item["mirror"] == "phys" else "magic"],
						cost = PressTurn.COST_FULL}
			if _restorative(item) and item.get("party", false):
				var lines: Array[String] = []
				for m: CharacterSheet in _living_party():
					if m.could_use(item):
						lines.append("%s: %s" % [_member_name(m), m.apply_restorative(item)])
				player.remove_item(item, 1)
				_refresh_hp()
				return {msg = "[color=aqua]Used %s on the party.[/color]\n%s" % [
						item["name"], "\n".join(lines)], cost = PressTurn.COST_FULL}
			if _restorative(item):
				var who: CharacterSheet = _ally_target \
						if _ally_target != null and _ally_target.is_alive() else player
				var done: String = who.apply_restorative(item)
				player.remove_item(item, 1)
				_refresh_hp()
				return {msg = "[color=aqua]Used %s on %s. %s[/color]" % [
						item["name"], _member_name(who), done], cost = PressTurn.COST_FULL}
			var result: String = player.use_item(item)
			return {msg = "[color=aqua]Used %s. %s[/color]" % [item["name"], result],
					cost = PressTurn.COST_FULL}
	return {msg = "[color=gray]Item not found.[/color]", cost = PressTurn.COST_FULL}



func _check_counter() -> String:
	if "counter" not in player.passive_skills or not player.is_alive() or randi() % 4 != 0:
		return ""
	var dmg: int = _apply_variance(int(player.effective_str() * CombatMath.PHYS_POWER)
			- enemy.def / 2)
	var crit: bool = _roll_crit()
	if crit:
		dmg = int(dmg * 1.75)
	dmg = max(1, dmg)
	enemy.take_damage(dmg)
	var crit_tag: String = " [CRITICAL!]" if crit else ""
	return "\n[color=orange]Counter! You strike back for %d damage!%s[/color]" % [dmg, crit_tag]



# A bound demon that goes down is struck off here — off the roster, not just
# out of this fight — which is the whole reason the compendium is there. It is
# struck off at this moment and not the one it dropped in, so everything up to
# the last enemy is a window in which Revive can still pull it back.
func _end_combat(result: String) -> void:
	# The hero outlives the fight; a mirror must not.
	for member: CharacterSheet in party:
		member.mirror = ""
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

# The one of the party a heal or a revive is about to land on, chosen in
# _pick_ally just before the action commits.
var _ally_target: CharacterSheet = null


# Everyone in the party who is down, the hero included. _fallen_party is the
# monsters only, for Summon.
func _fallen_members() -> Array[CharacterSheet]:
	var out: Array[CharacterSheet] = []
	for m: CharacterSheet in party:
		if not m.is_alive():
			out.append(m)
	return out


# Who in the party a heal (the living) or a revive (the fallen) lands on. With
# only one choice it does not ask.
func _pick_ally(fallen: bool, title: String, back: Callable, then: Callable) -> void:
	var pool: Array[CharacterSheet] = _fallen_members() if fallen else _living_party()
	if pool.size() == 1:
		_ally_target = pool[0]
		then.call()
		return
	_hide_actions()
	_set_back(back)
	_right_title.text = title
	_right_title.add_theme_color_override("font_color", Color(0.45, 1.0, 0.55))
	_submenu_clear()
	var entries: Array[Dictionary] = []
	for m: CharacterSheet in pool:
		var who: CharacterSheet = m
		entries.append({title = _member_name(who),
				detail = "%d/%d HP  %d/%d MP" % [who.hp, who.max_hp, who.mp, who.max_mp],
				press = func() -> void:
					_ally_target = who
					then.call()})
	_fill_submenu(entries)


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
	_step_back_immediate()
	for member: CharacterSheet in party:
		member.defending = false
		member.mirror = ""
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
# Nothing throws itself down while it is winning. A demon begs only once its own
# bar has left the green — yellow or red, the same two bands the player is
# already reading off the row — which turns the event from a free tier-four
# demon handed out at random into the end of a fight you were already winning.
#
# That also means the old single check on phase two had to go: almost nothing is
# hurt that early, so the event would have stopped firing altogether. It is
# rolled at the top of every phase from the second on, still only once a battle,
# and at five per cent, plus half a point per point of the hero's luck,
# capped at fifteen.
const BEG_CHANCE: float = 0.05
const BEG_PER_LUK: float = 0.005
const BEG_CAP: float = 0.15
const BEG_FROM_PHASE: int = 2

var _beg_used: bool = false
var _phases: int = 0


# Foes that can be talked to and are hurt enough to want to. hp_tint is what
# paints the bar, so "yellow or red" here means exactly what it looks like.
func _begging_candidates() -> Array[Enemy]:
	var out: Array[Enemy] = []
	for foe: Enemy in _living_foes():
		if foe.negotiable and hp_tint(foe.hp, foe.max_hp) != HP_OK:
			out.append(foe)
	return out


# Returns true when a plea took over the phase, so the caller stands down.
func _try_begging() -> bool:
	if _beg_used or _phases < BEG_FROM_PHASE:
		return false
	var pool: Array[Enemy] = _begging_candidates()
	if pool.is_empty():
		return false
	if randf() >= minf(BEG_CAP, BEG_CHANCE + BEG_PER_LUK * float(player.battle_luck())):
		return false
	_beg_used = true

	enemy = pool[randi() % pool.size()]
	_refresh_hp()

	# Already bound: it has nothing to offer that he has not got, and it knows
	# it. It pays its way out instead.
	if enemy.enemy_name in player.recruited:
		_log("[color=#ffd479]%s throws itself down — and sees its own face already standing with you.[/color]"
				% enemy.display_name())
		_prompt_tribute()
		return true

	# No room for it: the plea turns into the same payoff a duplicate gives.
	if not player.can_bind(enemy.enemy_name):
		_log("[color=#ffd479]%s begs to come with you — but six already do. It pays its way out instead.[/color]"
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

	var take: Button = _big_button("Recruit it",
			"%s joins your roster. Costs nothing." % enemy.enemy_name, false)
	take.pressed.connect(func() -> void:
		if take.disabled:
			return
		_lock_submenu()
		var who: String = enemy.enemy_name
		_remember_recruit(who, enemy.lv, enemy.abyss_element)
		_log("[color=lime]%s is recruited. It walks in behind you.[/color]" % who)
		await _beg_resolved())
	_submenu_add(take)

	var refuse: Button = _big_button("Refuse it",
			"Leave it where it is. The fight goes on.", false)
	refuse.pressed.connect(func() -> void:
		if refuse.disabled:
			return
		_lock_submenu()
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
# `from_beg` is what the plea path passes. It matters for the tail: a plea
# interrupts the phase before it has begun, so that path reopens the phase
# whole, while talking to it is an action you chose and costs the icon every
# other successful negotiation costs. Sharing one tail handed the player a free
# phase every time they spoke to something they already keep.
func _prompt_tribute(from_beg: bool = true) -> void:
	_set_buttons(false)
	_hide_actions()
	_open_tribute_window(from_beg)
	_back_target = Callable()
	_right_back_btn.visible = false
	_right_title.text = "It is paying you off"
	_right_title.add_theme_color_override("font_color", Color(1.0, 0.83, 0.47))
	_submenu_clear()

	# It empties its pockets: whatever it was carrying AND the coin. It used to
	# be one or the other, which made a demon you already keep worth less than
	# one you killed.
	var drop: Dictionary = enemy.roll_drop()
	var coin: int = maxi(5, enemy.gold_reward * 2)
	var what: String = "%d gold" % coin
	if not drop.is_empty():
		what = "%s and %d gold" % [drop["name"], coin]
	var who: String = enemy.display_name()

	var take: Button = _big_button("Take it",
			"%s gives up %s and leaves." % [who, what], false)
	take.pressed.connect(func() -> void:
		if take.disabled:
			return
		_lock_submenu()
		player.gold += coin
		if drop.is_empty():
			_log("[color=#ffd479]It empties its hands — %d gold — and goes.[/color]" % coin)
		else:
			player.add_item(drop.duplicate(), 1)
			_log("[color=#ffd479]It presses %s and %d gold on you, and goes.[/color]" % [
					drop["name"], coin])
		if from_beg:
			await _beg_resolved()
		else:
			_right_back_btn.visible = true
			_show_main_actions()
			await _foe_departs("talk"))
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
	# The dead keep their place in `foes` until the fight ends, so an empty list
	# is not the test: a field of bodies has nobody left to fight either.
	if _living_foes().is_empty():
		_end_combat("talk")
		return
	_press.begin(_living_party().size())
	_actor_idx = 0 if party[0].is_alive() else _next_living(0)
	_prompt_actor()


func _prompt_actor() -> void:
	_clear_floats()
	_refresh_hp()
	_step_forward_actor()
	_show_main_actions()
	_set_buttons(true)
	_refresh_button_states()


func _step_forward_actor() -> void:
	var member: CharacterSheet = _actor()
	for s: Dictionary in _party_slots:
		if s.get("card") != null and s["member"] == member:
			_step_forward(s["card"] as Control, false)
			return


func _step_forward_foe(foe: Enemy) -> void:
	for r: Dictionary in _foe_rows:
		if r.get("card") != null and r["foe"] == foe:
			_step_forward(r["card"] as Control, true)
			return


# Every player-side action funnels through here, so the icon economy has
# exactly one owner and the phase can only end in one place.

func _do_end_of_round() -> void:
	var tick_msg: String = _do_poison_ticks()
	if not tick_msg.is_empty():
		_log(tick_msg)
		_refresh_hp()
	# Poison has bitten for the round; now the foes' ailments count down a
	# turn, as the party's did when its phase ended.
	var worn_msg: String = _wear_off(foes)
	if not worn_msg.is_empty():
		_log(worn_msg)
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
	var actor_pr: TextureRect = _actor_portrait()
	if actor_pr != null:
		var anim: String = "attack"
		if action == "Defend":
			anim = "block"
		# A spell in the Knight's hands is his special attack, held on the
		# flash of the blade and coloured by what he is casting
		# (AnimatedPortrait.play_cast). A plain swing is his first attack.
		if action.begins_with("Magic:") and _actor_is_player() and actor_pr is AnimatedPortrait:
			(actor_pr as AnimatedPortrait).play_cast(_cast_kind(action.substr(6)))
		else:
			_play_anim(actor_pr, anim)
	var res: Dictionary = _resolve_action(action)
	_log(res["msg"] as String)
	await _after_action(res["cost"] as String)


# The colour a spell flashes in: its element, else green for a heal and teal
# for anything else (a buff, an ailment, Analyze).
static func _cast_kind(spell_id: String) -> String:
	var d: Dictionary = Spell.get_data(spell_id)
	var el: String = d.get("element", "") as String
	if el != "":
		return el
	return "heal" if d.get("type", "") == "heal" else "other"


func _actor_portrait() -> TextureRect:
	if _actor_is_player():
		return _member_portrait(_actor())
	var a: CharacterSheet = _actor()
	if a is Enemy:
		return _foe_portrait(a as Enemy)
	return _member_portrait(a)




# A potion, an ether or a cure: anything that mends rather than hurts or
# raises a ceiling. Any of the party can take one, so it asks who.
static func _restorative(item: Dictionary) -> bool:
	return int(item.get("hp_restore", 0)) > 0 or int(item.get("mp_restore", 0)) > 0 \
			or item.get("cures_status", "") != ""


func _on_use_item(item: Dictionary) -> void:
	if item.has("revive"):
		_pick_ally(true, "Revive who?", _back_to(_show_item_submenu),
				func() -> void: await _commit_item(item))
		return
	# A cauldron or a fountain is for everyone standing: nobody to pick.
	if _restorative(item) and item.get("party", false):
		await _commit_item(item)
		return
	if _restorative(item):
		_pick_ally(false, "Use %s on?" % item["name"], _back_to(_show_item_submenu),
				func() -> void: await _commit_item(item))
		return
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
	if actor.has_status(Status.PARALYZED) and randf() < PARALYSIS_SKIP:
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



func _land_hit(res: Dictionary, element: String, prefix: String,
		melee: bool = false, rung: float = Spell.POWER_I) -> Dictionary:
	_reveal(enemy, element)
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
		if melee:
			SlashFX.strike(pr)
		else:
			SpellFX.cast(pr, element, rung)
	var extra: String = ""
	if _actor_is_player() and melee \
			and "vampiric" in player.passive_skills:
		var heal_amt: int = max(1, dmg / 5)
		player.heal(heal_amt)
		extra = "  [color=lime]Vampiric: +%d HP.[/color]" % heal_amt
	# What happened after the blow: the foe going down, or a warden answering it.
	var after: String = ""
	if not enemy.is_alive():
		after = "  [color=lime]%s goes down![/color]" % enemy.display_name()
	elif melee or element == Affinity.PHYS:
		after = _warden_counter(enemy, actor)
	return {msg = "%s%s  [color=orange]%s takes %d damage.[/color]%s%s" % [
			prefix, CombatMath.outcome_tag(outcome, crit, muted), enemy.display_name(),
			dmg, extra, after],
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

# The odds a paralysed member, on either side, loses the action it was about
# to take. It still costs the icon.
const PARALYSIS_SKIP: float = 0.5

const AIL_SPELLS: Dictionary = {
	Status.POISON:     "venom",
	Status.PARALYZED:  "shock",
	Status.SILENCE:    "mute",
	Status.BLIND:      "blind",
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

	# A ward trinket never fails, and it is checked before the dice so a
	# warded hero sees why, every time.
	if target == player and not player.ward_against(status_id).is_empty():
		return {msg = "%s  [color=lime]%s's %s wards it off![/color]" % [lead,
				PlayerCharacter.DISPLAY_NAME, player.ward_against(status_id)["name"]],
				cost = PressTurn.COST_FULL}
	if randi() % 100 >= ail_landing_chance(actor.ailment_chance):
		return {msg = "%s  [color=gray]%s shrugs it off.[/color]" % [
				lead, _member_name(target)], cost = PressTurn.COST_FULL}
	if target == player and "resilience" in player.passive_skills and randi() % 4 == 0:
		return {msg = "%s  [color=lime]Resilience resists %s![/color]" % [lead, sname],
				cost = PressTurn.COST_FULL}
	target.apply_status(status_id)
	return {msg = "%s  [color=violet]%s is now %s.[/color]" % [
			lead, _member_name(target), sname], cost = PressTurn.COST_FULL}


# Kept for the CombatNeg* handlers: one provoked swing at the hero, taken
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


func _remember_recruit(demon_name: String, lv: int = 1, element: String = "") -> void:
	player.remember_recruit(demon_name, lv, element)


func _open_summon_menu() -> void:
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
	_fill_submenu(entries)


# A whole list into the submenu. Past six it scrolls — see _sub_scroll.
func _fill_submenu(entries: Array[Dictionary]) -> void:
	for e: Dictionary in entries:
		_submenu_add(_entry_button(e))


func _entry_button(e: Dictionary) -> Button:
	var btn: Button = _big_button(e["title"] as String, e["detail"] as String,
			bool(e.get("disabled", false)), e.get("icon", "") as String,
			e.get("tint", Color.TRANSPARENT) as Color)
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
	_set_back(_back_to(_show_summon_submenu))
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


func _ambush_line() -> String:
	if foes.size() == 1:
		return "%s gets the jump on you" % foes[0].display_name()
	return "They get the jump on you"


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


# Keeps the targeted foe on something that is still standing — and still on
# the field. A demon that talked its way out is alive, so checking HP alone left
# it targeted, and with one foe left the picker is skipped: Talk went straight
# back to the one that had gone.
func _ensure_target() -> void:
	if enemy != null and enemy.is_alive() and enemy in foes:
		return
	var living: Array[Enemy] = _living_foes()
	if not living.is_empty():
		enemy = living[0]


const CARD_SEP:       int = 2
const CARD_PORTRAIT:  int = 140

func _build_battlefield(parent: Control) -> void:
	pass

func _build_foe_card(foe: Enemy) -> Control:
	return null


func _foe_portrait(foe: Enemy) -> TextureRect:
	for r: Dictionary in _foe_rows:
		if r["foe"] == foe:
			return r["portrait"] as TextureRect
	return null


# A hit shows what the target does with that one element, on its chart, from
# this moment and for the rest of the run. Bosses and wardens too: Analyze is
# the only thing they refuse.
func _reveal(foe: Enemy, element: String) -> void:
	if foe == null or element == "":
		return
	player.learn_affinity(foe.lore_name(), element)
	for r: Dictionary in _foe_rows:
		if r["foe"] == foe or (r["foe"] as Enemy).lore_name() == foe.lore_name():
			(r["chart"] as AffinityChart).queue_redraw()


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
			# Ghosted rather than erased — it still has a name and a place
			# in the list.
			(r["marker"] as UIGlyph).visible = false
			(r["portrait"] as TextureRect).modulate = Color(1, 1, 1, 0.10)
			var gone_lbl: Label = r["name_lbl"] as Label
			gone_lbl.text = foe.display_name()
			gone_lbl.add_theme_color_override("font_color", Color(0.40, 0.40, 0.46))
			(r["bar"] as ProgressBar).visible = false
			(r["hp_lbl"] as Label).text = "Left"
			(r["hp_lbl"] as Label).add_theme_color_override("font_color",
					Color(0.45, 0.45, 0.52))
			(r["stages"] as StageArrows).visible = false
			(r["chart"] as AffinityChart).visible = false
			continue
		var alive: bool = foe.is_alive()
		var targeted: bool = (foe == enemy) and alive
		(r["marker"] as UIGlyph).visible = targeted and multiple
		(r["portrait"] as TextureRect).modulate.a = 1.0 if alive else 0.18
		if not alive and not r.get("_death_played", false):
			_play_anim(r["portrait"] as TextureRect, "death")
			r["_death_played"] = true
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
		bar.visible = alive
		var hp_lbl: Label = r["hp_lbl"] as Label
		hp_lbl.text = "%d / %d" % [foe.hp, foe.max_hp] if alive else "Down"
		hp_lbl.add_theme_color_override("font_color",
				hp_tint(foe.hp, foe.max_hp) if alive else Color(0.55, 0.38, 0.38))

		var stages: StageArrows = r["stages"] as StageArrows
		stages.visible = alive
		stages.queue_redraw()

		var chart: AffinityChart = r["chart"] as AffinityChart
		chart.visible = alive
		if chart.visible:
			chart.queue_redraw()


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
	# The party's turn is over, so its ailments count down a turn.
	var worn_msg: String = _wear_off(party)
	if not worn_msg.is_empty():
		_log(worn_msg)
	_step_back_immediate()
	_set_buttons(false)
	_show_main_actions()
	# The Necromancer changes form at the top of each of its phases; a wounded
	# Minotaur may lose its temper here, in time for the icon to count.
	_warden_raised = false
	for f: Enemy in _living_foes():
		if f.is_dragon() and not f.attack_elements.is_empty() and f.mp < f.max_mp:
			var was_dry: bool = f.mp < f.skill_cost()
			f.mp = mini(f.max_mp, f.mp + f.skill_cost() * Enemy.DRAGON_BREATH_PER_PHASE)
			if was_dry:
				f.announced_dry = false
				_log("[color=#ff9a6a]%s draws a fresh breath.[/color]" % f.display_name())
		if f.is_necromancer():
			_necro_begin_phase(f)
		elif f.warden_trick() == "enrage" and not f.enraged and f.hp * 2 < f.max_hp:
			f.enraged = true
			f.icons += 1
			f.shift_stage(CharacterSheet.STAT_ATK, 2)
			_log("[color=#ff6a4a]%s bellows and goes berserk! Its attack rises.[/color]"
					% f.display_name())
			_refresh_hp()
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
		# Only what stood when the phase began takes turns in it: a minion
		# raised mid-phase starts acting next phase, rather than taking the
		# icons its master was still spending.
		var actors: Array[Enemy] = []
		for f: Enemy in _living_foes():
			if f in living:
				actors.append(f)
		if actors.is_empty():
			break
		var actor: Enemy = actors[_foe_turn_idx % actors.size()]
		_foe_turn_idx += 1
		_clear_floats()
		_step_forward_foe(actor)
		var res: Dictionary = _necro_act(actor) if actor.is_necromancer() \
				else (_warden_act(actor) if actor.is_warden() else _enemy_act(actor))
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


# Counts one turn off every living member's ailments and says which ones
# lifted. Ailments last CharacterSheet.STATUS_TURNS of the afflicted's own turns.
func _wear_off(members: Array) -> String:
	var msgs: Array[String] = []
	for m: CharacterSheet in members:
		if not m.is_alive():
			continue
		for id: String in m.tick_statuses():
			var who: String = (m as Enemy).display_name() if m is Enemy else _member_name(m)
			msgs.append("[color=gray]%s recovers from %s.[/color]" % [
					who, Status.get_data(id).get("noun", id)])
	_refresh_hp()
	return "\n".join(msgs)


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
	# Agility as it stands this fight, so a blind hero struggles to get away
	# and a blind foe struggles to stop him.
	var fastest: float = 0.0
	for f: Enemy in _living_foes():
		fastest = maxf(fastest, f.agl * f.agility_mult())
	if player.effective_agl() * player.agility_mult() >= fastest or randi() % 2 == 0:
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
	Sfx.play("recruit")
	var leaving: Enemy = enemy
	foes.erase(leaving)
	_departed.append(leaving)
	_ensure_target()
	_refresh_hp()
	if _living_foes().is_empty():
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
			_on_talk_chosen()
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
# first, then whatever they carry. For the hero that is his equipped
# spells; for a bound demon it is its own element.



# ── Button state ──────────────────────────────────────────────────────────────

# Talk, Item, Summon and Flee are the hero's alone. On a demon's turn they
# are hidden rather than greyed — there is not much room on a phone, and a row
# of dead buttons reads as a bug.
func _refresh_button_states() -> void:
	var is_p: bool = _actor_is_player()
	for key: String in ["Item", "Talk", "Summon", "Flee"]:
		(_buttons[key] as Button).visible = is_p

	_buttons["Skills"].disabled = false
	# Bracing on top of a brace does nothing but spend the icon, and at half an
	# icon it is cheap enough to do by accident. Attack is never taken away, so
	# there is always something better to press.
	_buttons["Defend"].disabled = _actor().defending
	_buttons["Item"].disabled   = not is_p
	_buttons["Talk"].disabled   = not is_p or _living_foes().is_empty()
	# Live whenever there is anything to move: a body to raise, a demon waiting
	# off the field, or one standing that would rather not be.
	_buttons["Summon"].disabled = not is_p or (_fallen_party().is_empty() \
			and _available_summons().is_empty() and _standing_party().is_empty())
	_buttons["Flee"].disabled   = not is_p






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
	# Run here because every action on either side ends in a refresh, so the
	# blow that drops the Necromancer takes its minions with it at once.
	_crumble_orphans()
	_refresh_party_slots()
	_refresh_foe_rows()
	_refresh_icons()

func _build_icon_overlay() -> void:
	pass

func _side_row(who: String, color: Color, pips: UIGlyph) -> HBoxContainer:
	return null

func _refresh_icons() -> void:
	pass


# ── Skills ────────────────────────────────────────────────────────────────────

func _show_skills_submenu() -> void:
	_hide_actions()
	_set_back(_show_main_actions)
	_right_title.text = "%s's skills" % _actor_name()
	_right_title.add_theme_color_override("font_color", Color(0.80, 0.62, 1.0))
	_submenu_clear()

	var actor: CharacterSheet = _actor()

	# Paged like Summon: Attack plus a demon's full six is seven entries, and
	# a flat fill silently dropped the last one.
	var entries: Array[Dictionary] = []
	entries.append(_skill_entry("Attack", "Attack", _reach_count("one"), "", false, Affinity.PHYS))

	if _actor_is_player():
		# Analyze is no longer bolted on here \u2014 it is an ordinary equipped spell
		# and comes through the loop below with everything else.
		if player.equipped_spells.is_empty():
			_fill_submenu(entries)
			_submenu_add(_dim_label("No spells equipped."))
			return
		var silenced: bool = player.has_status(Status.SILENCE)
		for spell_id: String in player.equipped_spells:
			var data: Dictionary = Spell.get_data(spell_id)
			if data.is_empty():
				continue
			var element: String = data.get("element", "")
			# An element is its icon; anything without one says what it is.
			# How far it reaches is the thing a player most needs to know
			# before spending 22 MP, so it rides next to the element.
			var tag: String = _reach_count(Spell.reach_tag(spell_id)) if element != "" \
					else _stage_tag(data) if _stage_tint(data).a > 0.0 \
					else (data.get("type", "dmg") as String).capitalize()
			# A physical skill is paid in blood, not mana: silence does not
			# stop it, and it will not spend the last of the hero's HP.
			var blocked: bool
			var hp_price: int = Spell.hp_cost(spell_id, player.max_hp)
			if hp_price > 0:
				blocked = player.hp <= hp_price
			else:
				blocked = silenced or player.mp < int(data.get("mp", 0))
			entries.append(_skill_entry("Magic:" + spell_id,
					data["name"] as String, tag, Spell.cost_text(spell_id), blocked, element,
					_stage_tint(data)))
		_fill_submenu(entries)
		return

	var demon: Enemy = actor as Enemy
	var known: Array = player.skills_of(demon.enemy_name)
	var silenced_demon: bool = demon.has_status(Status.SILENCE)
	var reach: String = Spell.reach_tag_for(demon.attack_reach)
	# One button per skill it carries — its own lines at whatever rung they have
	# reached, and every buff or debuff it has picked up since it was bound.
	for i: int in known.size():
		var skill: Dictionary = known[i] as Dictionary
		var cost: int = _demon_skill_cost(demon, skill)
		var hp_price: int = _demon_hp_cost(demon, skill)
		var blocked: bool = demon.hp <= hp_price if hp_price > 0 \
				else silenced_demon or demon.mp < cost
		var tag: String = ""
		var icon: String = ""
		var tint: Color = Color.TRANSPARENT
		if skill.get("kind", "") == "unique":
			var u: Dictionary = Spell.get_data(skill.get("id", "") as String)
			tag = "Drain %s  one" % (u.get("drain", "hp") as String).to_upper()
		elif skill.get("kind", "") == "support":
			var d: Dictionary = Spell.get_data(skill.get("id", "") as String)
			tag = _stage_tag(d)
			tint = _stage_tint(d)
		else:
			# Its rung is already in its name (Ember, Blaze, Inferno).
			icon = skill.get("element", "") as String
			tag = _reach_count(reach)
		entries.append(_skill_entry("Skill:%d" % i,
				PlayerCharacter.skill_name(skill), tag,
				_demon_cost_text(skill) if hp_price > 0 else "%d MP" % cost, blocked, icon,
				tint))
	_fill_submenu(entries)


# An elemental cast is paid out of the demon's own pool and gets dearer as its
# rung climbs; a buff costs what the spell costs, the same as the hero pays.
func _demon_skill_cost(demon: Enemy, skill: Dictionary) -> int:
	if skill.get("kind", "") != "element":
		return int(Spell.get_data(skill.get("id", "") as String).get("mp", 8))
	var rung: int = int(skill.get("rung", 1))
	return maxi(1, roundi(float(demon.skill_cost())
			* (Spell.rung_power(rung) / Spell.POWER_I)))


# A physical line is paid in HP, the same share of the demon's own pool the
# hero pays for the same skill. 0 for everything paid in MP.
func _demon_hp_cost(demon: Enemy, skill: Dictionary) -> int:
	if skill.get("element", "") != Affinity.PHYS:
		return 0
	return maxi(1, Spell.hp_cost(_phys_skill_id(skill), demon.max_hp))


func _demon_cost_text(skill: Dictionary) -> String:
	return Spell.cost_text(_phys_skill_id(skill))


func _phys_skill_id(skill: Dictionary) -> String:
	return Spell.elemental_id(Affinity.PHYS, int(skill.get("rung", 1)),
			skill.get("shape", Spell.SHAPE_ONE) as String)


# One of a bound demon's skills, picked by its index in the demon's own list and
# paid for out of its own pool.
func _resolve_skill(chosen: String) -> Dictionary:
	var actor: Enemy = _actor() as Enemy
	var known: Array = player.skills_of(actor.enemy_name)
	# A bare "Skill" action means "its first one", which is what the auto path
	# and the older single-element button both asked for.
	var idx: int = chosen.to_int() if chosen.is_valid_int() else 0
	if idx < 0 or idx >= known.size():
		return {msg = "[color=gray]%s has nothing to call on.[/color]" % actor.display_name(),
				cost = PressTurn.COST_FULL}
	var skill: Dictionary = known[idx] as Dictionary
	var hp_price: int = _demon_hp_cost(actor, skill)
	if hp_price > 0:
		if actor.hp <= hp_price:
			return {msg = "[color=gray]%s: not enough HP![/color]" % actor.display_name(),
					cost = PressTurn.COST_FULL}
		actor.take_damage(hp_price)
	else:
		var price: int = _demon_skill_cost(actor, skill)
		if actor.mp < price:
			return {msg = "[color=gray]%s: not enough MP![/color]" % actor.display_name(),
					cost = PressTurn.COST_FULL}
		actor.mp -= price

	if skill.get("kind", "") == "unique":
		return _leech(actor, enemy, skill.get("id", "") as String)

	if skill.get("kind", "") == "support":
		var data: Dictionary = Spell.get_data(skill.get("id", "") as String)
		return _apply_stage_spell(data, "%s calls up %s" % [
				actor.display_name(), data.get("name", "?")])

	var element: String = skill.get("element", "") as String
	var rung: int = int(skill.get("rung", 1))
	var phys: bool = element == Affinity.PHYS
	var power: float = float(actor.str) * actor.stage_mult(CharacterSheet.STAT_ATK) if phys \
			else float(actor.mag) * actor.stage_mult(CharacterSheet.STAT_MAG)
	var banishing: bool = Affinity.is_banishing(element)
	var named: String = PlayerCharacter.skill_name(skill)

	# A bound demon casts exactly what it cast at you — same lines, same width.
	# The single-target case keeps the target you picked; anything wider draws
	# its own, which is why the menu does not ask.
	if actor.attack_reach != Spell.SHAPE_ONE:
		return _demon_spread(actor, element, power * Spell.rung_power(rung),
				banishing, Spell.rung_boost(rung), named)

	if banishing:
		return _demon_banish_one(actor, enemy, element, power,
				Spell.rung_boost(rung))

	# A physical line is a swing: it misses like one and wastes what one does.
	if phys and not CombatMath.lands(actor, enemy):
		return {msg = "[color=#9aa0aa]%s uses %s — %s dodges![/color]" % [
				actor.display_name(), named, enemy.display_name()],
				cost = PressTurn.COST_MISS}
	if not phys and not CombatMath.spell_lands(actor, enemy):
		return {msg = "[color=#9aa0aa]%s calls up %s — %s slips it![/color]" % [
				actor.display_name(), named, enemy.display_name()],
				cost = PressTurn.COST_FULL}
	var crit: bool = CombatMath.roll_crit(actor)
	var res: Dictionary = CombatMath.resolve(
			int(power * Spell.rung_power(rung)) - _guard_vs(enemy, element),
			element, enemy, crit, enemy.defending)
	return _land_hit(res, element, "%s %s %s!" % [
			actor.display_name(), "uses" if phys else "calls up", named], phys)


# ── Leeches ───────────────────────────────────────────────────────────────────
#
# A bat or a blood thing biting, from either side of the field. The cost is
# already paid. A bite, not a spell: it rolls to hit like a swing and a miss
# wastes what a missed swing does. No element, so no chart to hit or bounce off.
func _leech(actor: Enemy, target: CharacterSheet, id: String) -> Dictionary:
	var data: Dictionary = Spell.get_data(id)
	var who: String = _member_name(target) if not target is Enemy \
			else (target as Enemy).display_name()
	var lead: String = "%s uses %s" % [actor.display_name(), data.get("name", "?")]
	if not CombatMath.lands(actor, target):
		return {msg = "[color=#9aa0aa]%s — %s dodges![/color]" % [lead, who],
				cost = PressTurn.COST_MISS}
	var bite: float = float(actor.str) * actor.stage_mult(CharacterSheet.STAT_ATK) \
			* float(data.get("power", 1.0))

	if data.get("drain", "hp") == "mp":
		var took: int = mini(maxi(1, int(bite)), target.mp)
		if took <= 0:
			return {msg = "[color=gray]%s — %s has no MP to drink.[/color]" % [lead, who],
					cost = PressTurn.COST_FULL}
		target.mp -= took
		actor.mp = mini(actor.max_mp, actor.mp + took)
		_bite_fx(target, LEECH_MP_TINT)
		return {msg = "[color=#7fb0ff]%s! It drinks %d MP from %s.[/color]" % [lead, took, who],
				cost = PressTurn.COST_FULL}

	var guarded: bool = target.defending
	var res: Dictionary = CombatMath.resolve(int(bite) - _guarded_def(target), "",
			target, CombatMath.roll_crit(actor), guarded)
	var dmg: int = mini(int(res["dmg"]), target.hp)
	target.take_damage(dmg)
	actor.heal(dmg)
	_bite_fx(target, LEECH_HP_TINT, guarded)
	var tail: String = ""
	if not target.is_alive():
		tail = "  [color=lime]%s goes down![/color]" % who
	return {msg = "%s!  [color=orange]%s takes %d[/color] [color=lime]and %s drinks it back.[/color]%s%s" % [
			lead, who, dmg, actor.display_name(),
			CombatMath.outcome_tag(res["outcome"] as String, bool(res["crit"]),
					bool(res.get("suppressed", false))), tail],
			cost = PressTurn.COST_HALF if bool(res["crit"]) and not guarded
				else PressTurn.COST_FULL}


# A bite lands like a swing: the portrait shakes and the slash crosses it,
# red for blood and blue for MP, the whole stroke and not just its rim.
const LEECH_HP_TINT: Color = Color(1.0, 0.22, 0.22)
const LEECH_MP_TINT: Color = Color(0.30, 0.60, 1.0)


func _bite_fx(target: CharacterSheet, tint: Color, guarded: bool = false) -> void:
	var pr: TextureRect = _foe_portrait(target as Enemy) if target is Enemy \
			else _member_portrait(target)
	if pr == null:
		return
	_shake_portrait(pr, guarded)
	SlashFX.strike(pr, tint, true)


# What a bat or a blood thing on the other side bites with this turn, if it
# bites at all: HP when it is hurt and can pay, MP when it is short of what it
# wants to spend and someone across the field has some to take.
func _enemy_leech(actor: Enemy) -> Dictionary:
	if actor.unique_skills.is_empty() or randi() % 2 == 0:
		return {}
	var hp_cost: int = int(Spell.get_data("hp_leech").get("mp", 4))
	if "hp_leech" in actor.unique_skills and actor.hp * 10 < actor.max_hp * 7 \
			and actor.mp >= hp_cost:
		actor.mp -= hp_cost
		return _leech(actor, _pick_target(""), "hp_leech")
	if "mp_leech" in actor.unique_skills \
			and actor.mp < maxi(actor.skill_cost(), hp_cost):
		var richest: CharacterSheet = null
		for m: CharacterSheet in _living_party():
			if m.mp > 0 and (richest == null or m.mp > richest.mp):
				richest = m
		if richest != null:
			return _leech(actor, richest, "mp_leech")
	return {}


# One demon of yours, one line, one foe. Light and dark expel rather than burn,
# the same as they do out of the hero's own hands.
func _demon_banish_one(actor: Enemy, foe: Enemy, element: String,
		power: float, boost: float = 0.0) -> Dictionary:
	var res: Dictionary = CombatMath.resolve_banish(foe, element,
			maxi(1, int(power)), false, actor, boost)
	_reveal(foe, element)
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


# A bound demon's wide cast. Same arithmetic as the hero's own spread —
# what it gains in width it gives up on each target.
func _demon_spread(actor: Enemy, element: String, base: float,
		banishing: bool, boost: float = 0.0, named: String = "") -> Dictionary:
	var targets: Array[Enemy] = _spread_targets(actor.attack_reach)
	# Every target takes the whole cast, as the hero's does (see _cast_spread).
	var phys: bool = element == Affinity.PHYS
	var lines: Array[String] = ["[color=#9ad0ff]%s uses %s on %d of them![/color]" % [
			actor.display_name(), named, targets.size()] if phys
			else "[color=#9ad0ff]%s calls up %s over %d of them![/color]" % [
			actor.display_name(), Affinity.element_name(element), targets.size()]]
	var outcomes: Array[String] = []
	var reflected: int = 0
	var took_weak: bool = false

	for foe: Enemy in targets:
		if banishing:
			var br: Dictionary = CombatMath.resolve_banish(
					foe, element, maxi(1, int(base)), false, actor, boost)
			_reveal(foe, element)
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

		if not (CombatMath.lands(actor, foe) if phys else CombatMath.spell_lands(actor, foe)):
			outcomes.append("miss" if phys else "slip")
			lines.append("[color=#9aa0aa]%s %s it.[/color]" % [foe.display_name(),
					"dodges" if phys else "slips"])
			continue
		var res: Dictionary = CombatMath.resolve(
				int(base) - _guard_vs(foe, element), element, foe,
				CombatMath.roll_crit(actor), foe.defending)
		_reveal(foe, element)
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
	# A slipped spell cancels the weakness bonus here too (see _spread_cost).
	if cost == PressTurn.COST_FULL and took_weak and "slip" not in outcomes:
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

# The same button as an entry for _fill_submenu, so a long list scrolls.
# `icon` is an element, drawn as its picture in front of the detail line in
# place of its name, and the line reads "[fire] x 2-3 (14 MP)": how many it
# reaches, then what it costs.
func _skill_entry(action: String, label: String, tag: String,
		cost: String, disabled: bool, icon: String = "",
		tint: Color = Color.TRANSPARENT) -> Dictionary:
	var paid: String = "(%s)" % cost if cost != "" and cost != "\u2014" else ""
	var detail: String = ("%s %s" % [tag, paid]).strip_edges()
	return {title = label, detail = detail, disabled = disabled, icon = icon, tint = tint,
			press = func() -> void: await _on_skill_chosen(action)}


# A buff or a debuff in the skills menu: which stat, which way, and on whom
# ("AGL-  foes"), with the stat in its arrow colour, the same as a stat's
# name is written everywhere else.
static func _stage_tag(data: Dictionary) -> String:
	return "%s%s  %s" % [(data.get("stat", "") as String).to_upper(),
			"+" if int(data.get("delta", 1)) > 0 else "-",
			"party" if data.get("scope", "party") == "party" else "foes"]


static func _stage_tint(data: Dictionary) -> Color:
	if data.get("type", "") != "buff" or not data.has("stat"):
		return Color.TRANSPARENT
	return StageArrows.color_of(data["stat"] as String)


# How many a cast reaches, as the skill menu says it: "x 1", "x 2-3", "x all".
static func _reach_count(reach: String) -> String:
	return "x %s" % ("1" if reach == "one" else reach)


func _make_skill_button(action: String, label: String, element: String,
		cost: String, disabled: bool) -> Button:
	var btn: Button = _big_button(label, "%s   %s" % [element, cost], disabled)
	btn.pressed.connect(func() -> void: await _on_skill_chosen(action))
	return btn

func _rebuild_party_slots() -> void:
	pass


# ── Damage numbers ────────────────────────────────────────────────────────────
#
# Every hit and every heal floats its number over whoever took it: red for HP
# lost, green for HP back. A number belongs to the action that caused it, so it
# is gone before the next one starts: the next turn opens 0.5s after yours and
# the foes act 0.8s apart, and a number pops, holds and fades inside that.
# Anything still up when a turn begins is cleared then, whatever the timing.
const FLOAT_HOLD:  float = 0.2
const FLOAT_FADE:  float = 0.25
const FLOAT_RISE:  float = 36.0
const FLOAT_HURT:  Color = Color(1.0, 0.30, 0.28)
const FLOAT_HEAL:  Color = Color(0.40, 1.0, 0.50)
const FLOAT_MISS:  Color = Color(0.85, 0.87, 0.92)

# The number showing over each target right now, if any.
var _float_of: Dictionary = {}


# Hooked once per fighter. The hero lives on between fights, so a second fight
# must not stack a second connection; the scene going away drops its own.
func _watch_hp(who: CharacterSheet) -> void:
	var lost: Callable = _on_hp_changed.bind(who, FLOAT_HURT, "-")
	var gained: Callable = _on_hp_changed.bind(who, FLOAT_HEAL, "+")
	if not who.hp_lost.is_connected(lost):
		who.hp_lost.connect(lost)
	if not who.hp_gained.is_connected(gained):
		who.hp_gained.connect(gained)
	var missed: Callable = _show_float.bind(who, "MISS", FLOAT_MISS)
	if not who.evaded.is_connected(missed):
		who.evaded.connect(missed)
		who.evaded.connect(func() -> void: Sfx.play("miss"))


func _clear_floats() -> void:
	for lbl: Variant in _float_of.values():
		if is_instance_valid(lbl):
			(lbl as Label).queue_free()
	_float_of.clear()


func _on_hp_changed(amount: int, who: CharacterSheet, color: Color, prefix: String) -> void:
	_show_float(who, "%s%d" % [prefix, amount], color)
	if prefix == "+":
		Sfx.play("heal")
	# `foes` is typed to Enemy, and asking it about the hero is an engine error.
	elif who is Enemy and (who as Enemy) in foes:
		Sfx.play("hit" if who.is_alive() else "defeat")
	else:
		Sfx.play("hurt")


func _show_float(who: CharacterSheet, text: String, color: Color) -> void:
	if not is_inside_tree():
		return
	# A bound demon is an Enemy too, but only foes have a row in _foe_rows.
	var portrait: TextureRect = _foe_portrait(who as Enemy) if who is Enemy else null
	if portrait == null:
		portrait = _member_portrait(who)
	# Not "visible in tree": the blow that kills is the one most worth seeing,
	# and a card can start hiding on the same frame.
	if portrait == null:
		return
	var old: Variant = _float_of.get(who)
	if old != null and is_instance_valid(old):
		(old as Label).queue_free()
	var rect: Rect2 = portrait.get_global_rect()

	var lbl: Label = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 30)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0))
	lbl.add_theme_constant_override("outline_size", 8)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Over the spell effects, which are added after it and would bury it.
	lbl.z_index = 50
	lbl.size = Vector2(rect.size.x, 40)
	var start: Vector2 = rect.position - get_global_rect().position \
			+ Vector2(0.0, rect.size.y * 0.30)
	lbl.position = start
	add_child(lbl)
	_float_of[who] = lbl

	# Tweens belong to the label, so replacing it takes its animation with it.
	lbl.pivot_offset = lbl.size / 2.0
	lbl.scale = Vector2(0.6, 0.6)
	var pop: Tween = lbl.create_tween()
	pop.tween_property(lbl, "scale", Vector2(1.15, 1.15), 0.08)
	pop.tween_property(lbl, "scale", Vector2(1.0, 1.0), 0.08)
	var drift: Tween = lbl.create_tween()
	drift.tween_property(lbl, "position:y", start.y - FLOAT_RISE, FLOAT_HOLD + FLOAT_FADE) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	var fade: Tween = lbl.create_tween()
	fade.tween_interval(FLOAT_HOLD)
	fade.tween_property(lbl, "modulate:a", 0.0, FLOAT_FADE)
	fade.tween_callback(lbl.queue_free)


# The smallest a portrait is allowed to get while making a column fit.
const CARD_PORTRAIT_MIN: int = 56

func _fit_columns() -> void:
	pass

func _fit_column(cards: Array, avail: float) -> void:
	pass

func _build_party_slot(member: CharacterSheet) -> Control:
	return null

func _refresh_party_slots() -> void:
	pass

func _build_menu_panel(parent: Control) -> void:
	pass

func _add_sub_slot() -> MarginContainer:
	return null

func _make_slot_row() -> GridContainer:
	return null

func _show_actions() -> void:
	pass

func _hide_actions() -> void:
	pass

func _show_main_actions() -> void:
	pass


# Detaches immediately rather than waiting on queue_free, so the very next
# _submenu_add sees the slots as empty.
func _submenu_clear() -> void:
	while _sub_slots.size() > MENU_SLOTS:
		var extra: MarginContainer = _sub_slots.pop_back()
		_sub_bar.remove_child(extra)
		extra.queue_free()
	for slot: MarginContainer in _sub_slots:
		for child: Node in slot.get_children():
			slot.remove_child(child)
			child.queue_free()
	_sub_scroll.scroll_vertical = 0


# Greys out every button in the submenu. A choice whose result takes a moment
# to play out (a reaction line, a demon walking off) calls this first, so a
# second tap in that moment cannot answer a question twice — or answer the
# next demon's before it has asked.
func _lock_submenu() -> void:
	for slot: MarginContainer in _sub_slots:
		for c: Node in slot.get_children():
			if c is Button:
				(c as Button).disabled = true


# Drops one entry into the next free slot, making one when all six are taken.
func _submenu_add(control: Control) -> void:
	var into: MarginContainer = null
	for slot: MarginContainer in _sub_slots:
		if slot.get_child_count() == 0:
			into = slot
			break
	if into == null:
		into = _add_sub_slot()
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	into.add_child(control)


# A slot-sized submenu entry: title on top, the detail that decides the choice
# underneath. Built from child Labels because a Button's own text is one line.
# The element icon on a submenu button's detail line.
const ICON_PX: int = 16

func _big_button(title: String, subtitle: String, disabled: bool,
		icon: String = "", tint: Color = Color.TRANSPARENT) -> Button:
	return null


# ── Casting ───────────────────────────────────────────────────────────────────

func _on_skill_chosen(action: String) -> void:
	# Healing and buffs choose no target — buffs take the whole party, debuffs
	# take every enemy. Neither does a spell that reaches more than one demon:
	# it picks its own, so asking which one would be a lie.
	if action.begins_with("Magic:"):
		var spell_id: String = action.substr(6)
		var data: Dictionary = Spell.get_data(spell_id)
		var kind: String = data.get("type", "dmg") as String
		# A single heal lands on one of the party, so it asks who; the All
		# heals take everyone standing and ask nothing.
		if kind == "heal" and not Spell.is_multi(spell_id):
			_pick_ally(false, "Heal who?", _back_to(_show_skills_submenu),
					func() -> void: await _commit_action(action))
			return
		if kind == "heal" or kind == "buff" or kind == "dispel" or Spell.is_multi(spell_id):
			await _commit_action(action)
			return
	# A bound demon's buffs and debuffs take a whole side, and its wide lines
	# draw their own targets, so only a single-target line needs picking.
	if action.begins_with("Skill:") and not _actor_is_player():
		var demon: Enemy = _actor() as Enemy
		var known: Array = player.skills_of(demon.enemy_name)
		var idx: int = action.substr(6).to_int()
		if idx >= 0 and idx < known.size():
			var skill: Dictionary = known[idx] as Dictionary
			# A leech bites one, whatever reach its kind usually has.
			if skill.get("kind", "") == "support" \
					or (skill.get("kind", "") == "element"
						and demon.attack_reach != Spell.SHAPE_ONE):
				await _commit_action(action)
				return
	_with_target(func() -> void: await _commit_action(action))


func _cast_spell(spell_id: String) -> Dictionary:
	var data: Dictionary = Spell.DATA.get(spell_id, {name = "Spell", mp = 8})
	var hp_price: int = Spell.hp_cost(spell_id, player.max_hp)
	if hp_price > 0:
		# Never the killing blow on himself: it needs HP left over after paying.
		if player.hp <= hp_price:
			return {msg = "[color=gray]Not enough HP![/color]", cost = PressTurn.COST_FULL}
		player.take_damage(hp_price)
	else:
		var mp_cost: int = data.get("mp", 8)
		if player.mp < mp_cost:
			return {msg = "[color=gray]Not enough MP![/color]", cost = PressTurn.COST_FULL}
		player.mp -= mp_cost

	var spell_type: String = data.get("type", "dmg")

	if spell_type == "analyze":
		return _resolve_analyze()

	if spell_type == "buff":
		return _apply_stage_spell(data)

	if spell_type == "dispel":
		return _cast_dispel(data, true)

	if spell_type == "ailment":
		var target_status: String = data.get("status", "")
		if target_status == "" or enemy.has_status(target_status):
			return {msg = "[color=gray]Nothing happened.[/color]", cost = PressTurn.COST_FULL}
		if enemy.resists_status(target_status):
			return {msg = "You cast %s!  [color=gray]%s shrugs it off.[/color]" % [
					data["name"], enemy.display_name()], cost = PressTurn.COST_FULL}
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
		var amount: int = player.heal_amount_for(spell_id)
		if Spell.is_multi(spell_id):
			var total: int = 0
			for m: CharacterSheet in _living_party():
				var was: int = m.hp
				m.heal(amount)
				total += m.hp - was
			return {msg = "[color=lime]You cast %s! The party recovers %d HP.[/color]" % [
					data["name"], total], cost = PressTurn.COST_FULL}
		var who: CharacterSheet = _ally_target if _ally_target != null \
				and _ally_target.is_alive() else player
		var before: int = who.hp
		who.heal(amount)
		return {msg = "[color=lime]You cast %s! %s recovers %d HP.[/color]" % [
				data["name"], _member_name(who), who.hp - before], cost = PressTurn.COST_FULL}

	if Spell.is_multi(spell_id):
		return _cast_spread(data)

	var element: String = data.get("element", "")
	var phys: bool = element == Affinity.PHYS
	var power: float = _skill_power(phys)
	# A physical skill is a swing: it misses like one and wastes what one does.
	if phys and not CombatMath.lands(player, enemy):
		return {msg = "[color=#9aa0aa]You use %s — %s dodges![/color]" % [
				data["name"], enemy.display_name()], cost = PressTurn.COST_MISS}
	if not phys and not CombatMath.spell_lands(player, enemy):
		return {msg = "[color=#9aa0aa]You cast %s — %s slips it![/color]" % [
				data["name"], enemy.display_name()], cost = PressTurn.COST_FULL}
	var base: int = int(power * float(data.get("power", Spell.POWER_I))) \
			- _guard_vs(enemy, element)
	if not phys and "scholar" in player.passive_skills:
		base = int(base * 1.25)
	var crit: bool = CombatMath.roll_crit(player)
	var res: Dictionary = CombatMath.resolve(base, element, enemy, crit, enemy.defending,
			bool(data.get("pierce", false)))
	return _land_hit(res, element, "%s %s!" % ["You use" if phys else "You cast",
			data["name"]], phys, float(data.get("power", Spell.POWER_I)))


# What a damage spell or skill hits with: MAG for magic, the blade arm for a
# physical skill.
func _skill_power(phys: bool) -> float:
	if phys:
		return float(player.effective_str()) * player.stage_mult(CharacterSheet.STAT_ATK)
	return float(player.effective_mag()) * player.stage_mult(CharacterSheet.STAT_MAG)


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
# worst thing that happened decides, and a loss always outranks a gain, each
# priced as it would be on one target:
#   repel / drain              the phase ends
#   null, or a swing missed    two icons ("miss": a physical cut dodged)
#   a spell slipped            one icon, and no weakness bonus ("slip")
#   a weakness hit             half an icon, when nothing above happened
# One demon that nulls or dodges it is enough, whatever it hit on the way,
# which is what makes an ALL spell a gamble against a mixed line rather than a
# strict upgrade. The same rule holds for the demons' wide casts.
static func _spread_cost(outcomes: Array[String]) -> String:
	if "repel" in outcomes or "drain" in outcomes:
		return PressTurn.COST_LOST
	if "null" in outcomes or "miss" in outcomes:
		return PressTurn.COST_MISS
	if "slip" in outcomes:
		return PressTurn.COST_FULL
	if "weak" in outcomes:
		return PressTurn.COST_HALF
	return PressTurn.COST_FULL


func _cast_spread(data: Dictionary) -> Dictionary:
	var element: String = data.get("element", "") as String
	var targets: Array[Enemy] = _spread_targets(data.get("shape", Spell.SHAPE_ALL) as String)
	var phys: bool = element == Affinity.PHYS
	# Every target takes the whole cast, magic and physical alike. A wide spell
	# used to thin out across the line; it no longer needs to, because one
	# demon that nulls, dodges or turns it back now prices the whole cast (see
	# _spread_cost), and that risk is what a wide spell pays for its reach.
	var power: float = _skill_power(phys)

	var lines: Array[String] = ["%s %s!" % ["You use" if phys else "You cast", data["name"]]]
	var outcomes: Array[String] = []
	var reflected: int = 0

	var rung: float = float(data.get("power", Spell.POWER_I))
	for foe: Enemy in targets:
		if not (CombatMath.lands(player, foe) if phys else CombatMath.spell_lands(player, foe)):
			outcomes.append("miss" if phys else "slip")
			lines.append("[color=#9aa0aa]%s %s it.[/color]" % [foe.display_name(),
					"dodges" if phys else "slips"])
			continue
		var base: int = int(power * rung) - _guard_vs(foe, element)
		if not phys and "scholar" in player.passive_skills:
			base = int(base * 1.25)
		var crit: bool = CombatMath.roll_crit(player)
		var res: Dictionary = CombatMath.resolve(base, element, foe, crit, foe.defending)
		_reveal(foe, element)
		var outcome: String = res["outcome"] as String
		outcomes.append(outcome)
		var dmg: int = int(res["dmg"])

		# Every demon it reaches gets its own burst. That is what makes a wide
		# cast look wide — the count per portrait is the rung, not the reach.
		var spread_pr: TextureRect = _foe_portrait(foe)
		if spread_pr != null:
			SpellFX.cast(spread_pr, element, rung)
			if outcome != "null" and outcome != "drain":
				_shake_portrait(spread_pr)

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
	# A dodged cut costs two icons like a missed swing (see _spread_cost).
	return {msg = " ".join(lines), cost = _spread_cost(outcomes)}


# Buffs stack across the party, debuffs across the enemy line. Reporting how
# many actually moved is what tells the player they have hit the cap.
# `lead` names who cast it — "You cast Whet" for the hero, "Hellbat calls
# up Whet" for a demon of his.
func _apply_stage_spell(data: Dictionary, lead: String = "") -> Dictionary:
	if lead == "":
		lead = "You cast %s" % data["name"]
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
		return {msg = "[color=gray]%s — %s is already at the limit.[/color]" % [
				lead, who], cost = PressTurn.COST_FULL}
	var tint: String = "aqua" if delta > 0 else "orange"
	return {msg = "[color=%s]%s!  %s %s on %d of %d.[/color]" % [
			tint, lead, _stat_name(stat),
			"rises" if delta > 0 else "falls", moved, total],
			cost = PressTurn.COST_FULL}


# ── Dispels ───────────────────────────────────────────────────────────────────
#
# Dekaja and dekunda by another name. Both read from where the caster stands:
# "foes" is the other side and "party" is the caster's own, so one function
# serves the hero and the demon that casts it back at him. All or nothing
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


# In the stat's own colour, the one its arrows are drawn in.
static func _stat_name(stat: String) -> String:
	var word: String = stat
	match stat:
		CharacterSheet.STAT_ATK: word = "Attack"
		CharacterSheet.STAT_MAG: word = "Magic"
		CharacterSheet.STAT_DEF: word = "Defence"
		CharacterSheet.STAT_AGL: word = "Agility"
	if not StageArrows.COLORS.has(stat):
		return word
	return "[color=#%s]%s[/color]" % [StageArrows.color_of(stat).to_html(false), word]


# Defence as it counts right now: the stat, the guard stance, and the stage.
# What stands between a spell and its target: half DEF and half MAG, together
# the same size as the DEF a swing runs into when the two are level, so a
# caster turns magic better than a brute and armour still counts for something.
func _guarded_mdef(target: CharacterSheet) -> int:
	var mag: int = player.effective_mag() if target == player else target.mag
	var base: float = float(_defense_of(target)) * target.stage_mult(CharacterSheet.STAT_DEF) \
			+ float(mag) * target.stage_mult(CharacterSheet.STAT_MAG)
	if target.defending:
		base *= 2.0
	return int(base / 4.0)


# A swing meets DEF; anything elemental meets DEF and MAG together.
func _guard_vs(target: CharacterSheet, element: String) -> int:
	if element == Affinity.PHYS or element == "":
		return _guarded_def(target)
	return _guarded_mdef(target)


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
			float(data.get("boost", Spell.BOOST_I)))
	_reveal(enemy, element)
	var name: String = data["name"] as String
	var who: String  = enemy.display_name()

	# Fires on the cast, not on the result: the line reaches the demon whether
	# or not it takes, and a failed banish with no effect at all read as a
	# button that had not registered.
	var banish_pr: TextureRect = _foe_portrait(enemy)
	if banish_pr != null:
		SpellFX.cast(banish_pr, element, Spell.rung_of(data))

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
	var boost: float = float(data.get("boost", Spell.BOOST_I))
	var power: int = maxi(1, int(float(player.effective_mag())
			* player.stage_mult(CharacterSheet.STAT_MAG)))
	var targets: Array[Enemy] = _spread_targets(
			data.get("shape", Spell.SHAPE_ALL) as String)

	var lines: Array[String] = ["[color=#c9a6ff]You cast %s![/color]" % data["name"]]
	var outcomes: Array[String] = []
	var reflected: int = 0
	var took_weak: bool = false

	var wide_rung: float = Spell.rung_of(data)
	for foe: Enemy in targets:
		var res: Dictionary = CombatMath.resolve_banish(
				foe, element, power, false, player, boost)
		_reveal(foe, element)
		var outcome: String = res["outcome"] as String
		var wide_pr: TextureRect = _foe_portrait(foe)
		if wide_pr != null:
			SpellFX.cast(wide_pr, element, wide_rung)
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
	# A warden or a boss gives nothing up. The turn is still spent, so reading
	# the wrong thing is a real mistake rather than a free check.
	if enemy.unreadable:
		return {msg = "[color=#9aa0aa]%s gives you nothing.[/color]"
				% enemy.display_name(), cost = PressTurn.COST_FULL}
	var already: bool = player.has_analyzed(enemy.enemy_name)
	player.record_analysis(enemy.lore_name() if enemy.abyss_element != "" else enemy.enemy_name)
	var chart: String = _affinity_line(enemy)
	var lead: String = "You read %s again." if already else "You read %s."
	# A scan reads temperament as well as chart. Without this the match bonus in
	# a negotiation was a blind guess every time — the difference between eighty
	# per cent and nothing, decided by a coin the player could not see.
	var mood: String = ""
	if enemy.negotiable and enemy.talk_personality != "":
		mood = "  [color=#a0e0b0]%s \u2014 %d%% if you read it right.[/color]" % [
				enemy.talk_personality.capitalize(), Negotiation.odds_percent(enemy)]
	return {msg = "[color=#9ad0ff]%s  %s[/color]%s" % [
			lead % enemy.display_name(), chart, mood],
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
	var atk: float = float(player.effective_str()) * CombatMath.PHYS_POWER \
			if _actor_is_player() else float(actor.str)
	atk *= actor.stage_mult(CharacterSheet.STAT_ATK)
	if _actor_is_player() and "last_stand" in player.passive_skills \
			and player.hp * 4 < player.max_hp:
		atk *= 2.0
	# A bound demon swings with its claws. Only the hero carries a blade,
	# so only his swing can be something other than phys.
	var element: String = player.attack_element() if _actor_is_player() \
			else Affinity.PHYS
	if Affinity.is_banishing(element):
		return _resolve_banishing_swing(element, int(atk))
	var crit: bool = CombatMath.roll_crit(_actor())
	var res: Dictionary = CombatMath.resolve(int(atk) - _guarded_def(enemy),
			element, enemy, crit, enemy.defending)
	return _land_hit(res, element, "%s strikes!" % _actor_name(), true)


# A blade on one of the two banishing lines expels instead of wounding, at the
# same odds a cast of that element would get — the difference being that a swing
# has to land first. A banishing cast has no hit roll of its own: the banish
# odds already are one.
func _resolve_banishing_swing(element: String, power: int) -> Dictionary:
	var res: Dictionary = CombatMath.resolve_banish(
			enemy, element, power, false, player)
	_reveal(enemy, element)
	var prefix: String = "%s strikes!" % _actor_name()
	var who: String = enemy.display_name()

	match res["outcome"]:
		"banished":
			enemy.take_damage(enemy.max_hp * 2)
			return {msg = "%s  [color=#c9a6ff]%s is taken, whole.[/color]" % [prefix, who],
					cost = PressTurn.COST_HALF if
						enemy.affinity_of(element) == Affinity.WEAK else PressTurn.COST_FULL}
		"failed":
			return {msg = "%s  [color=gray]%s holds.[/color]" % [prefix, who],
					cost = PressTurn.COST_FULL}
		"null":
			return {msg = "%s  [color=#999999]%s does not feel it at all.[/color]" % [
					prefix, who], cost = PressTurn.COST_MISS}
		"repel":
			var back: int = int(res["dmg"])
			_actor().take_damage(back)
			var pr: TextureRect = _member_portrait(_actor())
			if pr != null:
				_shake_portrait(pr)
			return {msg = "%s  [color=#d070ff]Turned back — %s takes %d![/color]" % [
					prefix, _actor_name(), back], cost = PressTurn.COST_LOST}
		"drain":
			enemy.heal(int(res["dmg"]))
			return {msg = "%s  [color=lime]%s drinks it and recovers %d HP![/color]" % [
					prefix, who, int(res["dmg"])], cost = PressTurn.COST_LOST}
	return {msg = "%s  [color=gray]Nothing comes of it.[/color]" % prefix,
			cost = PressTurn.COST_FULL}


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
	var epr: TextureRect = _foe_portrait(actor)
	if epr != null:
		_play_anim(epr, "attack")
	if actor.has_status(Status.PARALYZED) and randf() < PARALYSIS_SKIP:
		return {msg = "[color=yellow]%s is paralyzed and cannot act![/color]" % actor.display_name(),
				cost = PressTurn.COST_FULL}

	# The same rule the party's own menus keep: Silence takes every cast away
	# (elements, buffs, ailments and bites) and leaves the swing.
	var silenced: bool = actor.has_status(Status.SILENCE)

	# The ailment goes out early or not at all: it is worth most on a full party
	# and worthless once everyone standing already has it, which is also what
	# keeps it to a cast or two a fight rather than a loop.
	if not silenced and randi() % 10 < AIL_CAST_ODDS and _ail_cast_ready(actor):
		return _enemy_cast_ailment(actor)

	# Support next: a demon that can stack a buff will, while it still has
	# room and the MP to pay for it — but never at the price of its element.
	# Both come out of the one pool, and Mire costs ten against a Cave Bat's
	# twenty-four, so a demon carrying both used to spend everything on buffs
	# and never once cast the thing it is named for.
	if not silenced and actor.support_skill != "" and randi() % 10 < 3 \
			and _can_spare_support(actor):
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

	var bit: Dictionary = {} if silenced else _enemy_leech(actor)
	if not bit.is_empty():
		return bit

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
	# five. A demon it takes from the hero does not come back, so those
	# stay something that happens rather than the opening move of every fight.
	var paid: bool = false
	var pool: Array[String] = []
	if not silenced:
		pool = actor.affordable_elements(randi() % 10 < 2)
	if silenced:
		dry = "[color=gray]%s is silenced.[/color]\n" % actor.display_name()
	elif not pool.is_empty():
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
	return _enemy_strike(actor, target, element, base, dry)


# One blow or one single-target cast from the other side, from the hit roll to
# the log line. `base` is the attack's raw power before the target's guard.
func _enemy_strike(actor: Enemy, target: CharacterSheet, element: String,
		base: float, dry: String) -> Dictionary:
	# A swing misses on agility; a spell misses half as often. A miss does not
	# spend the target's brace — it never had to absorb anything.
	if element == Affinity.PHYS and not CombatMath.lands(actor, target):
		return {msg = dry + "[color=#9aa0aa]%s lunges at %s and misses![/color]" % [
				actor.display_name(), _member_name(target)], cost = PressTurn.COST_MISS}
	# A spell misses half as often as a swing, and costs its one icon.
	if element != Affinity.PHYS and not CombatMath.spell_lands(actor, target):
		return {msg = dry + "[color=#9aa0aa]%s uses %s — %s slips it![/color]" % [
				actor.display_name(), Affinity.element_name(element), _member_name(target)],
				cost = PressTurn.COST_FULL}

	if element == Affinity.PHYS:
		base *= actor.stage_mult(CharacterSheet.STAT_ATK)
	var guarding: bool = target.defending
	var eff_def: int = _guard_vs(target, element)

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
		_shake_portrait(hit_pr, guarding)
		if element == Affinity.PHYS:
			SlashFX.strike(hit_pr)
		else:
			SpellFX.cast(hit_pr, element)
	var msg: String = dry + "[color=red]%s %s %s for %d damage.[/color]%s" % [
			ename, verb, tname, dmg, CombatMath.outcome_tag(outcome, crit, muted)]
	if element != Affinity.PHYS:
		msg += _warden_drain(actor, dmg)
	if target == player:
		msg += _check_counter()
	return {msg = msg, cost = CombatMath.cost_for(outcome, crit, muted)}


# ── The Necromancer ───────────────────────────────────────────────────────────
#
# Its rules, in Enemy's notes on it: a new form each phase, one skeleton a
# phase, a dispel when there is something to clear, and otherwise the form's
# element at one target.
const NECRO_DISPEL_ODDS: float = 0.5

# The foe portraits' own zoom, so the circle lands under the minion's feet.
const MINION_FX_ZOOM: float = 3.0

# What it has done this phase: one summon and at most one dispel per phase.
var _necro_turn: Dictionary = {summoned = false, dispelled = false}


func _necro_begin_phase(necro: Enemy) -> void:
	necro.take_form(necro.next_form())
	necro.mp = necro.max_mp
	_necro_turn = {summoned = false, dispelled = false}
	for r: Dictionary in _foe_rows:
		if r["foe"] == necro:
			(r["chart"] as AffinityChart).queue_redraw()


func _necro_act(actor: Enemy) -> Dictionary:
	var epr: TextureRect = _foe_portrait(actor)
	if actor.has_status(Status.PARALYZED) and randf() < PARALYSIS_SKIP:
		return {msg = "[color=yellow]%s is paralyzed and cannot act![/color]" % actor.display_name(),
				cost = PressTurn.COST_FULL}
	# Silenced, it can neither raise the dead nor cast: it swings the scythe.
	if actor.has_status(Status.SILENCE):
		if epr != null:
			_play_anim(epr, "attack01")
		return _enemy_strike(actor, _pick_target(Affinity.PHYS), Affinity.PHYS,
				float(actor.str), "[color=gray]%s is silenced.[/color]\n" % actor.display_name())

	if not _necro_turn["summoned"]:
		_necro_turn["summoned"] = true
		if _necro_minions().size() < Enemy.NECRO_MINIONS_MAX:
			if epr != null:
				_play_anim(epr, "summon")
			return _summon_minion(actor)

	# Everything past here is a spell: the staff, not the scythe.
	if epr != null:
		_play_anim(epr, "attack02")

	if not _necro_turn["dispelled"]:
		var steady: Dictionary = Spell.get_data("steady")
		var purge: Dictionary = Spell.get_data("purge")
		var pick: Dictionary = {}
		if _dispel_would_bite(steady, false) and randf() < NECRO_DISPEL_ODDS:
			pick = steady
		elif _dispel_would_bite(purge, false) and randf() < NECRO_DISPEL_ODDS:
			pick = purge
		if not pick.is_empty():
			_necro_turn["dispelled"] = true
			var out: Dictionary = _cast_dispel(pick, false)
			out["msg"] = "[color=#c9a6ff]%s casts[/color] %s" % [actor.display_name(), out["msg"]]
			return out

	var element: String = actor.form
	var base: float = float(actor.mag) * actor.stage_mult(CharacterSheet.STAT_MAG) * 2.0
	return _enemy_strike(actor, _pick_target(element), element, base, "")


func _necro_minions() -> Array[Enemy]:
	var out: Array[Enemy] = []
	for f: Enemy in _living_foes():
		if f.summoned:
			out.append(f)
	return out


# Raises a skeleton onto the field. The fallen ones' cards are cleared first,
# so the column only ever holds the master and what is standing beside it.
func _summon_minion(master: Enemy) -> Dictionary:
	for r: Dictionary in _foe_rows.duplicate():
		var f: Enemy = r["foe"] as Enemy
		if f.summoned and not f.is_alive():
			(r["card"] as Control).queue_free()
			_foe_rows.erase(r)
			foes.erase(f)
	var m: Enemy = Enemy.make_minion(master)
	# Owned by the scene, so it is freed with the fight; the foes Main brought
	# in are Main's to free.
	add_child(m)
	m.reset_stages()
	foes.append(m)
	_assign_battle_tags()
	_enemy_side.add_child(_build_foe_card(m))
	# It climbs out of a circle drawn at its feet.
	var mpr: TextureRect = _foe_portrait(m)
	if mpr != null:
		_play_anim(mpr, "summon")
		if ResourceLoader.exists(Enemy.NECRO_SUMMON_FX):
			mpr.add_child(AnimatedPortrait.one_shot(Enemy.NECRO_SUMMON_FX, MINION_FX_ZOOM))
	for r: Dictionary in _foe_rows:
		(r["name_lbl"] as Label).text = (r["foe"] as Enemy).display_name()
	_fit_columns.call_deferred()
	return {msg = "[color=#c9a6ff]%s raises a %s (LV %d) from the bones![/color]" % [
			master.display_name(), m.display_name(), m.lv], cost = PressTurn.COST_FULL}


# With the Necromancer (or the Death Knight) down, whatever it raised falls
# with it.
func _crumble_orphans() -> void:
	var master_up: bool = false
	var had_master: bool = false
	for f: Enemy in foes:
		if f.is_necromancer() or f.warden_trick() == "raise":
			had_master = true
			master_up = master_up or f.is_alive()
	if not had_master or master_up:
		return
	for m: Enemy in _necro_minions():
		m.hp = 0
		_log("[color=gray]%s crumbles to dust.[/color]" % m.display_name())


# ── Wardens ───────────────────────────────────────────────────────────────────
#
# Each warden's one trick (Enemy.WARDEN_TRICKS). The rage is checked at the
# top of the enemy phase; the rest are here.
const WARDEN_COUNTER_ODDS: float = 0.5

# The Death Knight raises at most one skeleton a phase.
var _warden_raised: bool = false


func _warden_act(actor: Enemy) -> Dictionary:
	if actor.warden_trick() == "raise" and not _warden_raised \
			and not actor.has_status(Status.SILENCE) \
			and not actor.has_status(Status.PARALYZED) and _necro_minions().is_empty():
		_warden_raised = true
		var epr: TextureRect = _foe_portrait(actor)
		if epr != null:
			_play_anim(epr, "attack")
		return _summon_minion(actor)
	return _enemy_act(actor)


# The Black Knight's answer to a blade that did not finish it.
func _warden_counter(target: Enemy, attacker: CharacterSheet) -> String:
	if target.warden_trick() != "counter" or attacker == null or not attacker.is_alive() \
			or randf() >= WARDEN_COUNTER_ODDS:
		return ""
	var base: float = float(target.str) * target.stage_mult(CharacterSheet.STAT_ATK)
	var res: Dictionary = CombatMath.resolve(int(base) - _guard_vs(attacker, Affinity.PHYS),
			Affinity.PHYS, attacker, false, attacker.defending)
	if res["outcome"] in ["null", "drain", "repel"]:
		return ""
	var dmg: int = int(res["dmg"])
	attacker.take_damage(dmg)
	var pr: TextureRect = _member_portrait(attacker)
	if pr != null:
		_shake_portrait(pr, attacker.defending)
	return "\n[color=#ff8a4a]%s counters! %s takes %d.[/color]" % [
			target.display_name(), _member_name(attacker), dmg]


# The Dark Knight drinks what its spells take.
func _warden_drain(actor: Enemy, dealt: int) -> String:
	if actor.warden_trick() != "drain" or dealt <= 0 or not actor.is_alive():
		return ""
	var back: int = maxi(1, dealt / 2)
	var before: int = actor.hp
	actor.heal(back)
	if actor.hp == before:
		return ""
	return " [color=#b070ff]%s drinks %d HP from it.[/color]" % [
			actor.display_name(), actor.hp - before]


# ── Wide casts from the other side ────────────────────────────────────────────
#
# The mirror of the hero's own 2-3 and all-reach spells, and priced the
# same way: what it gains in width it gives up on each target. Which of the
# hero's line a FEW cast catches is drawn fresh each time, so covering the
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
	var targets: Array[CharacterSheet] = _enemy_spread_targets(actor)
	var reach_word: String = "across" if actor.attack_reach == Spell.SHAPE_FEW else "over"

	var lines: Array[String] = [dry + "[color=#ff9a6a]%s calls up %s %s %d of you![/color]" % [
			actor.display_name(), Affinity.element_name(element),
			reach_word, targets.size()]]
	var outcomes: Array[String] = []
	var reflected: int = 0
	var dealt: int = 0

	for who: CharacterSheet in targets:
		if banishing:
			var br: Dictionary = CombatMath.resolve_banish(who, element,
					maxi(1, int(base)), who == player, actor)
			outcomes.append(_apply_enemy_banish_one(actor, who, element, br, lines))
			continue
		if element != Affinity.PHYS and not CombatMath.spell_lands(actor, who):
			outcomes.append("slip")
			lines.append("[color=#9aa0aa]%s slips it.[/color]" % _member_name(who))
			continue
		var res: Dictionary = CombatMath.resolve(
				int(base) - _guard_vs(who, element), element, who,
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
				dealt += dmg
				var pr: TextureRect = _member_portrait(who)
				if pr != null:
					_shake_portrait(pr, who.defending)
				lines.append("[color=red]%s takes %d.[/color]%s" % [
						_member_name(who), dmg,
						CombatMath.outcome_tag(outcome, false, bool(res.get("suppressed", false)))])

	if reflected > 0:
		actor.take_damage(reflected)
		lines.append("[color=#d070ff]%s takes %d from what came back.[/color]" % [
				actor.display_name(), reflected])
	if element != Affinity.PHYS:
		lines.append(_warden_drain(actor, dealt))

	# The demons' side pays the same press-turn arithmetic the hero does.
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


# A demon reaching for light or dark is reaching for one of yours. The hero
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
				_shake_portrait(pr, target.defending)
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

	# The hero takes it as a wound rather than an expulsion.
	var hurt: int = int(res["dmg"])
	target.take_damage(hurt)
	var hit_pr: TextureRect = _member_portrait(target)
	if hit_pr != null:
		_shake_portrait(hit_pr, target.defending)
		SpellFX.cast(hit_pr, element)
	var tag: String = "  [color=yellow]Weak![/color]" if res["outcome"] == "weak" else ""
	return {msg = dry + "[color=red]%s calls the %s — %s takes %d.[/color]%s" % [
			ename, word, tname, hurt, tag],
			cost = PressTurn.COST_HALF if res["outcome"] == "weak" else PressTurn.COST_FULL}


# ── Layout hooks ──────────────────────────────────────────────────────────────
#
# The few places where what happens next is the layout's to say. The phone's
# answers are the defaults here; the Steam layout overrides them.

# A list choice went a step deeper (a target, who to heal).
func _on_step_deeper() -> void:
	pass


# Where "back" goes from a step under a list: to that list on the phone.
func _back_to(list: Callable) -> Callable:
	return list


# The Talk command on the action bar: choose who, then the talk.
func _on_talk_chosen() -> void:
	_with_target(func() -> void:
		if not enemy.negotiable:
			_log("[color=gray]%s won't listen.[/color]" % enemy.display_name())
			_prompt_actor()
			return
		# It looks past you at its own face standing in your line. There
		# is nothing left to negotiate about — you already have one, and
		# it knows what that means. It pays its way out instead.
		if enemy.enemy_name in player.recruited:
			_log("[color=#ffd479]%s looks past you — and sees its own face already standing with you.[/color]"
					% enemy.display_name())
			_prompt_tribute(false)
			return
		# A full roster used to skip the talk and hand over a payoff here,
		# which made every negotiable monster a one-action win with no
		# roll and no level check. It talks normally now; only Recruit
		# is closed, in the submenu.
		_show_talk_submenu())


# Where the talk is shown and how to back out of it.
func _open_talk_window() -> void:
	_set_back(_talk_back)
	_right_title.text = "Talk to %s" % enemy.display_name()


# A demon paying its way out: the same window the talk uses.
func _open_tribute_window(_from_beg: bool) -> void:
	pass
