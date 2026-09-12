# Enemy
# Base class for all hostile entities. Inherits RPG stats from CharacterSheet.
# Use make_random() to generate a floor-scaled enemy without adding it to the tree.
class_name Enemy extends CharacterSheet

var enemy_name:       String = "Unknown"
var exp_reward:       int    = 20
var gold_reward:      int    = 5
var status_attack:    String = ""
var weakness:         String = ""
var negotiable:       bool   = true
var talk_difficulty:  int    = 2
var talk_personality: String = "cowardly"
var bribe_wants:      String = "any"
var sprite_path:      String = ""
var attack_element:   String = ""
var reflect_element:  String = ""

# Press-turn icons this enemy opens its phase with. Bosses get more, which is
# how they threaten a full party without inflating their damage numbers.
var icons: int = 1

# Suffix that keeps three Bats apart in the battle UI. Assigned by CombatScene
# when a group holds more than one of the same kind.
var battle_tag: String = ""

# A support spell this demon leans on, by Spell.DATA id. Empty means it only
# knows how to hit things.
var support_skill: String = ""

# Percent chance one of its hits also lands its ailment. Fixed per demon rather
# than swinging on the level gap, so the first area stays a gentle place.
var ailment_chance: int = 12


# Name as it should appear in the battle log and on the enemy row.
func display_name() -> String:
	if battle_tag == "":
		return enemy_name
	return "%s %s" % [enemy_name, battle_tag]
var absorb_element:   String = ""

# Levels and stats are fixed per template and never move — for enemies OR for
# demons bound to the party. A demon is exactly what it was when you met it,
# which is why binding a strong one is the reward rather than raising a weak one.
# Template data for all enemy types. Stats are base values for floor 1.
# min_floor / max_floor control which dungeon floors they appear on.
# max_floor = -1 means no upper limit.
#
# Every row is written in the same shape, one concern per line, so a demon's
# chart or its talk data can be found by position rather than by reading:
#
#   1  name, level, press-turn icons
#   2  the four stats
#   3  rewards, and the floors it appears on
#   4  the affinity chart — weakness, then any phys/light/dark/reflect/absorb
#   5  what it does in a fight — element, ailment, ailment chance, support spell
#   6  how it can be talked down, if it can
#   7  its sprite
#
# A key that is absent means the default: no element, no support, no affinity
# beyond the chart above. Lines 4-6 are the ones worth scanning down.
const TEMPLATES: Array[Dictionary] = [
	# --- Floor 1-2 ---
	{name = "Bat",              lv =  1,
		str =  2, def =  1, mag =  0, agl =  5,
		exp =  12, gold =   4, min_floor = 1, max_floor =  2,
		weakness = "fire", phys = "weak",
		status_attack = "", ail = 5,
		negotiable = true, talk_difficulty = 1, personality = "cowardly", wants = "any",
		sprite = "res://resources/enemySprites/Bat.png"},
	{name = "Slug",             lv =  1,
		str =  2, def =  2, mag =  0, agl =  1,
		exp =  18, gold =   6, min_floor = 1, max_floor =  2,
		weakness = "fire", phys = "resist", light = "resist", dark = "resist",
		status_attack = "poison", ail = 5,
		negotiable = false, talk_difficulty = 0,
		sprite = "res://resources/enemySprites/Slug.png"},
	{name = "GiantRat",         lv =  1,
		str =  3, def =  2, mag =  0, agl =  3,
		exp =  20, gold =   6, min_floor = 1, max_floor =  2,
		weakness = "fire",
		status_attack = "", ail = 5,
		negotiable = true, talk_difficulty = 1, personality = "cowardly", wants = "potion",
		sprite = "res://resources/enemySprites/GiantRat.png"},
	{name = "Cave Bat",         lv =  2,
		str =  3, def =  2, mag =  3, agl =  6,
		exp =  16, gold =   5, min_floor = 1, max_floor =  2,
		weakness = "fire", phys = "weak",
		attack_element = "thunder", status_attack = "", ail = 5,
		negotiable = true, talk_difficulty = 1, personality = "cowardly", wants = "any",
		sprite = "res://resources/enemySprites/BatB.png"},
	{name = "Giant Slug",       lv =  2,
		str =  3, def =  3, mag =  0, agl =  1,
		exp =  22, gold =   7, min_floor = 1, max_floor =  2,
		weakness = "fire", phys = "resist", light = "resist", dark = "resist",
		status_attack = "poison", ail = 5,
		negotiable = false, talk_difficulty = 0,
		sprite = "res://resources/enemySprites/SlugB.png"},
	{name = "Dire Rat",         lv =  2,
		str =  4, def =  3, mag =  0, agl =  4,
		exp =  25, gold =   8, min_floor = 1, max_floor =  2,
		weakness = "fire",
		status_attack = "poison", ail = 5,
		negotiable = true, talk_difficulty = 1, personality = "cowardly", wants = "potion",
		sprite = "res://resources/enemySprites/GiantRatB.png"},
	# --- Floor 1-3 ---
	{name = "Goblin",           lv =  2,
		str =  4, def =  2, mag =  0, agl =  4,
		exp =  25, gold =   8, min_floor = 1, max_floor =  3,
		weakness = "fire", phys = "weak",
		status_attack = "", ail = 5,
		negotiable = true, talk_difficulty = 2, personality = "greedy", wants = "throwable",
		sprite = "res://resources/enemySprites/Goblin.png"},
	{name = "GelatinousCube",   lv =  2,
		str =  2, def =  4, mag =  0, agl =  1,
		exp =  22, gold =   7, min_floor = 1, max_floor =  3,
		weakness = "fire", phys = "resist", light = "resist", dark = "resist",
		attack_element = "ice", status_attack = "immobilize", ail = 5,
		negotiable = false, talk_difficulty = 0,
		sprite = "res://resources/enemySprites/GelatinousCube.png"},
	{name = "Hobgoblin",        lv =  3,
		str =  5, def =  3, mag =  0, agl =  5,
		exp =  32, gold =  10, min_floor = 1, max_floor =  3,
		weakness = "fire", phys = "weak",
		status_attack = "", ail = 5,
		negotiable = true, talk_difficulty = 2, personality = "greedy", wants = "throwable",
		sprite = "res://resources/enemySprites/GoblinB.png"},
	{name = "Ooze",             lv =  3,
		str =  3, def =  5, mag =  0, agl =  1,
		exp =  28, gold =   9, min_floor = 1, max_floor =  3,
		weakness = "fire", phys = "resist", light = "resist", dark = "resist",
		attack_element = "ice", status_attack = "immobilize", ail = 5,
		negotiable = false, talk_difficulty = 0,
		sprite = "res://resources/enemySprites/GelatinousCubeB.png"},
	# --- Floor 2-4 ---
	{name = "Skeleton",         lv =  5,
		str =  5, def =  3, mag =  1, agl =  2,
		exp =  30, gold =  10, min_floor = 2, max_floor =  4,
		weakness = "fire", phys = "resist", light = "weak", dark = "null",
		status_attack = "immobilize", ail = 12,
		negotiable = false, talk_difficulty = 0,
		sprite = "res://resources/enemySprites/Skeleton.png"},
	{name = "GiantHornet",      lv =  5,
		str =  4, def =  2, mag =  0, agl =  6,
		exp =  28, gold =   9, min_floor = 2, max_floor =  4,
		weakness = "ice", phys = "weak",
		status_attack = "poison", ail = 12,
		negotiable = false, talk_difficulty = 0,
		sprite = "res://resources/enemySprites/GiantHornet.png"},
	{name = "Bandit",           lv =  5,
		str =  5, def =  3, mag =  3, agl =  5,
		exp =  32, gold =  12, min_floor = 2, max_floor =  4,
		weakness = "thunder", phys = "weak",
		attack_element = "fire", status_attack = "", ail = 12,
		negotiable = true, talk_difficulty = 2, personality = "greedy", wants = "any",
		sprite = "res://resources/enemySprites/Bandit.png"},
	{name = "WildBoar",         lv =  5,
		str =  6, def =  3, mag =  0, agl =  2,
		exp =  30, gold =   9, min_floor = 2, max_floor =  4,
		weakness = "ice",
		status_attack = "", ail = 12,
		negotiable = true, talk_difficulty = 2, personality = "cowardly", wants = "potion",
		sprite = "res://resources/enemySprites/WildBoar.png"},
	{name = "AnimatedPlant",    lv =  5,
		str =  3, def =  3, mag =  4, agl =  1,
		exp =  28, gold =   8, min_floor = 2, max_floor =  4,
		weakness = "fire", light = "resist", dark = "resist",
		status_attack = "poison", ail = 12,
		negotiable = false, talk_difficulty = 0,
		sprite = "res://resources/enemySprites/AnimatedPlant.png"},
	{name = "Bone Knight",      lv =  6,
		str =  6, def =  4, mag =  2, agl =  2,
		exp =  38, gold =  12, min_floor = 2, max_floor =  4,
		weakness = "fire", phys = "resist", light = "weak", dark = "null",
		status_attack = "immobilize", ail = 12,
		negotiable = false, talk_difficulty = 0,
		sprite = "res://resources/enemySprites/SkeletonB.png"},
	{name = "Queen Hornet",     lv =  6,
		str =  5, def =  3, mag =  0, agl =  7,
		exp =  35, gold =  11, min_floor = 2, max_floor =  4,
		weakness = "ice", phys = "weak",
		status_attack = "poison", ail = 12,
		negotiable = false, talk_difficulty = 0,
		sprite = "res://resources/enemySprites/GiantHornetB.png"},
	{name = "Veteran Bandit",   lv =  6,
		str =  6, def =  4, mag =  0, agl =  5,
		exp =  40, gold =  15, min_floor = 2, max_floor =  4,
		weakness = "thunder", phys = "weak",
		status_attack = "", ail = 12,
		negotiable = true, talk_difficulty = 3, personality = "greedy", wants = "any",
		sprite = "res://resources/enemySprites/BanditB.png"},
	{name = "Tusked Boar",      lv =  6,
		str =  7, def =  4, mag =  0, agl =  2,
		exp =  38, gold =  11, min_floor = 2, max_floor =  4,
		weakness = "ice",
		status_attack = "", ail = 12,
		negotiable = true, talk_difficulty = 2, personality = "cowardly", wants = "potion",
		sprite = "res://resources/enemySprites/WildBoarB.png"},
	{name = "Thornvine",        lv =  6,
		str =  4, def =  4, mag =  5, agl =  1,
		exp =  35, gold =  10, min_floor = 2, max_floor =  4,
		weakness = "fire", light = "resist", dark = "resist",
		status_attack = "poison", ail = 12,
		negotiable = false, talk_difficulty = 0,
		sprite = "res://resources/enemySprites/AnimatedPlantB.png"},
	# --- Floor 3+ ---
	{name = "Treant",           lv =  8,
		str =  6, def =  6, mag =  0, agl =  1,
		exp =  45, gold =  14, min_floor = 3, max_floor = -1,
		weakness = "fire", phys = "resist", light = "resist", dark = "resist",
		status_attack = "immobilize", ail = 18,
		negotiable = false, talk_difficulty = 0,
		sprite = "res://resources/enemySprites/Treant.png"},
	{name = "Orc",              lv =  8,
		str =  7, def =  4, mag =  0, agl =  2,
		exp =  38, gold =  12, min_floor = 3, max_floor =  5,
		weakness = "ice",
		status_attack = "", ail = 18,
		negotiable = true, talk_difficulty = 3, personality = "proud", wants = "throwable",
		sprite = "res://resources/enemySprites/Orc.png"},
	{name = "Fairy",            lv =  8,
		str =  2, def =  2, mag =  6, agl =  7,
		exp =  42, gold =  14, min_floor = 3, max_floor = -1,
		weakness = "thunder", phys = "weak", light = "resist", dark = "weak", absorb_element = "thunder",
		attack_element = "thunder", status_attack = "silence", ail = 18, support = "mire",
		negotiable = true, talk_difficulty = 3, personality = "lonely", wants = "potion",
		sprite = "res://resources/enemySprites/Fairy.png"},
	{name = "Elder Treant",     lv =  9, icons = 2,
		str =  7, def =  7, mag =  0, agl =  1,
		exp =  55, gold =  17, min_floor = 3, max_floor = -1,
		weakness = "fire", phys = "resist", light = "resist", dark = "resist",
		status_attack = "immobilize", ail = 18,
		negotiable = false, talk_difficulty = 0,
		sprite = "res://resources/enemySprites/TreantB.png"},
	{name = "Orc Warchief",     lv =  9, icons = 2,
		str =  8, def =  5, mag =  0, agl =  2,
		exp =  46, gold =  15, min_floor = 3, max_floor =  5,
		weakness = "ice",
		status_attack = "", ail = 18, support = "whet",
		negotiable = true, talk_difficulty = 4, personality = "proud", wants = "throwable",
		sprite = "res://resources/enemySprites/OrcB.png"},
	{name = "Dark Fairy",       lv =  9,
		str =  3, def =  3, mag =  7, agl =  8,
		exp =  50, gold =  17, min_floor = 3, max_floor = -1,
		weakness = "thunder", phys = "weak", light = "weak", dark = "resist", absorb_element = "thunder",
		attack_element = "dark", status_attack = "silence", ail = 18, support = "mire",
		negotiable = true, talk_difficulty = 3, personality = "lonely", wants = "potion",
		sprite = "res://resources/enemySprites/FairyB.png"},
	# --- Floor 4+ ---
	{name = "Ogre",             lv = 11, icons = 2,
		str =  9, def =  5, mag =  0, agl =  1,
		exp =  55, gold =  18, min_floor = 4, max_floor = -1,
		weakness = "ice",
		status_attack = "", ail = 22,
		negotiable = true, talk_difficulty = 4, personality = "proud", wants = "any",
		sprite = "res://resources/enemySprites/Ogre.png"},
	{name = "Wizard",           lv = 11,
		str =  2, def =  2, mag =  8, agl =  4,
		exp =  52, gold =  16, min_floor = 4, max_floor = -1,
		weakness = "ice", phys = "weak", dark = "resist", reflect_element = "fire",
		attack_element = "fire", status_attack = "silence", ail = 22, support = "whet",
		negotiable = true, talk_difficulty = 3, personality = "proud", wants = "potion",
		sprite = "res://resources/enemySprites/Wizard.png"},
	{name = "Stone Ogre",       lv = 12, icons = 2,
		str = 10, def =  6, mag =  0, agl =  1,
		exp =  65, gold =  22, min_floor = 4, max_floor = -1,
		weakness = "ice",
		status_attack = "", ail = 22, support = "ward",
		negotiable = true, talk_difficulty = 5, personality = "proud", wants = "any",
		sprite = "res://resources/enemySprites/OgreB.png"},
	{name = "Dark Wizard",      lv = 12,
		str =  3, def =  3, mag =  9, agl =  4,
		exp =  62, gold =  20, min_floor = 4, max_floor = -1,
		weakness = "ice", phys = "weak", light = "weak", dark = "null", reflect_element = "fire",
		attack_element = "dark", status_attack = "silence", ail = 22, support = "stoke",
		negotiable = true, talk_difficulty = 4, personality = "proud", wants = "potion",
		sprite = "res://resources/enemySprites/WizardB.png"},
]

# ── Written for this game, still waiting on art ───────────────────────────────
#
# Everything below is original to the detective case: the fantasy roster above
# is placeholder and these are not. Each carries `needs_art=true` and an
# `art_note` describing exactly what it looks like, because the sprite is the
# only thing standing between these and the live game. Nothing here is or ever
# was an object of worship.
#
# Wardens are the floor's locked door made flesh. One sits on each maze floor,
# does not roam, and holds the key — so unlike a random encounter it cannot be
# avoided, walked around, or fled from for long. They are repressions: the
# thing in a mind that will not let you go further in. Two icons each, so the
# fight is a wall rather than a speed bump, and none of them can be talked down.
const WARDEN_TEMPLATES: Array[Dictionary] = [
	{name = "Hushmouth",        lv =  4, icons = 2,
		str =  5, def =  4, mag =  2, agl =  3,
		exp =  70, gold =  30, min_floor = 1, max_floor =  1,
		weakness = "fire", phys = "weak",
		status_attack = "silence", ail = 5,
		negotiable = false, talk_difficulty = 0,
		sprite = "", needs_art = true,
		art_note = "A human jaw on its own, hung at head height across the doorway, wired shut through "
				+ "the teeth with rusted picture wire. No skull above it and no body below. The wire is "
				+ "bright and new; somebody keeps re-doing it."},

	{name = "The Held Breath",  lv =  6, icons = 2,
		str =  6, def =  5, mag =  5, agl =  4,
		exp = 110, gold =  45, min_floor = 2, max_floor =  2,
		weakness = "thunder", phys = "resist", light = "weak",
		status_attack = "immobilize", ail = 8, support = "ward",
		negotiable = false, talk_difficulty = 0,
		sprite = "", needs_art = true,
		art_note = "A room's worth of air pulled into the outline of someone standing, visible only "
				+ "where dust presses against the seam of it. Inside the outline the dust never "
				+ "settles. It does not move. The room moves around it."},

	{name = "Vacancy",          lv =  8, icons = 2,
		str =  7, def =  6, mag =  7, agl =  4,
		exp = 160, gold =  60, min_floor = 3, max_floor =  3,
		weakness = "ice", phys = "null", dark = "weak",
		attack_element = "ice", status_attack = "silence", ail = 10,
		negotiable = false, talk_difficulty = 0,
		sprite = "", needs_art = true,
		art_note = "A tall adult silhouette filling a lit doorway, backlit hard enough that you cannot "
				+ "see into it — except there is no light behind it, and no room behind it either. Its "
				+ "edges are crisp enough to cut, and they do not match the doorway it is standing in — "
				+ "they are the outline of some other door entirely."},
]


# Boss templates — one per 5-floor milestone, cycling every 4 bosses.
const BOSS_TEMPLATES: Array[Dictionary] = [
	{name = "The Tenant",       lv = 10, icons = 3,
		str = 10, def =  8, mag =  8, agl =  4,
		exp = 260, gold = 120, min_floor = 3, max_floor = -1,
		weakness = "fire", phys = "resist", light = "null", dark = "null",
		attack_element = "dark", status_attack = "immobilize", ail = 15, support = "ward",
		negotiable = false, talk_difficulty = 0,
		sprite = "", needs_art = true,
		art_note = "A heavy seated figure built out of years of nesting material — matted hair, dust, "
				+ "chewed paper, shed skin — packed dense and settled so deep it has gone the shape of "
				+ "whatever it sits on. A face is pressed into the front of the mass, worn smooth from "
				+ "use, and it opens to speak. Its limbs are stubby and folded away underneath; it has "
				+ "not needed them in a long time and it does not get up.",
		design_note = "Weak to fire on purpose — fire is the one spell the detective starts with, so the "
				+ "first boss is answerable with the kit he actually owns. The body earns it too: years "
				+ "of packed dry fibre. A blade sinks into that and finds nothing, which is the phys "
				+ "resist. Nulls both banishing lines like every boss."},
	{name = "Shadow Knight",    lv = 12, icons = 3,
		str = 12, def =  8, mag =  2, agl =  3,
		exp = 200, gold =  80, min_floor = 5, max_floor = -1,
		weakness = "thunder", light = "null", dark = "null",
		status_attack = "immobilize", ail = 25, support = "ward",
		negotiable = false, talk_difficulty = 0,
		sprite = ""},
	{name = "Bone Sorcerer",    lv = 14, icons = 3,
		str =  5, def =  6, mag = 14, agl =  4,
		exp = 280, gold = 110, min_floor = 10, max_floor = -1,
		weakness = "ice", light = "null", dark = "null",
		attack_element = "fire", status_attack = "silence", ail = 25, support = "stoke",
		negotiable = false, talk_difficulty = 0,
		sprite = ""},
	{name = "Iron Titan",       lv = 16, icons = 4,
		str = 16, def = 12, mag =  0, agl =  1,
		exp = 360, gold = 140, min_floor = 15, max_floor = -1,
		weakness = "thunder", light = "null", dark = "null",
		status_attack = "paralyzed", ail = 25, support = "ward",
		negotiable = false, talk_difficulty = 0,
		sprite = ""},
	{name = "Void Drake",       lv = 18, icons = 4,
		str = 14, def = 10, mag = 12, agl =  5,
		exp = 450, gold = 180, min_floor = 20, max_floor = -1,
		weakness = "ice", light = "null", dark = "null",
		attack_element = "thunder", status_attack = "", ail = 25, support = "damp",
		negotiable = false, talk_difficulty = 0,
		sprite = ""},
]



# Folds the template's element fields into a single affinity chart.
# weakness -> WEAK, reflect -> REPEL, absorb -> DRAIN, plus an optional
# explicit "phys" state for enemies that shrug off or crumple to a blade.
static func _affinities_from(t: Dictionary) -> Dictionary:
	var a: Dictionary = {}
	var w: String = t.get("weakness", "")
	if w != "":
		a[w] = Affinity.WEAK
	var r: String = t.get("reflect_element", "")
	if r != "":
		a[r] = Affinity.REPEL
	var d: String = t.get("absorb_element", "")
	if d != "":
		a[d] = Affinity.DRAIN
	var p: String = t.get("phys", "")
	if p != "":
		a[Affinity.PHYS] = p
	# Light and dark come off what the thing IS. The dead answer to light and
	# ignore the dark; things barely alive shrug off both.
	var li: String = t.get("light", "")
	if li != "":
		a[Affinity.LIGHT] = li
	var dk: String = t.get("dark", "")
	if dk != "":
		a[Affinity.DARK] = dk
	return a


static func make_random(floor_num: int) -> Enemy:
	var pool: Array[Dictionary] = []
	for tmpl: Dictionary in TEMPLATES:
		if floor_num >= tmpl["min_floor"] and (tmpl["max_floor"] == -1 or floor_num <= tmpl["max_floor"]):
			pool.append(tmpl)
	if pool.is_empty():
		pool = TEMPLATES
	return _build(pool[randi() % pool.size()], floor_num)


# Rolls an encounter. Sizes run 1-4 weighted 1:2:3:4, so a lone demon turns up
# a tenth of the time and a full pack of four is the single likeliest outcome.
static func make_group(floor_num: int) -> Array[Enemy]:
	var roll: int  = randi() % 10
	var count: int = 4
	if roll < 1:
		count = 1
	elif roll < 3:
		count = 2
	elif roll < 6:
		count = 3
	var group: Array[Enemy] = []
	for _i: int in range(count):
		group.append(make_random(floor_num))
	return group


# One boss per run of FLOOR_COUNT floors. The old index went negative on a
# short run and quietly handed back the LAST boss — the hardest one.
static func make_boss(floor_num: int) -> Enemy:
	var idx: int = clampi(floor_num / maxi(1, Level.FLOOR_COUNT) - 1,
			0, BOSS_TEMPLATES.size() - 1)
	var t: Dictionary = BOSS_TEMPLATES[idx]
	var e: Enemy = Enemy.new()
	e.enemy_name      = t["name"]
	e.lv              = int(t.get("lv", 12))
	e.str             = t["str"]
	e.def             = t["def"]
	e.mag             = t["mag"]
	e.agl             = t["agl"]
	e.exp_to_next     = 0
	e.exp_reward      = t["exp"]
	e.gold_reward     = t["gold"]
	e.status_attack   = t.get("status_attack", "")
	e.weakness        = t.get("weakness", "")
	e.negotiable      = false
	e.talk_difficulty = 0
	e.talk_personality = "proud"
	e.bribe_wants     = "any"
	e.sprite_path     = t.get("sprite", "")
	e.attack_element  = t.get("attack_element", "")
	e.reflect_element = t.get("reflect_element", "")
	e.absorb_element  = t.get("absorb_element", "")
	e.affinities      = _affinities_from(t)
	e.icons           = int(t.get("icons", 3))
	e.support_skill   = t.get("support", "")
	e.ailment_chance  = int(t.get("ail", 25))
	e.compute_max_hp()
	e.compute_max_mp()
	return e


# The warden for a given maze floor. Floors past the written ones fall back to
# the last warden rather than to a random demon, so the key always has a keeper.
static func make_warden(floor_num: int) -> Enemy:
	var idx: int = clampi(floor_num - 1, 0, WARDEN_TEMPLATES.size() - 1)
	return _build(WARDEN_TEMPLATES[idx], floor_num)


# Everything still waiting on a sprite, so the art queue can be read off the
# data rather than kept in somebody's head.
static func needing_art() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for t: Dictionary in all_templates():
		if bool(t.get("needs_art", false)):
			out.append(t)
	return out


static func all_templates() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	result.append_array(TEMPLATES)
	result.append_array(WARDEN_TEMPLATES)
	result.append_array(BOSS_TEMPLATES)
	return result



static func make_from_name(enemy_name: String, floor_num: int = 1) -> Enemy:
	for tmpl: Dictionary in all_templates():
		if tmpl["name"] == enemy_name:
			return _build(tmpl, floor_num)
	return make_random(floor_num)


# A demon's level and stats come off its own template and nothing else, so the
# same kind is the same fight wherever you meet it. Progression comes from which
# demons a floor can draw, not from inflating the ones you already know.
static func _build(t: Dictionary, floor_num: int) -> Enemy:
	var e: Enemy = Enemy.new()
	e.enemy_name      = t["name"]
	e.lv              = int(t.get("lv", 2))
	e.str             = t["str"]
	e.def             = t["def"]
	e.mag             = t["mag"]
	e.agl             = t["agl"]
	e.exp_to_next     = 0
	e.exp_reward      = t["exp"]
	e.gold_reward     = t["gold"]
	e.status_attack   = t.get("status_attack", "")
	e.weakness        = t.get("weakness", "")
	e.negotiable       = t.get("negotiable", true)
	e.talk_difficulty  = t.get("talk_difficulty", 2)
	e.talk_personality = t.get("personality", "cowardly")
	e.bribe_wants      = t.get("wants", "any")
	e.sprite_path      = t.get("sprite", "")
	e.attack_element  = t.get("attack_element", "")
	e.reflect_element = t.get("reflect_element", "")
	e.absorb_element  = t.get("absorb_element", "")
	e.affinities      = _affinities_from(t)
	e.icons           = int(t.get("icons", 1))
	e.support_skill   = t.get("support", "")
	e.ailment_chance  = int(t.get("ail", 12))
	e.compute_max_hp()
	e.compute_max_mp()
	return e


# What one cast of its element costs. Scales with the demon's own magic, so a
# strong caster gets a bigger pool and a bigger bill rather than infinite uses.
func skill_cost() -> int:
	if attack_element == "":
		return 0
	return maxi(6, mag)


func can_afford_skill() -> bool:
	return attack_element != "" and mp >= skill_cost()


# Returns a random item drop, or an empty dict if nothing drops (65% no-drop).
func roll_drop() -> Dictionary:
	if randi() % 100 < 65:
		return {}
	var table: Array[Dictionary] = Item.drop_table()
	return table[randi() % table.size()]
