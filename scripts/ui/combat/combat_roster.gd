# CombatRoster
# Who is on the field, split out of CombatScene: a demon begging to be let
# go, calling demons in from the bench or back from the dead, swapping and
# recalling them, and a demon leaving the fight. It works on the scene it
# belongs to (cs) and draws through it.
class_name CombatRoster extends RefCounted

var cs: CombatScene


func _init(host: CombatScene) -> void:
	cs = host


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


# Foes that can be talked to and are hurt enough to want to. hp_tint is what
# paints the bar, so "yellow or red" here means exactly what it looks like.
func _begging_candidates() -> Array[Enemy]:
	var out: Array[Enemy] = []
	for foe: Enemy in cs._living_foes():
		if foe.negotiable and CombatScene.hp_tint(foe.hp, foe.max_hp) != CombatScene.HP_OK:
			out.append(foe)
	return out


# Returns true when a plea took over the phase, so the caller stands down.
func _try_begging() -> bool:
	if _beg_used or cs._phases < BEG_FROM_PHASE:
		return false
	var pool: Array[Enemy] = _begging_candidates()
	if pool.is_empty():
		return false
	if randf() >= minf(BEG_CAP, BEG_CHANCE + BEG_PER_LUK * float(cs.player.battle_luck())):
		return false
	_beg_used = true

	cs.enemy = pool[randi() % pool.size()]
	cs._refresh_hp()

	# Already bound: it has nothing to offer that he has not got, and it knows
	# it. It pays its way out instead.
	if cs.enemy.enemy_name in cs.player.recruited:
		cs._log("[color=#ffd479]%s throws itself down — and sees its own face already standing with you.[/color]"
				% cs.enemy.display_name())
		_prompt_tribute()
		return true

	# No room for it: the plea turns into the same payoff a duplicate gives.
	if not cs.player.can_bind(cs.enemy.enemy_name):
		cs._log("[color=#ffd479]%s begs to come with you — but six already do. It pays its way out instead.[/color]"
				% cs.enemy.display_name())
		_prompt_tribute()
		return true

	cs._log("[color=#ffd479]%s stops fighting and begs to be taken with you.[/color]"
			% cs.enemy.display_name())
	_prompt_beg()
	return true


func _prompt_beg() -> void:
	cs._set_buttons(false)
	cs._hide_actions()
	cs._back_target = Callable()
	cs._right_back_btn.visible = false
	cs._right_title.text = "It is begging"
	cs._right_title.add_theme_color_override("font_color", Color(1.0, 0.83, 0.47))
	cs._submenu_clear()

	var take: Button = cs._big_button("Recruit it",
			"%s joins your roster. Costs nothing." % cs.enemy.enemy_name, false)
	take.pressed.connect(func() -> void:
		if take.disabled:
			return
		cs._lock_submenu()
		var who: String = cs.enemy.enemy_name
		_remember_recruit(who, cs.enemy.lv, cs.enemy.abyss_element)
		cs._log("[color=lime]%s is recruited. It walks in behind you.[/color]" % who)
		await _beg_resolved())
	cs._submenu_add(take)

	var refuse: Button = cs._big_button("Refuse it",
			"Leave it where it is. The fight goes on.", false)
	refuse.pressed.connect(func() -> void:
		if refuse.disabled:
			return
		cs._lock_submenu()
		cs._log("[color=gray]You say nothing. It picks itself back up.[/color]")
		cs._right_back_btn.visible = true
		cs._press.begin(cs._living_party().size())
		cs._actor_idx = 0 if cs.party[0].is_alive() else cs._next_living(0)
		cs._prompt_actor())
	cs._submenu_add(refuse)


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
	cs._set_buttons(false)
	cs._hide_actions()
	cs._open_tribute_window(from_beg)
	cs._back_target = Callable()
	cs._right_back_btn.visible = false
	cs._right_title.text = "It is paying you off"
	cs._right_title.add_theme_color_override("font_color", Color(1.0, 0.83, 0.47))
	cs._submenu_clear()

	# It empties its pockets: whatever it was carrying AND the coin. It used to
	# be one or the other, which made a demon you already keep worth less than
	# one you killed.
	var drop: Dictionary = cs.enemy.roll_drop()
	var coin: int = maxi(5, cs.enemy.gold_reward * 2)
	var what: String = "%d gold" % coin
	if not drop.is_empty():
		what = "%s and %d gold" % [drop["name"], coin]
	var who: String = cs.enemy.display_name()

	var take: Button = cs._big_button("Take it",
			"%s gives up %s and leaves." % [who, what], false)
	take.pressed.connect(func() -> void:
		if take.disabled:
			return
		cs._lock_submenu()
		cs.player.gold += coin
		if drop.is_empty():
			cs._log("[color=#ffd479]It empties its hands — %d gold — and goes.[/color]" % coin)
		else:
			cs.player.add_item(drop.duplicate(), 1)
			cs._log("[color=#ffd479]It presses %s and %d gold on you, and goes.[/color]" % [
					drop["name"], coin])
		if from_beg:
			await _beg_resolved()
		else:
			cs._right_back_btn.visible = true
			cs._show_main_actions()
			await _foe_departs("talk"))
	cs._submenu_add(take)


# Shared tail: the demon leaves the field, and the phase opens normally on
# whatever is left. No icon is spent either way.
func _beg_resolved() -> void:
	var leaving: Enemy = cs.enemy
	cs.foes.erase(leaving)
	cs._departed.append(leaving)
	cs._ensure_target()
	cs._refresh_hp()
	cs._right_back_btn.visible = true

	await cs.get_tree().create_timer(0.9).timeout
	if not is_instance_valid(cs):
		return
	# The dead keep their place in `foes` until the fight ends, so an empty list
	# is not the test: a field of bodies has nobody left to fight either.
	if cs._living_foes().is_empty():
		cs._end_combat("talk")
		return
	cs._press.begin(cs._living_party().size())
	cs._actor_idx = 0 if cs.party[0].is_alive() else cs._next_living(0)
	cs._prompt_actor()


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
	for i: int in range(1, cs.party.size()):
		var demon: Enemy = cs.party[i] as Enemy
		if not demon.is_alive():
			out.append(demon)
	return out


func _standing_party() -> Array[Enemy]:
	var out: Array[Enemy] = []
	for i: int in range(1, cs.party.size()):
		var demon: Enemy = cs.party[i] as Enemy
		if demon.is_alive():
			out.append(demon)
	return out


# Everything bound that is not currently standing. Benched demons come back as
# the instance that left; the rest are built fresh at the level they were bound.
func _available_summons() -> Array[String]:
	var standing: Array[String] = []
	for i: int in range(1, cs.party.size()):
		standing.append((cs.party[i] as Enemy).enemy_name)
	var out: Array[String] = []
	for name: String in cs.player.recruited:
		if name not in standing:
			out.append(name)
	return out


func _remember_recruit(demon_name: String, lv: int = 1, element: String = "") -> void:
	cs.player.remember_recruit(demon_name, lv, element)


func _open_summon_menu() -> void:
	_show_summon_submenu()


func _show_summon_submenu() -> void:
	cs._hide_actions()
	cs._set_back(cs._show_main_actions)
	cs._right_title.text = "Summon"
	cs._right_title.add_theme_color_override("font_color", Color(0.40, 1.0, 0.55))
	cs._submenu_clear()

	var entries: Array[Dictionary] = []

	# The fallen come first: one of them is on a clock that ends with the
	# battle, and everything under it will still be there afterwards.
	for demon: Enemy in _fallen_party():
		entries.append({title = demon.enemy_name, detail = "revive",
				press = _on_revive.bind(demon)})

	var room: bool = cs.party.size() < CombatScene.MAX_PARTY
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
		cs._submenu_add(cs._dim_label("Nothing left to call."))
		return
	_fill_submenu(entries)


# A whole list into the submenu. Past six it scrolls — see CombatScene._sub_scroll.
func _fill_submenu(entries: Array[Dictionary]) -> void:
	for e: Dictionary in entries:
		cs._submenu_add(_entry_button(e))


func _entry_button(e: Dictionary) -> Button:
	var btn: Button = cs._big_button(e["title"] as String, e["detail"] as String,
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
	cs._hide_actions()
	cs._set_back(cs._back_to(_show_summon_submenu))
	cs._right_title.text = "Who steps back?"
	cs._right_title.add_theme_color_override("font_color", Color(1.0, 0.80, 0.40))
	cs._submenu_clear()

	for i: int in range(1, cs.party.size()):
		var demon: Enemy = cs.party[i] as Enemy
		var note: String = "steps back" if demon.is_alive() else "struck off"
		var btn: Button = cs._big_button(demon.enemy_name, note, false)
		btn.pressed.connect(_on_swap.bind(demon, incoming))
		cs._submenu_add(btn)


func _on_swap(outgoing: Enemy, incoming: String) -> void:
	cs._show_main_actions()
	cs._set_buttons(false)

	var idx: int = cs.party.find(outgoing)
	if idx <= 0:
		return
	var was_alive: bool = outgoing.is_alive()
	if was_alive:
		bench.append(outgoing)
	else:
		_strike_off(outgoing)

	var demon: Enemy = _take_from_bench(incoming)
	if demon == null:
		demon = cs.player.bound_demon(incoming)
		cs.add_child(demon)
	cs.party[idx] = demon
	_ensure_actor_in_range()
	cs._rebuild_party_slots()
	if was_alive:
		cs._log("[color=#7fe0a0]%s steps back and %s takes the field.[/color]"
				% [outgoing.enemy_name, demon.enemy_name])
	else:
		cs._log("[color=#7fe0a0]%s takes the field.[/color]  [color=#d08080]%s is left where it fell.[/color]"
				% [demon.enemy_name, outgoing.enemy_name])
	await cs._after_action(PressTurn.COST_FULL)


# ── Recalling ─────────────────────────────────────────────────────────────────
#
# Taking a demon off the field with nothing replacing it. The slot closes, so
# the party is one icon lighter next phase — which is the whole price, and the
# reason this is worth doing anyway when the alternative is watching something
# on three HP take one more hit. It keeps everything it had; calling it back
# later returns the same demon, not a fresh one.
func _on_withdraw(demon: Enemy) -> void:
	cs._show_main_actions()
	cs._set_buttons(false)
	var idx: int = cs.party.find(demon)
	if idx <= 0 or not demon.is_alive():
		return
	cs.party.remove_at(idx)
	bench.append(demon)
	_ensure_actor_in_range()
	cs._rebuild_party_slots()
	cs._log("[color=#7fe0a0]%s is called back and stands down.[/color]" % demon.enemy_name)
	await cs._after_action(PressTurn.COST_FULL)


func _take_from_bench(demon_name: String) -> Enemy:
	for demon: Enemy in bench:
		if demon.enemy_name == demon_name:
			bench.erase(demon)
			return demon
	return null


func _strike_off(demon: Enemy) -> void:
	if demon.enemy_name not in cs.lost_demons:
		cs.lost_demons.append(demon.enemy_name)
	cs.player.recruited.erase(demon.enemy_name)
	cs.player.deactivate_demon(demon.enemy_name)


# Taking a demon off the field can leave the turn cursor pointing past the end
# of the party, so it is pulled back into range before anything reads it.
func _ensure_actor_in_range() -> void:
	cs._actor_idx = clampi(cs._actor_idx, 0, cs.party.size() - 1)


# Binding costs a full icon and the demon joins at the level it was bound.
# Its icon arrives with the next phase, not this one.
func _on_summon(summon_name: String) -> void:
	cs._show_main_actions()
	cs._set_buttons(false)
	var demon: Enemy = _take_from_bench(summon_name)
	if demon == null:
		demon = cs.player.bound_demon(summon_name)
		cs.add_child(demon)
	cs.party.append(demon)
	cs._rebuild_party_slots()
	cs._log("[color=#7fe0a0]%s answers the call.[/color]" % demon.enemy_name)
	await cs._after_action(PressTurn.COST_FULL)


# Costs a full icon, like a summon does, and nothing else. Whatever put the
# demon down came with it — a poisoned corpse pulled back up is still poisoned
# — so the slate is wiped along with the HP.
func _on_revive(demon: Enemy) -> void:
	if demon.is_alive():
		cs._show_main_actions()
		return
	cs._show_main_actions()
	cs._set_buttons(false)
	demon.active_statuses.clear()
	demon.defending = false
	demon.hp = maxi(1, roundi(float(demon.max_hp) * REVIVE_HP_SHARE))
	cs._rebuild_party_slots()
	cs._log("[color=#7fe0a0]%s is raised, and stands.[/color]" % demon.enemy_name)
	await cs._after_action(PressTurn.COST_FULL)


# ── A demon leaving the fight ─────────────────────────────────────────────────

# A successful negotiation removes one demon, not the encounter. The battle
# only ends here if it was the last one standing.
func _foe_departs(reason: String) -> void:
	Sfx.play("recruit")
	var leaving: Enemy = cs.enemy
	cs.foes.erase(leaving)
	cs._departed.append(leaving)
	cs._ensure_target()
	cs._refresh_hp()
	if cs._living_foes().is_empty():
		await cs.get_tree().create_timer(0.4).timeout
		if is_instance_valid(cs):
			cs._end_combat(reason)
		return
	cs._refresh_hp()
	await cs._after_action(PressTurn.COST_FULL)


