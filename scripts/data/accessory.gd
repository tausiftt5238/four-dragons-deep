# Accessory
# The only gear the detective carries. There are no weapons and no armour: he
# is not a soldier, he is a man who walks into other people's heads holding
# small objects that mean something. Two slots, so every trinket taken is
# another one left behind.
#
# Fields: str_bonus / def_bonus / mag_bonus / agl_bonus / luk_bonus, plus an
# optional single-element `resist_element` or `weak_element`. Nothing here
# grants DRAIN or REPEL — those belong to demons, not to objects a person owns.
class_name Accessory


static func make(id: String, name: String, desc: String, floor: int,
		str_bonus: int = 0, def_bonus: int = 0, mag_bonus: int = 0,
		agl_bonus: int = 0, luk_bonus: int = 0,
		resist_element: String = "", weak_element: String = "") -> Dictionary:
	return {id=id, name=name, type="accessory", desc=desc, floor=floor, qty=1,
			str_bonus=str_bonus, def_bonus=def_bonus, mag_bonus=mag_bonus,
			agl_bonus=agl_bonus, luk_bonus=luk_bonus,
			resist_element=resist_element, weak_element=weak_element}


# ── The trinkets ──────────────────────────────────────────────────────────────

static func cold_iron_ring() -> Dictionary:
	return make("cold_iron_ring", "Cold Iron Ring",
			"Iron that was never heated. Heavy on the hand.", 1, 2)

static func dowsing_pendulum() -> Dictionary:
	return make("dowsing_pendulum", "Dowsing Pendulum",
			"It swings before you decide to move it.", 1, 0, 0, 0, 0, 3)

static func thin_brass_bell() -> Dictionary:
	return make("thin_brass_bell", "Thin Brass Bell",
			"Too small to hear. Something answers it anyway.", 1, 0, 0, 0, 2, 1)

static func salt_line() -> Dictionary:
	return make("salt_line", "Pouch of Salt",
			"A line of it under the door. Old habit, still works.", 2,
			0, 1, 0, 0, 0, Affinity.DARK)

static func bone_rosary() -> Dictionary:
	return make("bone_rosary", "Bone Rosary",
			"Someone counted their way through something on these.", 2,
			0, 2, 0, 0, 0, Affinity.LIGHT)

static func copper_coil() -> Dictionary:
	return make("copper_coil", "Coil of Copper Wire",
			"Wound tight. It takes the current so you do not.", 2,
			0, 0, 2, 0, 0, "thunder")

static func ash_phylactery() -> Dictionary:
	return make("ash_phylactery", "Ash Phylactery",
			"A locket of someone's ashes. It has already burned once.", 3,
			0, 3, 0, 0, 0, "fire")

static func widows_lens() -> Dictionary:
	return make("widows_lens", "Widow's Lens",
			"Ground from a mourning brooch. You see more and move slower.", 3,
			0, 0, 3, -1)

static func gravediggers_gloves() -> Dictionary:
	return make("gravediggers_gloves", "Gravedigger's Gloves",
			"Stiff with work. Your hands are surer and no faster.", 3,
			3, 0, 0, -1)

static func ferrymans_coin() -> Dictionary:
	return make("ferrymans_coin", "Ferryman's Coin",
			"It was under a tongue. It is warm, and it should not be.", 4,
			0, 0, 0, 0, 4)


static func all() -> Array[Dictionary]:
	return [cold_iron_ring(), dowsing_pendulum(), thin_brass_bell(),
			salt_line(), bone_rosary(), copper_coil(),
			ash_phylactery(), widows_lens(), gravediggers_gloves(),
			ferrymans_coin()]


# What this floor could plausibly turn up.
static func for_floor(floor_num: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for a: Dictionary in all():
		if int(a["floor"]) <= floor_num:
			out.append(a)
	return out
