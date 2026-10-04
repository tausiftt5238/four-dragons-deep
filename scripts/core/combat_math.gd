# CombatMath
# Damage resolution shared by both sides of a battle. Kept free of UI and of
# scene references so it can be exercised headlessly.
class_name CombatMath

const CRIT_MULT: float = 1.75

# A weapon swing's multiplier on STR, the physical counterpart of a spell's
# rung. Without it a point of MAG was worth two of STR from the first spell on,
# and a swing that can miss had no business being the weaker option as well.
const PHYS_POWER: float = 1.5

# A damaging cast reaching several targets used to thin out across them (one
# target kept it all, four kept 40% each). It no longer does: every target
# takes the whole cast, and the price of the reach is the risk instead, since
# one target that nulls, dodges or turns it back prices the whole cast (see
# CombatScene._spread_cost).


static func variance(dmg: int) -> int:
	return max(1, roundi(dmg * randf_range(0.8, 1.2)))


# 10% bare, climbing half a point per point of luck, with no ceiling: at 180
# luck every swing crits.
# Luck is the only thing that moves it, which is the whole reason the stat is
# worth a level-up point next to a flat +1 STR.
const CRIT_BASE: float = 0.10
const CRIT_PER_LUK: float = 0.005
# The ceiling is the hero's to break, not a monster's: bosses carry luck equal
# to their level (it is what a banishing luck build has to beat), and uncapped
# that would have the Necromancer critting one swing in three.
const MONSTER_CRIT_CAP: float = 0.25


static func roll_crit(attacker: CharacterSheet = null) -> bool:
	if attacker == null:
		return randf() < CRIT_BASE
	var chance: float = CRIT_BASE + CRIT_PER_LUK * float(attacker.battle_luck())
	if attacker is Enemy:
		chance = minf(chance, MONSTER_CRIT_CAP)
	return randf() < chance


# Resolves one offensive hit against a target's affinity chart.
# Returns { dmg, outcome, crit } where outcome is one of
# "hit" | "weak" | "resist" | "null" | "repel" | "drain".
# The caller applies the damage — this only decides how much and to whom.
# `pierce` (Pierce): resist, null, repel and drain land as a plain hit.
static func resolve(base: int, element: String, target: CharacterSheet,
		crit: bool, guarded: bool = false, pierce: bool = false) -> Dictionary:
	var res: Dictionary = _resolve(base, element, target, crit, guarded, pierce)
	# Whatever earns the half-icon back gets the bigger sound.
	if cost_for(res["outcome"], res["crit"], res["suppressed"]) == PressTurn.COST_HALF:
		Sfx.play("weak")
	return res


static func _resolve(base: int, element: String, target: CharacterSheet,
		crit: bool, guarded: bool, pierce: bool = false) -> Dictionary:
	var state: String = target.affinity_of(element)
	if pierce and state != Affinity.WEAK:
		state = Affinity.NORMAL
	var dmg: int = variance(base)
	if crit:
		dmg = int(dmg * CRIT_MULT)
	dmg = max(1, dmg)

	# Bracing denies the press-turn bonus: a weakness landed on a guarding
	# target does ordinary damage and buys no extra action. Repel and drain are
	# what the target IS, not an opening, so a guard does not touch them.
	if guarded and (state == Affinity.WEAK or crit):
		var kept: String = state
		if state == Affinity.WEAK:
			kept = Affinity.NORMAL
		match kept:
			Affinity.DRAIN:
				return {dmg = dmg, outcome = "drain", crit = crit, suppressed = false}
			Affinity.REPEL:
				return {dmg = dmg, outcome = "repel", crit = crit, suppressed = false}
			Affinity.NULL:
				return {dmg = 0, outcome = "null", crit = crit, suppressed = false}
			Affinity.RESIST:
				return {dmg = max(1, dmg / 2), outcome = "resist", crit = crit, suppressed = true}
		return {dmg = dmg, outcome = "hit", crit = crit, suppressed = true}

	match state:
		Affinity.DRAIN:
			return {dmg = dmg, outcome = "drain", crit = crit, suppressed = false}
		Affinity.REPEL:
			return {dmg = dmg, outcome = "repel", crit = crit, suppressed = false}
		Affinity.NULL:
			return {dmg = 0, outcome = "null", crit = crit, suppressed = false}
		Affinity.WEAK:
			return {dmg = dmg * 2, outcome = "weak", crit = crit, suppressed = false}
		Affinity.RESIST:
			return {dmg = max(1, dmg / 2), outcome = "resist", crit = crit, suppressed = false}
	return {dmg = dmg, outcome = "hit", crit = crit, suppressed = false}


# ── Banishing ─────────────────────────────────────────────────────────────────
#
# Light and dark do not wound — they expel. A cast either removes the target
# outright or does nothing at all, and the affinity chart decides which. This is
# what makes them worth carrying instead of a fourth damage element, and what
# makes a demon's nature matter beyond which spell hurts it.

const BANISH_BASE:   float = 0.28   # something with no opinion either way
const BANISH_WEAK:   float = 0.62   # exactly what it is made to expel
const BANISH_RESIST: float = 0.08   # it barely has purchase


# Luck moves the coin flip, never the chart. A demon that nulls the light is
# immune to a lucky hero and an unlucky one alike — what luck buys is an
# edge on the rows that were already uncertain, and each row keeps its own
# floor and ceiling so no amount of it turns a resistance into a kill.
const BANISH_PER_LUK: float = 0.012
const BANISH_LUK_CAP: float = 0.15

# No cast is ever a certainty, whatever rung it sits on.
const BANISH_MAX: float = 0.92

# Against a boss (a dragon, a warden, the Necromancer) the chart's odds are
# set aside for these: next to nothing on its own, half a point per point of
# luck the caster has over the boss, and a quarter of the rung's boost, all
# capped at 30%. Bosses carry luck equal to their level, so a balanced hero
# never gets a real chance and a luck build gets one worth building for.
# Null, repel and drain still cannot be taken at all.
const BOSS_BANISH_BASE:     float = 0.01
const BOSS_BANISH_PER_LUK:  float = 0.005
const BOSS_BANISH_BOOST:    float = 0.25
const BOSS_BANISH_CAP:      float = 0.30

const BANISH_BOUNDS: Dictionary = {
	Affinity.WEAK:   Vector2(0.45, 0.80),
	Affinity.RESIST: Vector2(0.02, 0.18),
	Affinity.NORMAL: Vector2(0.15, 0.45),
}


# The odds a banishing element takes the target, or 0.0 if it cannot.
# `caster` is optional: without one this reports the bare chart odds, which is
# what Analyze and the bestiary want to show.
static func banish_chance(target: CharacterSheet, element: String,
		caster: CharacterSheet = null, boost: float = 0.0) -> float:
	var state: String = target.affinity_of(element)
	var base: float = BANISH_BASE
	match state:
		Affinity.WEAK:   base = BANISH_WEAK
		Affinity.RESIST: base = BANISH_RESIST
		Affinity.NULL, Affinity.REPEL, Affinity.DRAIN:
			return 0.0
		_: state = Affinity.NORMAL

	if target is Enemy and (target as Enemy).is_boss_class():
		var lead: float = 0.0
		if caster != null:
			lead = maxf(0.0, float(caster.battle_luck() - target.battle_luck()))
		return clampf(BOSS_BANISH_BASE + lead * BOSS_BANISH_PER_LUK
				+ boost * BOSS_BANISH_BOOST, 0.0, BOSS_BANISH_CAP)

	if caster == null:
		return clampf(base + boost, 0.0, BANISH_MAX)
	var edge: float = clampf(
			float(caster.battle_luck() - target.battle_luck()) * BANISH_PER_LUK,
			-BANISH_LUK_CAP, BANISH_LUK_CAP)
	var bounds: Vector2 = BANISH_BOUNDS[state] as Vector2
	# The rung is added after the per-state bounds, not inside them: a higher
	# rung is meant to beat the ceiling an ordinary cast runs into. It cannot
	# beat the chart — null, repel and drain returned zero above and stay zero.
	return clampf(clampf(base + edge, bounds.x, bounds.y) + boost, 0.0, BANISH_MAX)


# Resolves one banishing cast. The hero is never expelled — a coin-flip game
# over at an unsaved moment is not a fight, it is a dice roll. It costs him HP
# instead.
static func resolve_banish(target: CharacterSheet, element: String,
		power: int, is_hero: bool, caster: CharacterSheet = null,
		boost: float = 0.0) -> Dictionary:
	var state: String = target.affinity_of(element)
	match state:
		Affinity.DRAIN:
			return {outcome = "drain", dmg = max(1, variance(power)), taken = false}
		Affinity.REPEL:
			return {outcome = "repel", dmg = max(1, variance(power)), taken = false}
		Affinity.NULL:
			return {outcome = "null", dmg = 0, taken = false}

	if is_hero:
		# Not expelled, but the attempt still tears at him — and a weakness
		# still tears harder.
		var hurt: int = variance(power)
		if state == Affinity.WEAK:
			hurt *= 2
		elif state == Affinity.RESIST:
			hurt = max(1, hurt / 2)
		return {outcome = "weak" if state == Affinity.WEAK else "hit",
				dmg = max(1, hurt), taken = false}

	# A wide cast rolls the full odds on every target it reaches, as a single
	# one does. What keeps the wide versions from simply ending fights is the
	# chart (null, repel and drain cannot be taken) and the press-turn price of
	# a cast any one target blocks (CombatScene._spread_cost).
	if randf() < banish_chance(target, element, caster, boost):
		return {outcome = "banished", dmg = 0, taken = true}
	return {outcome = "failed", dmg = 0, taken = false}


# The odds a swing connects, from the two sides' agility. Ratio-based so it
# behaves the same at level 2 and level 20: even agility lands 95%, and four
# stages either way swings it roughly 95% <-> 55%.
static func hit_chance(attacker: CharacterSheet, target: CharacterSheet) -> float:
	var atk: float = maxf(1.0, float(attacker.battle_agility()) * attacker.agility_mult())
	var eva: float = maxf(1.0, float(target.battle_agility()) * target.agility_mult())
	return clampf(0.95 * (atk / (atk + eva)) * 2.0, 0.30, 0.99)


# Does a physical swing connect? A miss costs two icons, so a slowed party
# bleeds turns rather than damage.
static func lands(attacker: CharacterSheet, target: CharacterSheet) -> bool:
	return _rolled(randf() < hit_chance(attacker, target), target)


# What a damaging spell keeps of a swing's chance to miss. It used to be zero —
# magic never missed — which left agility buffs and debuffs doing nothing for or
# against a caster. At half, even agility lands 97.5% and a slowed caster
# against a quickened target still lands about three in four.
const SPELL_MISS_SHARE: float = 0.5


static func spell_hit_chance(attacker: CharacterSheet, target: CharacterSheet) -> float:
	return 1.0 - (1.0 - hit_chance(attacker, target)) * SPELL_MISS_SHARE


static func spell_lands(attacker: CharacterSheet, target: CharacterSheet) -> bool:
	return _rolled(randf() < spell_hit_chance(attacker, target), target)


# Every miss in a fight comes through the two rolls above, so this is the one
# place that tells the target it was missed.
static func _rolled(hit: bool, target: CharacterSheet) -> bool:
	if not hit:
		target.evaded.emit()
	return hit


# Which press-turn cost an outcome carries. Repel/drain/null are checked before
# the critical bonus so a reflected critical still ends the phase.
static func cost_for(outcome: String, crit: bool, suppressed: bool = false) -> String:
	match outcome:
		"repel", "drain":
			return PressTurn.COST_LOST
		"null":
			return PressTurn.COST_MISS
		"weak":
			return PressTurn.COST_HALF
	# A guard eats the half-icon a weakness or a critical would have paid back.
	if crit and not suppressed:
		return PressTurn.COST_HALF
	return PressTurn.COST_FULL


# BBCode tag appended to the combat log for a resolved hit.
static func outcome_tag(outcome: String, crit: bool, suppressed: bool = false) -> String:
	var tag: String = ""
	if crit and outcome != "repel" and outcome != "drain" and outcome != "null":
		tag += "  [color=yellow]Critical![/color]"
	if suppressed:
		tag += "  [color=#7fd4ff]Guarded![/color]"
	match outcome:
		"weak":   tag += "  [color=yellow]Weak![/color]"
		"resist": tag += "  [color=#8cb4e6]Resisted.[/color]"
		"null":   tag += "  [color=#999999]Nulled![/color]"
	return tag
