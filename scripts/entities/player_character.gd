# PlayerCharacter
# The player's RPG identity. Owns inventory, equipment slots, known spells,
# and gold. HP/MP persist across encounters; manage them carefully.
class_name PlayerCharacter extends CharacterSheet

const DISPLAY_NAME: String = "Hero"

var gold: int = 50

# Equipment — empty dict means nothing equipped.
var equipped_weapon: Dictionary = {}
var equipped_armor:  Dictionary = {}

# Learnable spell IDs. Looked up in Spell.DATA for display and cost.
var known_spells: Array[String] = []

# Inventory: Array of item dicts. Consumables stack via the qty field.
var inventory: Array[Dictionary] = []


func _ready() -> void:
	lv  = 1
	str = 5
	def = 4
	mag = 2
	agl = 3
	exp = 0
	exp_to_next = 100
	compute_max_hp()
	compute_max_mp()

	known_spells = ["fire"]

	# Starting gear — player begins with a rusty dagger pre-equipped.
	var dagger: Dictionary = Weapon.rusty_dagger()
	inventory.append(dagger)
	equip_weapon(dagger)

	add_item(Item.health_potion(), 2)
	add_item(Item.ether(), 1)
	add_item(Item.antidote(), 1)
	add_item(Item.stimulant(), 1)
	add_item(Item.venom_flask(), 1)
	add_item(Item.scroll_cure(), 1)

	add_item(Weapon.iron_sword())
	add_item(Armor.leather_armor())


# ── Effective stats (base + equipment bonuses) ────────────────────────────────

func effective_str() -> int:
	return str + equipped_weapon.get("str_bonus", 0)

func effective_def() -> int:
	return def + equipped_armor.get("def_bonus", 0)

func effective_mag() -> int:
	return mag + equipped_weapon.get("mag_bonus", 0)

func effective_agl() -> int:
	return agl + equipped_weapon.get("agl_pen", 0) + equipped_armor.get("agl_pen", 0)


# ── Inventory management ──────────────────────────────────────────────────────

func add_item(item: Dictionary, count: int = 1) -> void:
	if item["type"] == "consumable" or item["type"] == "scroll":
		for existing in inventory:
			if existing["id"] == item["id"]:
				existing["qty"] += count
				return
	item["qty"] = count
	inventory.append(item)


func remove_item(item: Dictionary, count: int = 1) -> void:
	if item.get("qty", 1) > count:
		item["qty"] -= count
	else:
		inventory.erase(item)


# Returns true if using this item would have any effect on the player's current state.
func can_use_item(item: Dictionary) -> bool:
	match item["type"]:
		"consumable":
			if item.get("hp_restore", 0) > 0 and hp < max_hp:
				return true
			if item.get("mp_restore", 0) > 0 and mp < max_mp:
				return true
			var cure: String = item.get("cures_status", "")
			if cure == "all":
				return not active_statuses.is_empty()
			if cure != "":
				return has_status(cure)
			return false
		"scroll":
			return item.get("teaches", "") not in known_spells
	return false


# Uses a consumable or scroll. Returns a human-readable result string.
func use_item(item: Dictionary) -> String:
	match item["type"]:
		"consumable":
			var msg: String = ""
			var hp_val: int  = item.get("hp_restore", 0)
			var mp_val: int  = item.get("mp_restore", 0)
			var cure: String = item.get("cures_status", "")
			if hp_val > 0:
				var before: int = hp
				heal(hp_val)
				msg += "Restored %d HP. " % (hp - before)
			if mp_val > 0:
				var before: int = mp
				restore_mp(mp_val)
				msg += "Restored %d MP. " % (mp - before)
			if cure == "all":
				active_statuses.clear()
				msg += "Cured all ailments."
			elif cure != "":
				if has_status(cure):
					remove_status(cure)
					msg += "Cured %s." % Status.get_data(cure).get("name", cure)
				else:
					msg += "Not afflicted."
			remove_item(item, 1)
			return msg.strip_edges()
		"scroll":
			var spell_id: String = item.get("teaches", "")
			if spell_id in known_spells:
				return "You already know %s." % item.get("spell_name", spell_id)
			known_spells.append(spell_id)
			remove_item(item, 1)
			return "Learned %s!" % item.get("spell_name", spell_id)
	return ""


func sort_inventory(mode: String = "type") -> void:
	var type_order: Dictionary = {consumable=0, scroll=1, weapon=2, armor=3}
	inventory.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if mode == "type":
			var ta: int = type_order.get(a["type"], 99)
			var tb: int = type_order.get(b["type"], 99)
			if ta != tb:
				return ta < tb
		return (a["name"] as String) < (b["name"] as String)
	)


# ── Equipment ─────────────────────────────────────────────────────────────────

func equip_weapon(item: Dictionary) -> void:
	if not equipped_weapon.is_empty():
		inventory.append(equipped_weapon)
	equipped_weapon = item
	inventory.erase(item)


func unequip_weapon() -> void:
	if not equipped_weapon.is_empty():
		inventory.append(equipped_weapon)
		equipped_weapon = {}


func equip_armor(item: Dictionary) -> void:
	if not equipped_armor.is_empty():
		inventory.append(equipped_armor)
	equipped_armor = item
	inventory.erase(item)


func unequip_armor() -> void:
	if not equipped_armor.is_empty():
		inventory.append(equipped_armor)
		equipped_armor = {}
