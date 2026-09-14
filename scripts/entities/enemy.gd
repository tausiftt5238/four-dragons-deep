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

# How the sprite is tinted for the floor it was drawn on. One palette is drawn
# per tier; within a tier the engine walks the same sprite from cool to hot
# across the five floors, so a floor-nine Bat is visibly not a floor-six Bat
# without anybody drawing a second Bat.
var tint: Color = Color.WHITE


# Cool and pale at the top of a tier, hot and bright at the bottom of it.
static func tint_for_floor(floor_num: int) -> Color:
	var step: float = float((floor_num - 1) % Level.BOSS_EVERY) / float(Level.BOSS_EVERY - 1)
	return Color(0.82, 0.88, 1.0).lerp(Color(1.0, 0.72, 0.62), step)


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
#   6  how it can be talked down
#   7  its sprite
#
# A key that is absent means the default: no element, no support, no affinity
# beyond the chart above. Lines 4-6 are the ones worth scanning down.
#
# Two rules the roster is written to:
#
#   * Everything here talks. Binding is where the party comes from and a demon
#     that cannot be talked to is a dead end wearing a sprite; only the wardens
#     and the bosses below are exempt, and they are set pieces.
#   * Nothing on the first tier resists a physical swing. A floor-one player
#     has a swing and one spell, and four of these used to answer both with
#     "resisted" — the slimes keep their high guard and their light resistance
#     to feel different, which is as far as it goes that early.
const TEMPLATES: Array[Dictionary] = [
	# --- Floor 1-2 ---
	{name = "Bat",              lv =  1,
		str =  2, def =  1, mag =  0, agl =  5,
		exp =  12, gold =   4, tier = 1, rank = 0, min_floor = 1, max_floor =  2,
		weakness = "fire", phys = "weak",
		status_attack = "", ail = 5,
		negotiable = true, talk_difficulty = 1, personality = "cowardly", wants = "any",
		sprite = "res://resources/enemySprites/Bat.png"},
	{name = "Slug",             lv =  1,
		str =  2, def =  2, mag =  0, agl =  1,
		exp =  18, gold =   6, tier = 1, rank = 0, min_floor = 1, max_floor =  2,
		weakness = "fire", light = "resist",
		status_attack = "poison", ail = 5,
		negotiable = true, talk_difficulty = 1, personality = "cowardly", wants = "any",
		sprite = "res://resources/enemySprites/Slug.png"},
	{name = "GiantRat",         lv =  1,
		str =  3, def =  2, mag =  0, agl =  3,
		exp =  20, gold =   6, tier = 1, rank = 0, min_floor = 1, max_floor =  2,
		weakness = "fire",
		status_attack = "", ail = 5,
		negotiable = true, talk_difficulty = 1, personality = "cowardly", wants = "potion",
		sprite = "res://resources/enemySprites/GiantRat.png"},
	{name = "Cave Bat",         lv =  2,
		str =  3, def =  2, mag =  3, agl =  6,
		exp =  16, gold =   5, tier = 1, rank = 0, min_floor = 1, max_floor =  2,
		weakness = "fire", phys = "weak",
		attack_element = "thunder", status_attack = "", ail = 5,
		negotiable = true, talk_difficulty = 1, personality = "cowardly", wants = "any",
		sprite = "res://resources/enemySprites/BatB.png"},
	{name = "Giant Slug",       lv =  2,
		str =  3, def =  3, mag =  0, agl =  1,
		exp =  22, gold =   7, tier = 1, rank = 0, min_floor = 1, max_floor =  2,
		weakness = "fire", light = "resist",
		status_attack = "poison", ail = 5,
		negotiable = true, talk_difficulty = 1, personality = "cowardly", wants = "any",
		sprite = "res://resources/enemySprites/SlugB.png"},
	{name = "Dire Rat",         lv =  2,
		str =  4, def =  3, mag =  0, agl =  4,
		exp =  25, gold =   8, tier = 1, rank = 0, min_floor = 1, max_floor =  2,
		weakness = "fire",
		status_attack = "poison", ail = 5,
		negotiable = true, talk_difficulty = 1, personality = "cowardly", wants = "potion",
		sprite = "res://resources/enemySprites/GiantRatB.png"},
	# --- Floor 1-3 ---
	{name = "Goblin",           lv =  2,
		str =  4, def =  2, mag =  0, agl =  4,
		exp =  25, gold =   8, tier = 1, rank = 0, min_floor = 1, max_floor =  3,
		weakness = "fire", phys = "weak",
		status_attack = "", ail = 5,
		negotiable = true, talk_difficulty = 2, personality = "greedy", wants = "throwable",
		sprite = "res://resources/enemySprites/Goblin.png"},
	{name = "GelatinousCube",   lv =  2,
		str =  2, def =  4, mag =  0, agl =  1,
		exp =  22, gold =   7, tier = 1, rank = 0, min_floor = 1, max_floor =  3,
		weakness = "fire", light = "resist",
		attack_element = "ice", status_attack = "immobilize", ail = 5,
		negotiable = true, talk_difficulty = 2, personality = "greedy", wants = "any",
		sprite = "res://resources/enemySprites/GelatinousCube.png"},
	{name = "Hobgoblin",        lv =  3,
		str =  5, def =  3, mag =  0, agl =  5,
		exp =  32, gold =  10, tier = 1, rank = 1, min_floor = 1, max_floor =  3,
		weakness = "fire", phys = "weak",
		status_attack = "", ail = 5,
		negotiable = true, talk_difficulty = 2, personality = "greedy", wants = "throwable",
		sprite = "res://resources/enemySprites/GoblinB.png"},
	{name = "Ooze",             lv =  3,
		str =  3, def =  5, mag =  0, agl =  1,
		exp =  28, gold =   9, tier = 1, rank = 1, min_floor = 1, max_floor =  3,
		weakness = "fire", light = "resist",
		attack_element = "ice", status_attack = "immobilize", ail = 5,
		negotiable = true, talk_difficulty = 2, personality = "greedy", wants = "any",
		sprite = "res://resources/enemySprites/GelatinousCubeB.png"},
	# --- Floor 2-4 ---
	{name = "Skeleton",         lv =  5,
		str =  5, def =  3, mag =  1, agl =  2,
		exp =  30, gold =  10, tier = 2, rank = 0, min_floor = 2, max_floor =  4,
		weakness = "fire", phys = "resist", light = "weak", dark = "null",
		status_attack = "immobilize", ail = 12,
		negotiable = true, talk_difficulty = 2, personality = "proud", wants = "throwable",
		sprite = "res://resources/enemySprites/Skeleton.png"},
	{name = "GiantHornet",      lv =  5,
		str =  4, def =  2, mag =  0, agl =  6,
		exp =  28, gold =   9, tier = 2, rank = 0, min_floor = 2, max_floor =  4,
		weakness = "ice", phys = "weak",
		status_attack = "poison", ail = 12,
		negotiable = true, talk_difficulty = 2, personality = "proud", wants = "any",
		sprite = "res://resources/enemySprites/GiantHornet.png"},
	{name = "Bandit",           lv =  5,
		str =  5, def =  3, mag =  3, agl =  5,
		exp =  32, gold =  12, tier = 2, rank = 0, min_floor = 2, max_floor =  4,
		weakness = "thunder", phys = "weak",
		attack_element = "fire", status_attack = "", ail = 12,
		negotiable = true, talk_difficulty = 2, personality = "greedy", wants = "any",
		sprite = "res://resources/enemySprites/Bandit.png"},
	{name = "WildBoar",         lv =  5,
		str =  6, def =  3, mag =  0, agl =  2,
		exp =  30, gold =   9, tier = 2, rank = 0, min_floor = 2, max_floor =  4,
		weakness = "ice",
		status_attack = "", ail = 12,
		negotiable = true, talk_difficulty = 2, personality = "cowardly", wants = "potion",
		sprite = "res://resources/enemySprites/WildBoar.png"},
	{name = "AnimatedPlant",    lv =  5,
		str =  3, def =  3, mag =  4, agl =  1,
		exp =  28, gold =   8, tier = 2, rank = 0, min_floor = 2, max_floor =  4,
		weakness = "fire", light = "resist", dark = "resist",
		status_attack = "poison", ail = 12,
		negotiable = true, talk_difficulty = 2, personality = "lonely", wants = "potion",
		sprite = "res://resources/enemySprites/AnimatedPlant.png"},
	{name = "Bone Knight",      lv =  6,
		str =  6, def =  4, mag =  2, agl =  2,
		exp =  38, gold =  12, tier = 2, rank = 0, min_floor = 2, max_floor =  4,
		weakness = "fire", phys = "resist", light = "weak", dark = "null",
		status_attack = "immobilize", ail = 12,
		negotiable = true, talk_difficulty = 3, personality = "proud", wants = "throwable",
		sprite = "res://resources/enemySprites/SkeletonB.png"},
	{name = "Queen Hornet",     lv =  6,
		str =  5, def =  3, mag =  0, agl =  7,
		exp =  35, gold =  11, tier = 2, rank = 0, min_floor = 2, max_floor =  4,
		weakness = "ice", phys = "weak",
		status_attack = "poison", ail = 12,
		negotiable = true, talk_difficulty = 3, personality = "proud", wants = "any",
		sprite = "res://resources/enemySprites/GiantHornetB.png"},
	{name = "Veteran Bandit",   lv =  6,
		str =  6, def =  4, mag =  0, agl =  5,
		exp =  40, gold =  15, tier = 2, rank = 0, min_floor = 2, max_floor =  4,
		weakness = "thunder", phys = "weak",
		status_attack = "", ail = 12,
		negotiable = true, talk_difficulty = 3, personality = "greedy", wants = "any",
		sprite = "res://resources/enemySprites/BanditB.png"},
	{name = "Tusked Boar",      lv =  6,
		str =  7, def =  4, mag =  0, agl =  2,
		exp =  38, gold =  11, tier = 2, rank = 0, min_floor = 2, max_floor =  4,
		weakness = "ice",
		status_attack = "", ail = 12,
		negotiable = true, talk_difficulty = 2, personality = "cowardly", wants = "potion",
		sprite = "res://resources/enemySprites/WildBoarB.png"},
	{name = "Thornvine",        lv =  6,
		str =  4, def =  4, mag =  5, agl =  1,
		exp =  35, gold =  10, tier = 2, rank = 0, min_floor = 2, max_floor =  4,
		weakness = "fire", light = "resist", dark = "resist",
		status_attack = "poison", ail = 12,
		negotiable = true, talk_difficulty = 3, personality = "lonely", wants = "potion",
		sprite = "res://resources/enemySprites/AnimatedPlantB.png"},
	# --- Floor 3+ ---
	{name = "Treant",           lv =  8,
		str =  6, def =  6, mag =  0, agl =  1,
		exp =  45, gold =  14, tier = 3, rank = 0, min_floor = 3, max_floor = -1,
		weakness = "fire", phys = "resist", light = "resist", dark = "resist",
		status_attack = "immobilize", ail = 18,
		negotiable = true, talk_difficulty = 3, personality = "lonely", wants = "potion",
		sprite = "res://resources/enemySprites/Treant.png"},
	{name = "Orc",              lv =  8,
		str =  7, def =  4, mag =  0, agl =  2,
		exp =  38, gold =  12, tier = 3, rank = 0, min_floor = 3, max_floor =  5,
		weakness = "ice",
		status_attack = "", ail = 18,
		negotiable = true, talk_difficulty = 3, personality = "proud", wants = "throwable",
		sprite = "res://resources/enemySprites/Orc.png"},
	{name = "Fairy",            lv =  8,
		str =  2, def =  2, mag =  6, agl =  7,
		exp =  42, gold =  14, tier = 3, rank = 0, min_floor = 3, max_floor = -1,
		weakness = "thunder", phys = "weak", light = "resist", dark = "weak", absorb_element = "thunder",
		attack_element = "thunder", status_attack = "silence", ail = 18, support = "mire",
		negotiable = true, talk_difficulty = 3, personality = "lonely", wants = "potion",
		sprite = "res://resources/enemySprites/Fairy.png"},
	{name = "Elder Treant",     lv =  9, icons = 2,
		str =  7, def =  7, mag =  0, agl =  1,
		exp =  55, gold =  17, tier = 3, rank = 0, min_floor = 3, max_floor = -1,
		weakness = "fire", phys = "resist", light = "resist", dark = "resist",
		status_attack = "immobilize", ail = 18,
		negotiable = true, talk_difficulty = 4, personality = "proud", wants = "potion",
		sprite = "res://resources/enemySprites/TreantB.png"},
	{name = "Orc Warchief",     lv =  9, icons = 2,
		str =  8, def =  5, mag =  0, agl =  2,
		exp =  46, gold =  15, tier = 3, rank = 0, min_floor = 3, max_floor =  5,
		weakness = "ice",
		status_attack = "", ail = 18, support = "whet",
		negotiable = true, talk_difficulty = 4, personality = "proud", wants = "throwable",
		sprite = "res://resources/enemySprites/OrcB.png"},
	{name = "Dark Fairy",       lv =  9,
		str =  3, def =  3, mag =  7, agl =  8,
		exp =  50, gold =  17, tier = 3, rank = 0, min_floor = 3, max_floor = -1,
		weakness = "thunder", phys = "weak", light = "weak", dark = "resist", absorb_element = "thunder",
		attack_element = "dark", status_attack = "silence", ail = 18, support = "mire",
		negotiable = true, talk_difficulty = 3, personality = "lonely", wants = "potion",
		sprite = "res://resources/enemySprites/FairyB.png"},
	# --- Floor 4+ ---
	{name = "Ogre",             lv = 11, icons = 2,
		str =  9, def =  5, mag =  0, agl =  1,
		exp =  55, gold =  18, tier = 4, rank = 0, min_floor = 4, max_floor = -1,
		weakness = "ice",
		status_attack = "", ail = 22,
		negotiable = true, talk_difficulty = 4, personality = "proud", wants = "any",
		sprite = "res://resources/enemySprites/Ogre.png"},
	{name = "Wizard",           lv = 11,
		str =  2, def =  2, mag =  8, agl =  4,
		exp =  52, gold =  16, tier = 4, rank = 0, min_floor = 4, max_floor = -1,
		weakness = "ice", phys = "weak", dark = "resist", reflect_element = "fire",
		attack_element = "fire", status_attack = "silence", ail = 22, support = "whet",
		negotiable = true, talk_difficulty = 3, personality = "proud", wants = "potion",
		sprite = "res://resources/enemySprites/Wizard.png"},
	{name = "Stone Ogre",       lv = 12, icons = 2,
		str = 10, def =  6, mag =  0, agl =  1,
		exp =  65, gold =  22, tier = 4, rank = 0, min_floor = 4, max_floor = -1,
		weakness = "ice",
		status_attack = "", ail = 22, support = "ward",
		negotiable = true, talk_difficulty = 5, personality = "proud", wants = "any",
		sprite = "res://resources/enemySprites/OgreB.png"},
	{name = "Dark Wizard",      lv = 12,
		str =  3, def =  3, mag =  9, agl =  4,
		exp =  62, gold =  20, tier = 4, rank = 0, min_floor = 4, max_floor = -1,
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
	{name = "Gargoyle",        icons = 2,
		str =  6, def =  7, mag =  2, agl =  2,
		weakness = "thunder", phys = "resist", light = "resist",
		status_attack = "immobilize", ail = 8,
		negotiable = false, talk_difficulty = 0,
		sprite = "", needs_art = true,
		art_note = "A squat stone thing perched on the lintel with its knees up under its chin and "
				+ "its wings folded flat down its back. It is the same grey as the wall and it has "
				+ "been part of it for a long time. The only thing that moves first is the head.",
		design_note = "Stone: a blade glances off it, and current finds it the way current finds "
				+ "anything standing alone on a high point."},

	{name = "Barrow Wight",    icons = 2,
		str =  7, def =  5, mag =  6, agl =  3,
		weakness = "fire", phys = "resist", light = "weak", dark = "null",
		status_attack = "silence", ail = 10, support = "mire",
		negotiable = false, talk_difficulty = 0,
		sprite = "", needs_art = true,
		art_note = "A dry, sunken figure in the rags of something that was once well made, wearing "
				+ "far more rings than it has fingers left. It does not guard the door so much as "
				+ "guard what it is holding, and the key is simply one of the things it holds.",
		design_note = "Undead, so it follows the same chart as the Skeleton line: light takes it and "
				+ "dark slides off. It has the key because a wight hoards, not because it was posted."},

	{name = "Chained Hound",   icons = 2,
		str =  9, def =  4, mag =  0, agl =  7,
		weakness = "ice", phys = "weak",
		status_attack = "paralyzed", ail = 14,
		negotiable = false, talk_difficulty = 0,
		sprite = "", needs_art = true,
		art_note = "Lean, long-legged and already at the end of its chain when you come round the "
				+ "corner. The collar is iron and far newer than the animal. There is a worn arc "
				+ "scraped into the floor showing exactly how far it reaches, and the door is just "
				+ "outside it.",
		design_note = "Fast and fragile: it hits hard and often but a blade finds it easily. The "
				+ "chain is why a warden does not roam — the one warden with a reason to."},

	{name = "Basilisk",        icons = 2,
		str =  7, def =  6, mag =  8, agl =  2,
		weakness = "thunder", phys = "resist", dark = "resist",
		attack_element = "ice", status_attack = "immobilize", ail = 18, support = "ward",
		negotiable = false, talk_difficulty = 0,
		sprite = "", needs_art = true,
		art_note = "A heavy crested lizard coiled across the whole width of the passage, in no hurry "
				+ "at all. Its eyes are the only part of it that is not dull. Around it, at the edges "
				+ "of the floor, are several things that used to be standing up.",
		design_note = "It never has to move, so it is slow and well armoured and leans on immobilising "
				+ "you. The highest ailment chance of any warden."},

	{name = "Mimic",           icons = 2,
		str =  8, def =  6, mag =  3, agl =  4,
		weakness = "fire", phys = "resist", light = "weak",
		status_attack = "poison", ail = 12,
		negotiable = false, talk_difficulty = 0,
		sprite = "", needs_art = true,
		art_note = "A cache set into the wall, lit from inside exactly like the real ones, sitting a "
				+ "little further forward than a recess should allow. When it opens, the opening keeps "
				+ "going: the lid is the upper jaw and the shelf it was resting on is the lower one.",
		design_note = "Placed among real caches, so the floor's own furniture becomes a thing to read "
				+ "twice. Weak to fire and to light because the disguise is the whole of its defence."},
]



# Boss templates — one per 5-floor milestone, cycling every 4 bosses.
const BOSS_TEMPLATES: Array[Dictionary] = [
	{name = "Shadow Knight",    lv = 12, icons = 3,
		str = 12, def =  8, mag =  2, agl =  3,
		exp = 200, gold =  80, tier = 4, rank = 0, min_floor = 5, max_floor = -1,
		weakness = "thunder", light = "null", dark = "null",
		status_attack = "immobilize", ail = 25, support = "ward",
		negotiable = false, talk_difficulty = 0,
		sprite = ""},
	{name = "Bone Sorcerer",    lv = 14, icons = 3,
		str =  5, def =  6, mag = 14, agl =  4,
		exp = 280, gold = 110, tier = 4, rank = 0, min_floor = 10, max_floor = -1,
		weakness = "ice", light = "null", dark = "null",
		attack_element = "fire", status_attack = "silence", ail = 25, support = "stoke",
		negotiable = false, talk_difficulty = 0,
		sprite = ""},
	{name = "Iron Titan",       lv = 16, icons = 4,
		str = 16, def = 12, mag =  0, agl =  1,
		exp = 360, gold = 140, tier = 4, rank = 0, min_floor = 15, max_floor = -1,
		weakness = "thunder", light = "null", dark = "null",
		status_attack = "paralyzed", ail = 25, support = "ward",
		negotiable = false, talk_difficulty = 0,
		sprite = ""},
	{name = "Void Drake",       lv = 18, icons = 4,
		str = 14, def = 10, mag = 12, agl =  5,
		exp = 450, gold = 180, tier = 4, rank = 0, min_floor = 20, max_floor = -1,
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
	# Draw from this floor's tier, widening downward if a tier is thin rather
	# than falling back to the whole table, which would put a tier-one Bat in
	# front of you on floor nineteen.
	var want: int = tier_for_floor(floor_num)
	var pool: Array[Dictionary] = []
	while pool.is_empty() and want >= 1:
		for tmpl: Dictionary in TEMPLATES:
			if int(tmpl.get("tier", 1)) == want:
				pool.append(tmpl)
		want -= 1
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
	var idx: int = clampi(floor_num / maxi(1, Level.BOSS_EVERY) - 1,
			0, BOSS_TEMPLATES.size() - 1)
	var t: Dictionary = BOSS_TEMPLATES[idx]
	var e: Enemy = Enemy.new()
	e.enemy_name      = t["name"]
	e.lv              = maxi(2, floor_num * 2)
	var scale: float = 1.0 + float(e.lv - 1) * 0.22
	e.str             = maxi(1, roundi(float(t["str"]) * scale))
	e.def             = maxi(1, roundi(float(t["def"]) * scale))
	e.mag             = roundi(float(t["mag"]) * scale)
	e.agl             = maxi(1, roundi(float(t["agl"]) * scale))
	e.exp_to_next     = 0
	e.exp_reward      = exp_for_level(e.lv) * 3
	e.gold_reward     = e.lv * 12
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
	# A boss keeps its own colours; it is not one of a set.
	e.tint            = Color.WHITE
	e.compute_max_hp()
	e.compute_max_mp()
	return e


# Rebuilds a demon at the level it was bound at. A demon never levels, so the
# one you caught on floor three is a floor-three demon forever — which is the
# whole reason selling it on to fund a deeper one is a real decision.
static func make_at_level(enemy_name: String, lv: int) -> Enemy:
	for tmpl: Dictionary in all_templates():
		if tmpl["name"] == enemy_name:
			var floor_guess: int = maxi(1, roundi(float(lv) / 1.5))
			var e: Enemy = _build(tmpl, floor_guess)
			e.lv = maxi(1, lv)
			var scale: float = 1.0 + float(e.lv - 1) * 0.22
			e.str = maxi(1, roundi(float(tmpl["str"]) * scale))
			e.def = maxi(1, roundi(float(tmpl["def"]) * scale))
			e.mag = roundi(float(tmpl["mag"]) * scale)
			e.agl = maxi(1, roundi(float(tmpl["agl"]) * scale))
			e.exp_reward = exp_for_level(e.lv)
			e.gold_reward = maxi(4, e.lv * 3)
			e.compute_max_hp()
			e.compute_max_mp()
			return e
	return make_random(1)


# The warden for a given maze floor. Floors past the written ones fall back to
# the last warden rather than to a random demon, so the key always has a keeper.
# It is built at the floor's own level like anything else down there.
static func make_warden(floor_num: int) -> Enemy:
	# Counted in MAZE floors, not raw ones. Indexing by floor number couples the
	# rotation to the boss cadence, and with five wardens and a boss every fifth
	# floor the fifth warden only ever came up on floors that have no warden —
	# the Mimic was written and then never appeared once.
	var maze_index: int = (floor_num - 1) - (floor_num - 1) / Level.BOSS_EVERY
	var idx: int = clampi(maze_index % WARDEN_TEMPLATES.size(),
			0, WARDEN_TEMPLATES.size() - 1)
	var e: Enemy = _build(WARDEN_TEMPLATES[idx], floor_num)
	# A warden is the floor's locked door: a step above its neighbours, a step
	# below the boss waiting five floors down.
	e.lv = maxi(2, roundi(float(floor_num) * 1.75))
	e.exp_reward = exp_for_level(e.lv) * 2
	e.gold_reward = e.lv * 6
	e.compute_max_hp()
	e.compute_max_mp()
	return e


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
# What a demon is worth. A rule rather than eighty hand-typed numbers, and it
# reproduces the old values closely at the shallow end — a level 1 Bat was 12
# and comes out 10 — while scaling properly at depth, which is what lets the
# player's level keep up with a boss set at twice the floor number.
static func exp_for_level(lv: int) -> int:
	return 10 + (lv * lv) / 2


# Ordinary demons sit at half again the floor number; a boss sits at twice it.
# So a boss is always a real step up from what you have been fighting rather
# than more of the same. `rank` is the only thing the template still says about
# level: whether it is the weaker or the stronger of its pair.
static func level_for_floor(floor_num: int, rank: int) -> int:
	return maxi(1, roundi(float(floor_num) * 1.5) + rank)


# Which band of demons a floor draws from. Five floors to a tier, four tiers,
# and a boss closing each one.
static func tier_for_floor(floor_num: int) -> int:
	return clampi((floor_num - 1) / Level.BOSS_EVERY + 1, 1, 4)


static func _build(t: Dictionary, floor_num: int) -> Enemy:
	var e: Enemy = Enemy.new()
	e.enemy_name      = t["name"]
	e.lv              = level_for_floor(floor_num, int(t.get("rank", 0)))
	# Stats ride the level rather than the row, so the same demon met deeper is
	# genuinely a harder demon and not just a bigger number over its head.
	var scale: float = 1.0 + float(e.lv - 1) * 0.22
	e.str             = maxi(1, roundi(float(t["str"]) * scale))
	e.def             = maxi(1, roundi(float(t["def"]) * scale))
	e.mag             = roundi(float(t["mag"]) * scale)
	e.agl             = maxi(1, roundi(float(t["agl"]) * scale))
	e.exp_to_next     = 0
	e.exp_reward      = exp_for_level(e.lv)
	e.gold_reward     = maxi(4, e.lv * 3)
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
	e.tint            = tint_for_floor(floor_num)
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
