# CombatEnemyTurns
# The monsters' side of a battle, split out of CombatScene: whom they aim at,
# the ailments they throw, an ordinary monster's turn, the Necromancer's and
# the wardens' own rules, and spells that reach the whole party. It works on
# the scene it belongs to (cs) and draws through it.
class_name CombatEnemyTurns extends RefCounted

var cs: CombatScene


func _init(host: CombatScene) -> void:
	cs = host


# ── Enemy side ────────────────────────────────────────────────────────────────

# Picks a target and resolves one enemy action. Returns { msg, cost }.

func _pick_target(element: String) -> CharacterSheet:
	if cs._force_target != null and cs._force_target.is_alive():
		return cs._force_target
	var living: Array[CharacterSheet] = cs._living_party()
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
	if member == cs.player:
		return cs.player.effective_def()
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
	for m: CharacterSheet in cs._living_party():
		if not m.has_status(actor.status_attack):
			return true
	return false


func _enemy_cast_ailment(actor: Enemy) -> Dictionary:
	var status_id: String = actor.status_attack
	var sp: Dictionary = Spell.get_data(AIL_SPELLS[status_id] as String)
	actor.mp -= int(sp.get("mp", 4))

	# Whoever on the field is not already carrying it.
	var clean: Array[CharacterSheet] = []
	for m: CharacterSheet in cs._living_party():
		if not m.has_status(status_id):
			clean.append(m)
	var target: CharacterSheet = clean[randi() % clean.size()] if not clean.is_empty() \
			else _pick_target(Affinity.PHYS)

	var sname: String = Status.get_data(status_id).get("name", status_id)
	var lead: String = "[color=violet]%s casts %s![/color]" % [
			actor.display_name(), sp.get("name", sname)]

	# A ward trinket never fails, and it is checked before the dice so a
	# warded hero sees why, every time.
	if target == cs.player and not cs.player.ward_against(status_id).is_empty():
		return {msg = "%s  [color=lime]%s's %s wards it off![/color]" % [lead,
				cs.player.hero_name, cs.player.ward_against(status_id)["name"]],
				cost = PressTurn.COST_FULL}
	if randi() % 100 >= ail_landing_chance(actor.ailment_chance):
		return {msg = "%s  [color=gray]%s shrugs it off.[/color]" % [
				lead, cs._member_name(target)], cost = PressTurn.COST_FULL}
	if target == cs.player and "resilience" in cs.player.passive_skills and randi() % 4 == 0:
		return {msg = "%s  [color=lime]Resilience resists %s![/color]" % [lead, sname],
				cost = PressTurn.COST_FULL}
	target.apply_status(status_id)
	return {msg = "%s  [color=violet]%s is now %s.[/color]" % [
			lead, cs._member_name(target), sname], cost = PressTurn.COST_FULL}


# Kept for the CombatNeg* handlers: one provoked swing at the hero, taken
# outside the icon economy because a failed negotiation is its own risk.
func _apply_enemy_turn() -> String:
	cs._force_target = cs.player
	var res: Dictionary = await _enemy_act(cs.enemy)
	cs._force_target = null
	return res["msg"] as String


# Called by the CombatNeg* handlers when an attempt ends without a deal. The
# attempt cost the actor its turn, so the phase moves on.
func _talk_attempt_failed() -> void:
	await cs._after_action(PressTurn.COST_FULL)


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
	if actor.has_status(Status.PARALYZED) and randf() < PARALYSIS_SKIP:
		return {msg = "[color=yellow]%s is paralyzed and cannot act![/color]" % actor.display_name(),
				cost = PressTurn.COST_FULL}
	var epr: TextureRect = cs._foe_portrait(actor)
	if epr != null:
		await cs._windup(epr, "attack")

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
			if cs._actions._dispel_would_bite(sup, false):
				actor.mp -= int(sup.get("mp", 8))
				var out: Dictionary = cs._actions._cast_dispel(sup, false)
				out["msg"] = "[color=#c9a6ff]%s casts[/color] %s" % [
						actor.display_name(), out["msg"]]
				return out
		elif not sup.is_empty() and actor.mp >= int(sup.get("mp", 8)):
			var stat: String = sup.get("stat", CharacterSheet.STAT_ATK) as String
			var delta: int   = int(sup.get("delta", 1))
			var on_party: bool = (sup.get("scope", "party") == "party")
			var moved: int = 0
			if on_party:
				for f: Enemy in cs._living_foes():
					if f.shift_stage(stat, delta) != 0:
						moved += 1
						cs._actions._stage_fx(f, stat, delta)
			else:
				for m: CharacterSheet in cs._living_party():
					if m.shift_stage(stat, delta) != 0:
						moved += 1
						cs._actions._stage_fx(m, stat, delta)
			if moved > 0:
				actor.mp -= int(sup.get("mp", 8))
				return {msg = "[color=%s]%s casts %s! %s %s on %d.[/color]" % [
						"orange" if delta > 0 else "aqua", actor.display_name(),
						sup["name"], CombatActions._stat_name(stat),
						"rises" if delta > 0 else "falls", moved],
						cost = PressTurn.COST_FULL}

	var bit: Dictionary = {} if silenced else cs._actions._enemy_leech(actor)
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
	if paid and Spell.reach_for(element, actor.attack_reach) != Spell.SHAPE_ONE:
		return _enemy_spread(actor, element, base, dry)

	var target: CharacterSheet = _pick_target(element)

	if Affinity.is_banishing(element):
		return _enemy_banish(actor, target, element, dry)
	return _enemy_strike(actor, target, element, base, dry, paid)


# One blow or one single-target cast from the other side, from the hit roll to
# the log line. `base` is the attack's raw power before the target's guard.
# What a monster's element looks like when it lands: the highest rung of it an
# orb on this floor sells (Item.ELEMENTAL_SCROLLS), so a monster on the floor
# where you can first buy Blaze casts something that looks like Blaze. The
# look only: a monster's element hits as hard as its MAG says, as it always has.
func _foe_rung(element: String) -> float:
	var best: int = 1
	for rung: int in [2, 3]:
		var id: String = Spell.elemental_id(element, rung, Spell.SHAPE_ONE)
		if id != "" and int(Item.ELEMENTAL_SCROLLS.get(id, 999)) <= cs.floor_num:
			best = rung
	return Spell.rung_power(best)


func _enemy_strike(actor: Enemy, target: CharacterSheet, element: String,
		base: float, dry: String, skill: bool = false) -> Dictionary:
	# A swing misses on agility; a spell misses half as often. A miss does not
	# spend the target's brace — it never had to absorb anything.
	if element == Affinity.PHYS and not CombatMath.lands(actor, target):
		return {msg = dry + "[color=#9aa0aa]%s lunges at %s and misses![/color]" % [
				actor.display_name(), cs._member_name(target)], cost = PressTurn.COST_MISS}
	# A spell misses half as often as a swing, and costs its one icon.
	if element != Affinity.PHYS and not CombatMath.spell_lands(actor, target):
		return {msg = dry + "[color=#9aa0aa]%s uses %s — %s slips it![/color]" % [
				actor.display_name(), Affinity.element_name(element), cs._member_name(target)],
				cost = PressTurn.COST_FULL}

	if element == Affinity.PHYS:
		base *= actor.stage_mult(CharacterSheet.STAT_ATK)
	var guarding: bool = target.defending
	var eff_def: int = cs._actions._guard_vs(target, element)

	var crit: bool = CombatMath.roll_crit(actor)
	var res: Dictionary = CombatMath.resolve(int(base) - eff_def, element, target,
			crit, guarding)
	var outcome: String = res["outcome"] as String
	var dmg: int        = res["dmg"] as int
	var muted: bool     = bool(res.get("suppressed", false))
	var tname: String   = cs._member_name(target)
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
			var pr: TextureRect = cs._foe_portrait(actor)
			if pr != null:
				cs._shake_portrait(pr)
			return {msg = dry + "[color=#d070ff]%s %s %s — repelled! %s takes %d damage.[/color]" % [
					ename, verb, tname, ename, dmg], cost = PressTurn.COST_LOST}
		"null":
			return {msg = dry + "[color=#999999]%s %s %s — no effect.[/color]" % [ename, verb, tname],
					cost = PressTurn.COST_MISS}

	target.take_damage(dmg)
	var hit_pr: TextureRect = cs._member_portrait(target)
	if hit_pr != null:
		cs._shake_portrait(hit_pr, guarding)
		if element == Affinity.PHYS:
			# A swing is a slash; a physical line it paid for looks its rung.
			if skill:
				SpellFX.skill(hit_pr, _foe_rung(element))
			else:
				SlashFX.strike(hit_pr)
		else:
			SpellFX.cast(hit_pr, element, _foe_rung(element))
	var msg: String = dry + "[color=red]%s %s %s for %d damage.[/color]%s" % [
			ename, verb, tname, dmg, CombatMath.outcome_tag(outcome, crit, muted)]
	if element != Affinity.PHYS:
		msg += _warden_drain(actor, dmg)
	if target == cs.player:
		msg += cs._check_counter()
	return {msg = msg, cost = CombatMath.cost_for(outcome, crit, muted)}


# ── The Necromancer ───────────────────────────────────────────────────────────
#
# Its rules, in Enemy's notes on it: a new form each phase, one skeleton a
# phase, a dispel when there is something to clear (then none for the next
# three phases), and otherwise the form's element at one target.
const NECRO_DISPEL_EVERY: int = 4

# The foe portraits' own zoom, so the circle lands under the minion's feet.
const MINION_FX_ZOOM: float = 3.0

# What it has done this phase: one summon and at most one dispel per phase.
var _necro_turn: Dictionary = {summoned = false, dispelled = false}
# Phases until it may dispel again; 0 means it may now.
var _necro_dispel_wait: int = 0


func _necro_begin_phase(necro: Enemy) -> void:
	necro.take_form(necro.next_form())
	necro.mp = necro.max_mp
	_necro_turn = {summoned = false, dispelled = false}
	_necro_dispel_wait = maxi(_necro_dispel_wait - 1, 0)
	for r: Dictionary in cs._foe_rows:
		if r["foe"] == necro:
			(r["chart"] as AffinityChart).queue_redraw()


func _necro_act(actor: Enemy) -> Dictionary:
	var epr: TextureRect = cs._foe_portrait(actor)
	if actor.has_status(Status.PARALYZED) and randf() < PARALYSIS_SKIP:
		return {msg = "[color=yellow]%s is paralyzed and cannot act![/color]" % actor.display_name(),
				cost = PressTurn.COST_FULL}
	# Silenced, it can neither raise the dead nor cast: it swings the scythe.
	if actor.has_status(Status.SILENCE):
		if epr != null:
			await cs._windup(epr, "attack01")
		return _enemy_strike(actor, _pick_target(Affinity.PHYS), Affinity.PHYS,
				float(actor.str), "[color=gray]%s is silenced.[/color]\n" % actor.display_name())

	if not _necro_turn["summoned"]:
		_necro_turn["summoned"] = true
		if _necro_minions().size() < Enemy.NECRO_MINIONS_MAX:
			if epr != null:
				await cs._windup(epr, "summon")
			return _summon_minion(actor)

	# Everything past here is a spell: the staff, not the scythe.
	if epr != null:
		await cs._windup(epr, "attack02")

	if not _necro_turn["dispelled"] and _necro_dispel_wait == 0:
		var steady: Dictionary = Spell.get_data("steady")
		var purge: Dictionary = Spell.get_data("purge")
		var pick: Dictionary = {}
		if cs._actions._dispel_would_bite(steady, false):
			pick = steady
		elif cs._actions._dispel_would_bite(purge, false):
			pick = purge
		if not pick.is_empty():
			_necro_turn["dispelled"] = true
			# Counted down at the start of each of its phases, this one's included.
			_necro_dispel_wait = NECRO_DISPEL_EVERY
			var out: Dictionary = cs._actions._cast_dispel(pick, false)
			out["msg"] = "[color=#c9a6ff]%s casts[/color] %s" % [actor.display_name(), out["msg"]]
			return out

	var element: String = actor.form
	var base: float = float(actor.mag) * actor.stage_mult(CharacterSheet.STAT_MAG) * 2.0
	return _enemy_strike(actor, _pick_target(element), element, base, "")


func _necro_minions() -> Array[Enemy]:
	var out: Array[Enemy] = []
	for f: Enemy in cs._living_foes():
		if f.summoned:
			out.append(f)
	return out


# Raises a skeleton onto the field. The fallen ones' cards are cleared first,
# so the column only ever holds the master and what is standing beside it.
func _summon_minion(master: Enemy) -> Dictionary:
	for r: Dictionary in cs._foe_rows.duplicate():
		var f: Enemy = r["foe"] as Enemy
		if f.summoned and not f.is_alive():
			(r["card"] as Control).queue_free()
			cs._foe_rows.erase(r)
			cs.foes.erase(f)
	var m: Enemy = Enemy.make_minion(master)
	# Owned by the scene, so it is freed with the fight; the foes Main brought
	# in are Main's to free.
	cs.add_child(m)
	m.reset_stages()
	cs.foes.append(m)
	cs._assign_battle_tags()
	cs._enemy_side.add_child(cs._build_foe_card(m))
	# It climbs out of a circle drawn at its feet.
	var mpr: TextureRect = cs._foe_portrait(m)
	if mpr != null:
		cs._play_anim(mpr, "summon")
		if ResourceLoader.exists(Enemy.NECRO_SUMMON_FX):
			mpr.add_child(AnimatedPortrait.one_shot(Enemy.NECRO_SUMMON_FX, MINION_FX_ZOOM))
	for r: Dictionary in cs._foe_rows:
		(r["name_lbl"] as Label).text = (r["foe"] as Enemy).display_name()
	cs._fit_columns.call_deferred()
	return {msg = "[color=#c9a6ff]%s raises a %s (LV %d) from the bones![/color]" % [
			master.display_name(), m.display_name(), m.lv], cost = PressTurn.COST_FULL}


# With the Necromancer (or the Death Knight) down, whatever it raised falls
# with it.
func _crumble_orphans() -> void:
	var master_up: bool = false
	var had_master: bool = false
	for f: Enemy in cs.foes:
		if f.is_necromancer() or f.warden_trick() == "raise":
			had_master = true
			master_up = master_up or f.is_alive()
	if not had_master or master_up:
		return
	for m: Enemy in _necro_minions():
		m.hp = 0
		cs._log("[color=gray]%s crumbles to dust.[/color]" % m.display_name())


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
		var epr: TextureRect = cs._foe_portrait(actor)
		if epr != null:
			await cs._windup(epr, "attack")
		return _summon_minion(actor)
	return await _enemy_act(actor)


# The Black Knight's answer to a blade that did not finish it.
func _warden_counter(target: Enemy, attacker: CharacterSheet) -> String:
	if target.warden_trick() != "counter" or attacker == null or not attacker.is_alive() \
			or randf() >= WARDEN_COUNTER_ODDS:
		return ""
	var base: float = float(target.str) * target.stage_mult(CharacterSheet.STAT_ATK)
	var res: Dictionary = CombatMath.resolve(int(base) - cs._actions._guard_vs(attacker, Affinity.PHYS),
			Affinity.PHYS, attacker, false, attacker.defending)
	if res["outcome"] in ["null", "drain", "repel"]:
		return ""
	var dmg: int = int(res["dmg"])
	attacker.take_damage(dmg)
	var pr: TextureRect = cs._member_portrait(attacker)
	if pr != null:
		cs._shake_portrait(pr, attacker.defending)
	return "\n[color=#ff8a4a]%s counters! %s takes %d.[/color]" % [
			target.display_name(), cs._member_name(attacker), dmg]


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
	var standing: Array[CharacterSheet] = cs._living_party()
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
		# Every one it reaches gets its own burst or cut, the way a wide cast
		# from your side does; without it a breath over the whole party was
		# only the portraits shaking.
		var fx_pr: TextureRect = cs._member_portrait(who)
		if fx_pr != null:
			if element == Affinity.PHYS:
				SpellFX.skill(fx_pr, _foe_rung(element))
			else:
				SpellFX.cast(fx_pr, element, _foe_rung(element))
		if banishing:
			var br: Dictionary = CombatMath.resolve_banish(who, element,
					maxi(1, int(base)), who == cs.player, actor)
			outcomes.append(_apply_enemy_banish_one(actor, who, element, br, lines))
			continue
		if element != Affinity.PHYS and not CombatMath.spell_lands(actor, who):
			outcomes.append("slip")
			lines.append("[color=#9aa0aa]%s slips it.[/color]" % cs._member_name(who))
			continue
		var res: Dictionary = CombatMath.resolve(
				int(base) - cs._actions._guard_vs(who, element), element, who,
				CombatMath.roll_crit(actor), who.defending)
		var outcome: String = res["outcome"] as String
		var dmg: int = int(res["dmg"])
		outcomes.append(outcome)
		match outcome:
			"drain":
				who.heal(dmg)
				lines.append("[color=lime]%s drinks it — %d HP.[/color]" % [
						cs._member_name(who), dmg])
			"repel":
				reflected += dmg
				lines.append("[color=#d070ff]%s turns it back.[/color]" % cs._member_name(who))
			"null":
				lines.append("[color=#999999]%s does not feel it.[/color]" % cs._member_name(who))
			_:
				who.take_damage(dmg)
				dealt += dmg
				var pr: TextureRect = cs._member_portrait(who)
				if pr != null:
					cs._shake_portrait(pr, who.defending)
				lines.append("[color=red]%s takes %d.[/color]%s" % [
						cs._member_name(who), dmg,
						CombatMath.outcome_tag(outcome, false, bool(res.get("suppressed", false)))])

	if reflected > 0:
		actor.take_damage(reflected)
		lines.append("[color=#d070ff]%s takes %d from what came back.[/color]" % [
				actor.display_name(), reflected])
	if element != Affinity.PHYS:
		lines.append(_warden_drain(actor, dealt))

	# The demons' side pays the same press-turn arithmetic the hero does.
	return {msg = " ".join(lines), cost = CombatActions._spread_cost(outcomes)}


# One target of a wide banishing cast, written out so the single-target path and
# this one cannot drift apart on what an expulsion actually costs.
func _apply_enemy_banish_one(actor: Enemy, who: CharacterSheet, element: String,
		res: Dictionary, lines: Array[String]) -> String:
	match res["outcome"]:
		"banished":
			who.take_damage(who.max_hp * 2)
			lines.append("[color=#c9a6ff]%s is taken.[/color]" % cs._member_name(who))
			return "hit"
		"drain":
			who.heal(int(res["dmg"]))
			lines.append("[color=lime]%s drinks it.[/color]" % cs._member_name(who))
			return "drain"
		"repel":
			actor.take_damage(int(res["dmg"]))
			lines.append("[color=#d070ff]%s turns it back.[/color]" % cs._member_name(who))
			return "repel"
		"null":
			lines.append("[color=#999999]%s does not feel it.[/color]" % cs._member_name(who))
			return "null"
		"weak":
			who.take_damage(int(res["dmg"]))
			lines.append("[color=red]%s is torn for %d.[/color]" % [
					cs._member_name(who), int(res["dmg"])])
			return "weak"
		"hit":
			who.take_damage(int(res["dmg"]))
			lines.append("[color=red]%s is torn for %d.[/color]" % [
					cs._member_name(who), int(res["dmg"])])
			return "hit"
	lines.append("[color=gray]%s holds.[/color]" % cs._member_name(who))
	return "hit"


# A demon reaching for light or dark is reaching for one of yours. The hero
# cannot be expelled, so it tears at him instead; a bound demon it takes is gone
# for good, which is what makes these the frightening ones to meet.
func _enemy_banish(actor: Enemy, target: CharacterSheet, element: String,
		dry: String) -> Dictionary:
	var power: int = maxi(1, int(float(actor.mag)
			* actor.stage_mult(CharacterSheet.STAT_MAG)))
	var is_hero: bool = (target == cs.player)
	var res: Dictionary = CombatMath.resolve_banish(target, element, power, is_hero)
	var ename: String = actor.display_name()
	var tname: String = cs._member_name(target)
	var word: String  = "Light" if element == Affinity.LIGHT else "Dark"

	# On the cast, not the result, as the hero's own banishing does: it reaches
	# them whether or not it takes.
	var hit_pr: TextureRect = cs._member_portrait(target)
	if hit_pr != null:
		SpellFX.cast(hit_pr, element, _foe_rung(element))

	match res["outcome"]:
		"banished":
			target.take_damage(target.max_hp * 2)
			var pr: TextureRect = cs._member_portrait(target)
			if pr != null:
				cs._shake_portrait(pr, target.defending)
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
	if hit_pr != null:
		cs._shake_portrait(hit_pr, target.defending)
	var tag: String = "  [color=yellow]Weak![/color]" if res["outcome"] == "weak" else ""
	return {msg = dry + "[color=red]%s calls the %s — %s takes %d.[/color]%s" % [
			ename, word, tname, hurt, tag],
			cost = PressTurn.COST_HALF if res["outcome"] == "weak" else PressTurn.COST_FULL}

