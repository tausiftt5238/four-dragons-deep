# CombatActions
# What a skill, a spell or a swing does once it is chosen, split out of
# CombatScene: the skills list, bites, casting, spells that reach more than
# one demon, dispels and banishing, and plain attacks. The monsters' side uses
# some of it too (a dispel or a bite is the same from either side). It works
# on the scene it belongs to (cs) and draws through it.
class_name CombatActions extends RefCounted

var cs: CombatScene


func _init(host: CombatScene) -> void:
	cs = host


# ── Skills ────────────────────────────────────────────────────────────────────

func _show_skills_submenu() -> void:
	cs._hide_actions()
	cs._set_back(cs._show_main_actions)
	cs._right_title.text = "%s's skills" % cs._actor_name()
	cs._right_title.add_theme_color_override("font_color", Color(0.80, 0.62, 1.0))
	cs._submenu_clear()

	var actor: CharacterSheet = cs._actor()

	# Paged like Summon: Attack plus a demon's full six is seven entries, and
	# a flat fill silently dropped the last one.
	var entries: Array[Dictionary] = []
	entries.append(cs._skill_entry("Attack", "Attack", CombatScene._reach_count("one"), "", false, Affinity.PHYS))

	if cs._actor_is_player():
		# Analyze is no longer bolted on here \u2014 it is an ordinary equipped spell
		# and comes through the loop below with everything else.
		if cs.player.equipped_spells.is_empty():
			cs._roster._fill_submenu(entries)
			cs._submenu_add(cs._dim_label("No spells equipped."))
			return
		var silenced: bool = cs.player.has_status(Status.SILENCE)
		for spell_id: String in cs.player.equipped_spells:
			var data: Dictionary = Spell.get_data(spell_id)
			if data.is_empty():
				continue
			var element: String = data.get("element", "")
			# An element is its icon; anything without one says what it is.
			# How far it reaches is the thing a player most needs to know
			# before spending 22 MP, so it rides next to the element.
			var tag: String = CombatScene._reach_count(Spell.reach_tag(spell_id)) if element != "" \
					else CombatScene._stage_tag(data) if CombatScene._stage_tint(data).a > 0.0 \
					else (data.get("type", "dmg") as String).capitalize()
			# A physical skill is paid in blood, not mana: silence does not
			# stop it, and it will not spend the last of the hero's HP.
			var blocked: bool
			var hp_price: int = Spell.hp_cost(spell_id, cs.player.max_hp)
			if hp_price > 0:
				blocked = cs.player.hp <= hp_price
			else:
				blocked = silenced or cs.player.mp < int(data.get("mp", 0))
			entries.append(cs._skill_entry("Magic:" + spell_id,
					data["name"] as String, tag, Spell.cost_text(spell_id), blocked, element,
					CombatScene._stage_tint(data)))
		cs._roster._fill_submenu(entries)
		return

	var demon: Enemy = actor as Enemy
	var known: Array = cs.player.skills_of(demon.enemy_name)
	var silenced_demon: bool = demon.has_status(Status.SILENCE)
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
			tag = CombatScene._stage_tag(d)
			tint = CombatScene._stage_tint(d)
		else:
			# Its rung is already in its name (Ember, Blaze, Inferno).
			icon = skill.get("element", "") as String
			tag = CombatScene._reach_count(Spell.reach_tag_for(
					Spell.reach_for(icon, demon.attack_reach)))
		entries.append(cs._skill_entry("Skill:%d" % i,
				PlayerCharacter.skill_name(skill), tag,
				_demon_cost_text(skill) if hp_price > 0 else "%d MP" % cost, blocked, icon,
				tint))
	cs._roster._fill_submenu(entries)


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
	var actor: Enemy = cs._actor() as Enemy
	var known: Array = cs.player.skills_of(actor.enemy_name)
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
		return _leech(actor, cs.enemy, skill.get("id", "") as String)

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
	if Spell.reach_for(element, actor.attack_reach) != Spell.SHAPE_ONE:
		return _demon_spread(actor, element, power * Spell.rung_power(rung),
				banishing, Spell.rung_boost(rung), named, Spell.rung_power(rung))

	if banishing:
		return _demon_banish_one(actor, cs.enemy, element, power,
				Spell.rung_boost(rung), Spell.rung_power(rung))

	# A physical line is a swing: it misses like one and wastes what one does.
	if phys and not CombatMath.lands(actor, cs.enemy):
		return {msg = "[color=#9aa0aa]%s uses %s — %s dodges![/color]" % [
				actor.display_name(), named, cs.enemy.display_name()],
				cost = PressTurn.COST_MISS}
	if not phys and not CombatMath.spell_lands(actor, cs.enemy):
		return {msg = "[color=#9aa0aa]%s calls up %s — %s slips it![/color]" % [
				actor.display_name(), named, cs.enemy.display_name()],
				cost = PressTurn.COST_FULL}
	var crit: bool = CombatMath.roll_crit(actor)
	var res: Dictionary = CombatMath.resolve(
			int(power * Spell.rung_power(rung)) - _guard_vs(cs.enemy, element),
			element, cs.enemy, crit, cs.enemy.defending)
	return cs._land_hit(res, element, "%s %s %s!" % [
			actor.display_name(), "uses" if phys else "calls up", named], phys,
			Spell.rung_power(rung))


# ── Leeches ───────────────────────────────────────────────────────────────────
#
# A bat or a blood thing biting, from either side of the field. The cost is
# already paid. A bite, not a spell: it rolls to hit like a swing and a miss
# wastes what a missed swing does. No element, so no chart to hit or bounce off.
func _leech(actor: Enemy, target: CharacterSheet, id: String) -> Dictionary:
	var data: Dictionary = Spell.get_data(id)
	var who: String = cs._member_name(target) if not target is Enemy \
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
		actor.restore_mp(took)
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
	var pr: TextureRect = cs._portrait_of(target)
	if pr == null:
		return
	cs._shake_portrait(pr, guarded)
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
		return _leech(actor, cs._enemy_turns._pick_target(""), "hp_leech")
	if "mp_leech" in actor.unique_skills \
			and actor.mp < maxi(actor.skill_cost(), hp_cost):
		var richest: CharacterSheet = null
		for m: CharacterSheet in cs._living_party():
			if m.mp > 0 and (richest == null or m.mp > richest.mp):
				richest = m
		if richest != null:
			return _leech(actor, richest, "mp_leech")
	return {}


# One demon of yours, one line, one foe. Light and dark expel rather than burn,
# the same as they do out of the hero's own hands.
func _demon_banish_one(actor: Enemy, foe: Enemy, element: String,
		power: float, boost: float = 0.0, rung: float = Spell.POWER_I) -> Dictionary:
	var res: Dictionary = CombatMath.resolve_banish(foe, element,
			maxi(1, int(power)), false, actor, boost)
	cs._reveal(foe, element)
	_spread_fx(foe, element, rung, "null")
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
# `rung` is only for the picture: each demon it reaches gets the burst the
# hero's own cast of that rung would give it. This drew nothing at all, so a
# bound demon's Forkfall or Sweep did its damage with no sign of where.
func _demon_spread(actor: Enemy, element: String, base: float,
		banishing: bool, boost: float = 0.0, named: String = "",
		rung: float = Spell.POWER_I) -> Dictionary:
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
			cs._reveal(foe, element)
			_spread_fx(foe, element, rung, "null")
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
		cs._reveal(foe, element)
		var outcome: String = res["outcome"] as String
		var dmg: int = int(res["dmg"])
		outcomes.append(outcome)
		_spread_fx(foe, element, rung, outcome)
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

	cs._ensure_target()
	var cost: String = _spread_cost(outcomes)
	# A slipped spell cancels the weakness bonus here too (see _spread_cost).
	if cost == PressTurn.COST_FULL and took_weak and "slip" not in outcomes:
		cost = PressTurn.COST_HALF
	return {msg = " ".join(lines), cost = cost}


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
			cs._pick_ally(false, "Heal who?", cs._back_to(_show_skills_submenu),
					func() -> void: await cs._commit_action(action))
			return
		if kind == "heal" or kind == "buff" or kind == "dispel" or Spell.is_multi(spell_id):
			await cs._commit_action(action)
			return
	# A bound demon's buffs and debuffs take a whole side, and its wide lines
	# draw their own targets, so only a single-target line needs picking.
	if action.begins_with("Skill:") and not cs._actor_is_player():
		var demon: Enemy = cs._actor() as Enemy
		var known: Array = cs.player.skills_of(demon.enemy_name)
		var idx: int = action.substr(6).to_int()
		if idx >= 0 and idx < known.size():
			var skill: Dictionary = known[idx] as Dictionary
			# A leech bites one, whatever reach its kind usually has.
			if skill.get("kind", "") == "support" \
					or (skill.get("kind", "") == "element"
						and Spell.reach_for(skill.get("element", "") as String,
							demon.attack_reach) != Spell.SHAPE_ONE):
				await cs._commit_action(action)
				return
	cs._with_target(func() -> void: await cs._commit_action(action))


func _cast_spell(spell_id: String) -> Dictionary:
	var data: Dictionary = Spell.DATA.get(spell_id, {name = "Spell", mp = 8})
	var hp_price: int = Spell.hp_cost(spell_id, cs.player.max_hp)
	if hp_price > 0:
		# Never the killing blow on himself: it needs HP left over after paying.
		if cs.player.hp <= hp_price:
			return {msg = "[color=gray]Not enough HP![/color]", cost = PressTurn.COST_FULL}
		cs.player.take_damage(hp_price)
	else:
		var mp_cost: int = data.get("mp", 8)
		if cs.player.mp < mp_cost:
			return {msg = "[color=gray]Not enough MP![/color]", cost = PressTurn.COST_FULL}
		cs.player.mp -= mp_cost

	var spell_type: String = data.get("type", "dmg")

	if spell_type == "analyze":
		return _resolve_analyze()

	if spell_type == "buff":
		return _apply_stage_spell(data)

	if spell_type == "dispel":
		return _cast_dispel(data, true)

	if spell_type == "ailment":
		var target_status: String = data.get("status", "")
		if target_status == "" or cs.enemy.has_status(target_status):
			return {msg = "[color=gray]Nothing happened.[/color]", cost = PressTurn.COST_FULL}
		if cs.enemy.resists_status(target_status):
			return {msg = "You cast %s!  [color=gray]%s shrugs it off.[/color]" % [
					data["name"], cs.enemy.display_name()], cost = PressTurn.COST_FULL}
		cs.enemy.apply_status(target_status)
		return {msg = "You cast %s!  [color=violet]%s is now %s.[/color]" % [
				data["name"], cs.enemy.display_name(),
				Status.get_data(target_status).get("name", target_status)],
				cost = PressTurn.COST_FULL}

	if spell_type == "banish":
		var bd: Dictionary = data.duplicate()
		bd["id"] = spell_id
		return _cast_banish(bd)

	if spell_type == "heal":
		var amount: int = cs.player.heal_amount_for(spell_id)
		if Spell.is_multi(spell_id):
			var total: int = 0
			for m: CharacterSheet in cs._living_party():
				var was: int = m.hp
				m.heal(amount)
				total += m.hp - was
				SpellFX.heal(cs._member_portrait(m))
			return {msg = "[color=lime]You cast %s! The party recovers %d HP.[/color]" % [
					data["name"], total], cost = PressTurn.COST_FULL}
		var who: CharacterSheet = cs._ally_target if cs._ally_target != null \
				and cs._ally_target.is_alive() else cs.player
		var before: int = who.hp
		who.heal(amount)
		SpellFX.heal(cs._member_portrait(who))
		return {msg = "[color=lime]You cast %s! %s recovers %d HP.[/color]" % [
				data["name"], cs._member_name(who), who.hp - before], cost = PressTurn.COST_FULL}

	if Spell.is_multi(spell_id):
		return _cast_spread(data)

	var element: String = data.get("element", "")
	var phys: bool = element == Affinity.PHYS
	var power: float = _skill_power(phys)
	# A physical skill is a swing: it misses like one and wastes what one does.
	if phys and not CombatMath.lands(cs.player, cs.enemy):
		return {msg = "[color=#9aa0aa]You use %s — %s dodges![/color]" % [
				data["name"], cs.enemy.display_name()], cost = PressTurn.COST_MISS}
	if not phys and not CombatMath.spell_lands(cs.player, cs.enemy):
		return {msg = "[color=#9aa0aa]You cast %s — %s slips it![/color]" % [
				data["name"], cs.enemy.display_name()], cost = PressTurn.COST_FULL}
	var base: int = int(power * float(data.get("power", Spell.POWER_I))) \
			- _guard_vs(cs.enemy, element)
	if not phys and "scholar" in cs.player.passive_skills:
		base = int(base * 1.25)
	var crit: bool = CombatMath.roll_crit(cs.player)
	var res: Dictionary = CombatMath.resolve(base, element, cs.enemy, crit, cs.enemy.defending,
			bool(data.get("pierce", false)))
	return cs._land_hit(res, element, "%s %s!" % ["You use" if phys else "You cast",
			data["name"]], phys, float(data.get("power", Spell.POWER_I)))


# What a damage spell or skill hits with: MAG for magic, the blade arm for a
# physical skill.
func _skill_power(phys: bool) -> float:
	if phys:
		return float(cs.player.effective_str()) * cs.player.stage_mult(CharacterSheet.STAT_ATK)
	return float(cs.player.effective_mag()) * cs.player.stage_mult(CharacterSheet.STAT_MAG)


# ── Spells that reach more than one demon ─────────────────────────────────────
#
# Which demons a wide cast touches: everything standing for an ALL spell, two
# or three at random for a FEW. Fewer demons than that on the field means it
# simply takes all of them — the spell is not wasted, it just has less to do.
func _spread_targets(shape: String) -> Array[Enemy]:
	var living: Array[Enemy] = cs._living_foes()
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


# Every demon a wide cast reaches gets its own burst. That is what makes a wide
# cast look wide — the count per portrait is the rung, not the reach. A
# physical one is the swing's picture (the slash at rung I, the spikes above
# it): SpellFX.cast has no rung-I drawing for phys, so Sweep and Rampage
# showed nothing.
func _spread_fx(foe: Enemy, element: String, rung: float, outcome: String) -> void:
	var pr: TextureRect = cs._foe_portrait(foe)
	if pr == null:
		return
	if element == Affinity.PHYS:
		SpellFX.skill(pr, rung)
	else:
		SpellFX.cast(pr, element, rung)
	if outcome != "null" and outcome != "drain":
		cs._shake_portrait(pr)


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
		if not (CombatMath.lands(cs.player, foe) if phys else CombatMath.spell_lands(cs.player, foe)):
			outcomes.append("miss" if phys else "slip")
			lines.append("[color=#9aa0aa]%s %s it.[/color]" % [foe.display_name(),
					"dodges" if phys else "slips"])
			continue
		var base: int = int(power * rung) - _guard_vs(foe, element)
		if not phys and "scholar" in cs.player.passive_skills:
			base = int(base * 1.25)
		var crit: bool = CombatMath.roll_crit(cs.player)
		var res: Dictionary = CombatMath.resolve(base, element, foe, crit, foe.defending)
		cs._reveal(foe, element)
		var outcome: String = res["outcome"] as String
		outcomes.append(outcome)
		var dmg: int = int(res["dmg"])

		_spread_fx(foe, element, rung, outcome)

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
		cs._actor().take_damage(reflected)
		lines.append("[color=red]%s takes %d from what came back.[/color]" % [
				cs._actor_name(), reflected])

	cs._ensure_target()
	# A dodged cut costs two icons like a missed swing (see _spread_cost).
	return {msg = " ".join(lines), cost = _spread_cost(outcomes)}


# Buffs stack across the party, debuffs across the enemy line. Reporting how
# many actually moved is what tells the player they have hit the cap.
# `lead` names who cast it — "You cast Whet" for the hero, "Hellbat calls
# up Whet" for a demon of his.
# Rings in the stat's colour over whoever's stat just moved (StageFX).
func _stage_fx(who: CharacterSheet, stat: String, delta: int) -> void:
	StageFX.play(cs._portrait_of(who), stat, delta)


func _apply_stage_spell(data: Dictionary, lead: String = "") -> Dictionary:
	if lead == "":
		lead = "You cast %s" % data["name"]
	var stat: String = data.get("stat", CharacterSheet.STAT_ATK) as String
	var delta: int   = int(data.get("delta", 1))
	var on_party: bool = (data.get("scope", "party") == "party")

	var moved: int = 0
	var total: int = 0
	if on_party:
		for member: CharacterSheet in cs._living_party():
			total += 1
			if member.shift_stage(stat, delta) != 0:
				moved += 1
				_stage_fx(member, stat, delta)
	else:
		for foe: Enemy in cs._living_foes():
			total += 1
			if foe.shift_stage(stat, delta) != 0:
				moved += 1
				_stage_fx(foe, stat, delta)

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
		targets = cs._living_party()
	else:
		for foe: Enemy in cs._living_foes():
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
		targets = cs._living_party()
	else:
		for foe: Enemy in cs._living_foes():
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
	var mag: int = cs.player.effective_mag() if target == cs.player else target.mag
	var base: float = float(cs._enemy_turns._defense_of(target)) * target.stage_mult(CharacterSheet.STAT_DEF) \
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
	var base: float = float(cs._enemy_turns._defense_of(target)) * target.stage_mult(CharacterSheet.STAT_DEF)
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
	var power: int = maxi(1, int(float(cs.player.effective_mag())
			* cs.player.stage_mult(CharacterSheet.STAT_MAG)))
	var res: Dictionary = CombatMath.resolve_banish(cs.enemy, element, power, false, cs.player,
			float(data.get("boost", Spell.BOOST_I)))
	cs._reveal(cs.enemy, element)
	var name: String = data["name"] as String
	var who: String  = cs.enemy.display_name()

	# Fires on the cast, not on the result: the line reaches the demon whether
	# or not it takes, and a failed banish with no effect at all read as a
	# button that had not registered.
	var banish_pr: TextureRect = cs._foe_portrait(cs.enemy)
	if banish_pr != null:
		SpellFX.cast(banish_pr, element, Spell.rung_of(data))

	match res["outcome"]:
		"banished":
			cs.enemy.take_damage(cs.enemy.max_hp * 2)
			return {msg = "[color=#c9a6ff]%s! %s is taken, whole.[/color]" % [name, who],
					cost = PressTurn.COST_HALF if
						cs.enemy.affinity_of(element) == Affinity.WEAK else PressTurn.COST_FULL}
		"failed":
			return {msg = "[color=gray]%s! %s holds.[/color]" % [name, who],
					cost = PressTurn.COST_FULL}
		"null":
			return {msg = "[color=#999999]%s! %s does not feel it at all.[/color]" % [name, who],
					cost = PressTurn.COST_MISS}
		"repel":
			var back: int = int(res["dmg"])
			cs._actor().take_damage(back)
			return {msg = "[color=#d070ff]%s! Turned back — %s takes %d.[/color]" % [
					name, cs._actor_name(), back], cost = PressTurn.COST_LOST}
		"drain":
			cs.enemy.heal(int(res["dmg"]))
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
	var power: int = maxi(1, int(float(cs.player.effective_mag())
			* cs.player.stage_mult(CharacterSheet.STAT_MAG)))
	var targets: Array[Enemy] = _spread_targets(
			data.get("shape", Spell.SHAPE_ALL) as String)

	var lines: Array[String] = ["[color=#c9a6ff]You cast %s![/color]" % data["name"]]
	var outcomes: Array[String] = []
	var reflected: int = 0
	var took_weak: bool = false

	var wide_rung: float = Spell.rung_of(data)
	for foe: Enemy in targets:
		var res: Dictionary = CombatMath.resolve_banish(
				foe, element, power, false, cs.player, boost)
		cs._reveal(foe, element)
		var outcome: String = res["outcome"] as String
		var wide_pr: TextureRect = cs._foe_portrait(foe)
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
		cs._actor().take_damage(reflected)
		lines.append("[color=red]%s takes %d from what came back.[/color]" % [
				cs._actor_name(), reflected])

	cs._ensure_target()
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
	if cs.enemy.unreadable:
		return {msg = "[color=#9aa0aa]%s gives you nothing.[/color]"
				% cs.enemy.display_name(), cost = PressTurn.COST_FULL}
	var already: bool = cs.player.has_analyzed(cs.enemy.enemy_name)
	cs.player.record_analysis(cs.enemy.lore_name() if cs.enemy.abyss_element != "" else cs.enemy.enemy_name)
	var chart: String = _affinity_line(cs.enemy)
	var lead: String = "You read %s again." if already else "You read %s."
	# A scan reads temperament as well as chart. Without this the match bonus in
	# a negotiation was a blind guess every time — the difference between eighty
	# per cent and nothing, decided by a coin the player could not see.
	var mood: String = ""
	if cs.enemy.negotiable and cs.enemy.talk_personality != "":
		mood = "  [color=#a0e0b0]%s \u2014 %d%% if you read it right.[/color]" % [
				cs.enemy.talk_personality.capitalize(), Negotiation.odds_percent(cs.enemy)]
	return {msg = "[color=#9ad0ff]%s  %s[/color]%s" % [
			lead % cs.enemy.display_name(), chart, mood],
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
	var actor: CharacterSheet = cs._actor()
	if not CombatMath.lands(actor, cs.enemy):
		return {msg = "[color=#9aa0aa]%s swings at %s and misses![/color]" % [
				cs._actor_name(), cs.enemy.display_name()], cost = PressTurn.COST_MISS}
	var atk: float = float(cs.player.effective_str()) * CombatMath.PHYS_POWER \
			if cs._actor_is_player() else float(actor.str)
	atk *= actor.stage_mult(CharacterSheet.STAT_ATK)
	if cs._actor_is_player() and "last_stand" in cs.player.passive_skills \
			and cs.player.hp * 4 < cs.player.max_hp:
		atk *= 2.0
	# A bound demon swings with its claws. Only the hero carries a blade,
	# so only his swing can be something other than phys.
	var element: String = cs.player.attack_element() if cs._actor_is_player() \
			else Affinity.PHYS
	if Affinity.is_banishing(element):
		return _resolve_banishing_swing(element, int(atk))
	var crit: bool = CombatMath.roll_crit(cs._actor())
	var res: Dictionary = CombatMath.resolve(int(atk) - _guarded_def(cs.enemy),
			element, cs.enemy, crit, cs.enemy.defending)
	return cs._land_hit(res, element, "%s strikes!" % cs._actor_name(), true)


# A blade on one of the two banishing lines expels instead of wounding, at the
# same odds a cast of that element would get — the difference being that a swing
# has to land first. A banishing cast has no hit roll of its own: the banish
# odds already are one.
func _resolve_banishing_swing(element: String, power: int) -> Dictionary:
	var res: Dictionary = CombatMath.resolve_banish(
			cs.enemy, element, power, false, cs.player)
	cs._reveal(cs.enemy, element)
	var prefix: String = "%s strikes!" % cs._actor_name()
	var who: String = cs.enemy.display_name()

	match res["outcome"]:
		"banished":
			cs.enemy.take_damage(cs.enemy.max_hp * 2)
			return {msg = "%s  [color=#c9a6ff]%s is taken, whole.[/color]" % [prefix, who],
					cost = PressTurn.COST_HALF if
						cs.enemy.affinity_of(element) == Affinity.WEAK else PressTurn.COST_FULL}
		"failed":
			return {msg = "%s  [color=gray]%s holds.[/color]" % [prefix, who],
					cost = PressTurn.COST_FULL}
		"null":
			return {msg = "%s  [color=#999999]%s does not feel it at all.[/color]" % [
					prefix, who], cost = PressTurn.COST_MISS}
		"repel":
			var back: int = int(res["dmg"])
			cs._actor().take_damage(back)
			var pr: TextureRect = cs._member_portrait(cs._actor())
			if pr != null:
				cs._shake_portrait(pr)
			return {msg = "%s  [color=#d070ff]Turned back — %s takes %d![/color]" % [
					prefix, cs._actor_name(), back], cost = PressTurn.COST_LOST}
		"drain":
			cs.enemy.heal(int(res["dmg"]))
			return {msg = "%s  [color=lime]%s drinks it and recovers %d HP![/color]" % [
					prefix, who, int(res["dmg"])], cost = PressTurn.COST_LOST}
	return {msg = "%s  [color=gray]Nothing comes of it.[/color]" % prefix,
			cost = PressTurn.COST_FULL}


