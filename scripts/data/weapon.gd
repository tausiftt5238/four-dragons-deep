# Weapon
# What the detective swings. One slot, and a clear progression across the run's
# four tiers — a tier-one blade on floor eighteen is the same as no blade.
#
# Every weapon trades: reach and weight cost agility, and a caster's weapon
# gives up strength for magic entirely. The floor field is the tier it belongs
# to, which is what the drop table and the orb's shelves both read.
#
# A weapon may also carry an `attack_element`, which is what an ordinary swing
# is scored as instead of phys. That buys a free elemental hit — no MP, every
# turn — and charges for it on the chart: swinging fire into something that
# drains or repels fire ends the phase exactly as a cast would. On the two
# banishing lines the swing expels rather than wounds, at the same odds a cast
# gets.
class_name Weapon


static func make(id: String, name: String, desc: String,
		str_bonus: int, mag_bonus: int, floor: int, agl_pen: int = 0,
		attack_element: String = "", found_only: bool = false,
		def_bonus: int = 0) -> Dictionary:
	return {id=id, name=name, type="weapon", desc=desc,
			str_bonus=str_bonus, mag_bonus=mag_bonus, agl_pen=agl_pen,
			def_bonus=def_bonus, attack_element=attack_element,
			found_only=found_only, floor=floor, qty=1}


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

static func bronze_shortsword() -> Dictionary:
	return make("bronze_shortsword", "Bronze Shortsword",
			"Soft metal. It bends before it breaks, and it is quick about both.",
			3, 0, 1, 1)

static func woodsmans_hatchet() -> Dictionary:
	return make("woodsmans_hatchet", "Woodsman's Hatchet",
			"Not made for this. It does not know the difference.", 4, 0, 1, -1)

static func chapel_censer() -> Dictionary:
	return make("chapel_censer", "Chapel Censer",
			"It still smells of the service. Swung, it argues.",
			0, 3, 1, 0, "", false, 1)


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

static func steel_longsword() -> Dictionary:
	return make("steel_longsword", "Steel Longsword",
			"What the iron sword was trying to be.", 8, 0, 2)

static func fire_sword() -> Dictionary:
	return make("fire_sword", "Fire Sword",
			"The edge holds a coal that never goes out. Every swing carries it.",
			6, 0, 2, 0, "fire")

static func ice_sword() -> Dictionary:
	return make("ice_sword", "Ice Sword",
			"Cold enough that the wound closes wrong.", 6, 0, 2, 0, "ice")

static func thunder_sword() -> Dictionary:
	return make("thunder_sword", "Thunder Sword",
			"It stands your hair up before it lands.", 6, 0, 2, 0, "thunder")


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

static func mythril_sword() -> Dictionary:
	return make("mythril_sword", "Mythril Sword",
			"Lighter than it has any right to be. Nothing about it argues with your wrist.",
			15, 0, 3, 1)

static func silver_sword() -> Dictionary:
	return make("silver_sword", "Silver Sword",
			"Silver was always the metal they buried things with. It expels rather than cuts.",
			12, 0, 3, 0, Affinity.LIGHT)

static func obsidian_edge() -> Dictionary:
	return make("obsidian_edge", "Obsidian Edge",
			"A glass edge one atom wide, and the dark comes along for free.",
			14, 0, 3, 0, Affinity.DARK)

static func flamberge() -> Dictionary:
	return make("flamberge", "Flamberge",
			"The waved blade was for show. What runs down it now is not.",
			14, 0, 3, -1, "fire")


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

static func diamond_sword() -> Dictionary:
	return make("diamond_sword", "Diamond Sword",
			"Nothing down here has managed to blunt it yet.", 26, 0, 4)

static func rimefang_greatsword() -> Dictionary:
	return make("rimefang_greatsword", "Rimefang Greatsword",
			"Two hands, and the air in front of it goes white.",
			20, 0, 4, -2, "ice")

# The one weapon no orb will sell. It turns up in the deep, or not at all.
static func excalibur() -> Dictionary:
	return make("excalibur", "Excalibur",
			"It was in a stone, and then it was in a lake, and now it is down here with you.",
			24, 10, 4, 0, Affinity.LIGHT, true)


static func all() -> Array[Dictionary]:
	return [rusty_dagger(), iron_sword(), hazel_wand(),
			bronze_shortsword(), woodsmans_hatchet(), chapel_censer(),
			battle_axe(), silver_rapier(), magic_rod(), steel_longsword(),
			fire_sword(), ice_sword(), thunder_sword(),
			runed_glaive(), headsman_maul(), witchs_focus(),
			mythril_sword(), silver_sword(), obsidian_edge(), flamberge(),
			drakebone_sabre(), titans_cleaver(), sorcerers_crook(),
			diamond_sword(), rimefang_greatsword(), excalibur()]


# What an orb at this depth will sell: this tier and everything above it, minus
# anything marked found_only, which is on no shelf at any depth.
static func for_floor(floor_num: int) -> Array[Dictionary]:
	var tier: int = clampi((floor_num - 1) / 5 + 1, 1, 4)
	var out: Array[Dictionary] = []
	for w: Dictionary in all():
		if int(w["floor"]) <= tier and not bool(w.get("found_only", false)):
			out.append(w)
	return out
