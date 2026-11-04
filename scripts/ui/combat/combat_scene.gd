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
#
# This file is the screen and the flow of turns. Three parts live in files of
# their own, each holding a reference back to the scene (cs): CombatEnemyTurns
# (the monsters' side, bosses included), CombatActions (what a skill, a spell
# or a swing does) and CombatRoster (summoning, swapping, recalling, begging
# off). The two builds lay the screen out in CombatScenePortable and
# CombatSceneSteam.
class_name CombatScene extends Control

signal combat_ended(result: String)

var player: PlayerCharacter
# The floor the fight is on (Main sets it). The monsters' spells look the rung
# an orb on this floor would sell (CombatEnemyTurns._foe_rung).
var floor_num: int = 1

# Every demon in this encounter. `enemy` is whichever one the player currently
# has targeted — it is kept as a plain field because the CombatNeg* handlers
# all address the demon they are talking to through it.
var foes: Array[Enemy] = []
var enemy: Enemy
# The foe under the cursor in the target list, before it is chosen.
var _aimed: Enemy = null

# One row widget per foe: {foe, portrait, name_lbl, bar, hp_lbl, marker, chart}.
var _foe_rows: Array[Dictionary] = []
var _foe_turn_idx: int = 0
# The player phases opened so far in this fight.
var _phases: int = 0

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
# The fight is won and over (see _end_combat): the field is only scenery now.
var finished: bool = false

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


# The press-turn readout. Both sides are always visible so the player can see a
# phase about to snowball against them, not just their own banked halves.

# The strip is sized in whole lines rather than in pixels, because a height
# that lands mid-line shows two and a sliver of a third, which reads as two.
const LOG_LINES:  int = 3
const LOG_LINE_H: int = 24    # the pixel font at 16, ascent and descent
const LOG_PAD:    int = 8


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


# The rest of the battle, in files of their own that work on this scene:
var _enemy_turns: CombatEnemyTurns = CombatEnemyTurns.new(self)  # the monsters' side, bosses included
var _actions: CombatActions = CombatActions.new(self)            # what a skill, spell or swing does
var _roster: CombatRoster = CombatRoster.new(self)               # summoning, swapping, recalling, begging off


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


# A blow lands when the swing that throws it is over: the cut, the burst, the
# shake, the number and the bar all together, rather than the moment the arm
# goes up. Swings run quicker in a fight than the sheets' own 8 a second, and
# the longest are cut short of their end, so a turn never waits long.
const SWING_FPS: float = 12.0
const SWING_MAX: float = 0.9


func _windup(node: TextureRect, anim_name: String) -> void:
	if not node is AnimatedPortrait:
		return
	var fig: AnimatedPortrait = node as AnimatedPortrait
	var frames: int = fig.frames_of(anim_name)
	if frames <= 0:
		return
	fig.play_once(anim_name, SWING_FPS)
	await get_tree().create_timer(minf(float(frames) / SWING_FPS, SWING_MAX)).timeout


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
		elif item.has("stage_up"):
			usable = true
		elif _restorative(item):
			usable = _living_party().any(func(m: CharacterSheet) -> bool: return m.could_use(item))
		entries.append({title = item["name"] as String,
				detail = "x%d" % int(item.get("qty", 1)),
				disabled = not usable,
				press = _on_use_item.bind(item)})
	_roster._fill_submenu(entries)


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
		if item["id"] == item_id and item["type"] == "consumable" and item.has("revive") \
				and item.get("party", false):
			var fallen: Array[CharacterSheet] = _fallen_members()
			if fallen.is_empty():
				return {msg = "[color=gray]Nobody to revive.[/color]", cost = PressTurn.COST_FULL}
			player.remove_item(item, 1)
			var names: Array[String] = []
			for m: CharacterSheet in fallen:
				m.heal(maxi(1, m.max_hp * int(item["revive"]) / 100))
				names.append(_member_name(m))
			_refresh_hp()
			return {msg = "[color=lime]Used %s! %s %s back on their feet.[/color]" % [
					item["name"], ", ".join(names), "is" if names.size() == 1 else "are"],
					cost = PressTurn.COST_FULL}
		if item["id"] == item_id and item["type"] == "consumable" and item.has("stage_up"):
			player.remove_item(item, 1)
			var rose: Array[String] = []
			for st: Variant in item["stage_up"] as Dictionary:
				var moved: int = 0
				for m: CharacterSheet in _living_party():
					var by: int = int((item["stage_up"] as Dictionary)[st])
					if m.shift_stage(st as String, by) != 0:
						moved += 1
						_actions._stage_fx(m, st as String, by)
				if moved > 0:
					rose.append(CombatActions._stat_name(st as String))
			_refresh_hp()
			if rose.is_empty():
				return {msg = "[color=gray]Used %s — the party is already at the limit.[/color]" % item["name"],
						cost = PressTurn.COST_FULL}
			return {msg = "[color=aqua]Used %s!  The party's %s %s.[/color]" % [
					item["name"], ", ".join(rose), "rises" if rose.size() == 1 else "rise"],
					cost = PressTurn.COST_FULL}
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
		_roster._strike_off(demon)
	# A win leaves the field up under the results (Main frees it once they
	# are done) with the party hopping for joy; nothing on it answers any more.
	if result == "win":
		finished = true
		_set_buttons(false)
		_celebrate()
		combat_ended.emit(result)
		return
	combat_ended.emit(result)
	queue_free()


# How the party celebrates a win: everyone still standing hops, a beat apart,
# over and over until the field is taken down.
const HOP_HEIGHT: float = 14.0
const HOP_UP: float = 0.14
const HOP_REST: float = 0.30
const HOP_STAGGER: float = 0.09


func _celebrate() -> void:
	var n: int = 0
	for slot: Dictionary in _party_slots:
		var member: CharacterSheet = slot.get("member") as CharacterSheet
		var pic: TextureRect = slot.get("portrait") as TextureRect
		if member == null or not member.is_alive() or not is_instance_valid(pic):
			continue
		var base: float = pic.position.y
		var hop: Tween = pic.create_tween().set_loops()
		hop.tween_property(pic, "position:y", base - HOP_HEIGHT, HOP_UP) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		hop.tween_property(pic, "position:y", base, HOP_UP) \
				.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		hop.tween_interval(HOP_REST)
		# Each one starts a beat after the last, so they hop in a ripple.
		hop.pause()
		get_tree().create_timer(HOP_STAGGER * n).timeout.connect(func() -> void:
			if hop.is_valid():
				hop.play())
		n += 1


# ── Who is acting, and picking an ally ────────────────────────────────────────

# The one of the party a heal or a revive is about to land on, chosen in
# _pick_ally just before the action commits.
var _ally_target: CharacterSheet = null


# Everyone in the party who is down, the hero included. CombatRoster._fallen_party is the
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
	_roster._fill_submenu(entries)


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
		return player.hero_name
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
	if finished:
		return
	_step_back_immediate()
	for member: CharacterSheet in party:
		member.defending = false
		member.mirror = ""
	_phases += 1
	if _roster._try_begging():
		return
	_press.begin(_living_party().size())
	_actor_idx = 0 if party[0].is_alive() else _next_living(0)
	_prompt_actor()


# ── Whose turn it is, and the end of a round ──────────────────────────────────

func _prompt_actor() -> void:
	if finished:
		return
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
		player.restore_mp(2)
	_recover_mp_each_round()
	await get_tree().create_timer(0.7).timeout
	if is_instance_valid(self):
		_begin_player_phase()


# A Tide Stone worn: everyone still standing on the hero's side gets a tenth
# of their MP back as the round closes.
const TIDE_MP_SHARE: float = 0.10


func _recover_mp_each_round() -> void:
	if not player.recovers_mp_each_round():
		return
	var any: bool = false
	for member: CharacterSheet in _living_party():
		if member.mp < member.max_mp:
			member.restore_mp(maxi(1, roundi(float(member.max_mp) * TIDE_MP_SHARE)))
			any = true
	if any:
		_log("[color=#7fb8ff]The Tide Stone rises. MP flows back to the party.[/color]")
		_refresh_hp()


# ── Player-side actions ───────────────────────────────────────────────────────


# What one brace gives back, as a slice of the pool.
const DEFEND_HP_SHARE: float = 0.05
const DEFEND_MP_SHARE: float = 0.05


func _commit_action(action: String) -> void:
	_show_main_actions()
	_set_buttons(false)
	var actor_pr: TextureRect = _actor_portrait()
	if actor_pr != null:
		# A spell in the Knight's hands is his special attack, held on the
		# flash of the blade and coloured by what he is casting
		# (AnimatedPortrait.play_cast); it lands on the flash. A plain swing
		# is his first attack, and lands when the swing is over. Bracing has
		# nothing to wait for.
		if action == "Defend":
			_play_anim(actor_pr, "block")
		elif action.begins_with("Magic:") and _actor_is_player() and actor_pr is AnimatedPortrait:
			(actor_pr as AnimatedPortrait).play_cast(_cast_kind(action.substr(6)))
			await get_tree().create_timer(AnimatedPortrait.CAST_FLASH).timeout
		else:
			await _windup(actor_pr, "attack")
		if not is_instance_valid(self) or finished:
			return
	var res: Dictionary = _resolve_action(action)
	_log(res["msg"] as String)
	await _after_action(res["cost"] as String)


# The colour a spell flashes in: its element (grey for a physical skill),
# green for a heal, a buff or debuff in its stat's colour, and teal for
# anything else (an ailment, a dispel, Analyze).
static func _cast_kind(spell_id: String) -> String:
	var d: Dictionary = Spell.get_data(spell_id)
	var el: String = d.get("element", "") as String
	if el != "":
		return el
	match d.get("type", ""):
		"heal":
			return "heal"
		"buff":
			return d.get("stat", "other") as String
	return "other"


func _actor_portrait() -> TextureRect:
	return _portrait_of(_actor())


# Whoever this is, on whichever side. A bound demon is an Enemy too, so "is
# Enemy" never meant "is a foe": reading it that way sent every demon of yours
# to _foe_rows, found nothing, and its swing never played.
func _portrait_of(who: CharacterSheet) -> TextureRect:
	var pr: TextureRect = _member_portrait(who)
	if pr == null and who is Enemy:
		pr = _foe_portrait(who as Enemy)
	return pr


# A potion, an ether or a cure: anything that mends rather than hurts or
# raises a ceiling. Any of the party can take one, so it asks who.
static func _restorative(item: Dictionary) -> bool:
	return int(item.get("hp_restore", 0)) > 0 or int(item.get("mp_restore", 0)) > 0 \
			or item.get("cures_status", "") != ""


func _on_use_item(item: Dictionary) -> void:
	# A Phoenix Plume or a draught is for everyone: nobody to pick.
	if item.has("stage_up") or (item.has("revive") and item.get("party", false)):
		await _commit_item(item)
		return
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
	if actor.has_status(Status.PARALYZED) and randf() < CombatEnemyTurns.PARALYSIS_SKIP:
		return {msg = "[color=yellow]%s is paralyzed and cannot act![/color]" % _actor_name(),
				cost = PressTurn.COST_FULL}
	if action.begins_with("Magic:"):
		return _actions._cast_spell(action.substr(6))
	if action.begins_with("Skill:"):
		return _actions._resolve_skill(action.substr(6))
	match action:
		"Attack":
			return _actions._resolve_attack()
		"Analyze":
			return _actions._resolve_analyze()
		"Skill":
			return _actions._resolve_skill("")
		"Defend":
			# Half an icon, like a weakness read or a critical. Bracing is the
			# one defensive move in the game and a full icon made it a turn
			# thrown away — at half it buys the guard AND leaves most of the
			# action behind, so covering a demon that is about to be hit where
			# it is weak is a play rather than a forfeit.
			# It also catches the breath: a little HP and MP back each time,
			# so bracing again on the next turn is never wasted.
			actor.defending = true
			var hp_back: int = mini(actor.max_hp - actor.hp,
					maxi(1, roundi(float(actor.max_hp) * DEFEND_HP_SHARE)))
			var mp_back: int = mini(actor.max_mp - actor.mp,
					maxi(1, roundi(float(actor.max_mp) * DEFEND_MP_SHARE)))
			actor.heal(hp_back)
			actor.restore_mp(mp_back)
			_refresh_hp()
			var msg: String = "[color=cyan]%s braces. DEF doubled until struck.[/color]" % _actor_name()
			if hp_back > 0 or mp_back > 0:
				msg += "  [color=lime]+%d HP  +%d MP[/color]" % [hp_back, mp_back]
			return {msg = msg, cost = PressTurn.COST_HALF}
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
		if melee and element == Affinity.PHYS:
			SpellFX.skill(pr, rung)
		elif melee:
			SlashFX.strike(pr)
		else:
			SpellFX.cast(pr, element, rung)
	var extra: String = ""
	if _actor_is_player() and melee \
			and "vampiric" in player.passive_skills:
		var heal_amt: int = max(1, dmg / 5)
		player.heal(heal_amt)
		extra = "  [color=lime]Vampiric: +%d HP.[/color]" % heal_amt
	if _actor_is_player() and melee:
		extra += _weapon_on_hit(dmg)
	# What happened after the blow: the foe going down, or a warden answering it.
	var after: String = ""
	if not enemy.is_alive():
		after = "  [color=lime]%s goes down![/color]" % enemy.display_name()
	elif melee or element == Affinity.PHYS:
		after = _enemy_turns._warden_counter(enemy, actor)
	return {msg = "%s%s  [color=orange]%s takes %d damage.[/color]%s%s" % [
			prefix, CombatMath.outcome_tag(outcome, crit, muted), enemy.display_name(),
			dmg, extra, after],
			cost = CombatMath.cost_for(outcome, crit, muted)}


# What the hero's blade does besides cut: drink some of the blow back, and on
# its own odds lay an ailment or knock a stage off the foe it struck. Read off
# the weapon (Weapon.make's `extra`), so a plain blade adds nothing.
func _weapon_on_hit(dmg: int) -> String:
	var w: Dictionary = player.equipped_weapon
	var out: String = ""
	var drain: int = int(w.get("drain_pct", 0))
	if drain > 0 and dmg > 0:
		var back: int = maxi(1, dmg * drain / 100)
		player.heal(back)
		out += "  [color=lime]%s drinks %d HP.[/color]" % [w["name"], back]
	if not enemy.is_alive():
		return out
	var status: String = w.get("hit_status", "") as String
	if status != "" and randi() % 100 < int(w.get("hit_status_pct", 0)) \
			and not enemy.has_status(status) and not enemy.resists_status(status):
		enemy.apply_status(status)
		out += "  [color=violet]%s is now %s.[/color]" % [enemy.display_name(),
				Status.get_data(status).get("name", status)]
	var stat: String = w.get("hit_stage", "") as String
	if stat != "" and randi() % 100 < int(w.get("hit_stage_pct", 0)) \
			and enemy.shift_stage(stat, -1) != 0:
		_actions._stage_fx(enemy, stat, -1)
		out += "  [color=orange]%s's %s falls.[/color]" % [enemy.display_name(), CombatActions._stat_name(stat)]
	return out


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
			_aimed = null
			enemy = foe
			_refresh_hp()
			cb.call())
		# The caret over the field moves with the cursor, not only on a choice.
		btn.focus_entered.connect(_aim_at.bind(foe))
		btn.mouse_entered.connect(_aim_at.bind(foe))
		_submenu_add(btn)


# Points the target caret at `foe` while it is only being looked at in the
# target list; null hands it back to the real target.
func _aim_at(foe: Enemy) -> void:
	if _aimed == foe:
		return
	_aimed = foe
	_refresh_foe_rows()


# ── Refreshing the foe rows ───────────────────────────────────────────────────


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
		var targeted: bool = (foe == (_aimed if _aimed != null else enemy)) and alive
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
	_enemy_turns._warden_raised = false
	for f: Enemy in _living_foes():
		if f.is_dragon() and not f.attack_elements.is_empty() and f.mp < f.max_mp:
			var was_dry: bool = f.mp < f.skill_cost()
			f.mp = mini(f.max_mp, f.mp + f.skill_cost() * Enemy.DRAGON_BREATH_PER_PHASE)
			if was_dry:
				f.announced_dry = false
				_log("[color=#ff9a6a]%s draws a fresh breath.[/color]" % f.display_name())
		if f.is_necromancer():
			_enemy_turns._necro_begin_phase(f)
		elif f.warden_trick() == "enrage" and not f.enraged and f.hp * 2 < f.max_hp:
			f.enraged = true
			f.icons += 1
			f.shift_stage(CharacterSheet.STAT_ATK, 2)
			_actions._stage_fx(f, CharacterSheet.STAT_ATK, 2)
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
		var res: Dictionary
		if actor.is_necromancer():
			res = await _enemy_turns._necro_act(actor)
		elif actor.is_warden():
			res = await _enemy_turns._warden_act(actor)
		else:
			res = await _enemy_turns._enemy_act(actor)
		if not is_instance_valid(self):
			return
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


# ── Fleeing ───────────────────────────────────────────────────────────────────

# Anyone on the hero's side can call the retreat, a bound demon included, so
# demons left standing over a fallen hero can still drag him out. The runner's
# own agility is what counts.
func _do_flee() -> void:
	# Agility as it stands this fight, so a blind runner struggles to get away
	# and a blind foe struggles to stop it.
	var fastest: float = 0.0
	for f: Enemy in _living_foes():
		fastest = maxf(fastest, f.agl * f.agility_mult())
	var runner: CharacterSheet = _actor()
	var speed: float = float(player.effective_agl() if runner == player else runner.agl) \
			* runner.agility_mult()
	if speed >= fastest or randi() % 2 == 0:
		if runner == player:
			_log("You slip away into the dark.")
		elif player.is_alive():
			_log("%s finds a gap, and the party slips away into the dark." % _actor_name())
		else:
			_log("%s hauls you up and drags you off into the dark." % _actor_name())
		await get_tree().create_timer(0.9).timeout
		if is_instance_valid(self):
			_end_combat("flee")
		return
	_log("[color=yellow]Failed to escape![/color]")
	await _after_action(PressTurn.COST_FULL)


# ── Actions ───────────────────────────────────────────────────────────────────

func _on_action(action: String) -> void:
	match action:
		"Skills":
			_actions._show_skills_submenu()
			return
		"Item":
			_show_item_submenu()
			return
		"Talk":
			_on_talk_chosen()
			return
		"Summon":
			_roster._open_summon_menu()
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

# Talk, Item and Summon are the hero's alone; anyone can Flee. On a demon's
# turn the hero's buttons are hidden rather than greyed — there is not much room on a phone, and a row
# of dead buttons reads as a bug.
func _refresh_button_states() -> void:
	var is_p: bool = _actor_is_player()
	for key: String in ["Item", "Talk", "Summon"]:
		(_buttons[key] as Button).visible = is_p

	_buttons["Skills"].disabled = false
	# Bracing again is allowed: the guard holds, and it still catches a little
	# HP and MP back.
	_buttons["Defend"].disabled = false
	_buttons["Item"].disabled   = not is_p
	_buttons["Talk"].disabled   = not is_p or _living_foes().is_empty()
	# Live whenever there is anything to move: a body to raise, a demon waiting
	# off the field, or one standing that would rather not be.
	_buttons["Summon"].disabled = not is_p or (_roster._fallen_party().is_empty() \
			and _roster._available_summons().is_empty() and _roster._standing_party().is_empty())
	_buttons["Flee"].disabled   = false


func _member_portrait(member: CharacterSheet) -> TextureRect:
	for slot: Dictionary in _party_slots:
		if slot["member"] == member:
			return slot["portrait"] as TextureRect
	return null


# ── Refreshing after every action ─────────────────────────────────────────────

func _refresh_hp() -> void:
	# Run here because every action on either side ends in a refresh, so the
	# blow that drops the Necromancer takes its minions with it at once.
	_enemy_turns._crumble_orphans()
	_refresh_party_slots()
	_refresh_foe_rows()
	_refresh_icons()


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

# The same button as an entry for CombatRoster._fill_submenu, so a long list scrolls.
# `icon` is an element, drawn as its picture in front of the detail line in
# place of its name, and the line reads "[fire] x 2-3 (14 MP)": how many it
# reaches, then what it costs.
func _skill_entry(action: String, label: String, tag: String,
		cost: String, disabled: bool, icon: String = "",
		tint: Color = Color.TRANSPARENT) -> Dictionary:
	var paid: String = "(%s)" % cost if cost != "" and cost != "\u2014" else ""
	var detail: String = ("%s %s" % [tag, paid]).strip_edges()
	return {title = label, detail = detail, disabled = disabled, icon = icon, tint = tint,
			press = func() -> void: await _actions._on_skill_chosen(action)}


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
# The MP bars' own blue (the party windows draw them in it).
const FLOAT_MP:    Color = Color(0.32, 0.46, 0.95)
const FLOAT_MP_DROP: float = 34.0

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
	var mp_back: Callable = _on_mp_gained.bind(who)
	if not who.mp_gained.is_connected(mp_back):
		who.mp_gained.connect(mp_back)
	if who is PlayerCharacter and not (who as PlayerCharacter).poppet_broke.is_connected(_on_poppet_broke):
		(who as PlayerCharacter).poppet_broke.connect(_on_poppet_broke)
	var missed: Callable = _show_float.bind(who, "MISS", FLOAT_MISS)
	if not who.evaded.is_connected(missed):
		who.evaded.connect(missed)
		who.evaded.connect(func() -> void: Sfx.play("miss"))


# The blow that felled the hero broke a Straw Poppet instead; they are already
# back up (PlayerCharacter.take_damage), so this only has to say so.
func _on_poppet_broke() -> void:
	_log("[color=#e8c060]A Straw Poppet breaks in %s's place! %s is back on their feet.[/color]" % [
			_member_name(player), _member_name(player)])


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


func _on_mp_gained(amount: int, who: CharacterSheet) -> void:
	_show_float(who, "+%d" % amount, FLOAT_MP, true)


# `mp`: an MP number, which has a place of its own just under the HP one, so a
# Defend that gives back both shows both.
func _show_float(who: CharacterSheet, text: String, color: Color, mp: bool = false) -> void:
	if not is_inside_tree():
		return
	var portrait: TextureRect = _portrait_of(who)
	# Not "visible in tree": the blow that kills is the one most worth seeing,
	# and a card can start hiding on the same frame.
	if portrait == null:
		return
	var key: Variant = [who, "mp"] if mp else who
	var old: Variant = _float_of.get(key)
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
			+ Vector2(0.0, rect.size.y * 0.30 + (FLOAT_MP_DROP if mp else 0.0))
	lbl.position = start
	add_child(lbl)
	_float_of[key] = lbl

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


# Detaches immediately rather than waiting on queue_free, so the very next
# _submenu_add sees the slots as empty.
func _submenu_clear() -> void:
	# Leaving the target list, by a choice or by backing out.
	if _aimed != null:
		_aim_at(null)
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


# ── Layout ────────────────────────────────────────────────────────────────────
#
# Drawn by the build's layout, CombatScenePortable or CombatSceneSteam: the
# field, the panels, the menus. The rules above call these and leave the
# looks to them.

func _build_ui() -> void:
	pass


func _step_forward(_card: Control, _is_enemy: bool) -> void:
	pass


func _step_back_immediate() -> void:
	pass


func _set_buttons(_enabled: bool) -> void:
	pass


func _build_foe_card(_foe: Enemy) -> Control:
	return null


func _refresh_icons() -> void:
	pass


func _rebuild_party_slots() -> void:
	pass


func _fit_columns() -> void:
	pass


func _refresh_party_slots() -> void:
	pass


func _add_sub_slot() -> MarginContainer:
	return null


func _hide_actions() -> void:
	pass


func _show_main_actions() -> void:
	pass


func _big_button(_title: String, _subtitle: String, _disabled: bool,
		_icon: String = "", _tint: Color = Color.TRANSPARENT) -> Button:
	return null


# Whether the fight is waiting on the player to pick what to do: the
# commands are up and live. For a tool driving the fight (tools/playtester.gd).
func player_to_act() -> bool:
	return false


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
			_roster._prompt_tribute(false)
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
