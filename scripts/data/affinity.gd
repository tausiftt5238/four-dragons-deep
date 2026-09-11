# Affinity
# Elemental affinity states and the damage they imply.
#
# Every combatant carries an `affinities` Dictionary of element -> state.
# An element missing from that Dictionary is NORMAL. "phys" is a real element
# here, so physical attacks participate in the same chart as magic.
class_name Affinity

const NORMAL: String = ""
const WEAK:   String = "weak"
const RESIST: String = "resist"
const NULL:   String = "null"
const REPEL:  String = "repel"
const DRAIN:  String = "drain"

const PHYS:  String = "phys"
const LIGHT: String = "light"
const DARK:  String = "dark"

# Every element that can appear in an affinity chart. Light and dark are the
# instant-kill lines rather than damage — see CombatMath.banish_chance.
const ELEMENTS: Array[String] = ["phys", "fire", "ice", "thunder", "light", "dark"]

# The two that expel rather than wound.
static func is_banishing(element: String) -> bool:
	return element == LIGHT or element == DARK


static func multiplier(state: String) -> float:
	match state:
		WEAK:   return 2.0
		RESIST: return 0.5
		NULL:   return 0.0
	return 1.0


static func label(state: String) -> String:
	match state:
		WEAK:   return "WEAK"
		RESIST: return "RESIST"
		NULL:   return "NULL"
		REPEL:  return "REPEL"
		DRAIN:  return "DRAIN"
	return "-"


static func color(state: String) -> Color:
	match state:
		WEAK:   return Color(1.00, 0.85, 0.20)
		RESIST: return Color(0.55, 0.70, 0.90)
		NULL:   return Color(0.60, 0.60, 0.65)
		REPEL:  return Color(0.85, 0.45, 1.00)
		DRAIN:  return Color(0.40, 0.95, 0.55)
	return Color(0.75, 0.75, 0.78)


static func element_name(element: String) -> String:
	match element:
		PHYS:  return "Phys"
		LIGHT: return "Light"
		DARK:  return "Dark"
	return element.capitalize()
