# PlayerCharacter
# The player's RPG identity. Owns inventory, accessory slots, known spells,
# and gold. HP/MP persist across encounters; manage them carefully.
class_name PlayerCharacter extends CharacterSheet

const DISPLAY_NAME: String = "Hero"

const SPRITE_KNIGHT: String = "Knight"


# Always the Knight, whatever is in hand: he is who walks down the stairs on the
# loading screen and up them at the end, so he is who fights in between. A
# spell shows in his special attack instead (see CombatScene._commit_action).
func hero_sprite_id() -> String:
	return SPRITE_KNIGHT


static func sprite() -> Texture2D:
	return AnimatedPortrait.first_frame_texture(SPRITE_KNIGHT)


static func portrait() -> AtlasTexture:
	var tex: Texture2D = sprite()
	if tex is AtlasTexture:
		return tex as AtlasTexture
	var a: AtlasTexture = AtlasTexture.new()
	a.atlas  = tex
	a.region = Rect2(0, 0, tex.get_width(), tex.get_height())
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
# always one of them — so five spells.
# Five, not four: Analyze became an ordinary spell and started taking one of
# these, which quietly cost the player a slot they used to have for free.
const SPELL_SLOTS: int = 5
var equipped_spells: Array[String] = []


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


# Everything in the pack a fight can use: every consumable, potions and
# throwables alike, in pack order. There used to be a six-slot belt between the
# pack and the battle; the battle's item menu scrolls instead, so nothing carried
# is out of reach mid-fight.
func battle_items() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for item: Dictionary in inventory:
		if item.get("type", "") == "consumable" and int(item.get("qty", 0)) > 0:
			out.append(item)
	return out

# Every demon he has bound. The roster.
var recruited: Array[String] = []

# Every demon that has EVER answered to him, kept after one is sold or falls.
# This, not encountered_enemies, is what an orb will call back: the orb reaches
# for something that has been bound before, and fighting a thing in a corridor
# is not an introduction it would honour.
var ever_bound: Array[String] = []

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

# Max HP and MP a demon has been given by stones, per demon: {"hp": n, "mp": n}.
# Seeds given to a demon go into demon_gains with its own level-up points.
var demon_bonus: Dictionary = {}

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

# Five, because the skills menu is a fixed six cells and Attack takes one — see
# CombatScene.MENU_SLOTS. The same five the hero gets in SPELL_SLOTS. A
# full demon can still be offered something new; taking it means forgetting
# something it has.
const DEMON_SKILL_CAP: int = 5
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
	var bonus: Dictionary = demon_bonus.get(demon_name, {}) as Dictionary
	if not gains.is_empty() or not bonus.is_empty():
		e.str = maxi(1, e.str + int(gains.get("str", 0)))
		e.def = maxi(1, e.def + int(gains.get("def", 0)))
		e.mag = maxi(0, e.mag + int(gains.get("mag", 0)))
		e.agl = maxi(1, e.agl + int(gains.get("agl", 0)))
		e._hp_bonus = int(bonus.get("hp", 0))
		e._mp_bonus = int(bonus.get("mp", 0))
		e.compute_max_hp()
		e.compute_max_mp()
	return e


# A seed or a stone: the items that can be given to a demon as well as used.
static func is_keepsake(item: Dictionary) -> bool:
	return item.has("stat_up") or int(item.get("max_hp_gain", 0)) > 0 \
			or int(item.get("max_mp_gain", 0)) > 0


# Demons have no Luck, so a Seed of Luck is the hero's alone.
static func demon_can_take(item: Dictionary) -> bool:
	return is_keepsake(item) and item.get("stat_up", "") != "luk"


# Feeds a seed or a stone to a bound demon, for good. Kept with its other
# gains, so it is there every time the demon is called, and it goes if the
# demon is sold. Returns the line for the status bar.
func give_keepsake(item: Dictionary, demon_name: String) -> String:
	if not demon_can_take(item) or demon_name not in recruited:
		return "%s cannot take that." % demon_name
	var out: String = ""
	if item.has("stat_up"):
		var stat: String = item["stat_up"] as String
		var gains: Dictionary = demon_gains.get(demon_name, {}) as Dictionary
		gains[stat] = int(gains.get(stat, 0)) + int(item.get("stat_up_amount", 1))
		demon_gains[demon_name] = gains
		var e: Enemy = bound_demon(demon_name)
		out = "%s's %s rises to %d." % [demon_name, Item.SEEDS[stat][2], int(e.get(stat))]
		e.free()
	else:
		var bonus: Dictionary = demon_bonus.get(demon_name, {}) as Dictionary
		bonus["hp"] = int(bonus.get("hp", 0)) + int(item.get("max_hp_gain", 0))
		bonus["mp"] = int(bonus.get("mp", 0)) + int(item.get("max_mp_gain", 0))
		demon_bonus[demon_name] = bonus
		var e2: Enemy = bound_demon(demon_name)
		out = "%s's maximum %s is now %d." % [demon_name,
				"HP" if int(item.get("max_hp_gain", 0)) > 0 else "MP",
				e2.max_hp if int(item.get("max_hp_gain", 0)) > 0 else e2.max_mp]
		e2.free()
	remove_item(item, 1)
	return out


# What a benched demon banks of a fight it sat out. Without a share the bench
# froze at the level it was caught at, so the demon a boss finally called for
# was six levels behind the three that did all the walking.
const BENCH_EXP_PERCENT: int = 50


# Exp from a won fight: in full to every demon that was standing in it, and a
# share to the rest of the roster on the bench. A demon never passes the
# hero: he is the one leading the descent, and a party that outgrows him would
# make his own levels pointless.
#
# Returns {climbed = [names], learned = {name: [rungs it climbed]},
# offers = {name: [skill entries]}}. A rung climb is simply taken; a new skill
# is only offered, and the level-up screen asks whether to learn it.
func award_demon_exp(amount: int) -> Dictionary:
	var climbed: Array[String] = []
	var learned: Dictionary = {}
	var offers: Dictionary = {}
	if amount <= 0:
		return {climbed = climbed, learned = learned, offers = offers}
	for demon_name: String in recruited:
		var at: int = int(bound_level.get(demon_name, 1))
		if at >= lv:
			continue
		var share: int = amount if is_active(demon_name) \
				else maxi(1, amount * BENCH_EXP_PERCENT / 100)
		var banked: int = int(demon_exp.get(demon_name, 0)) + share
		var gained: bool = false
		while at < lv and banked >= demon_exp_to_next(at):
			banked -= demon_exp_to_next(at)
			at += 1
			_roll_demon_gain(demon_name)
			gained = true
			var levels: int = int(demon_levels_gained.get(demon_name, 0)) + 1
			demon_levels_gained[demon_name] = levels
			if levels % DEMON_GROWTH_EVERY == 0:
				var pending: Array = offers.get(demon_name, []) as Array
				var got: Dictionary = _roll_demon_skill(demon_name, pending)
				if got.has("raised"):
					if not learned.has(demon_name):
						learned[demon_name] = []
					(learned[demon_name] as Array).append(got["raised"])
				elif got.has("offer"):
					pending.append(got["offer"])
					offers[demon_name] = pending
		bound_level[demon_name] = at
		# At the hero's level it stops banking, so the overflow is not
		# sitting there waiting to fire off three levels the moment he gains one.
		demon_exp[demon_name] = 0 if at >= lv else banked
		if gained:
			climbed.append(demon_name)
	return {climbed = climbed, learned = learned, offers = offers}


# Every second level a demon picks something up, and a coin decides which kind:
# one of its lines climbs a rung, or it is offered a skill it does not have — a
# buff or debuff, or a physical line if it hits harder than it casts. A coin
# that lands on an impossible side takes the other.
#
# A climb is applied here and comes back as {raised = name}. A new skill is
# not: it comes back as {offer = entry}, and the player decides on the level-up
# screen whether to learn it, and what to forget for it if the list is full.
# `pending` is what this fight has already offered, so two level-ups in one
# fight do not offer the same thing twice.
func _roll_demon_skill(demon_name: String, pending: Array = []) -> Dictionary:
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
	for id: String in DEMON_SUPPORTS:
		var entry: Dictionary = {kind = "support", id = id}
		if not _has_skill(list, entry) and not _has_skill(pending, entry):
			unlearned.append(id)

	# A demon that hits harder than it casts can pick up a physical line of
	# its own, at the reach it already fights at. It is one new line like any
	# other: it takes a slot, starts on the first rung and climbs from there.
	var phys_reach: String = _phys_line_reach(demon_name, list)
	if phys_reach != "" and _has_skill(pending, {kind = "element", element = Affinity.PHYS}):
		phys_reach = ""
	var can_learn: bool = not unlearned.is_empty() or phys_reach != ""

	if upgradable.is_empty() and not can_learn:
		return {}
	var climb: bool = (randi() % 2 == 0)
	if climb and upgradable.is_empty():
		climb = false
	elif not climb and not can_learn:
		climb = true

	if climb:
		var idx: int = upgradable[randi() % upgradable.size()]
		var skill: Dictionary = list[idx] as Dictionary
		skill["rung"] = int(skill.get("rung", 1)) + 1
		list[idx] = skill
		demon_skills[demon_name] = list
		return {raised = skill_name(skill)}

	# Even odds between the physical line and a buff, while both are open —
	# otherwise it would be one name lost among eight supports.
	if phys_reach != "" and (unlearned.is_empty() or randi() % 2 == 0):
		return {offer = {kind = "element", element = Affinity.PHYS,
				rung = 1, shape = phys_reach}}
	return {offer = {kind = "support", id = unlearned[randi() % unlearned.size()]}}


# Same support, or a line in the same element — a rung does not make it new.
static func _has_skill(list: Array, want: Dictionary) -> bool:
	for skill: Dictionary in list:
		if skill.get("kind", "") != want.get("kind", ""):
			continue
		if want.get("kind", "") != "element" and skill.get("id", "") == want.get("id", ""):
			return true
		if want.get("kind", "") == "element" and skill.get("element", "") == want.get("element", ""):
			return true
	return false


# Takes an offered skill. `forget` is the index of the one it replaces, which
# a full list has to give up; -1 adds it while there is room. False when there
# is no room and nothing was named to make some.
func learn_demon_skill(demon_name: String, skill: Dictionary, forget: int = -1) -> bool:
	var list: Array = skills_of(demon_name)
	if _has_skill(list, skill):
		return false
	if forget >= 0 and forget < list.size():
		list[forget] = skill
	elif list.size() < DEMON_SKILL_CAP:
		list.append(skill)
	else:
		return false
	demon_skills[demon_name] = list
	return true


# The reach a physical line would come in at, or "" when this demon cannot
# learn one: it already has one, or it is a caster at heart.
# Judged on what it is now — its level and the points it has rolled — so a
# demon that has grown into its arms can pick one up later.
func _phys_line_reach(demon_name: String, list: Array) -> String:
	for skill: Dictionary in list:
		if skill.get("kind", "") == "element" and skill.get("element", "") == Affinity.PHYS:
			return ""
	var e: Enemy = bound_demon(demon_name)
	var reach: String = e.attack_reach if e.str > e.mag else ""
	e.free()
	return reach


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
# since the hero takes the first slot himself.
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


# Struck off the roster for good — sold at an orb. The level goes with it:
# remember_recruit keeps the best copy ever bound, so leaving the old level
# behind would hand a later, weaker recruit the sold demon's strength for free.
func release_demon(demon_name: String) -> void:
	recruited.erase(demon_name)
	active_demons.erase(demon_name)
	bound_level.erase(demon_name)
	demon_exp.erase(demon_name)
	demon_gains.erase(demon_name)
	demon_bonus.erase(demon_name)
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
	# Kept even when the demon is later sold or falls. An orb can only call back
	# something that answered to you once — meeting a thing in a corridor is not
	# an introduction it would honour.
	if demon_name not in ever_bound:
		ever_bound.append(demon_name)
	# Keep the best one ever bound: re-catching a weaker copy should never
	# downgrade what is already in the roster.
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
	for id: String in e.unique_skills:
		if list.size() < DEMON_SKILL_CAP:
			list.append({kind = "unique", id = id})
	e.free()
	demon_skills[demon_name] = list


# A demon bound before its kind had a unique skill picks it up here, on load,
# if it has a slot free for it. Nothing is forgotten to make room. One its kind
# no longer has is dropped, so a change to a template reaches old saves.
func top_up_unique_skills() -> void:
	# The starting demon used to be bound with no skills at all. A save made
	# then carries an empty list; seed it as if it had just been recruited.
	for demon_name: String in recruited:
		if (demon_skills.get(demon_name, []) as Array).is_empty():
			demon_skills.erase(demon_name)
			seed_demon_skills(demon_name)
	for demon_name: String in demon_skills:
		var list: Array = demon_skills[demon_name] as Array
		var e: Enemy = Enemy.make_at_level(demon_name, 1)
		list = list.filter(func(sk: Dictionary) -> bool:
				return sk.get("kind", "") != "unique" or sk.get("id", "") in e.unique_skills)
		demon_skills[demon_name] = list
		for id: String in e.unique_skills:
			var entry: Dictionary = {kind = "unique", id = id}
			if list.size() < DEMON_SKILL_CAP and not _has_skill(list, entry):
				list.append(entry)
		e.free()


func skills_of(demon_name: String) -> Array:
	return demon_skills.get(demon_name, []) as Array


# The name a skill entry goes by on a button and in the log.
static func skill_name(skill: Dictionary) -> String:
	if skill.get("kind", "") != "element":
		return Spell.get_data(skill.get("id", "") as String).get("name", "?") as String
	var id: String = Spell.elemental_id(skill.get("element", "") as String,
			int(skill.get("rung", 1)), skill.get("shape", Spell.SHAPE_ONE) as String)
	if id != "":
		return Spell.get_data(id).get("name", "?") as String
	# No cast sits at that element and reach — the banishing lines have no
	# "few" damage rung, for one. Fall back on naming the line itself.
	return "%s Strike" % Affinity.element_name(skill.get("element", "") as String)

# Nobody goes down into the Deep empty-handed. A first-floor demon, not a
# strong one — it will grow on its own from here, and a powerful gift would
# flatten the whole run. One demon is already bound,
# which is also what makes the opening floors survivable — a lone hero
# against a pack of three loses on action economy no matter how well he reads
# the affinity chart.
const STARTING_DEMON: String = "Hellbat"

# Enemy names encountered at least once in combat (bestiary unlock).
var encountered_enemies: Array[String] = []

# Enemy names whose affinity chart he has read with Analyze. Meeting something
# records that it exists; only Analyze records what it is made of.
var analyzed: Array[String] = []

# Floor hazards met at least once. The first of each kind stops to say what it
# does; after that it just happens.
var hazards_seen: Array[String] = []


func has_analyzed(enemy_name: String) -> bool:
	return enemy_name in analyzed


func record_analysis(enemy_name: String) -> void:
	if enemy_name not in analyzed:
		analyzed.append(enemy_name)


# Single lines learned the hard way: hitting a demon with an element shows what
# it does with that element, one box of its chart at a time, before Analyze or
# a kill hands over the whole thing. enemy name -> [elements].
var learned_affinities: Dictionary = {}


func knows_affinity(enemy_name: String, element: String) -> bool:
	return has_analyzed(enemy_name) \
			or element in (learned_affinities.get(enemy_name, []) as Array)


func learn_affinity(enemy_name: String, element: String) -> void:
	if element == "" or knows_affinity(enemy_name, element):
		return
	if not learned_affinities.has(enemy_name):
		learned_affinities[enemy_name] = []
	(learned_affinities[enemy_name] as Array).append(element)

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
	# The run opens holding one spell. On the bare formula that is 10 MP — a
	# single cast of Ember and then nothing for the rest of the floor, which is
	# not a loadout so much as a demonstration. Three casts is a start.
	_mp_bonus = 14
	compute_max_hp()
	compute_max_mp()

	known_spells    = ["analyze", "ember"]
	equipped_spells = ["analyze", "ember"]
	equipped_weapon = {}
	equipped_armor  = {}
	equipped_accessories = []
	recruited       = [STARTING_DEMON]
	ever_bound      = [STARTING_DEMON]
	bound_level     = {STARTING_DEMON: 2}
	active_demons   = [STARTING_DEMON]
	# Bound the same way a recruit is, so it walks in knowing its own lines —
	# without this the gift carried no skills at all until a save was loaded.
	demon_skills    = {}
	seed_demon_skills(STARTING_DEMON)
	hazards_seen    = []

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
	if mirrors(element):
		return Affinity.REPEL
	if element in Armor.resists_of(equipped_armor):
		return Affinity.RESIST
	for acc: Dictionary in equipped_accessories:
		if element in Armor.resists_of(acc):
			return Affinity.RESIST
	if element in Armor.weaknesses_of(equipped_armor):
		return Affinity.WEAK
	for acc2: Dictionary in equipped_accessories:
		if element in Armor.weaknesses_of(acc2):
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


# The worn trinket that keeps this ailment off, or {} if none does.
func ward_against(status_id: String) -> Dictionary:
	for acc: Dictionary in equipped_accessories:
		if Accessory.wards_off(acc, status_id):
			return acc
	return {}


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


# What a healing spell would restore right now. Lives here rather than in the
# battle scene because the menu casts the same spells out of combat and the two
# must not drift into healing different amounts for the same MP.
func heal_amount_for(spell_id: String) -> int:
	var data: Dictionary = Spell.get_data(spell_id)
	var base: int = int(data.get("heal", 30))
	var bonus: int = int(float(effective_mag()) * stage_mult(CharacterSheet.STAT_MAG)
			* float(data.get("mag_mult", 1.0)))
	return maxi(1, base + bonus)


# How many of an item are sitting in the pack.
func item_qty(item_id: String) -> int:
	for it: Dictionary in inventory:
		if it.get("id", "") == item_id:
			return int(it.get("qty", 1))
	return 0


func has_item(item_id: String) -> bool:
	return item_qty(item_id) > 0


# Whether the run has this thing at all, worn pieces included. Equipping takes
# an item OUT of `inventory` — so a shop that asked the pack alone would say you
# do not own the sword you are holding, which is the one case it most needs to
# get right.
func owns(item_id: String) -> bool:
	if equipped_weapon.get("id", "") == item_id:
		return true
	if equipped_armor.get("id", "") == item_id:
		return true
	if is_accessory_equipped(item_id):
		return true
	return has_item(item_id)


func remove_item(item: Dictionary, count: int = 1) -> void:
	if item.get("qty", 1) > count:
		item["qty"] -= count
	else:
		inventory.erase(item)


# Returns true if using this item would have any effect on the player's current state.
func can_use_item(item: Dictionary) -> bool:
	match item["type"]:
		"consumable":
			# A stone always has something to do: the ceiling it raises is never
			# already full.
			if item.get("max_hp_gain", 0) > 0 or item.get("max_mp_gain", 0) > 0 \
					or item.has("stat_up"):
				return true
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
			if item.has("stat_up"):
				var stat: String = item["stat_up"] as String
				set(stat, int(get(stat)) + int(item.get("stat_up_amount", 1)))
				# Defence and Magic feed the HP and MP ceilings. Recomputing
				# refills them, which a seed should not do: keep what was there.
				var keep_hp: int = hp
				var keep_mp: int = mp
				compute_max_hp()
				compute_max_mp()
				hp = mini(keep_hp, max_hp)
				mp = mini(keep_mp, max_mp)
				remove_item(item, 1)
				return "%s rises to %d." % [Item.SEEDS[stat][2], int(get(stat))]
			var max_hp_up: int = item.get("max_hp_gain", 0)
			var max_mp_up: int = item.get("max_mp_gain", 0)
			if max_hp_up > 0 or max_mp_up > 0:
				# Both pools come back full, which is compute_max_*'s own
				# behaviour — a stone raises the ceiling and fills what it
				# raised. That makes one worth carrying to a boss door.
				_hp_bonus += max_hp_up
				_mp_bonus += max_mp_up
				compute_max_hp()
				compute_max_mp()
				if max_hp_up > 0:
					msg += "Maximum HP is now %d. " % max_hp
				if max_mp_up > 0:
					msg += "Maximum MP is now %d. " % max_mp
				msg += "Restored to full."
				remove_item(item, 1)
				return msg.strip_edges()
			msg = apply_restorative(item)
			remove_item(item, 1)
			return msg
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


