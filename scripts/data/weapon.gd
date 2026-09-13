# Weapon
# What the detective swings. One slot, and a clear progression across the run's
# four tiers — a tier-one blade on floor eighteen is the same as no blade.
#
# Every weapon trades: reach and weight cost agility, and a caster's weapon
# gives up strength for magic entirely. The floor field is the tier it belongs
# to, which is what the drop table and the orb's shelves both read.
class_name Weapon


static func make(id: String, name: String, desc: String,
		str_bonus: int, mag_bonus: int, floor: int, agl_pen: int = 0) -> Dictionary:
	return {id=id, name=name, type="weapon", desc=desc,
			str_bonus=str_bonus, mag_bonus=mag_bonus, agl_pen=agl_pen,
			floor=floor, qty=1}


# ── Tier I · floors 1-5 ──────────────────────────────────────────────────────

static func rusty_dagger() -> Dictionary:
	return make("rusty_dagger", "Rusty Dagger",
			"A worn blade, better than bare hands.", 2, 0, 1)

static func iron_sword() -> Dictionary:
	return make("iron_sword", "Iron Sword",
			"A sturdy iron blade, honest and slow.", 5, 0, 1, -1)

static func hazel_wand() -> Dictionary:
	return make("hazel_wand", "Hazel Wand",
			"Cut green and never dried. It carries a spell further than it carries a blow.",
			0, 4, 1)


# ── Tier II · floors 6-10 ────────────────────────────────────────────────────

static func battle_axe() -> Dictionary:
	return make("battle_axe", "Battle Axe",
			"Powerful, and it arrives late.", 9, 0, 2, -2)

static func silver_rapier() -> Dictionary:
	return make("silver_rapier", "Silver Rapier",
			"Light enough to lead with. Quick hands matter more than strong ones.",
			7, 0, 2, 1)

static func magic_rod() -> Dictionary:
	return make("magic_rod", "Magic Rod",
			"Channels what you have learned, and asks nothing of your arm.", 0, 9, 2)


# ── Tier III · floors 11-15 ──────────────────────────────────────────────────

static func runed_glaive() -> Dictionary:
	return make("runed_glaive", "Runed Glaive",
			"A long reach with something written down the flat of it.", 13, 3, 3, -1)

static func headsman_maul() -> Dictionary:
	return make("headsman_maul", "Headsman's Maul",
			"It only has to land once.", 17, 0, 3, -3)

static func witchs_focus() -> Dictionary:
	return make("witchs_focus", "Witch's Focus",
			"A knot of blackthorn around a stone. It does the thinking.", 0, 15, 3)


# ── Tier IV · floors 16-20 ───────────────────────────────────────────────────

static func drakebone_sabre() -> Dictionary:
	return make("drakebone_sabre", "Drakebone Sabre",
			"Cut from something that was still arguing at the time.", 22, 0, 4, -1)

static func titans_cleaver() -> Dictionary:
	return make("titans_cleaver", "Titan's Cleaver",
			"Made for a larger hand. You manage.", 28, 0, 4, -4)

static func sorcerers_crook() -> Dictionary:
	return make("sorcerers_crook", "Sorcerer's Crook",
			"Bone, and still warm. Whatever it was taken from knew a great deal.",
			0, 24, 4)


static func all() -> Array[Dictionary]:
	return [rusty_dagger(), iron_sword(), hazel_wand(),
			battle_axe(), silver_rapier(), magic_rod(),
			runed_glaive(), headsman_maul(), witchs_focus(),
			drakebone_sabre(), titans_cleaver(), sorcerers_crook()]


# What a floor could plausibly turn up: this tier and everything above it.
static func for_floor(floor_num: int) -> Array[Dictionary]:
	var tier: int = clampi((floor_num - 1) / 5 + 1, 1, 4)
	var out: Array[Dictionary] = []
	for w: Dictionary in all():
		if int(w["floor"]) <= tier:
			out.append(w)
	return out
