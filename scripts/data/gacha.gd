# Gacha
# The orb's slot machine. Three reels, four faces (experience, gold, an item, a
# monster), each equally likely on every reel. Two alike pays that face; three
# alike is the jackpot and pays it bigger. All three different pays nothing.
#
# With four faces the odds come out at:
#   any pair       36 in 64   (56%)
#   jackpot         4 in 64   (6%)
#   nothing        24 in 64   (38%)
# Gold alone gives back about a third of the stake on average, so it is not a
# way to make money (the Gauntlet is). What makes a spin worth it is the
# experience, the monsters, and the chance of gear from the band below.
class_name Gacha

const EXP:  String = "exp"
const GOLD: String = "gold"
const ITEM: String = "item"
const MONSTER: String = "monster"
const FACES: Array[String] = [EXP, GOLD, ITEM, MONSTER]

const GOLD_PAIR: float = 1.5      # times the price
const GOLD_JACKPOT: float = 10.0
const EXP_PAIR_FIGHTS: int = 3    # about one ordinary fight on this floor
const EXP_JACKPOT_MULT: int = 5


static func price(floor_num: int) -> int:
	return 25 + 15 * maxi(1, floor_num)


static func spin() -> Array[String]:
	var out: Array[String] = []
	for i: int in 3:
		out.append(FACES[randi() % FACES.size()])
	return out


# The face that paid and whether it was all three, or {} when nothing matched.
static func outcome(reels: Array[String]) -> Dictionary:
	for face: String in FACES:
		var n: int = reels.count(face)
		if n >= 2:
			return {face = face, jackpot = n == 3}
	return {}


static func gold_prize(floor_num: int, jackpot: bool) -> int:
	return roundi(price(floor_num) * (GOLD_JACKPOT if jackpot else GOLD_PAIR))


static func exp_prize(floor_num: int, jackpot: bool) -> int:
	var per_fight: int = Enemy.exp_for_level(Enemy.level_for_floor(floor_num, 0)) \
			* EXP_PAIR_FIGHTS
	return per_fight * (EXP_JACKPOT_MULT if jackpot else 1)


# A pair: one supply off this floor's shelf, mirrors aside (those are a
# thousand gold each and would make a pair worth more than a jackpot).
# A jackpot: a piece of gear from the next band down, or the deepest band once
# there is no deeper one. Found-only pieces are in the draw; this is luck.
static func item_prize(supplies: Array[Dictionary], floor_num: int, jackpot: bool) -> Dictionary:
	if not jackpot:
		var pool: Array[Dictionary] = []
		for it: Dictionary in supplies:
			if not it.has("mirror"):
				pool.append(it)
		return pool[randi() % pool.size()].duplicate()
	var tier: int = mini(4, Enemy.tier_for_floor(floor_num) + 1)
	var gear: Array[Dictionary] = []
	for shelf: Array[Dictionary] in [Weapon.all(), Armor.all(), Accessory.all()]:
		for g: Dictionary in shelf:
			if int(g["floor"]) == tier:
				gear.append(g)
	return gear[randi() % gear.size()].duplicate()


# A pair: a monster from this floor's band. A jackpot: one from the band below.
# Only what can be talked to (anything else could never be recruited anyway),
# and nothing already on the roster. Joins at its level on this floor, but
# never above the hero's, the same rule recruiting keeps. {} when nothing fits.
static func monster_prize(p: PlayerCharacter, floor_num: int, jackpot: bool) -> Dictionary:
	var tier: int = Enemy.tier_for_floor(floor_num) + (1 if jackpot else 0)
	tier = mini(4, tier)
	var pool: Array[String] = []
	for t: Dictionary in Enemy.TEMPLATES:
		if int(t.get("tier", 1)) == tier and bool(t.get("negotiable", true)) \
				and t["name"] not in p.recruited:
			pool.append(t["name"] as String)
	if pool.is_empty():
		return {}
	var picked: String = pool[randi() % pool.size()]
	var e: Enemy = Enemy.make_from_name(picked, floor_num)
	var lv: int = mini(e.lv, p.lv)
	e.free()
	return {name = picked, lv = lv}
