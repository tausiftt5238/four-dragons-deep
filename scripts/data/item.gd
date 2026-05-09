# Item
# Registry for all consumable and scroll items.
# Use the static factory functions instead of building dictionaries by hand.
class_name Item


# ── Factories ─────────────────────────────────────────────────────────────────

static func consumable(id: String, name: String, desc: String,
		hp_restore: int, mp_restore: int, cures_status: String = "",
		inflicts_status: String = "") -> Dictionary:
	var d: Dictionary = {id=id, name=name, type="consumable", desc=desc,
			hp_restore=hp_restore, mp_restore=mp_restore, qty=1}
	if cures_status != "":
		d["cures_status"] = cures_status
	if inflicts_status != "":
		d["inflicts_status"] = inflicts_status
	return d


static func scroll(id: String, name: String, spell_id: String,
		spell_name: String, desc: String) -> Dictionary:
	return {id=id, name=name, type="scroll", desc=desc,
			teaches=spell_id, spell_name=spell_name, qty=1}


# ── Predefined consumables ────────────────────────────────────────────────────

static func health_potion() -> Dictionary:
	return consumable("health_potion", "Health Potion", "Restores 30 HP.", 30, 0)

static func hi_potion() -> Dictionary:
	return consumable("hi_potion", "Hi-Potion", "Restores 80 HP.", 80, 0)

static func ether() -> Dictionary:
	return consumable("ether", "Ether", "Restores 20 MP.", 0, 20)

static func antidote() -> Dictionary:
	return consumable("antidote", "Antidote", "Cures Poison.", 0, 0, "poison")

static func stimulant() -> Dictionary:
	return consumable("stimulant", "Stimulant", "Cures Paralysis.", 0, 0, "paralyzed")

static func echo_gem() -> Dictionary:
	return consumable("echo_gem", "Echo Gem", "Cures Silence.", 0, 0, "silence")

static func elixir_motion() -> Dictionary:
	return consumable("elixir_motion", "Elixir of Motion", "Cures Immobilize.", 0, 0, "immobilize")

static func panacea() -> Dictionary:
	return consumable("panacea", "Panacea", "Cures all ailments.", 0, 0, "all")


# ── Predefined scrolls ────────────────────────────────────────────────────────

static func scroll_cure() -> Dictionary:
	return scroll("scroll_cure", "Scroll of Cure", "cure", "Cure",
			"Teaches the Cure healing spell.")

static func scroll_venom() -> Dictionary:
	return scroll("scroll_venom", "Scroll of Venom", "venom", "Venom",
			"Teaches the Venom ailment spell.")

static func scroll_shock() -> Dictionary:
	return scroll("scroll_shock", "Scroll of Shock", "shock", "Shock",
			"Teaches the Shock ailment spell.")

static func scroll_mute() -> Dictionary:
	return scroll("scroll_mute", "Scroll of Mute", "mute", "Mute",
			"Teaches the Mute ailment spell.")

static func scroll_bind() -> Dictionary:
	return scroll("scroll_bind", "Scroll of Bind", "bind", "Bind",
			"Teaches the Bind ailment spell.")


# ── Predefined offensive throwables ──────────────────────────────────────────

static func venom_flask() -> Dictionary:
	return consumable("venom_flask", "Venom Flask", "Throws a vial of poison at an enemy.", 0, 0, "", "poison")

static func flash_powder() -> Dictionary:
	return consumable("flash_powder", "Flash Powder", "Blinds and paralyzes an enemy.", 0, 0, "", "paralyzed")

static func silence_dust() -> Dictionary:
	return consumable("silence_dust", "Silence Dust", "Silences an enemy, preventing spells.", 0, 0, "", "silence")

static func binding_web() -> Dictionary:
	return consumable("binding_web", "Binding Web", "Ensnares an enemy, immobilizing it.", 0, 0, "", "immobilize")


# ── Enemy drop table ──────────────────────────────────────────────────────────

static func drop_table() -> Array[Dictionary]:
	return [health_potion(), ether(), antidote(), stimulant(), echo_gem(),
			venom_flask(), flash_powder(), silence_dust(), binding_web()]
