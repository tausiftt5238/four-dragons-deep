# PressTurn
# Nocturne-style icon economy for one side of a battle.
#
# A side opens its phase with one full icon per living combatant. Actions spend
# icons; hitting a weakness or landing a critical spends only half, which is
# what makes the phase snowball. The rules are deliberately unforgiving:
#
#   normal action            1 full icon
#   weakness hit / critical   a full icon becomes a blinking half icon;
#                             if only blinking icons remain, one is consumed
#   miss, or target nulls     2 icons
#   target repels or drains   every remaining icon — the phase ends outright
#
# Blinking icons are always spent before full ones, so a banked half is used
# up by the next ordinary action rather than hoarded.
class_name PressTurn extends RefCounted

const COST_FULL: String = "full"
const COST_HALF: String = "half"
const COST_MISS: String = "miss"
const COST_LOST: String = "lost"

# Full icons still untouched this phase.
var full: int = 0
# Blinking (half-spent) icons. Each is worth one more action.
var blink: int = 0


func begin(count: int) -> void:
	full  = max(0, count)
	blink = 0


func total() -> int:
	return full + blink


func has_turns() -> bool:
	return total() > 0


func end_phase() -> void:
	full  = 0
	blink = 0


# Spends icons for one action. Returns how many icons were actually consumed,
# counting a half as 1 and a full as 2, so callers can report the cost.
func spend(kind: String) -> void:
	match kind:
		COST_HALF:
			if full > 0:
				full  -= 1
				blink += 1
			else:
				_consume(1)
		COST_MISS:
			_consume(2)
		COST_LOST:
			end_phase()
		_:
			_consume(1)


func _consume(n: int) -> void:
	for _i: int in range(n):
		if blink > 0:
			blink -= 1
		elif full > 0:
			full -= 1
		else:
			return


# "●●◐" — full icons then blinking ones. Used by the combat HUD.
func icons_string() -> String:
	return "●".repeat(full) + "◐".repeat(blink)
