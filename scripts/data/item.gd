# Item
# Registry for all consumable and scroll items.
# Use the static factory functions instead of building dictionaries by hand.
class_name Item


# ── Factories ─────────────────────────────────────────────────────────────────

static func consumable(id: String, name: String, desc: String,
		hp_restore: int, mp_restore: int, floor: int,
		cures_status: String = "", inflicts_status: String = "") -> Dictionary:
	var d: Dictionary = {id=id, name=name, type="consumable", desc=desc,
			hp_restore=hp_restore, mp_restore=mp_restore, floor=floor, qty=1}
	if cures_status != "":
		d["cures_status"] = cures_status
	if inflicts_status != "":
		d["inflicts_status"] = inflicts_status
	return d


# `floor` is both the depth that unlocks it and, normally, the price tier. A
# scroll that should cost far more than its depth suggests carries an explicit
# `price` instead — the dispels do, because they answer a whole stacked line and
# a cheap one would make stacking pointless for either side.
static func scroll(id: String, name: String, spell_id: String,
		spell_name: String, desc: String, floor: int, price: int = 0) -> Dictionary:
	var d: Dictionary = {id=id, name=name, type="scroll", desc=desc,
			teaches=spell_id, spell_name=spell_name, floor=floor, qty=1}
	if price > 0:
		d["price"] = price
	return d


static func elemental_throwable(id: String, name: String, desc: String,
		element: String, dmg: int, floor: int) -> Dictionary:
	return {id=id, name=name, type="consumable", desc=desc,
			hp_restore=0, mp_restore=0, floor=floor, qty=1, element=element, dmg=dmg}


# ── Predefined consumables ────────────────────────────────────────────────────

static func health_potion() -> Dictionary:
	return consumable("health_potion", "Health Potion",
			"Restores 30 HP.",
			30, 0, 1)

static func hi_potion() -> Dictionary:
	return consumable("hi_potion", "Hi-Potion",
			"Restores 80 HP.",
			80, 0, 2)

static func ether() -> Dictionary:
	return consumable("ether", "Ether",
			"Restores 20 MP.",
			0, 20, 1)

static func antidote() -> Dictionary:
	return consumable("antidote", "Antidote",
			"Cures Poison.",
			0, 0, 1, "poison")

static func stimulant() -> Dictionary:
	return consumable("stimulant", "Stimulant",
			"Cures Paralysis.",
			0, 0, 1, "paralyzed")

static func echo_gem() -> Dictionary:
	return consumable("echo_gem", "Echo Gem",
			"Cures Silence.",
			0, 0, 1, "silence")

static func elixir_motion() -> Dictionary:
	return consumable("elixir_motion", "Elixir of Motion",
			"Cures Immobilize.",
			0, 0, 1, "immobilize")

static func panacea() -> Dictionary:
	return consumable("panacea", "Panacea",
			"Cures all ailments.",
			0, 0, 4, "all")


# ── Predefined scrolls ────────────────────────────────────────────────────────

static func scroll_cure() -> Dictionary:
	return scroll("scroll_cure", "Scroll of Cure", "cure", "Cure",
			"Teaches the Cure healing spell.", 1)

static func scroll_cura() -> Dictionary:
	return scroll("scroll_cura", "Scroll of Cura", "cura", "Cura",
			"Teaches the Cura healing spell.", 7)

static func scroll_curaga() -> Dictionary:
	return scroll("scroll_curaga", "Scroll of Curaga", "curaga", "Curaga",
			"Teaches the Curaga healing spell.", 13)

static func scroll_venom() -> Dictionary:
	return scroll("scroll_venom", "Scroll of Venom", "venom", "Venom",
			"Teaches the Venom ailment spell.", 2)

static func scroll_shock() -> Dictionary:
	return scroll("scroll_shock", "Scroll of Shock", "shock", "Shock",
			"Teaches the Shock ailment spell.", 2)

static func scroll_mute() -> Dictionary:
	return scroll("scroll_mute", "Scroll of Mute", "mute", "Mute",
			"Teaches the Mute ailment spell.", 3)

static func scroll_bind() -> Dictionary:
	return scroll("scroll_bind", "Scroll of Bind", "bind", "Bind",
			"Teaches the Bind ailment spell.", 3)

# One scroll per elemental spell, built straight off Spell.DATA so a scroll can
# never name a spell that no longer exists. `floor` is only the price tier — the
# whole grid is learnable from the first floor, and what gates the wide ones is
# what they cost to buy and to cast.
static func spell_scroll(spell_id: String, floor: int) -> Dictionary:
	var d: Dictionary = Spell.get_data(spell_id)
	var sname: String = d.get("name", spell_id) as String
	return scroll("scroll_" + spell_id, "Scroll of " + sname, spell_id, sname,
			d.get("desc", "") as String, floor)


# Two axes, one table. Reach sets the price within a rung — one demon is cheap,
# the whole room is not — and the rung sets the depth you have to have reached
# before an orb will sell it at all. Nothing is ever taken off the shelf, so a
# late orb still stocks Ember for the player who wants a cheap opener.
const ELEMENTAL_SCROLLS: Dictionary = {
	# Rung one
	"ember": 1, "rime": 1, "arc": 1,
	"cinderfall": 2, "hailfall": 2, "forkfall": 2,
	"pyre": 4, "whiteout": 4, "thunderhead": 4,
	"banish": 3, "consign": 3,
	"winnow": 5, "cull": 5,
	"daybreak": 6, "nightfall": 6,

	# Rung two
	"blaze": 6, "frostbite": 6, "bolt": 6,
	"firestorm": 8, "blizzard": 8, "thunderstorm": 8,
	"inferno": 10, "deepwinter": 10, "tempest": 10,
	"exile": 8, "erase": 8,
	"scour": 10, "reap": 10,
	"zenith": 12, "eclipse": 12,

	# Rung three
	"immolate": 12, "glaciate": 12, "levin": 12,
	"ashfall": 14, "shardfall": 14, "skyfall": 14,
	"worldfire": 16, "killingfrost": 16, "stormcrown": 16,
	"absolve": 14, "unmake": 14,
	"sunburst": 16, "harvest": 16,
	"whitehour": 18, "longnight": 18,
}


# Every scroll the depth reached has unlocked, cheapest rung first. This is the
# only way into an element the player did not start with, so an orb has to be
# able to sell all of it eventually.
static func scrolls_for_floor(floor_num: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for maker: Callable in SUPPORT_SCROLLS:
		var scroll_item: Dictionary = maker.call() as Dictionary
		if int(scroll_item["floor"]) <= floor_num:
			out.append(scroll_item)
	for spell_id: String in ELEMENTAL_SCROLLS:
		var gate: int = int(ELEMENTAL_SCROLLS[spell_id])
		if gate <= floor_num:
			out.append(spell_scroll(spell_id, gate))
	return out


# Healing, the four buffs, the four debuffs, the four ailments and the two
# dispels. None of these dropped anywhere an orb could reach before, which meant
# a run could finish without ever being able to learn Cure.
static var SUPPORT_SCROLLS: Array[Callable] = [
	scroll_cure, scroll_cura, scroll_curaga,
	scroll_whet, scroll_ward, scroll_quicken, scroll_stoke,
	scroll_blunt, scroll_sunder, scroll_mire, scroll_damp,
	scroll_venom, scroll_shock, scroll_mute, scroll_bind,
	scroll_purge, scroll_steady,
]


static func elemental_scrolls() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for spell_id: String in ELEMENTAL_SCROLLS:
		out.append(spell_scroll(spell_id, int(ELEMENTAL_SCROLLS[spell_id])))
	return out


# ── Support scrolls ───────────────────────────────────────────────────────────

static func scroll_whet() -> Dictionary:
	return scroll("scroll_whet", "Scroll of Whet", "whet", "Whet",
			"Teaches Whet — raises the party's attack.", 2)

static func scroll_ward() -> Dictionary:
	return scroll("scroll_ward", "Scroll of Ward", "ward", "Ward",
			"Teaches Ward — raises the party's defence.", 2)

static func scroll_quicken() -> Dictionary:
	return scroll("scroll_quicken", "Scroll of Quicken", "quicken", "Quicken",
			"Teaches Quicken — raises the party's agility.", 3)

static func scroll_stoke() -> Dictionary:
	return scroll("scroll_stoke", "Scroll of Stoke", "stoke", "Stoke",
			"Teaches Stoke — raises the party's magic.", 3)

static func scroll_damp() -> Dictionary:
	return scroll("scroll_damp", "Scroll of Damp", "damp", "Damp",
			"Teaches Damp — lowers every enemy's magic.", 4)

static func scroll_blunt() -> Dictionary:
	return scroll("scroll_blunt", "Scroll of Blunt", "blunt", "Blunt",
			"Teaches Blunt — lowers every enemy's attack.", 3)

static func scroll_sunder() -> Dictionary:
	return scroll("scroll_sunder", "Scroll of Sunder", "sunder", "Sunder",
			"Teaches Sunder — lowers every enemy's defence.", 4)

static func scroll_mire() -> Dictionary:
	return scroll("scroll_mire", "Scroll of Mire", "mire", "Mire",
			"Teaches Mire — lowers every enemy's agility.", 4)

# The dear ones. Everything above raises or lowers a single stage; these two
# take a whole side's worth back in one cast, which is the only real answer to a
# line that has spent three phases stacking. Priced to be saved for.
const DISPEL_PRICE: int = 1000

static func scroll_purge() -> Dictionary:
	return scroll("scroll_purge", "Scroll of Purge", "purge", "Purge",
			"Teaches Purge — strips the other side of everything it has raised.",
			8, DISPEL_PRICE)

static func scroll_steady() -> Dictionary:
	return scroll("scroll_steady", "Scroll of Steady", "steady", "Steady",
			"Teaches Steady — clears every penalty stacked on your own side.",
			8, DISPEL_PRICE)


# ── Predefined offensive throwables ──────────────────────────────────────────

static func venom_flask() -> Dictionary:
	return consumable("venom_flask", "Venom Flask",
			"Throws a vial of poison at an enemy.",
			0, 0, 1, "", "poison")

static func flash_powder() -> Dictionary:
	return consumable("flash_powder", "Flash Powder",
			"Blinds and paralyzes an enemy.",
			0, 0, 2, "", "paralyzed")

static func silence_dust() -> Dictionary:
	return consumable("silence_dust", "Silence Dust",
			"Silences an enemy, preventing spells.",
			0, 0, 2, "", "silence")

static func binding_web() -> Dictionary:
	return consumable("binding_web", "Binding Web",
			"Ensnares an enemy, immobilizing it.",
			0, 0, 3, "", "immobilize")


# ── Elemental throwables ──────────────────────────────────────────────────────

static func fire_bomb() -> Dictionary:
	return elemental_throwable("fire_bomb", "Fire Bomb",
			"Hurls a flaming explosive. Effective vs. fire-weak foes.",
			"fire", 20, 2)

static func ice_shard() -> Dictionary:
	return elemental_throwable("ice_shard", "Ice Shard",
			"Throws a razor-sharp sliver of ice. Effective vs. ice-weak foes.",
			"ice", 20, 3)

static func thunder_bead() -> Dictionary:
	return elemental_throwable("thunder_bead", "Thunder Bead",
			"Discharges a crackling orb. Effective vs. thunder-weak foes.",
			"thunder", 20, 3)


# ── Enemy drop table ──────────────────────────────────────────────────────────

static func drop_table() -> Array[Dictionary]:
	var out: Array[Dictionary] = [
		health_potion(), ether(), antidote(), stimulant(), echo_gem(),
		venom_flask(), flash_powder(), silence_dust(), binding_web(),
		fire_bomb(), ice_shard(), thunder_bead(),
		scroll_cure(), scroll_cura(),
		scroll_whet(), scroll_ward(), scroll_quicken(), scroll_stoke(),
		scroll_damp(), scroll_blunt(), scroll_sunder(), scroll_mire(),
		scroll_venom(), scroll_shock(), scroll_mute(), scroll_bind(),
	]
	out.append_array(elemental_scrolls())
	out.append_array(Accessory.all())
	out.append_array(Weapon.all())
	out.append_array(Armor.all())
	return out
