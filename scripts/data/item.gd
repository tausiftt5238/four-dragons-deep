# Item
# Registry for all consumable and scroll items.
# Use the static factory functions instead of building dictionaries by hand.
class_name Item


# ── Factories ─────────────────────────────────────────────────────────────────

static func consumable(id: String, name: String, desc: String,
		hp_restore: int, mp_restore: int) -> Dictionary:
	return {id=id, name=name, type="consumable", desc=desc,
			hp_restore=hp_restore, mp_restore=mp_restore, qty=1}


static func scroll(id: String, name: String, spell_id: String,
		spell_name: String, desc: String) -> Dictionary:
	return {id=id, name=name, type="scroll", desc=desc,
			teaches=spell_id, spell_name=spell_name, qty=1}


# ── Predefined items ──────────────────────────────────────────────────────────

static func health_potion() -> Dictionary:
	return consumable("health_potion", "Health Potion", "Restores 30 HP.", 30, 0)

static func hi_potion() -> Dictionary:
	return consumable("hi_potion", "Hi-Potion", "Restores 80 HP.", 80, 0)

static func ether() -> Dictionary:
	return consumable("ether", "Ether", "Restores 20 MP.", 0, 20)

static func scroll_cure() -> Dictionary:
	return scroll("scroll_cure", "Scroll of Cure", "cure", "Cure",
			"Teaches the Cure healing spell.")


# ── Enemy drop table ──────────────────────────────────────────────────────────

static func drop_table() -> Array[Dictionary]:
	return [health_potion(), ether()]
