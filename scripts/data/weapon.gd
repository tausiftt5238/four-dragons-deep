# Weapon
# Registry for all weapon items.
# Use the static factory or the predefined accessors.
class_name Weapon


# ── Factory ───────────────────────────────────────────────────────────────────

static func make(id: String, name: String, desc: String,
		str_bonus: int, mag_bonus: int, floor: int, agl_pen: int = 0) -> Dictionary:
	return {id=id, name=name, type="weapon", desc=desc,
			str_bonus=str_bonus, mag_bonus=mag_bonus, agl_pen=agl_pen, floor=floor, qty=1}


# ── Predefined weapons ────────────────────────────────────────────────────────

static func rusty_dagger() -> Dictionary:
	return make("rusty_dagger", "Rusty Dagger",
			"A worn blade, better than bare hands.", 2, 0, 1)

static func iron_sword() -> Dictionary:
	return make("iron_sword", "Iron Sword",
			"A sturdy iron blade.  STR+5  AGL-1", 5, 0, 1, -1)

static func battle_axe() -> Dictionary:
	return make("battle_axe", "Battle Axe",
			"Powerful but heavy.  STR+7  AGL-1", 7, 0, 2, -1)

static func magic_rod() -> Dictionary:
	return make("magic_rod", "Magic Rod",
			"Channels arcane power.  MAG+5", 0, 5, 3)
