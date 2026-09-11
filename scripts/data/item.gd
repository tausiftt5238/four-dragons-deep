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


static func scroll(id: String, name: String, spell_id: String,
		spell_name: String, desc: String, floor: int) -> Dictionary:
	return {id=id, name=name, type="scroll", desc=desc,
			teaches=spell_id, spell_name=spell_name, floor=floor, qty=1}


static func elemental_throwable(id: String, name: String, desc: String,
		element: String, dmg: int, floor: int) -> Dictionary:
	return {id=id, name=name, type="consumable", desc=desc,
			hp_restore=0, mp_restore=0, floor=floor, qty=1, element=element, dmg=dmg}


# ── Predefined consumables ────────────────────────────────────────────────────

static func health_potion() -> Dictionary:
	return consumable("health_potion", "Health Potion", "Restores 30 HP.", 30, 0, 1)

static func hi_potion() -> Dictionary:
	return consumable("hi_potion", "Hi-Potion", "Restores 80 HP.", 80, 0, 2)

static func ether() -> Dictionary:
	return consumable("ether", "Ether", "Restores 20 MP.", 0, 20, 1)

static func antidote() -> Dictionary:
	return consumable("antidote", "Antidote", "Cures Poison.", 0, 0, 1, "poison")

static func stimulant() -> Dictionary:
	return consumable("stimulant", "Stimulant", "Cures Paralysis.", 0, 0, 1, "paralyzed")

static func echo_gem() -> Dictionary:
	return consumable("echo_gem", "Echo Gem", "Cures Silence.", 0, 0, 1, "silence")

static func elixir_motion() -> Dictionary:
	return consumable("elixir_motion", "Elixir of Motion", "Cures Immobilize.", 0, 0, 1, "immobilize")

static func panacea() -> Dictionary:
	return consumable("panacea", "Panacea", "Cures all ailments.", 0, 0, 4, "all")


# ── Predefined scrolls ────────────────────────────────────────────────────────

static func scroll_cure() -> Dictionary:
	return scroll("scroll_cure", "Scroll of Cure", "cure", "Cure",
			"Teaches the Cure healing spell.", 1)

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

static func scroll_fira() -> Dictionary:
	return scroll("scroll_fira", "Scroll of Fira", "fira", "Fira",
			"Teaches the Fira fire spell.", 3)

static func scroll_thundara() -> Dictionary:
	return scroll("scroll_thundara", "Scroll of Thundara", "thundara", "Thundara",
			"Teaches the Thundara lightning spell.", 3)

static func scroll_blizzara() -> Dictionary:
	return scroll("scroll_blizzara", "Scroll of Blizzara", "blizzara", "Blizzara",
			"Teaches the Blizzara ice spell.", 4)


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

static func scroll_banish() -> Dictionary:
	return scroll("scroll_banish", "Scroll of Banish", "banish", "Banish",
			"Teaches Banish — expels one enemy outright, or does nothing.", 4)

static func scroll_consign() -> Dictionary:
	return scroll("scroll_consign", "Scroll of Consign", "consign", "Consign",
			"Teaches Consign — unmakes one enemy outright, or does nothing.", 4)

static func scroll_blunt() -> Dictionary:
	return scroll("scroll_blunt", "Scroll of Blunt", "blunt", "Blunt",
			"Teaches Blunt — lowers every enemy's attack.", 3)

static func scroll_sunder() -> Dictionary:
	return scroll("scroll_sunder", "Scroll of Sunder", "sunder", "Sunder",
			"Teaches Sunder — lowers every enemy's defence.", 4)

static func scroll_mire() -> Dictionary:
	return scroll("scroll_mire", "Scroll of Mire", "mire", "Mire",
			"Teaches Mire — lowers every enemy's agility.", 4)

static func scroll_purge() -> Dictionary:
	return scroll("scroll_purge", "Scroll of Purge", "purge", "Purge",
			"Teaches Purge — strips every enemy buff.", 5)

static func scroll_steady() -> Dictionary:
	return scroll("scroll_steady", "Scroll of Steady", "steady", "Steady",
			"Teaches Steady — clears the party's debuffs.", 5)


# ── Predefined offensive throwables ──────────────────────────────────────────

static func venom_flask() -> Dictionary:
	return consumable("venom_flask", "Venom Flask", "Throws a vial of poison at an enemy.", 0, 0, 1, "", "poison")

static func flash_powder() -> Dictionary:
	return consumable("flash_powder", "Flash Powder", "Blinds and paralyzes an enemy.", 0, 0, 2, "", "paralyzed")

static func silence_dust() -> Dictionary:
	return consumable("silence_dust", "Silence Dust", "Silences an enemy, preventing spells.", 0, 0, 2, "", "silence")

static func binding_web() -> Dictionary:
	return consumable("binding_web", "Binding Web", "Ensnares an enemy, immobilizing it.", 0, 0, 3, "", "immobilize")


# ── Elemental throwables ──────────────────────────────────────────────────────

static func fire_bomb() -> Dictionary:
	return elemental_throwable("fire_bomb", "Fire Bomb", "Hurls a flaming explosive. Effective vs. fire-weak foes.", "fire", 20, 2)

static func ice_shard() -> Dictionary:
	return elemental_throwable("ice_shard", "Ice Shard", "Throws a razor-sharp sliver of ice. Effective vs. ice-weak foes.", "ice", 20, 3)

static func thunder_bead() -> Dictionary:
	return elemental_throwable("thunder_bead", "Thunder Bead", "Discharges a crackling orb. Effective vs. thunder-weak foes.", "thunder", 20, 3)


# ── Enemy drop table ──────────────────────────────────────────────────────────

static func drop_table() -> Array[Dictionary]:
	return [
		health_potion(), ether(), antidote(), stimulant(), echo_gem(),
		venom_flask(), flash_powder(), silence_dust(), binding_web(),
		fire_bomb(), ice_shard(), thunder_bead(),
		scroll_fira(), scroll_thundara(), scroll_blizzara(),
		scroll_whet(), scroll_ward(), scroll_quicken(), scroll_stoke(),
		scroll_damp(), scroll_banish(), scroll_consign(),
		scroll_blunt(), scroll_sunder(), scroll_mire(),
		scroll_purge(), scroll_steady(),
	]
