# CombatMath
# Damage resolution shared by both sides of a battle. Kept free of UI and of
# scene references so it can be exercised headlessly.
class_name CombatMath

const CRIT_MULT: float = 1.75


static func variance(dmg: int) -> int:
	return max(1, roundi(dmg * randf_range(0.8, 1.2)))


static func roll_crit() -> bool:
	return randi() % 10 == 0


# Resolves one offensive hit against a target's affinity chart.
# Returns { dmg, outcome, crit } where outcome is one of
# "hit" | "weak" | "resist" | "null" | "repel" | "drain".
# The caller applies the damage — this only decides how much and to whom.
static func resolve(base: int, element: String, target: CharacterSheet,
		crit: bool, guarded: bool = false) -> Dictionary:
	var state: String = target.affinity_of(element)
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


# Does a physical swing connect? Magic never misses — that is the Nocturne rule,
# and it keeps the affinity chart reliable while leaving agility to decide the
# things agility should decide. A miss costs two icons, so a slowed party bleeds
# turns rather than damage.
static func lands(attacker: CharacterSheet, target: CharacterSheet) -> bool:
	var atk: float = maxf(1.0, float(attacker.battle_agility())
			* attacker.stage_mult(CharacterSheet.STAT_AGL))
	var eva: float = maxf(1.0, float(target.battle_agility())
			* target.stage_mult(CharacterSheet.STAT_AGL))
	# Ratio-based so it behaves the same at level 2 and level 20: even agility
	# lands 95%, and four stages either way swings it roughly 95% <-> 55%.
	var chance: float = clampf(0.95 * (atk / (atk + eva)) * 2.0, 0.30, 0.99)
	return randf() < chance


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
		tag += "  [color=yellow][CRITICAL!][/color]"
	if suppressed:
		tag += "  [color=#7fd4ff]GUARDED![/color]"
	match outcome:
		"weak":   tag += "  [color=yellow]WEAK![/color]"
		"resist": tag += "  [color=#8cb4e6]Resisted.[/color]"
		"null":   tag += "  [color=#999999]Nulled![/color]"
	return tag
