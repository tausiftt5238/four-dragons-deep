# Armor
# Registry for all armor items.
# Use the static factory or the predefined accessors.
class_name Armor


# ── Factory ───────────────────────────────────────────────────────────────────

static func make(id: String, name: String, desc: String,
		def_bonus: int, floor: int, agl_pen: int = 0) -> Dictionary:
	return {id=id, name=name, type="armor", desc=desc,
			def_bonus=def_bonus, agl_pen=agl_pen, floor=floor, qty=1}


# ── Predefined armors ─────────────────────────────────────────────────────────

static func leather_armor() -> Dictionary:
	return make("leather_armor", "Leather Armor", "Light but dependable.  DEF+3", 3, 1)

static func leather_vest() -> Dictionary:
	return make("leather_vest", "Leather Vest", "Light protection.  DEF+3", 3, 1)

static func chain_mail() -> Dictionary:
	return make("chain_mail", "Chain Mail", "Solid protection.  DEF+6  AGL-1", 6, 2, -1)

static func plate_armor() -> Dictionary:
	return make("plate_armor", "Plate Armor", "Heavy protection.  DEF+10  AGL-2", 10, 3, -2)
