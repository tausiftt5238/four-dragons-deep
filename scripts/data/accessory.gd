# Accessory
# The small things carried alongside a weapon and a worn piece. Two slots, so
# every trinket taken is another one left behind.
#
# Fields: str_bonus / def_bonus / mag_bonus / agl_bonus / luk_bonus, plus an
# optional single-element `resist_element` or `weak_element`. Nothing here
# grants DRAIN or REPEL — those belong to demons, not to objects a person owns.
#
# A ward trinket carries `wards`: the ailments it keeps off the hero, or "all".
# No stats on those: the slot is the price. A `found_only` piece is on no shelf.
class_name Accessory

# What a ward trinket costs at an orb. Its depth tier says nothing about what
# it is worth to someone the Thunder Dragon keeps paralysing.
const WARD_PRICE: int = 400


static func make(id: String, name: String, desc: String, floor: int,
		str_bonus: int = 0, def_bonus: int = 0, mag_bonus: int = 0,
		agl_bonus: int = 0, luk_bonus: int = 0,
		resist_element: String = "", weak_element: String = "") -> Dictionary:
	return {id=id, name=name, type="accessory", desc=desc, floor=floor, qty=1,
			str_bonus=str_bonus, def_bonus=def_bonus, mag_bonus=mag_bonus,
			agl_bonus=agl_bonus, luk_bonus=luk_bonus,
			resist_element=resist_element, weak_element=weak_element}


# One ward against one ailment, or every one. Final Fantasy's protection
# accessories, in this dungeon's voice; the Ribbon keeps its name.
static func ward(id: String, name: String, desc: String, floor: int,
		wards: Array, found_only: bool = false) -> Dictionary:
	var d: Dictionary = make(id, name, desc, floor)
	d["wards"] = wards
	if found_only:
		d["found_only"] = true
	else:
		d["price"] = WARD_PRICE
	return d


# ── The wards ─────────────────────────────────────────────────────────────────

static func star_pendant() -> Dictionary:
	return ward("star_pendant", "Star Pendant",
			"A tin star on a cord. Venom finds nothing in you to hold.", 2,
			[Status.POISON])

static func silver_specs() -> Dictionary:
	return ward("silver_specs", "Silver Specs",
			"Round lenses rimmed in silver. Whatever is thrown in your eyes slides off.", 2,
			[Status.BLIND])

static func echo_bangle() -> Dictionary:
	return ward("echo_bangle", "Echo Bangle",
			"A ring of tiny bells. However it is smothered, your voice carries.", 2,
			[Status.SILENCE])

static func grounding_cord() -> Dictionary:
	return ward("grounding_cord", "Grounding Cord",
			"Braided copper trailing to the floor. The current runs past you.", 2,
			[Status.PARALYZED])

static func ribbon() -> Dictionary:
	return ward("ribbon", "Ribbon",
			"A plain ribbon. Nobody can say why it works, and it always has.", 4,
			["all"], true)


# Whether a worn trinket keeps this ailment off.
static func wards_off(acc: Dictionary, status_id: String) -> bool:
	var w: Array = acc.get("wards", []) as Array
	return "all" in w or status_id in w


# ── Bought, not found ─────────────────────────────────────────────────────────

# Nothing gets the jump on its wearer (CombatScene.can_ambush), however slow
# they are. On the first shelf so a player who keeps being ambushed has an
# answer, and priced so it is a decision on floor one rather than a given.
const SENTRY_PRICE: int = 500

static func sentrys_whistle() -> Dictionary:
	var d: Dictionary = make("sentrys_whistle", "Sentry's Whistle",
			"Blown at the first footstep. Nothing in the dark gets the first move on you.", 1)
	d["first_strike"] = true
	d["price"] = SENTRY_PRICE
	return d


# Walking brings MP back only while this is worn (Main._recover_mp_on_step):
# a slice of the pool a step, fifty steps from empty to full. Without it MP
# comes back at orbs and from ethers, and nowhere else.
const WELL_PRICE: int = 100

static func wellspring_charm() -> Dictionary:
	var d: Dictionary = make("wellspring_charm", "Wellspring Charm",
			"A wet stone on a cord. Every step you take, a little of what you spent comes back.", 1)
	d["walk_mp"] = true
	d["price"] = WELL_PRICE
	return d


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

static func ironwood_bracer() -> Dictionary:
	return make("ironwood_bracer", "Ironwood Bracer",
			"Cut from a tree that grew through a fence and kept the fence.", 1,
			1, 2)

static func hummingbird_feather() -> Dictionary:
	return make("hummingbird_feather", "Hummingbird Feather",
			"Weightless, and it makes everything else you carry feel like a decision.",
			2, 0, -1, 0, 3)

static func scrying_mirror() -> Dictionary:
	return make("scrying_mirror", "Scrying Mirror",
			"You are in it twice and you only stepped up once.", 3,
			0, 0, 4, 0, 0, Affinity.LIGHT)

static func serpents_tooth() -> Dictionary:
	return make("serpents_tooth", "Serpent's Tooth",
			"Sharper than you are. It wants something in return.", 3,
			5, 0, 0, 0, 0, "", Affinity.DARK)

static func kings_signet() -> Dictionary:
	return make("kings_signet", "King's Signet",
			"Whoever wore it last is further down than you have been.", 4,
			2, 2, 2, 2, 2)

static func thiefs_lantern() -> Dictionary:
	return make("thiefs_lantern", "Thief's Lantern",
			"Shuttered on three sides. It shows you the floor and nothing else.", 4,
			0, 0, 0, 2, 3)


static func all() -> Array[Dictionary]:
	return [cold_iron_ring(), dowsing_pendulum(), thin_brass_bell(),
			ironwood_bracer(),
			salt_line(), bone_rosary(), copper_coil(), hummingbird_feather(),
			ash_phylactery(), widows_lens(), gravediggers_gloves(),
			scrying_mirror(), serpents_tooth(),
			ferrymans_coin(), kings_signet(), thiefs_lantern(),
			star_pendant(), silver_specs(), echo_bangle(), grounding_cord(),
			ribbon(), sentrys_whistle(), wellspring_charm()]


# What a floor could plausibly turn up: this tier and everything above it.
static func for_floor(floor_num: int) -> Array[Dictionary]:
	var tier: int = clampi((floor_num - 1) / 5 + 1, 1, 4)
	var out: Array[Dictionary] = []
	for a: Dictionary in all():
		if int(a["floor"]) <= tier and not bool(a.get("found_only", false)):
			out.append(a)
	return out
