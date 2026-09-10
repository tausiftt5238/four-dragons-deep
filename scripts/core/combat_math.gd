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
		crit: bool) -> Dictionary:
	var state: String = target.affinity_of(element)
	var dmg: int = variance(base)
	if crit:
		dmg = int(dmg * CRIT_MULT)
	dmg = max(1, dmg)

	match state:
		Affinity.DRAIN:
			return {dmg = dmg, outcome = "drain", crit = crit}
		Affinity.REPEL:
			return {dmg = dmg, outcome = "repel", crit = crit}
		Affinity.NULL:
			return {dmg = 0, outcome = "null", crit = crit}
		Affinity.WEAK:
			return {dmg = dmg * 2, outcome = "weak", crit = crit}
		Affinity.RESIST:
			return {dmg = max(1, dmg / 2), outcome = "resist", crit = crit}
	return {dmg = dmg, outcome = "hit", crit = crit}


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
static func cost_for(outcome: String, crit: bool) -> String:
	match outcome:
		"repel", "drain":
			return PressTurn.COST_LOST
		"null":
			return PressTurn.COST_MISS
		"weak":
			return PressTurn.COST_HALF
	if crit:
		return PressTurn.COST_HALF
	return PressTurn.COST_FULL


# BBCode tag appended to the combat log for a resolved hit.
static func outcome_tag(outcome: String, crit: bool) -> String:
	var tag: String = ""
	if crit and outcome != "repel" and outcome != "drain" and outcome != "null":
		tag += "  [color=yellow][CRITICAL!][/color]"
	match outcome:
		"weak":   tag += "  [color=yellow]WEAK![/color]"
		"resist": tag += "  [color=#8cb4e6]Resisted.[/color]"
		"null":   tag += "  [color=#999999]Nulled![/color]"
	return tag
