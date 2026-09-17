# Armor
# One worn piece. Defence always costs agility, and the heavier pieces buy
# their protection by opening an elemental hole — which is why the best armour
# for a floor depends on what lives there rather than on its defence number.
#
# A piece can resist one element or open a weakness to one. Nothing here grants
# a drain or a repel: those belong to demons, not to smithing.
class_name Armor


static func make(id: String, name: String, desc: String,
		def_bonus: int, floor: int, agl_pen: int = 0, weakness: String = "",
		resist_element: String = "") -> Dictionary:
	return {id=id, name=name, type="armor", desc=desc,
			def_bonus=def_bonus, agl_pen=agl_pen, floor=floor, qty=1,
			weakness=weakness, resist_element=resist_element}


# ── Tier I · floors 1-5 ──────────────────────────────────────────────────────

static func leather_vest() -> Dictionary:
	return make("leather_vest", "Leather Vest",
			"Light, quiet, and no help at all against a flame.", 3, 1, 0, "fire")

static func padded_coat() -> Dictionary:
	return make("padded_coat", "Padded Coat",
			"Quilted against the cold. Bulky through a doorway.", 4, 1, -1, "", "ice")

static func leather_garb() -> Dictionary:
	return make("leather_garb", "Leather Garb",
			"Worn soft by the road. It hides nothing and it slows nothing.", 2, 1, 1)


# ── Tier II · floors 6-10 ────────────────────────────────────────────────────

static func chain_mail() -> Dictionary:
	return make("chain_mail", "Chain Mail",
			"Turns a blade, and draws lightning like a hooked rug.", 8, 2, -1, "thunder", Affinity.PHYS)

static func salt_tanned_hide() -> Dictionary:
	return make("salt_tanned_hide", "Salt-Tanned Hide",
			"Cured hard in brine. Whatever crawls does not like it.", 7, 2, 0, "", Affinity.DARK)

static func silver_armor() -> Dictionary:
	return make("silver_armor", "Silver Armour",
			"Polished to throw back whatever is thrown at it.",
			9, 2, -1, "", Affinity.LIGHT)

static func scale_hauberk() -> Dictionary:
	return make("scale_hauberk", "Scale Hauberk",
			"Overlapping plates on a leather backing. Heavy in all the usual places.",
			10, 2, -2, "thunder")


# ── Tier III · floors 11-15 ──────────────────────────────────────────────────

static func plate_armor() -> Dictionary:
	return make("plate_armor", "Plate Armour",
			"Everything a smith knows, all at once, all of it heavy.", 15, 3, -3, "ice")

static func warded_surcoat() -> Dictionary:
	return make("warded_surcoat", "Warded Surcoat",
			"Stitched through with something that objects to being looked at.",
			11, 3, -1, "", Affinity.LIGHT)

static func gold_armor() -> Dictionary:
	return make("gold_armor", "Gold Armour",
			"Soft, heavy, and it makes you look worth robbing.",
			13, 3, -2, "thunder", Affinity.DARK)

static func mythril_chain() -> Dictionary:
	return make("mythril_chain", "Mythril Chain",
			"The only mail down here that costs you nothing to wear.", 13, 3)


# ── Tier IV · floors 16-20 ───────────────────────────────────────────────────

static func gargoyle_scale() -> Dictionary:
	return make("gargoyle_scale", "Gargoyle Scale",
			"Prised off something that was part of a wall. Still wants to be one.",
			22, 4, -3, "thunder", Affinity.PHYS)

static func drakescale_cuirass() -> Dictionary:
	return make("drakescale_cuirass", "Drakescale Cuirass",
			"It has already survived worse than anything down here.", 19, 4, -2, "", "fire")

static func platinum_armor() -> Dictionary:
	return make("platinum_armor", "Platinum Armour",
			"No trick to it and no hole in it. Only the number.", 24, 4, -3)

static func diamond_armor() -> Dictionary:
	return make("diamond_armor", "Diamond Armour",
			"Set with stone across the chest. It cracks at a temperature you will meet.",
			27, 4, -4, "ice")

static func saints_raiment() -> Dictionary:
	return make("saints_raiment", "Saint's Raiment",
			"Cloth, and it has outlasted every plate in this tier.",
			17, 4, -1, "", Affinity.DARK)


static func all() -> Array[Dictionary]:
	return [leather_vest(), padded_coat(), leather_garb(),
			chain_mail(), salt_tanned_hide(), silver_armor(), scale_hauberk(),
			plate_armor(), warded_surcoat(), gold_armor(), mythril_chain(),
			gargoyle_scale(), drakescale_cuirass(), platinum_armor(),
			diamond_armor(), saints_raiment()]


# What a floor could plausibly turn up: this tier and everything above it.
static func for_floor(floor_num: int) -> Array[Dictionary]:
	var tier: int = clampi((floor_num - 1) / 5 + 1, 1, 4)
	var out: Array[Dictionary] = []
	for a: Dictionary in all():
		if int(a["floor"]) <= tier:
			out.append(a)
	return out
