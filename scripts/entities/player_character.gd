# PlayerCharacter
# The player's RPG identity. Owns inventory, accessory slots, known spells,
# and gold. HP/MP persist across encounters; manage them carefully.
class_name PlayerCharacter extends CharacterSheet

const DISPLAY_NAME: String = "Hero"

# One drawing of him, used two ways. The battle row wants the whole figure; the
# menu wants a face. Rather than two files that can drift apart, the portrait is
# a window onto the same texture — head, shoulders and the hands at the bottom
# edge, which is as much as reads at 90 px.
const SPRITE: String = "res://resources/misc/Hero.png"
const PORTRAIT_REGION: Rect2 = Rect2(12, 0, 40, 40)


static func sprite() -> Texture2D:
	return load(SPRITE) as Texture2D


static func portrait() -> AtlasTexture:
	var a: AtlasTexture = AtlasTexture.new()
	a.atlas  = sprite()
	a.region = PORTRAIT_REGION
	return a

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

# The level each bound demon is at now. It starts at the level it was caught
# and climbs: a demon that fights alongside him grows into the run rather than
# falling behind it. Only bound demons do this — a wild one is whatever its
# floor makes it, and selling an outgrown demon on is still a real decision
# because what it fetches follows the level it has reached.
var bound_level: Dictionary = {}

# Exp banked toward each bound demon's next level.
var demon_exp: Dictionary = {}

# Stat points a demon has rolled on its own levels, per demon:
# {"str": n, "def": n, "mag": n, "agl": n}. Two per level, placed at random, so
# two Bats raised from the same floor are not the same Bat.
var demon_gains: Dictionary = {}

# What each bound demon can call on. One entry per skill:
#   {kind = "element", element = "fire", rung = 1, shape = "one"}
#   {kind = "support", id = "ward"}
# Raising a rung rewrites an entry in place, so only learning a new support
# ever costs a slot.
var demon_skills: Dictionary = {}

# Level-ups each demon has banked, which is what its growth triggers off.
var demon_levels_gained: Dictionary = {}

# Points a demon places per level, and how much exp its next level asks for.
const DEMON_POINTS_PER_LEVEL: int = 2
const DEMON_EXP_FACTOR: int = 6

# Six, because the skills menu is a fixed six cells — see CombatScene.MENU_SLOTS.
# A full demon stops learning; its rungs can still climb, since those rewrite a
# skill rather than adding one.
const DEMON_SKILL_CAP: int = 6
const DEMON_GROWTH_EVERY: int = 2
const DEMON_MAX_RUNG: int = 3

# Every buff and debuff a demon could pick up, which is the same set the
# templates already hand out as support skills.
const DEMON_SUPPORTS: Array[String] = ["whet", "ward", "quicken", "stoke",
		"blunt", "sunder", "mire", "damp"]

static func demon_exp_to_next(lv: int) -> int:
	return maxi(1, Enemy.exp_for_level(lv) * DEMON_EXP_FACTOR)


# Rebuilds a bound demon at the level it has reached, with the stat points it
# rolled getting there laid on top of what its template says.
func bound_demon(demon_name: String) -> Enemy:
	var e: Enemy = Enemy.make_at_level(demon_name, int(bound_level.get(demon_name, 1)))
	var gains: Dictionary = demon_gains.get(demon_name, {}) as Dictionary
	if not gains.is_empty():
		e.str = maxi(1, e.str + int(gains.get("str", 0)))
		e.def = maxi(1, e.def + int(gains.get("def", 0)))
		e.mag = maxi(0, e.mag + int(gains.get("mag", 0)))
		e.agl = maxi(1, e.agl + int(gains.get("agl", 0)))
		e.compute_max_hp()
		e.compute_max_mp()
	return e


# Exp from a won fight, paid to every demon that was standing in it. A demon
# never passes the detective: he is the one holding the case open, and a party
# that outgrows him would make his own levels pointless.
#
# Returns {climbed = [names], learned = {name: [what it picked up]}} so the
# result screen can say both what grew and what it can now call on.
func award_demon_exp(amount: int) -> Dictionary:
	var climbed: Array[String] = []
	var learned: Dictionary = {}
	if amount <= 0:
		return {climbed = climbed, learned = learned}
	for demon_name: String in active_demons:
		var at: int = int(bound_level.get(demon_name, 1))
		if at >= lv:
			continue
		var banked: int = int(demon_exp.get(demon_name, 0)) + amount
		var gained: bool = false
		while at < lv and banked >= demon_exp_to_next(at):
			banked -= demon_exp_to_next(at)
			at += 1
			_roll_demon_gain(demon_name)
			gained = true
			var levels: int = int(demon_levels_gained.get(demon_name, 0)) + 1
			demon_levels_gained[demon_name] = levels
			if levels % DEMON_GROWTH_EVERY == 0:
				var got: String = _roll_demon_skill(demon_name)
				if got != "":
					if not learned.has(demon_name):
						learned[demon_name] = []
					(learned[demon_name] as Array).append(got)
		bound_level[demon_name] = at
		# At the detective's level it stops banking, so the overflow is not
		# sitting there waiting to fire off three levels the moment he gains one.
		demon_exp[demon_name] = 0 if at >= lv else banked
		if gained:
			climbed.append(demon_name)
	return {climbed = climbed, learned = learned}


# Every second level a demon picks something up, and a coin decides which kind:
# one of its lines climbs a rung, or it learns a buff or debuff it did not have.
# A coin that lands on an impossible side takes the other — a demon with every
# rung maxed keeps learning, and a full one keeps climbing rungs, since a rung
# rewrites a skill instead of adding one.
func _roll_demon_skill(demon_name: String) -> String:
	# An empty list is not a dead end: a demon that throws no element at all —
	# a Bat has none and no support either — grows into a support caster, which
	# is the only way it can grow at all.
	var list: Array = skills_of(demon_name)

	var upgradable: Array[int] = []
	for i: int in list.size():
		var skill: Dictionary = list[i] as Dictionary
		if skill.get("kind", "") == "element" \
				and int(skill.get("rung", 1)) < DEMON_MAX_RUNG:
			upgradable.append(i)

	var unlearned: Array[String] = []
	if list.size() < DEMON_SKILL_CAP:
		for id: String in DEMON_SUPPORTS:
			var known: bool = false
			for skill: Dictionary in list:
				if skill.get("kind", "") == "support" and skill.get("id", "") == id:
					known = true
			if not known:
				unlearned.append(id)

	if upgradable.is_empty() and unlearned.is_empty():
		return ""
	var climb: bool = (randi() % 2 == 0)
	if climb and upgradable.is_empty():
		climb = false
	elif not climb and unlearned.is_empty():
		climb = true

	if climb:
		var idx: int = upgradable[randi() % upgradable.size()]
		var skill: Dictionary = list[idx] as Dictionary
		skill["rung"] = int(skill.get("rung", 1)) + 1
		list[idx] = skill
		demon_skills[demon_name] = list
		return skill_name(skill)

	var pick: String = unlearned[randi() % unlearned.size()]
	list.append({kind = "support", id = pick})
	demon_skills[demon_name] = list
	return Spell.get_data(pick).get("name", pick) as String


func _roll_demon_gain(demon_name: String) -> void:
	var gains: Dictionary = demon_gains.get(demon_name, {}) as Dictionary
	if gains.is_empty():
		gains = {"str": 0, "def": 0, "mag": 0, "agl": 0}
	for i: int in range(DEMON_POINTS_PER_LEVEL):
		var stat: String = ["str", "def", "mag", "agl"][randi() % 4]
		gains[stat] = int(gains.get(stat, 0)) + 1
	demon_gains[demon_name] = gains


# What a demon has rolled, as "STR+2 AGL+1", for the party and result screens.
func demon_gain_string(demon_name: String) -> String:
	var gains: Dictionary = demon_gains.get(demon_name, {}) as Dictionary
	var parts: Array[String] = []
	for stat: String in ["str", "def", "mag", "agl"]:
		var n: int = int(gains.get(stat, 0))
		if n > 0:
			parts.append("%s+%d" % [stat.to_upper(), n])
	return " ".join(parts)

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
	demon_exp.erase(demon_name)
	demon_gains.erase(demon_name)
	demon_skills.erase(demon_name)
	demon_levels_gained.erase(demon_name)


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
	seed_demon_skills(demon_name)
	activate_demon(demon_name)


# What a demon knows the moment it is bound: every line it throws, on the first
# rung, plus the support its template already casts at you. That support was
# only ever used by the enemy AI before — a bound demon carried it and could
# not call it.
func seed_demon_skills(demon_name: String) -> void:
	if demon_skills.has(demon_name):
		return
	var e: Enemy = Enemy.make_at_level(demon_name, 1)
	var list: Array = []
	for el: String in e.attack_elements:
		list.append({kind = "element", element = el, rung = 1,
				shape = e.attack_reach})
	if e.support_skill != "":
		list.append({kind = "support", id = e.support_skill})
	e.free()
	demon_skills[demon_name] = list


func skills_of(demon_name: String) -> Array:
	return demon_skills.get(demon_name, []) as Array


# The name a skill entry goes by on a button and in the log.
static func skill_name(skill: Dictionary) -> String:
	if skill.get("kind", "") == "support":
		return Spell.get_data(skill.get("id", "") as String).get("name", "?") as String
	var id: String = Spell.elemental_id(skill.get("element", "") as String,
			int(skill.get("rung", 1)), skill.get("shape", Spell.SHAPE_ONE) as String)
	if id != "":
		return Spell.get_data(id).get("name", "?") as String
	# No cast sits at that element and reach — the banishing lines have no
	# "few" damage rung, for one. Fall back on naming the line itself.
	return "%s Strike" % Affinity.element_name(skill.get("element", "") as String)

# Nobody walks into their first case empty-handed. A first-floor demon, not a
# strong one — it will grow on its own from here, and a powerful gift would
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


