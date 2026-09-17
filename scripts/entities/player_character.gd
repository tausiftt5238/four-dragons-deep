# PlayerCharacter
# The player's RPG identity. Owns inventory, accessory slots, known spells,
# and gold. HP/MP persist across encounters; manage them carefully.
class_name PlayerCharacter extends CharacterSheet

const DISPLAY_NAME: String = "Hero"

var gold: int = 200

# What he is carrying into the dark: a weapon, a worn piece, and two trinkets.
# Empty dict means the slot is empty.
var equipped_weapon: Dictionary = {}
var equipped_armor:  Dictionary = {}

const ACCESSORY_SLOTS: int = 2
var equipped_accessories: Array[Dictionary] = []

# Every spell he has learned. Looked up in Spell.DATA for display and cost.
var known_spells: Array[String] = []

# The spells he actually carries into a battle. Knowing a spell and having it
# to hand are different things — the loadout is the choice, and it is made in
# the menu rather than mid-fight.
# Six entries is what the battle menu shows without scrolling, and Attack is
# always one of them — so five spells, and six items on their own belt.
const SPELL_SLOTS: int = 4
var equipped_spells: Array[String] = []

# Item ids on the belt. Only these reach a battle; the rest stay in the pack.
const ITEM_SLOTS: int = 6
var equipped_items: Array[String] = []


func is_equipped(spell_id: String) -> bool:
	return spell_id in equipped_spells


func has_free_slot() -> bool:
	return equipped_spells.size() < SPELL_SLOTS


# Returns false when every slot is already taken.
func equip_spell(spell_id: String) -> bool:
	if is_equipped(spell_id) or not has_free_slot():
		return false
	equipped_spells.append(spell_id)
	return true


func unequip_spell(spell_id: String) -> void:
	equipped_spells.erase(spell_id)


func is_item_equipped(item_id: String) -> bool:
	return item_id in equipped_items


func has_free_item_slot() -> bool:
	return equipped_items.size() < ITEM_SLOTS


func equip_item(item_id: String) -> bool:
	if is_item_equipped(item_id) or not has_free_item_slot():
		return false
	equipped_items.append(item_id)
	return true


func unequip_item(item_id: String) -> void:
	equipped_items.erase(item_id)


# The belt as it stands right now: equipped ids that are still in the pack,
# in slot order. This is exactly what the battle menu offers.
func belt() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for item_id: String in equipped_items:
		for item: Dictionary in inventory:
			if item["id"] == item_id and int(item.get("qty", 0)) > 0:
				out.append(item)
				break
	return out

# Every demon he has bound. The rolodex.
var recruited: Array[String] = []

# The level each one was bound at. A demon never levels, so a Bat talked down
# on floor three is a level-four Bat for the rest of the run however deep you
# take it — which is exactly what makes selling it on to fund a deeper one a
# real decision rather than bookkeeping.
var bound_level: Dictionary = {}


# Rebuilds a bound demon at the level it was caught, not at some default.
func bound_demon(demon_name: String) -> Enemy:
	return Enemy.make_at_level(demon_name, int(bound_level.get(demon_name, 1)))

# The ones he actually walks in with, in slot order. Chosen in the menu before
# a fight rather than assembled mid-battle — CombatScene.MAX_PARTY - 1 of them,
# since the detective takes the first slot himself.
const ACTIVE_SLOTS: int = 3
var active_demons: Array[String] = []


func is_active(demon_name: String) -> bool:
	return demon_name in active_demons


func has_free_demon_slot() -> bool:
	return active_demons.size() < ACTIVE_SLOTS


func activate_demon(demon_name: String) -> bool:
	if is_active(demon_name) or not has_free_demon_slot() \
			or demon_name not in recruited:
		return false
	active_demons.append(demon_name)
	return true


func deactivate_demon(demon_name: String) -> void:
	active_demons.erase(demon_name)


# Struck off the rolodex for good — sold at an orb. The level goes with it:
# remember_recruit keeps the best copy ever bound, so leaving the old level
# behind would hand a later, weaker recruit the sold demon's strength for free.
func release_demon(demon_name: String) -> void:
	recruited.erase(demon_name)
	active_demons.erase(demon_name)
	bound_level.erase(demon_name)


# How many demons can answer to him at once, summoned and benched together.
# Past this a new one has to be paid off, or something sold at an orb first.
const ROSTER_SIZE: int = 6


# Room for one more name — or this one is already on the list.
func can_bind(demon_name: String) -> bool:
	return demon_name in recruited or recruited.size() < ROSTER_SIZE


# Newly bound demons take a free slot on their own, so a first recruit is
# usable without a trip to the menu. A full roster turns the demon away.
func remember_recruit(demon_name: String, lv: int = 1) -> void:
	if not can_bind(demon_name):
		return
	if demon_name not in recruited:
		recruited.append(demon_name)
	# Keep the best one ever bound: re-catching a weaker copy should never
	# downgrade what is already in the rolodex.
	bound_level[demon_name] = maxi(int(bound_level.get(demon_name, 0)), maxi(1, lv))
	activate_demon(demon_name)

# Nobody walks into their first case empty-handed. A first-floor demon, not a
# strong one — since demons never level, a powerful gift would stay powerful and
# flatten the whole run. One demon is already bound,
# which is also what makes the opening floors survivable — a lone detective
# against a pack of three loses on action economy no matter how well he reads
# the affinity chart.
const STARTING_DEMON: String = "Cave Bat"

# Enemy names encountered at least once in combat (bestiary unlock).
var encountered_enemies: Array[String] = []

# Enemy names whose affinity chart he has read with Analyze. Meeting something
# records that it exists; only Analyze records what it is made of.
var analyzed: Array[String] = []


func has_analyzed(enemy_name: String) -> bool:
	return enemy_name in analyzed


func record_analysis(enemy_name: String) -> void:
	if enemy_name not in analyzed:
		analyzed.append(enemy_name)

# Passive skills gained at level-up.
var passive_skills: Array[String] = []

# Inventory: Array of item dicts. Consumables stack via the qty field.
var inventory: Array[Dictionary] = []


func _ready() -> void:
	lv  = 1
	str = 5
	def = 4
	mag = 2
	agl = 3
	luk = 3
	exp = 0
	exp_to_next = 100
	compute_max_hp()
	compute_max_mp()

	known_spells    = ["ember"]
	equipped_spells = ["ember"]
	equipped_items  = []
	equipped_weapon = {}
	equipped_armor  = {}
	equipped_accessories = []
	recruited       = [STARTING_DEMON]
	bound_level     = {STARTING_DEMON: 2}
	active_demons   = [STARTING_DEMON]

	# He is human. No resistances of his own, and the cold gets through —
	# which is what makes putting him in front of anything a real decision.
	affinities = {Affinity.PHYS: Affinity.NORMAL, "ice": Affinity.WEAK}


# Gear is layered over the innate chart. Anything worn can cancel a weakness or
# open one, and no further: nothing a person straps on makes them drink fire.
# A resistance beats a vulnerability wherever they collide, so a charm that
# protects and a breastplate that exposes leave him merely protected rather
# than quietly doomed.
func affinity_of(element: String) -> String:
	if element == "":
		return Affinity.NORMAL
	if equipped_armor.get("resist_element", "") == element:
		return Affinity.RESIST
	for acc: Dictionary in equipped_accessories:
		if acc.get("resist_element", "") == element:
			return Affinity.RESIST
	if equipped_armor.get("weakness", "") == element:
		return Affinity.WEAK
	for acc2: Dictionary in equipped_accessories:
		if acc2.get("weak_element", "") == element:
			return Affinity.WEAK
	return affinities.get(element, Affinity.NORMAL) as String


# ── Weapon and armour ─────────────────────────────────────────────────────────

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


# ── Accessories ───────────────────────────────────────────────────────────────

func is_accessory_equipped(item_id: String) -> bool:
	for acc: Dictionary in equipped_accessories:
		if acc.get("id", "") == item_id:
			return true
	return false


func has_free_accessory_slot() -> bool:
	return equipped_accessories.size() < ACCESSORY_SLOTS


# Returns false when both slots are already taken, so the caller can say so.
func equip_accessory(item: Dictionary) -> bool:
	if not has_free_accessory_slot() or is_accessory_equipped(item.get("id", "") as String):
		return false
	equipped_accessories.append(item)
	inventory.erase(item)
	return true


func unequip_accessory(item_id: String) -> void:
	for acc: Dictionary in equipped_accessories:
		if acc.get("id", "") == item_id:
			equipped_accessories.erase(acc)
			inventory.append(acc)
			return


func _accessory_sum(key: String) -> int:
	var total: int = 0
	for acc: Dictionary in equipped_accessories:
		total += int(acc.get(key, 0))
	return total


# ── Effective stats (base + what he is carrying) ──────────────────────────────

func effective_str() -> int:
	return maxi(1, str + int(equipped_weapon.get("str_bonus", 0))
			+ _accessory_sum("str_bonus"))

func effective_def() -> int:
	return maxi(0, def + int(equipped_armor.get("def_bonus", 0))
			+ int(equipped_weapon.get("def_bonus", 0))
			+ _accessory_sum("def_bonus"))

func effective_mag() -> int:
	return maxi(1, mag + int(equipped_weapon.get("mag_bonus", 0))
			+ _accessory_sum("mag_bonus"))

# Weight is paid in agility, and a heavy weapon and heavy armour both charge.
func effective_agl() -> int:
	return maxi(1, agl + int(equipped_weapon.get("agl_pen", 0))
			+ int(equipped_armor.get("agl_pen", 0)) + _accessory_sum("agl_bonus"))

func effective_luk() -> int:
	return maxi(1, luk + _accessory_sum("luk_bonus"))


# What an ordinary swing is scored as. Most weapons are phys; an elemental one
# replaces that outright rather than adding to it, so the chart still gets a
# single answer.
func attack_element() -> String:
	var el: String = equipped_weapon.get("attack_element", "") as String
	return el if el != "" else Affinity.PHYS


func battle_agility() -> int:
	return effective_agl()


func battle_luck() -> int:
	return effective_luk()


# ── Inventory management ──────────────────────────────────────────────────────

func add_item(item: Dictionary, count: int = 1) -> void:
	if item["type"] == "consumable" or item["type"] == "scroll":
		for existing in inventory:
			if existing["id"] == item["id"]:
				existing["qty"] += count
				return
	item["qty"] = count
	inventory.append(item)
	# A new consumable takes a free belt slot on its own, so the early game
	# never needs a trip to the menu before the potion is usable.
	if item["type"] == "consumable":
		equip_item(item["id"] as String)


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
			if equip_spell(spell_id):
				return "Learned %s!" % item.get("spell_name", spell_id)
			return "Learned %s! Equip it in the menu — all %d slots are full." % [
					item.get("spell_name", spell_id), SPELL_SLOTS]
	return ""


func sort_inventory(mode: String = "type") -> void:
	var type_order: Dictionary = {consumable=0, scroll=1, weapon=2, armor=3, accessory=4}
	inventory.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if mode == "type":
			var ta: int = type_order.get(a["type"], 99)
			var tb: int = type_order.get(b["type"], 99)
			if ta != tb:
				return ta < tb
		return (a["name"] as String) < (b["name"] as String)
	)


