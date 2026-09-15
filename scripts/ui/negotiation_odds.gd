# Negotiation
# The arithmetic behind Negotiate and Recruit, in one place because the two
# used to be the same machine copied twice with different words — and drifted.
#
# Two rounds, one roll each, and a demon agrees when the rolls add up to what
# its band asks for. The band IS the difficulty: a tier is the one number the
# player already understands from the floor they are standing on, where the old
# talk_difficulty was a private 1-to-5 scale nothing on screen ever showed.
#
#   tier I   need 2    tier II  need 3    tier III need 4    tier IV  need 5
#
# A right read rolls 0-3, a wrong one 0-2, and two rolls of 0-3 land on or above
# those four thresholds 81%, 63%, 38% and 19% of the time. That is the whole
# design: read the demon correctly and the tier is your odds.
#
#   read it right   81% / 63% / 38% / 19%
#   read it wrong   67% / 33% / 11% /  0%
#
# The wrong-read row is only a trap while the personality is a secret, which is
# why Analyze records it now. Guessing is for a demon you have never scanned.
class_name Negotiation extends RefCounted

const ROUNDS: int = 2

# What the sum of two rolls has to reach, by the band the demon belongs to.
const NEED_BASE: int = 1

# A roll that read the demon right, and one that did not.
const ROLL_RIGHT: int = 4   # 0-3
const ROLL_WRONG: int = 3   # 0-2


static func needed(demon: Enemy) -> int:
	return NEED_BASE + clampi(demon.tier, 1, 4)


static func roll(matched: bool) -> int:
	return randi() % (ROLL_RIGHT if matched else ROLL_WRONG)


# Which line of talk each temperament answers to. Two tables because the two
# conversations are not the same one: talking a demon out of a fight appeals to
# what it stands to lose, talking it into your service appeals to what it wants.
const REASON_MATCH: Dictionary = {
	"cowardly": ["Survival"],
	"proud":    ["Logic"],
	"greedy":   ["Gain"],
	"lonely":   ["Logic", "Survival"],
}

const RECRUIT_MATCH: Dictionary = {
	"cowardly": ["Safety"],
	"proud":    ["Pride"],
	"greedy":   ["Flatter"],
	"lonely":   ["Flatter", "Safety"],
}


static func matches(table: Dictionary, personality: String, approach: String) -> bool:
	return approach in (table.get(personality, []) as Array)


# What the menu shows once the demon has been scanned: the temperament, and
# what the band is worth in plain odds.
static func odds_percent(demon: Enemy) -> int:
	return tier_odds(demon.tier)


static func tier_odds(tier: int) -> int:
	match clampi(tier, 1, 4):
		1: return 81
		2: return 63
		3: return 38
	return 19
