# Armor
# One worn piece. Defence always costs agility, and the heavier pieces buy
# their protection by opening an elemental hole — which is why the best armour
# for a floor depends on what lives there rather than on its defence number.
#
# A piece can resist elements and open weaknesses to others. The plain ones
# carry one of each at most; the layered ones (make_layered) carry two or three,
# and pay for every element they turn with a hole somewhere else. Nothing here
# grants a drain or a repel: those belong to demons, not to smithing.
class_name Armor


static func make(id: String, name: String, desc: String,
		def_bonus: int, floor: int, agl_pen: int = 0, weakness: String = "",
		resist_element: String = "") -> Dictionary:
	return {id=id, name=name, type="armor", desc=desc,
			def_bonus=def_bonus, agl_pen=agl_pen, floor=floor, qty=1,
			weakness=weakness, resist_element=resist_element}


static func make_layered(id: String, name: String, desc: String,
		def_bonus: int, floor: int, agl_pen: int,
		resists: Array[String], weaknesses: Array[String]) -> Dictionary:
	var d: Dictionary = make(id, name, desc, def_bonus, floor, agl_pen)
	d["resists"] = resists
	d["weaknesses"] = weaknesses
	return d


# Every element a worn piece (armour or trinket) resists, and every one it
# opens: the single-element fields the older pieces and saves carry, plus the
# lists the layered ones do.
static func resists_of(item: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var one: String = item.get("resist_element", "") as String
	if one != "":
		out.append(one)
	for e: Variant in item.get("resists", []):
		if not (e as String) in out:
			out.append(e as String)
	return out


static func weaknesses_of(item: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var one: String = item.get("weak_element", item.get("weakness", "")) as String
	if one != "":
		out.append(one)
	for e: Variant in item.get("weaknesses", []):
		if not (e as String) in out:
			out.append(e as String)
	return out


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

static func fur_mantle() -> Dictionary:
	return make_layered("fur_mantle", "Fur Mantle",
			"A whole pelt. Frost and spark slide off it; a spark of the other kind does not.",
			3, 1, -1, ["ice", "thunder"], ["fire"])

static func tarred_jerkin() -> Dictionary:
	return make_layered("tarred_jerkin", "Tarred Jerkin",
			"Pitch keeps the lightning out. It burns, and it cracks in the cold.",
			4, 1, 0, ["thunder"], ["fire", "ice"])

static func pilgrims_robe() -> Dictionary:
	return make_layered("pilgrims_robe", "Pilgrim's Robe",
			"Blessed at every shrine on the road down. No blessing stops a blade.",
			2, 1, 1, [Affinity.LIGHT, Affinity.DARK], [Affinity.PHYS])


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

static func bronze_cuirass() -> Dictionary:
	return make_layered("bronze_cuirass", "Bronze Cuirass",
			"Turns an edge and shrugs off heat. Rings like a bell when the sky strikes.",
			9, 2, -1, [Affinity.PHYS, "fire"], ["thunder", "ice"])

static func wyrmhide_jacket() -> Dictionary:
	return make_layered("wyrmhide_jacket", "Wyrmhide Jacket",
			"A young drake's skin, good in the fire and the cold. It never learned the storm.",
			8, 2, 0, ["fire", "ice"], ["thunder"])

static func grave_shroud() -> Dictionary:
	return make_layered("grave_shroud", "Grave Shroud",
			"Taken off someone who did not need it. The dark and the cold know it as theirs.",
			7, 2, 0, [Affinity.DARK, "ice"], [Affinity.LIGHT, "fire"])


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

static func obsidian_plate() -> Dictionary:
	return make_layered("obsidian_plate", "Obsidian Plate",
			"Volcanic glass, edge-proof and fire-born. Cold shatters it; lightning finds the seams.",
			15, 3, -3, [Affinity.PHYS, "fire"], ["ice", "thunder"])

static func stormglass_mail() -> Dictionary:
	return make_layered("stormglass_mail", "Stormglass Mail",
			"Fused where lightning struck sand. It drinks the storm and the frost, and melts.",
			13, 3, -1, ["thunder", "ice"], ["fire"])

static func templars_hauberk() -> Dictionary:
	return make_layered("templars_hauberk", "Templar's Hauberk",
			"Consecrated mail. Steel and the light both glance off; the dark has its measure.",
			14, 3, -2, [Affinity.PHYS, Affinity.LIGHT], [Affinity.DARK])


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

static func abyssal_carapace() -> Dictionary:
	return make_layered("abyssal_carapace", "Abyssal Carapace",
			"Grown, not forged, somewhere under the last floor. It hates the light and the storm.",
			24, 4, -3, [Affinity.DARK, "fire", "ice"], [Affinity.LIGHT, "thunder"])

static func seraphs_mail() -> Dictionary:
	return make_layered("seraphs_mail", "Seraph's Mail",
			"Feather-light and bright. Storm, frost and the light all pass it by; the dark does not.",
			21, 4, -1, [Affinity.LIGHT, "thunder", "ice"], [Affinity.DARK])

static func dragonbone_plate() -> Dictionary:
	return make_layered("dragonbone_plate", "Dragonbone Plate",
			"Cut from the dragons themselves: fire, frost and storm. Nothing holy or unholy in it.",
			26, 4, -3, ["fire", "ice", "thunder"], [Affinity.LIGHT, Affinity.DARK])


static func all() -> Array[Dictionary]:
	return [leather_vest(), padded_coat(), leather_garb(),
			fur_mantle(), tarred_jerkin(), pilgrims_robe(),
			chain_mail(), salt_tanned_hide(), silver_armor(), scale_hauberk(),
			bronze_cuirass(), wyrmhide_jacket(), grave_shroud(),
			plate_armor(), warded_surcoat(), gold_armor(), mythril_chain(),
			obsidian_plate(), stormglass_mail(), templars_hauberk(),
			gargoyle_scale(), drakescale_cuirass(), platinum_armor(),
			diamond_armor(), saints_raiment(),
			abyssal_carapace(), seraphs_mail(), dragonbone_plate()]


# What a floor could plausibly turn up: this tier and everything above it.
static func for_floor(floor_num: int) -> Array[Dictionary]:
	var tier: int = clampi((floor_num - 1) / 5 + 1, 1, 4)
	var out: Array[Dictionary] = []
	for a: Dictionary in all():
		if int(a["floor"]) <= tier:
			out.append(a)
	return out
