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
# Which band the demon was written for. Talking reads this directly: a tier is
# the one number a player already understands from the floor they are standing
# on, where talk_difficulty was a private scale nothing on screen ever showed.
var tier:             int    = 1

var talk_difficulty:  int    = 2
var talk_personality: String = "cowardly"
var bribe_wants:      String = "any"
var sprite_path:      String = ""
var sprite_id:        String = ""
# The first element it carries, which is the one the bestiary and Analyze name.
# Everything that actually throws one reads attack_elements.
var attack_element:   String = ""

# Every element it can call up. A template writes either `attack_element = "fire"`
# for one or `attack_elements = ["fire", "ice"]` for several; both land here.
var attack_elements:  Array[String] = []

# A caster never swings. When the pool runs out it reaches for the dregs of its
# cheapest ordinary element rather than throwing a punch — a wizard with no MP
# left is a worse wizard, not a brawler.
var caster:           bool = false

# How wide its element lands: Spell.SHAPE_ONE, SHAPE_FEW or SHAPE_ALL. The same
# value drives it as a foe and as a bound demon, so what a thing did to you is
# exactly what it does for you once it is yours.
var attack_reach:     String = Spell.SHAPE_ONE
var reflect_element:  String = ""

# What a set piece opens its phase with. A warden gets two actions to your
# party's four, a boss gets four — it is one thing standing where a pack would
# be, so the icons are what make it a fight rather than a health bar.
const BOSS_ICONS:   int = 4
const WARDEN_ICONS: int = 2

# A boss's HP as a multiple of what the ordinary formula (lv*10 + def*3) gives
# it, so a dragon is a long fight rather than a few good rounds.
const BOSS_HP_MULT: int = 8

# Press-turn icons this enemy opens its phase with. Bosses get more, which is
# how they threaten a full party without inflating their damage numbers.
var icons: int = 1

# Wardens and bosses keep their chart to themselves — Analyze refuses them and
# killing one teaches nothing. They are met once each in a whole run, so a
# chart handed over in advance would turn the one fight that is supposed to be
# read on the fly into a lookup.
var unreadable: bool = false

# Suffix that keeps three Bats apart in the battle UI. Assigned by CombatScene
# when a group holds more than one of the same kind.
var battle_tag: String = ""

# A support spell this demon leans on, by Spell.DATA id. Empty means it only
# knows how to hit things.
var support_skill: String = ""
# Skills only its own kind has — the bats drink HP and the blood things MP,
# scaled off STR. Ids in Spell.DATA; a template lists them as `unique`.
var unique_skills: Array[String] = []

# Set the first turn a demon reaches for its element and cannot pay. It tries
# every turn now, so without this the log would say so every turn.
var announced_dry: bool = false

# The floor this one was built for. What it carries when it dies is drawn
# against this, so a shallow demon cannot hand over deep gear.
var spawn_floor: int = 1

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


func static_portrait() -> Texture2D:
	if sprite_id != "":
		return AnimatedPortrait.first_frame_texture(sprite_id)
	if sprite_path != "":
		return load(sprite_path) as Texture2D
	return null
var absorb_element:   String = ""

# Levels and stats here are what a template says at a given level, for enemies
# and for the copy a bound demon is rebuilt from. A bound demon's own climb —
# its level and the points it rolled — lives on PlayerCharacter, so this table
# stays the fixed thing both sides are measured against.
# Template data for all enemy types. Stats are base values for floor 1.
# min_floor / max_floor are left over from before the pack drew by tier, and
# nothing reads them: `tier` decides the floors now (see where_found).
#
# Every row is written in the same shape, one concern per line, so a demon's
# chart or its talk data can be found by position rather than by reading:
#
#   1  name, level, press-turn icons
#   2  the four stats
#   3  rewards, and the floors it appears on
#   4  the affinity chart — weakness, then any phys/light/dark/reflect/absorb
#   5  what it does in a fight — elements, ailment, ailment chance, support
#      spell; a demon carrying more than one element puts the list on its own
#      line above the rest
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
	# ── Tier 1 · Floors 1-2 ──────────────────────────────────────────────────
	{name = "Bat",              lv =  1,
		str =  2, def =  1, mag =  0, agl =  5,
		exp =  12, gold =   4, tier = 1, rank = 0, min_floor = 1, max_floor =  2,
		weakness = "thunder", phys = "weak",
		status_attack = "", ail = 5,
		negotiable = true, talk_difficulty = 1, personality = "cowardly", wants = "any",
		unique = ["hp_leech"],
		sprite_id = "Bat"},
	{name = "Slime",            lv =  1,
		str =  2, def =  2, mag =  3, agl =  1,
		exp =  18, gold =   6, tier = 1, rank = 0, min_floor = 1, max_floor =  2,
		weakness = "fire", light = "resist",
		attack_element = "ice", status_attack = "poison", ail = 5,
		negotiable = true, talk_difficulty = 1, personality = "cowardly", wants = "any",
		sprite_id = "Slime"},
	{name = "Skeleton",         lv =  1,
		str =  3, def =  2, mag =  0, agl =  3,
		exp =  20, gold =   6, tier = 1, rank = 0, min_floor = 1, max_floor =  2,
		weakness = "fire", light = "weak", dark = "null",
		status_attack = "", ail = 5,
		negotiable = true, talk_difficulty = 1, personality = "cowardly", wants = "potion",
		sprite_id = "Skeleton"},
	{name = "Hellbat",          lv =  2,
		str =  3, def =  2, mag =  3, agl =  6,
		exp =  16, gold =   5, tier = 1, rank = 0, min_floor = 1, max_floor =  2,
		weakness = "thunder", phys = "weak",
		attack_element = "fire", status_attack = "", ail = 5, support = "mire",
		negotiable = true, talk_difficulty = 1, personality = "cowardly", wants = "any",
		unique = ["hp_leech"],
		sprite_id = "Hellbat"},
	{name = "Lava Slime",       lv =  2,
		str =  3, def =  3, mag =  3, agl =  1,
		exp =  22, gold =   7, tier = 1, rank = 0, min_floor = 1, max_floor =  2,
		weakness = "ice", light = "resist",
		attack_element = "fire", status_attack = "poison", ail = 5,
		negotiable = true, talk_difficulty = 1, personality = "cowardly", wants = "any",
		sprite_id = "Lava_Slime"},
	{name = "Blood Spawn",      lv =  2,
		str =  4, def =  3, mag =  3, agl =  4,
		exp =  25, gold =   8, tier = 1, rank = 0, min_floor = 1, max_floor =  2,
		weakness = "fire",
		attack_element = "thunder", status_attack = "poison", ail = 5,
		negotiable = true, talk_difficulty = 1, personality = "cowardly", wants = "potion",
		unique = ["mp_leech"],
		sprite_id = "Blood_Monster_A"},
	# ── Tier 1 · Floors 1-3 ──────────────────────────────────────────────────
	{name = "Orc",              lv =  2,
		str =  4, def =  2, mag =  3, agl =  4,
		exp =  25, gold =   8, tier = 1, rank = 0, min_floor = 1, max_floor =  3,
		weakness = "ice", phys = "weak",
		attack_element = "fire", status_attack = "", ail = 5,
		negotiable = true, talk_difficulty = 2, personality = "greedy", wants = "throwable",
		sprite_id = "Orc"},
	{name = "Skeleton Archer",  lv =  2,
		str =  2, def =  3, mag =  3, agl =  3,
		exp =  22, gold =   7, tier = 1, rank = 0, min_floor = 1, max_floor =  3,
		weakness = "fire", light = "weak", dark = "null",
		attack_element = "ice", status_attack = "immobilize", ail = 5,
		negotiable = true, talk_difficulty = 2, personality = "proud", wants = "any",
		sprite_id = "Skeleton_Archer"},
	{name = "Demon",            lv =  3,
		str =  5, def =  3, mag =  4, agl =  5,
		exp =  32, gold =  10, tier = 1, rank = 1, min_floor = 1, max_floor =  3,
		weakness = "ice",
		attack_element = "fire", reach = "few", status_attack = "", ail = 5, support = "whet",
		negotiable = true, talk_difficulty = 2, personality = "greedy", wants = "throwable",
		sprite_id = "Demon_A"},
	{name = "Imp",              lv =  3,
		str =  3, def =  3, mag =  4, agl =  5,
		exp =  28, gold =   9, tier = 1, rank = 1, min_floor = 1, max_floor =  3,
		weakness = "thunder",
		attack_element = "thunder", reach = "few", status_attack = "immobilize", ail = 5, support = "ward",
		negotiable = true, talk_difficulty = 2, personality = "greedy", wants = "any",
		sprite_id = "Demon_B"},
	# ── Tier 2 · Floors 2-4 ──────────────────────────────────────────────────
	{name = "Armored Skeleton", lv =  5,
		str =  5, def =  4, mag =  4, agl =  2,
		exp =  30, gold =  10, tier = 2, rank = 0, min_floor = 2, max_floor =  4,
		weakness = "fire", nulls = ["ice"], phys = "resist", light = "weak", dark = "null",
		attack_element = "ice", status_attack = "immobilize", ail = 12, support = "ward",
		negotiable = true, talk_difficulty = 2, personality = "proud", wants = "throwable",
		sprite_id = "Armored_Skeleton"},
	{name = "Greatsword Skeleton", lv =  5,
		str =  6, def =  3, mag =  4, agl =  2,
		exp =  32, gold =  11, tier = 2, rank = 0, min_floor = 2, max_floor =  4,
		weakness = "fire", nulls = ["ice"], phys = "resist", light = "weak", dark = "null",
		attack_elements = ["ice", "dark"], reach = "few", status_attack = "immobilize", ail = 12,
		negotiable = true, talk_difficulty = 3, personality = "proud", wants = "throwable",
		sprite_id = "Greatsword_Skeleton"},
	{name = "Armored Orc",      lv =  5,
		str =  5, def =  4, mag =  4, agl =  4,
		exp =  32, gold =  12, tier = 2, rank = 0, min_floor = 2, max_floor =  4,
		weakness = "thunder", phys = "weak",
		attack_element = "fire", status_attack = "", ail = 12, support = "mire",
		negotiable = true, talk_difficulty = 2, personality = "greedy", wants = "any",
		sprite_id = "Armored_Orc"},
	{name = "Orc Rider",        lv =  5,
		str =  6, def =  3, mag =  0, agl =  5,
		exp =  30, gold =   9, tier = 2, rank = 0, min_floor = 2, max_floor =  4,
		weakness = "ice",
		attack_element = "fire", status_attack = "", ail = 12,
		negotiable = true, talk_difficulty = 2, personality = "greedy", wants = "potion",
		sprite_id = "Orc_rider"},
	{name = "Hellhound",        lv =  5,
		str =  5, def =  2, mag =  4, agl =  6,
		exp =  28, gold =   9, tier = 2, rank = 0, min_floor = 2, max_floor =  4,
		weakness = "ice", phys = "weak",
		attack_element = "fire", status_attack = "poison", ail = 12,
		negotiable = true, talk_difficulty = 2, personality = "proud", wants = "any",
		sprite_id = "Hellhound"},
	{name = "Blood Fiend",      lv =  6,
		str =  5, def =  3, mag =  5, agl =  5,
		exp =  35, gold =  11, tier = 2, rank = 0, min_floor = 2, max_floor =  4,
		weakness = "thunder", dark = "null",
		attack_elements = ["dark", "thunder"], reach = "few", status_attack = "poison", ail = 12,
		negotiable = true, talk_difficulty = 3, personality = "proud", wants = "any",
		unique = ["mp_leech"],
		sprite_id = "Blood_Monster_B"},
	{name = "Fell Demon",       lv =  6,
		str =  5, def =  3, mag =  5, agl =  5,
		exp =  35, gold =  11, tier = 2, rank = 0, min_floor = 2, max_floor =  4,
		weakness = "ice",
		attack_element = "thunder", reach = "few", status_attack = "poison", ail = 12, support = "quicken",
		negotiable = true, talk_difficulty = 3, personality = "proud", wants = "any",
		sprite_id = "Demon_C"},
	{name = "Horned Demon",     lv =  6,
		str =  6, def =  4, mag =  5, agl =  4,
		exp =  40, gold =  15, tier = 2, rank = 0, min_floor = 2, max_floor =  4,
		weakness = "thunder",
		attack_element = "fire", status_attack = "", ail = 12, support = "blunt",
		negotiable = true, talk_difficulty = 3, personality = "greedy", wants = "any",
		sprite_id = "Demon_D"},
	{name = "Ghostfire",        lv =  6,
		str =  3, def =  2, mag =  6, agl =  6,
		exp =  38, gold =  13, tier = 2, rank = 0, min_floor = 2, max_floor =  4,
		weakness = "ice", phys = "weak", dark = "resist",
		attack_elements = ["fire", "dark"], reach = "all", caster = true,
		status_attack = "silence", ail = 12, support = "damp",
		negotiable = true, talk_difficulty = 3, personality = "lonely", wants = "potion",
		sprite_id = "Ghostfire"},
	{name = "Eyeball",          lv =  6,
		str =  3, def =  3, mag =  6, agl =  3,
		exp =  35, gold =  10, tier = 2, rank = 0, min_floor = 2, max_floor =  4,
		weakness = "thunder", nulls = ["dark"], light = "resist",
		attack_element = "ice", reach = "few", status_attack = "immobilize", ail = 12, support = "sunder",
		negotiable = true, talk_difficulty = 3, personality = "lonely", wants = "potion",
		sprite_id = "Eyeball_Monster"},
	# ── Tier 3 · Floors 3+ ───────────────────────────────────────────────────
	{name = "Elite Orc",        lv =  8,
		str =  7, def =  5, mag =  5, agl =  3,
		exp =  45, gold =  14, tier = 3, rank = 0, min_floor = 3, max_floor = -1,
		weakness = "ice", phys = "resist",
		attack_element = "fire", status_attack = "", ail = 18, support = "whet",
		negotiable = true, talk_difficulty = 3, personality = "proud", wants = "throwable",
		sprite_id = "Elite_Orc"},
	{name = "Werewolf",         lv =  8,
		str =  7, def =  3, mag =  5, agl =  7,
		exp =  42, gold =  14, tier = 3, rank = 0, min_floor = 3, max_floor = -1,
		weakness = "fire", phys = "weak",
		attack_element = "thunder", status_attack = "poison", ail = 18, support = "quicken",
		negotiable = true, talk_difficulty = 3, personality = "proud", wants = "throwable",
		sprite_id = "Werewolf"},
	{name = "Werebear",         lv =  8,
		str =  6, def =  6, mag =  5, agl =  2,
		exp =  45, gold =  14, tier = 3, rank = 0, min_floor = 3, max_floor = -1,
		weakness = "thunder", phys = "resist",
		attack_element = "ice", status_attack = "immobilize", ail = 18, support = "ward",
		negotiable = true, talk_difficulty = 3, personality = "lonely", wants = "potion",
		sprite_id = "Werebear"},
	{name = "Arch Demon",       lv =  9, icons = 2,
		str =  7, def =  5, mag =  6, agl =  4,
		exp =  55, gold =  17, tier = 3, rank = 0, min_floor = 3, max_floor = -1,
		weakness = "ice", nulls = ["fire"], light = "weak", dark = "resist",
		attack_elements = ["fire", "dark"], reach = "few", status_attack = "silence", ail = 18, support = "stoke",
		negotiable = true, talk_difficulty = 4, personality = "proud", wants = "potion",
		sprite_id = "Demon_E"},
	{name = "Demoness",         lv =  9, icons = 2,
		str =  8, def =  4, mag =  6, agl =  5,
		exp =  50, gold =  16, tier = 3, rank = 0, min_floor = 3, max_floor = -1,
		weakness = "ice",
		attack_elements = ["fire", "thunder"], reach = "few", status_attack = "", ail = 18, support = "whet",
		negotiable = true, talk_difficulty = 4, personality = "proud", wants = "throwable",
		sprite_id = "Demoness_A"},
	{name = "Flame Golem",      lv =  9,
		str =  4, def =  6, mag =  7, agl =  1,
		exp =  50, gold =  17, tier = 3, rank = 0, min_floor = 3, max_floor = -1,
		weakness = "ice", absorb_element = "fire", phys = "resist",
		attack_element = "fire", reach = "all", caster = true,
		status_attack = "poison", ail = 18, support = "ward",
		negotiable = true, talk_difficulty = 3, personality = "lonely", wants = "potion",
		sprite_id = "Flame_Golem"},
	# ── Tier 4 · Floors 4+ ───────────────────────────────────────────────────
	{name = "Dark Demoness",    lv = 11, icons = 2,
		str =  8, def =  5, mag =  7, agl =  5,
		exp =  55, gold =  18, tier = 4, rank = 0, min_floor = 4, max_floor = -1,
		weakness = "thunder", nulls = ["fire"], dark = "resist",
		attack_elements = ["fire", "dark"], status_attack = "silence", ail = 22, support = "stoke",
		negotiable = true, talk_difficulty = 4, personality = "proud", wants = "any",
		sprite_id = "Demoness_B"},
	{name = "Warlock",          lv = 11,
		str =  3, def =  3, mag =  9, agl =  4,
		exp =  52, gold =  16, tier = 4, rank = 0, min_floor = 4, max_floor = -1,
		weakness = "ice", nulls = ["thunder"], phys = "weak", dark = "resist", reflect_element = "fire",
		attack_elements = ["fire", "ice", "thunder"], reach = "all", caster = true,
		status_attack = "silence", ail = 22, support = "purge",
		negotiable = true, talk_difficulty = 4, personality = "proud", wants = "potion",
		sprite_id = "Warlock"},
]

# ── Written for this game, still waiting on art ───────────────────────────────
#
# Everything below is original to this game: the fantasy roster above is
# placeholder and these are not. Each carries `needs_art=true` and an
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
	{name = "Black Knight",    icons = WARDEN_ICONS,
		str =  6, def =  7, mag =  6, agl =  2,
		weakness = "thunder", nulls = ["ice"], reflect_element = "fire", phys = "resist", light = "resist",
		attack_elements = ["thunder", "light"], reach = "few", status_attack = "immobilize", ail = 8,
		negotiable = false, talk_difficulty = 0,
		sprite_id = "Black_Knight_A"},

	{name = "Dark Knight",     icons = WARDEN_ICONS,
		str =  7, def =  6, mag =  6, agl =  3,
		weakness = "fire", nulls = ["ice"], phys = "resist", light = "weak", dark = "drain",
		attack_elements = ["ice", "dark"], reach = "all", status_attack = "silence", ail = 10, support = "mire",
		negotiable = false, talk_difficulty = 0,
		sprite_id = "Black_Knight_B"},

	{name = "Death Knight",    icons = WARDEN_ICONS,
		str =  4, def =  7, mag = 11, agl =  4,
		weakness = "ice", nulls = ["thunder"], reflect_element = "fire", light = "weak", dark = "drain",
		attack_elements = ["fire", "dark", "ice"], reach = "all", caster = true,
		status_attack = "silence", ail = 20, support = "purge",
		negotiable = false, talk_difficulty = 0,
		sprite_id = "Black_Knight_C"},

	{name = "Minotaur",        icons = WARDEN_ICONS,
		str = 10, def =  9, mag =  7, agl =  5,
		weakness = "thunder", nulls = ["fire"], absorb_element = "ice", phys = "resist",
		light = "weak", dark = "drain",
		attack_elements = ["ice", "dark"], reach = "few", status_attack = "immobilize", ail = 20,
		support = "ward",
		negotiable = false, talk_difficulty = 0,
		sprite_id = "Minotaur"},
]



# Boss templates — one per 5-floor milestone, cycling every 4 bosses.
# Four dragons, one at the bottom of each band. A boss is no longer a different
# kind of thing every five floors — it is the same kind of thing four times, and
# what changes is which element it is made of. That is what makes the wall colour
# worth reading: a band is a dragon's colour long before you meet the dragon.
#
# The elements chain. Each dragon is weak to the element the one before it was
# made of, so the reward for the last boss is the key to the next one — you walk
# out of the ice corridor holding ice, and ice is what the Thunder Dragon cannot
# stand. The Void Dragon closes the ring back onto ice because there is no fifth
# element to hand out, and by floor 20 finding the ice again is the point.
#
# All four null light and dark: a dragon is not a thing the banishing lines can
# talk out of the room, and a run that ended on a lucky Hama would end a lot of
# runs. Four icons each — see BOSS_ICONS.
const BOSS_TEMPLATES: Array[Dictionary] = [
	{name = "Ice Dragon",       lv = 12, icons = BOSS_ICONS,
		str = 12, def =  9, mag = 10, agl =  4,
		exp = 200, gold =  80, tier = 4, rank = 0, min_floor = 5, max_floor = -1,
		weakness = "fire", nulls = ["thunder"], absorb_element = "ice", light = "null", dark = "null",
		attack_elements = ["ice"], reach = "few", status_attack = "immobilize", ail = 25,
		support = "ward",
		negotiable = false, talk_difficulty = 0,
		sprite_id = "Ice_Dragon",
		design_note = "The first dragon and the only one the player is armed for on arrival: the run "
				+ "opens holding Ember and this thing drinks its own element and burns on the other. "
				+ "One element and a narrow reach, so the fight teaches what a dragon is before the "
				+ "next one starts asking questions about it."},

	{name = "Thunder Dragon",   lv = 14, icons = BOSS_ICONS,
		str = 13, def =  9, mag = 13, agl = 10,
		exp = 280, gold = 110, tier = 4, rank = 0, min_floor = 10, max_floor = -1,
		weakness = "ice", nulls = ["fire"], absorb_element = "thunder", light = "null", dark = "null",
		attack_elements = ["thunder"], reach = "all", status_attack = "paralyzed", ail = 25,
		support = "steady",
		negotiable = false, talk_difficulty = 0,
		sprite_id = "Thunder_Dragon",
		design_note = "Fast — the only boss that outruns a party — and it hits the whole room every "
				+ "turn it can pay for. Paralysis on a room-wide cast is the threat: it is trying to "
				+ "take your turns, not your HP. Ice is the answer and the ice corridor is where you "
				+ "got it."},

	{name = "Fire Dragon",      lv = 16, icons = BOSS_ICONS,
		str = 16, def = 11, mag = 13, agl =  6,
		exp = 360, gold = 140, tier = 4, rank = 0, min_floor = 15, max_floor = -1,
		weakness = "thunder", nulls = ["ice"], absorb_element = "fire", phys = "resist",
		light = "null", dark = "null",
		attack_elements = ["fire"], reach = "all", status_attack = "poison", ail = 25,
		support = "ward",
		negotiable = false, talk_difficulty = 0,
		sprite_id = "Fire_Dragon",
		design_note = "The hardest hitter and the one that punishes the opening loadout: Ember has "
				+ "carried the player fifteen floors and here it feeds the thing. Scales turn a blade "
				+ "as well, so the party that has leaned on swinging has to have found a second line "
				+ "by now."},

	{name = "Void Dragon",      lv = 18, icons = BOSS_ICONS,
		str = 15, def = 12, mag = 15, agl =  7,
		exp = 450, gold = 180, tier = 4, rank = 0, min_floor = 20, max_floor = -1,
		weakness = "ice", nulls = ["fire", "thunder"], phys = "resist",
		light = "null", dark = "drain",
		attack_elements = ["dark", "fire", "thunder"], reach = "all",
		status_attack = "silence", ail = 25, support = "purge",
		negotiable = false, talk_difficulty = 0,
		sprite_id = "Void_Dragon",
		design_note = "The last fight. It answers to exactly one element out of six and shrugs at a "
				+ "blade, casts three lines room-wide, drinks the dark and purges anything put on it. "
				+ "Silence is the real danger — it can close the one door it is vulnerable through, "
				+ "which is why the corridor has an orb at the mouth and the player should arrive "
				+ "with more than one way to say ice."},
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
	# Elements a thing simply does not feel. Written as a list because fire, ice
	# and thunder have no key of their own the way phys, light and dark do —
	# and applied before those three so an explicit one still wins.
	for n: Variant in t.get("nulls", []):
		a[n as String] = Affinity.NULL
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
	return _build(_pick_from_tier(tier_for_floor(floor_num)), floor_num)


# One template from exactly this tier, widening downward if a tier is empty
# rather than falling back to the whole table.
static func _pick_from_tier(tier: int) -> Dictionary:
	var want: int = tier
	var pool: Array[Dictionary] = []
	while pool.is_empty() and want >= 1:
		for tmpl: Dictionary in TEMPLATES:
			if int(tmpl.get("tier", 1)) == want:
				pool.append(tmpl)
		want -= 1
	if pool.is_empty():
		pool = TEMPLATES
	return pool[randi() % pool.size()]


# Rolls an encounter. Every size from one up to the cap is equally likely, and
# the cap is the floor number until floor four — so the first fight of a run is
# always one on one, and floor four onward is an even quarter each.
#
# The first monster is always from this floor's tier, so the band's own roster
# is in every fight. Past tier one, each other slot is a coin: this tier again,
# or a random lower one. Every monster is built at this floor's level whichever
# band it comes from, so an old face met deep is a deep monster — its lower base
# stats make it the lighter hitter in the pack, not a pushover.
static func make_group(floor_num: int) -> Array[Enemy]:
	var count: int = 1 + randi() % clampi(floor_num, 1, 4)
	var tier: int = tier_for_floor(floor_num)
	var group: Array[Enemy] = [make_random(floor_num)]
	for _i: int in range(count - 1):
		var from: int = tier
		if tier > 1 and randi() % 2 == 0:
			from = 1 + randi() % (tier - 1)
		group.append(_build(_pick_from_tier(from), floor_num))
	return group


# One boss per run of FLOOR_COUNT floors. The old index went negative on a
# short run and quietly handed back the LAST boss — the hardest one.
static func make_boss(floor_num: int) -> Enemy:
	var idx: int = clampi(floor_num / maxi(1, Level.BOSS_EVERY) - 1,
			0, BOSS_TEMPLATES.size() - 1)
	var t: Dictionary = BOSS_TEMPLATES[idx]
	var e: Enemy = Enemy.new()
	e.spawn_floor     = maxi(1, floor_num)
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
	e.sprite_id       = t.get("sprite_id", "")
	e.attack_elements = _elements_from(t)
	e.attack_element  = e.attack_elements[0] if not e.attack_elements.is_empty() else ""
	e.caster          = bool(t.get("caster", false))
	e.attack_reach    = t.get("reach", Spell.SHAPE_ONE)
	e.tier            = int(t.get("tier", 1))
	e.reflect_element = t.get("reflect_element", "")
	e.absorb_element  = t.get("absorb_element", "")
	e.affinities      = _affinities_from(t)
	e.icons           = int(t.get("icons", BOSS_ICONS))
	e.unreadable      = true
	e.support_skill   = t.get("support", "")
	e.unique_skills.assign(t.get("unique", []) as Array)
	e.ailment_chance  = int(t.get("ail", 25))
	# A boss keeps its own colours; it is not one of a set.
	e.tint            = Color.WHITE
	e.compute_max_hp()
	e.max_hp *= BOSS_HP_MULT
	e.hp = e.max_hp
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
	# One warden per band, standing in the middle of it, so the four of them map
	# one to one onto the four tiers. No rotation and no modulus to get wrong:
	# the floor says which band it is in and the band says which warden.
	var idx: int = clampi(tier_for_floor(floor_num) - 1,
			0, WARDEN_TEMPLATES.size() - 1)
	var e: Enemy = _build(WARDEN_TEMPLATES[idx], floor_num)
	# Its own colours, like a boss. The depth tint exists so the same sprite read
	# twice in one tier is visibly deeper the second time; a warden is met once in
	# the whole run, so the tint has nothing to say and only fights the art.
	e.tint = Color.WHITE
	# A warden is the floor's locked door: a step above its neighbours, a step
	# below the boss waiting one floor down.
	e.lv = maxi(2, roundi(float(floor_num) * 1.75))
	e.exp_reward = exp_for_level(e.lv) * 2
	e.gold_reward = e.lv * 6
	e.unreadable = true
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


# Where a template is actually met, worked out from the same rules that place
# it rather than from its min_floor/max_floor, which nothing spawns from any
# more: the pack draws by tier, and wardens and bosses stand on fixed floors.
# Reading the old fields put the floor-four warden down
# as "Floors 1+".
static func where_found(tmpl: Dictionary) -> String:
	var tname: String = tmpl.get("name", "") as String
	for i: int in WARDEN_TEMPLATES.size():
		if WARDEN_TEMPLATES[i]["name"] == tname:
			return "Floor %d" % (i * Level.BOSS_EVERY + Level.WARDEN_OFFSET)
	for i: int in BOSS_TEMPLATES.size():
		if BOSS_TEMPLATES[i]["name"] == tname:
			return "Floor %d" % ((i + 1) * Level.BOSS_EVERY)
	# A tier's band is five floors, the last of which is the boss corridor and
	# carries no pack.
	var tier: int = int(tmpl.get("tier", 1))
	var first: int = (tier - 1) * Level.BOSS_EVERY + 1
	return "Floors %d-%d" % [first, first + Level.BOSS_EVERY - 2]


static func all_templates() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	result.append_array(TEMPLATES)
	result.append_array(WARDEN_TEMPLATES)
	result.append_array(BOSS_TEMPLATES)
	return result



# Whether a name is a monster the game still has. A save can remember one that
# has since been taken out (the Mimic), and the bestiary must not show a random
# stand-in for it.
static func is_known(enemy_name: String) -> bool:
	for tmpl: Dictionary in all_templates():
		if tmpl["name"] == enemy_name:
			return true
	return false


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


# What a demon met on the opening floors keeps of its HP. The first floor is the
# only place the player has no levels, no gear and one spell, and a tier-one
# demon there outlasted them: 32-45 HP against a starting 22.
#
# Ramped over three floors rather than dropped on floor one alone, which would
# have put a wall at floor two instead of a brutal opening at floor one.
const OPENING_HP: Array[float] = [0.60, 0.78, 0.92]


static func opening_hp_scale(floor_num: int) -> float:
	if floor_num < 1 or floor_num > OPENING_HP.size():
		return 1.0
	return OPENING_HP[floor_num - 1]


# Which band of demons a floor draws from. Five floors to a tier, four tiers,
# and a boss closing each one.
static func tier_for_floor(floor_num: int) -> int:
	return clampi((floor_num - 1) / Level.BOSS_EVERY + 1, 1, 4)


static func _build(t: Dictionary, floor_num: int) -> Enemy:
	var e: Enemy = Enemy.new()
	e.spawn_floor     = maxi(1, floor_num)
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
	e.sprite_id        = t.get("sprite_id", "")
	e.attack_elements = _elements_from(t)
	e.attack_element  = e.attack_elements[0] if not e.attack_elements.is_empty() else ""
	e.caster          = bool(t.get("caster", false))
	e.attack_reach    = t.get("reach", Spell.SHAPE_ONE)
	e.tier            = int(t.get("tier", 1))
	e.reflect_element = t.get("reflect_element", "")
	e.absorb_element  = t.get("absorb_element", "")
	e.affinities      = _affinities_from(t)
	e.icons           = int(t.get("icons", 1))
	e.support_skill   = t.get("support", "")
	e.unique_skills.assign(t.get("unique", []) as Array)
	e.ailment_chance  = int(t.get("ail", 12))
	e.tint            = tint_for_floor(floor_num)
	e.compute_max_hp()
	e.max_hp = maxi(1, roundi(float(e.max_hp) * opening_hp_scale(floor_num)))
	e.hp = e.max_hp
	e.compute_max_mp()
	return e


# What one cast of its element costs. Scales with the demon's own magic, so a
# strong caster gets a bigger pool and a bigger bill rather than infinite uses.
static func _elements_from(t: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for e: Variant in t.get("attack_elements", []):
		var key: String = e as String
		if key != "" and key not in out:
			out.append(key)
	var one: String = t.get("attack_element", "") as String
	if one != "" and one not in out:
		out.insert(0, one)
	return out


# How many casts a demon's pool is worth, by how wide it throws. Priced off the
# magazine rather than off MAG: a cost derived from the stat drifted with level
# and handed a room-wide caster a single shot per fight, which is not a boss,
# it is a cutscene. Six narrow casts, four at two or three, three that take the
# whole row — the same for a floor-two warden and a floor-twenty drake.
const MAGAZINE: Dictionary = {
	Spell.SHAPE_ONE: 6,
	Spell.SHAPE_FEW: 4,
	Spell.SHAPE_ALL: 3,
}


func skill_cost() -> int:
	if attack_elements.is_empty():
		return 0
	return maxi(4, roundi(float(max_mp) / float(MAGAZINE.get(attack_reach, 6))))


# What each target keeps of a cast that was split across several of them.
func reach_spread(banishing: bool) -> float:
	match attack_reach:
		Spell.SHAPE_FEW:
			return Spell.SPREAD_FEW_BANISH if banishing else Spell.SPREAD_FEW_DMG
		Spell.SHAPE_ALL:
			return Spell.SPREAD_ALL_BANISH if banishing else Spell.SPREAD_ALL_DMG
	return 1.0


func can_afford_skill() -> bool:
	return not attack_elements.is_empty() and mp >= skill_cost()


# What it could throw this turn. A banishing line only joins the pool on the
# turn the caller says it may: a demon it takes from you is gone for good, so
# those stay a thing that happens occasionally rather than the opening move.
func affordable_elements(with_banishing: bool) -> Array[String]:
	if not can_afford_skill():
		return []
	var out: Array[String] = []
	for e: String in attack_elements:
		if with_banishing or not Affinity.is_banishing(e):
			out.append(e)
	return out


# What a dry caster reaches for. Never a banishing line — expelling one of the
# hero's demons should never be the thing something does for free.
func dregs_element() -> String:
	for e: String in attack_elements:
		if not Affinity.is_banishing(e):
			return e
	return ""


# Returns a random item drop, or an empty dict if nothing drops (65% no-drop).
func roll_drop() -> Dictionary:
	# Rolled ahead of the table and on its own odds — see Item.roll_stone.
	var stone: Dictionary = Item.roll_stone(Item.STONE_FROM_KILL)
	if not stone.is_empty():
		return stone
	if randi() % 100 < 65:
		return {}
	return Item.pick_drop(spawn_floor)
