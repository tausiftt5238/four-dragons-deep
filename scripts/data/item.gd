# Item
# Registry for all consumable and scroll items.
# Use the static factory functions instead of building dictionaries by hand.
class_name Item


# ── Factories ─────────────────────────────────────────────────────────────────

static func consumable(id: String, name: String, desc: String,
		hp_restore: int, mp_restore: int, cures_status: String = "") -> Dictionary:
	var d: Dictionary = {id=id, name=name, type="consumable", desc=desc,
			hp_restore=hp_restore, mp_restore=mp_restore, qty=1}
	if cures_status != "":
		d["cures_status"] = cures_status
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


# ── Enemy drop table ──────────────────────────────────────────────────────────

static func drop_table() -> Array[Dictionary]:
	return [health_potion(), ether(), antidote(), stimulant(), echo_gem()]
