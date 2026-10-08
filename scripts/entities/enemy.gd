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
# How much of its fight portrait the figure fills. The dragons' art fills its
# frame at every age, so a hatchling would stand as tall as a boss; the young
# ones carry a `size` in their template to be drawn their age.
var figure_scale:     float  = 1.0
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
const WARDEN_ICONS: int = 3
# Between an ordinary demon (1x) and a dragon (BOSS_HP_MULT): about one and a
# half full packs of its floor, a third of the dragon waiting below it.
const WARDEN_HP_MULT: int = 4

# Each warden has one thing of its own, run by CombatScene:
#   counter  Black Knight   strikes back at a blade, one time in two
#   drain    Dark Knight    its spells heal it for half the damage they deal
#   raise    Death Knight   raises a skeleton whenever none of its own stands
#   enrage   Minotaur       below half HP it goes berserk, once: +1 icon, +2 ATK
const WARDEN_TRICKS: Dictionary = {
	"Black Knight": "counter",
	"Dark Knight":  "drain",
	"Death Knight": "raise",
	"Minotaur":     "enrage",
}

# A boss's HP as a multiple of what the ordinary formula (lv*10 + def*3) gives
# it, so a dragon is a long fight rather than a few good rounds.
const BOSS_HP_MULT: int = 8

# How many times over a dragon's well holds its MAGAZINE of casts. One was
# three room-wide casts and then claws for the rest of a long fight (the
# Thunder Dragon's rounding left it two); a dragon should breathe its element
# for most of the fight.
const BOSS_CASTS_MULT: int = 2

# Casts' worth of MP a dragon draws back at the top of each of its phases
# (CombatScene._enemy_phase). Four icons spend a full well in about a phase
# and a half, after which a dry dragon used to swing claws for the rest of the
# fight, and a demon that turned blades back ended every one of its phases for
# it. With this it settles to about two breaths and two swings a phase.
const DRAGON_BREATH_PER_PHASE: int = 2

# Casts per MAGAZINE this one carries (BOSS_CASTS_MULT for a dragon): its MP
# holds that many times the magazine at the same price a cast.
var cast_mult: int = 1

# Press-turn icons this enemy opens its phase with. Bosses get more, which is
# how they threaten a full party without inflating their damage numbers.
var icons: int = 1

# The final boss's current form: the element it casts this phase, and the
# matching dragon's affinity chart it wears until its next phase. "" for
# everything else.
var form: String = ""
# Raised by the Necromancer mid-fight. Worth nothing when it falls, and it
# crumbles when its master does.
var summoned: bool = false
# The Minotaur's rage, once it has gone off.
var enraged: bool = false

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

# In the Abyss every monster comes up in one element (Abyss.apply_variant):
# its colours, what it casts, and its chart all follow from it. Empty for the
# main game's monsters, and for one recruited, which joins as its own kind.
var abyss_element: String = ""


# Cool and pale at the top of a tier, hot and bright at the bottom of it.
static func tint_for_floor(floor_num: int) -> Color:
	var step: float = float((floor_num - 1) % Level.BOSS_EVERY) / float(Level.BOSS_EVERY - 1)
	return Color(0.82, 0.88, 1.0).lerp(Color(1.0, 0.72, 0.62), step)


# Name as it should appear in the battle log and on the enemy row.
func display_name() -> String:
	var n: String = enemy_name
	if abyss_element != "":
		n = "%s %s" % [Abyss.EPITHET.get(abyss_element, ""), enemy_name]
	if battle_tag == "":
		return n
	return "%s %s" % [n, battle_tag]


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
#   7  its sprite, and `size` if the figure is drawn smaller than its box
#      (the young dragons, by age; see figure_scale)
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
		attack_element = "ice", status_attack = "blind", ail = 5,
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
		attack_element = "thunder", reach = "few", status_attack = "blind", ail = 5, support = "ward",
		negotiable = true, talk_difficulty = 2, personality = "greedy", wants = "any",
		sprite_id = "Demon_B"},
	# Hatchlings: the first dragons a run meets, each already breathing the
	# element its scales are named for, none of them hard to a blade yet.
	{name = "Baby Brass Dragon", lv =  3,
		str =  4, def =  3, mag =  4, agl =  4,
		exp =  30, gold =  10, tier = 1, rank = 0, min_floor = 1, max_floor =  3,
		weakness = "ice",
		attack_element = "fire", status_attack = "", ail = 5, support = "whet",
		negotiable = true, talk_difficulty = 2, personality = "proud", wants = "any",
		size = 0.6, sprite_id = "Baby_Brass_Dragon"},
	{name = "Baby Copper Dragon", lv =  3,
		str =  3, def =  3, mag =  4, agl =  6,
		exp =  28, gold =  12, tier = 1, rank = 0, min_floor = 1, max_floor =  3,
		weakness = "fire",
		attack_element = "thunder", status_attack = "", ail = 5, support = "quicken",
		negotiable = true, talk_difficulty = 2, personality = "greedy", wants = "throwable",
		size = 0.6, sprite_id = "Baby_Copper_Dragon"},
	{name = "Baby Green Dragon", lv =  3,
		str =  3, def =  3, mag =  4, agl =  4,
		exp =  28, gold =   9, tier = 1, rank = 0, min_floor = 1, max_floor =  3,
		weakness = "fire", light = "weak", dark = "resist",
		attack_element = "dark", status_attack = "poison", ail = 5, support = "mire",
		negotiable = true, talk_difficulty = 2, personality = "lonely", wants = "potion",
		size = 0.6, sprite_id = "Baby_Green_Dragon"},
	{name = "Baby White Dragon", lv =  3,
		str =  3, def =  3, mag =  4, agl =  5,
		exp =  28, gold =   9, tier = 1, rank = 0, min_floor = 1, max_floor =  3,
		weakness = "fire",
		attack_element = "ice", status_attack = "blind", ail = 5, support = "damp",
		negotiable = true, talk_difficulty = 2, personality = "cowardly", wants = "any",
		size = 0.6, sprite_id = "Baby_White_Dragon"},
	{name = "Baby Iron Dragon", lv =  3,
		str =  5, def =  4, mag =  0, agl =  2,
		exp =  30, gold =  10, tier = 1, rank = 0, min_floor = 1, max_floor =  3,
		weakness = "thunder",
		status_attack = "", ail = 5, support = "ward",
		negotiable = true, talk_difficulty = 2, personality = "proud", wants = "throwable",
		size = 0.6, sprite_id = "Baby_Iron_Dragon"},
	# ── Tier 2 · Floors 2-4 ──────────────────────────────────────────────────
	{name = "Armored Skeleton", lv =  5,
		str =  5, def =  4, mag =  4, agl =  2,
		exp =  30, gold =  10, tier = 2, rank = 0, min_floor = 2, max_floor =  4,
		weakness = "fire", nulls = ["ice"], phys = "resist", light = "weak", dark = "null",
		attack_element = "ice", status_attack = "blind", ail = 12, support = "ward",
		negotiable = true, talk_difficulty = 2, personality = "proud", wants = "throwable",
		sprite_id = "Armored_Skeleton"},
	{name = "Greatsword Skeleton", lv =  5,
		str =  6, def =  3, mag =  4, agl =  2,
		exp =  32, gold =  11, tier = 2, rank = 0, min_floor = 2, max_floor =  4,
		weakness = "fire", nulls = ["ice"], phys = "resist", light = "weak", dark = "null",
		attack_elements = ["ice", "dark"], reach = "few", status_attack = "blind", ail = 12,
		negotiable = true, talk_difficulty = 3, personality = "proud", wants = "throwable",
		sprite_id = "Greatsword_Skeleton"},
	{name = "Armored Orc",      lv =  5,
		str =  5, def =  4, mag =  4, agl =  4,
		exp =  32, gold =  12, tier = 2, rank = 0, min_floor = 2, max_floor =  4,
		weakness = "thunder", phys = "resist",
		attack_element = "fire", status_attack = "", ail = 12, support = "mire",
		negotiable = true, talk_difficulty = 2, personality = "greedy", wants = "any",
		sprite_id = "Armored_Orc"},
	{name = "Orc Rider",        lv =  5,
		str =  6, def =  3, mag =  0, agl =  5,
		exp =  30, gold =   9, tier = 2, rank = 0, min_floor = 2, max_floor =  4,
		weakness = "ice", phys = "resist",
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
		attack_elements = ["ice", "light"], reach = "few", status_attack = "blind", ail = 12, support = "sunder",
		negotiable = true, talk_difficulty = 3, personality = "lonely", wants = "potion",
		sprite_id = "Eyeball_Monster"},
	# Young dragons: their own element no longer touches them.
	{name = "Young Red Dragon", lv =  6,
		str =  6, def =  4, mag =  5, agl =  4,
		exp =  40, gold =  14, tier = 2, rank = 0, min_floor = 2, max_floor =  4,
		weakness = "ice", nulls = ["fire"],
		attack_element = "fire", reach = "few", status_attack = "", ail = 12, support = "stoke",
		negotiable = true, talk_difficulty = 3, personality = "proud", wants = "any",
		size = 0.75, sprite_id = "Young_Red_Dragon"},
	{name = "Young Brass Dragon", lv =  6,
		str =  5, def =  4, mag =  6, agl =  4,
		exp =  38, gold =  15, tier = 2, rank = 0, min_floor = 2, max_floor =  4,
		weakness = "ice", light = "resist",
		attack_elements = ["fire", "light"], reach = "few", status_attack = "blind", ail = 12, support = "whet",
		negotiable = true, talk_difficulty = 3, personality = "greedy", wants = "throwable",
		size = 0.75, sprite_id = "Young_Brass_Dragon"},
	{name = "Young Copper Dragon", lv =  6,
		str =  5, def =  3, mag =  5, agl =  7,
		exp =  38, gold =  16, tier = 2, rank = 0, min_floor = 2, max_floor =  4,
		weakness = "fire", nulls = ["thunder"],
		attack_element = "thunder", reach = "few", status_attack = "", ail = 12, support = "quicken",
		negotiable = true, talk_difficulty = 3, personality = "greedy", wants = "any",
		size = 0.75, sprite_id = "Young_Copper_Dragon"},
	{name = "Young Silver Dragon", lv =  6,
		str =  5, def =  5, mag =  5, agl =  3,
		exp =  40, gold =  14, tier = 2, rank = 0, min_floor = 2, max_floor =  4,
		weakness = "fire", nulls = ["ice"], light = "resist",
		attack_element = "ice", reach = "few", status_attack = "", ail = 12, support = "ward",
		negotiable = true, talk_difficulty = 3, personality = "proud", wants = "potion",
		size = 0.75, sprite_id = "Young_Silver_Dragon"},
	# ── Tier 3 · Floors 3+ ───────────────────────────────────────────────────
	{name = "Elite Orc",        lv =  8,
		str =  7, def =  5, mag =  5, agl =  3,
		exp =  45, gold =  14, tier = 3, rank = 0, min_floor = 3, max_floor = -1,
		weakness = "ice", phys = "repel",
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
		attack_element = "ice", status_attack = "blind", ail = 18, support = "ward",
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
		weakness = "ice", light = "resist",
		attack_elements = ["fire", "thunder", "light"], reach = "few", status_attack = "", ail = 18, support = "whet",
		negotiable = true, talk_difficulty = 4, personality = "proud", wants = "throwable",
		unique = ["hp_leech", "mp_leech"],
		sprite_id = "Demoness_A"},
	{name = "Flame Golem",      lv =  9,
		str =  4, def =  6, mag =  7, agl =  1,
		exp =  50, gold =  17, tier = 3, rank = 0, min_floor = 3, max_floor = -1,
		weakness = "ice", absorb_element = "fire", phys = "resist",
		attack_element = "fire", reach = "all", caster = true,
		status_attack = "poison", ail = 18, support = "ward",
		negotiable = true, talk_difficulty = 3, personality = "lonely", wants = "potion",
		sprite_id = "Flame_Golem"},
	# Juveniles: hard to a blade or strange to magic, and one of them carries
	# all three of the open elements at once.
	{name = "Juvenile Bronze Dragon", lv =  9,
		str =  7, def =  5, mag =  6, agl =  4,
		exp =  52, gold =  16, tier = 3, rank = 0, min_floor = 3, max_floor = -1,
		weakness = "ice", absorb_element = "thunder", phys = "resist",
		attack_element = "thunder", reach = "few", status_attack = "paralyzed", ail = 18, support = "whet",
		negotiable = true, talk_difficulty = 3, personality = "proud", wants = "throwable",
		size = 0.9, sprite_id = "Juvenile_Bronze_Dragon"},
	{name = "Juvenile Black Dragon", lv =  9,
		str =  7, def =  4, mag =  6, agl =  5,
		exp =  50, gold =  15, tier = 3, rank = 0, min_floor = 3, max_floor = -1,
		weakness = "thunder", light = "weak", dark = "null",
		attack_element = "dark", reach = "few", status_attack = "poison", ail = 18, support = "sunder",
		negotiable = true, talk_difficulty = 3, personality = "proud", wants = "any",
		unique = ["hp_leech"],
		size = 0.9, sprite_id = "Juvenile_Black_Dragon"},
	{name = "Juvenile Mercury Dragon", lv =  9,
		str =  4, def =  4, mag =  7, agl =  8,
		exp =  50, gold =  17, tier = 3, rank = 0, min_floor = 3, max_floor = -1,
		weakness = "thunder", reflect_element = "ice", light = "resist",
		attack_elements = ["ice", "light"], reach = "all", caster = true,
		status_attack = "silence", ail = 18, support = "quicken",
		negotiable = true, talk_difficulty = 4, personality = "lonely", wants = "potion",
		size = 0.9, sprite_id = "Juvenile_Mercury_Dragon"},
	{name = "Juvenile Multihued Dragon", lv =  9, icons = 2,
		str =  6, def =  4, mag =  7, agl =  5,
		exp =  58, gold =  18, tier = 3, rank = 0, min_floor = 3, max_floor = -1,
		weakness = "dark", nulls = ["fire", "ice", "thunder"], phys = "weak",
		attack_elements = ["fire", "ice", "thunder"], reach = "few", status_attack = "", ail = 18, support = "stoke",
		negotiable = true, talk_difficulty = 4, personality = "proud", wants = "potion",
		size = 0.9, sprite_id = "Juvenile_Multihued_Dragon"},
	# ── Tier 4 · Floors 4+ ───────────────────────────────────────────────────
	{name = "Dark Demoness",    lv = 11, icons = 2,
		str =  8, def =  5, mag =  7, agl =  5,
		exp =  55, gold =  18, tier = 4, rank = 0, min_floor = 4, max_floor = -1,
		weakness = "thunder", nulls = ["fire"], dark = "resist",
		attack_elements = ["fire", "dark"], status_attack = "silence", ail = 22, support = "stoke",
		negotiable = true, talk_difficulty = 4, personality = "proud", wants = "any",
		unique = ["hp_leech", "mp_leech"],
		sprite_id = "Demoness_B"},
	{name = "Warlock",          lv = 11,
		str =  3, def =  3, mag =  9, agl =  4,
		exp =  52, gold =  16, tier = 4, rank = 0, min_floor = 4, max_floor = -1,
		weakness = "ice", nulls = ["thunder"], phys = "weak", dark = "resist", light = "resist",
		reflect_element = "fire",
		attack_elements = ["fire", "ice", "thunder", "light"], reach = "all", caster = true,
		status_attack = "silence", ail = 22, support = "purge",
		negotiable = true, talk_difficulty = 4, personality = "proud", wants = "potion",
		sprite_id = "Warlock"},
	# Mature dragons: two actions a turn and they drink their own element.
	{name = "Mature Bronze Dragon", lv = 11, icons = 2,
		str =  8, def =  6, mag =  7, agl =  4,
		exp =  58, gold =  19, tier = 4, rank = 0, min_floor = 4, max_floor = -1,
		weakness = "ice", absorb_element = "thunder", phys = "resist",
		attack_element = "thunder", reach = "all", status_attack = "paralyzed", ail = 22, support = "whet",
		negotiable = true, talk_difficulty = 4, personality = "proud", wants = "throwable",
		sprite_id = "Mature_Bronze_Dragon"},
	{name = "Mature Black Dragon", lv = 11, icons = 2,
		str =  8, def =  5, mag =  7, agl =  5,
		exp =  56, gold =  18, tier = 4, rank = 0, min_floor = 4, max_floor = -1,
		weakness = "thunder", light = "weak", dark = "drain",
		attack_element = "dark", reach = "few", status_attack = "poison", ail = 22, support = "sunder",
		negotiable = true, talk_difficulty = 4, personality = "proud", wants = "any",
		unique = ["hp_leech"],
		sprite_id = "Mature_Black_Dragon"},
	{name = "Mature Blue Dragon", lv = 11, icons = 2,
		str =  6, def =  5, mag =  8, agl =  5,
		exp =  56, gold =  18, tier = 4, rank = 0, min_floor = 4, max_floor = -1,
		weakness = "fire", absorb_element = "ice", light = "resist",
		attack_element = "ice", reach = "all", caster = true,
		status_attack = "silence", ail = 22, support = "ward",
		negotiable = true, talk_difficulty = 4, personality = "lonely", wants = "potion",
		sprite_id = "Mature_Blue_Dragon"},
	{name = "Mature Iron Dragon", lv = 11, icons = 2,
		str =  9, def =  8, mag =  5, agl =  2,
		exp =  58, gold =  20, tier = 4, rank = 0, min_floor = 4, max_floor = -1,
		weakness = "thunder", phys = "repel", nulls = ["fire"],
		attack_element = "fire", status_attack = "blind", ail = 22, support = "blunt",
		negotiable = true, talk_difficulty = 4, personality = "proud", wants = "throwable",
		sprite_id = "Mature_Iron_Dragon"},
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
		weakness = "thunder", light = "resist", dark = "resist", nulls = ["ice"], reflect_element = "fire", phys = "resist",
		attack_elements = ["thunder", "light"], reach = "few", status_attack = "blind", ail = 8,
		negotiable = false, talk_difficulty = 0,
		sprite_id = "Black_Knight_A"},

	{name = "Dark Knight",     icons = WARDEN_ICONS,
		str =  7, def =  6, mag =  6, agl =  3,
		weakness = "fire", light = "resist", dark = "resist", nulls = ["ice"], phys = "resist",
		attack_elements = ["ice", "dark"], reach = "all", status_attack = "silence", ail = 10, support = "mire",
		negotiable = false, talk_difficulty = 0,
		sprite_id = "Black_Knight_B"},

	{name = "Death Knight",    icons = WARDEN_ICONS,
		str =  4, def =  7, mag = 11, agl =  4,
		weakness = "ice", light = "resist", dark = "resist", nulls = ["thunder"], reflect_element = "fire",
		phys = "repel",
		attack_elements = ["fire", "dark", "ice"], reach = "all", caster = true,
		status_attack = "silence", ail = 20, support = "purge",
		negotiable = false, talk_difficulty = 0,
		sprite_id = "Black_Knight_C"},

	{name = "Minotaur",        icons = WARDEN_ICONS,
		str = 10, def =  9, mag =  7, agl =  5,
		weakness = "thunder", light = "resist", dark = "resist", nulls = ["fire"], absorb_element = "ice", phys = "resist",
		attack_elements = ["ice", "dark"], reach = "few", status_attack = "blind", ail = 20,
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
# stand. The Void Dragon keeps the chain: weak to the Fire Dragon's fire, and
# shrugging off the ice and thunder of the two before that.
#
# All four resist light and dark, as do the wardens and the Necromancer's
# forms. Against them banishing runs on the boss odds instead of the chart's
# (CombatMath.banish_chance): about nothing for an ordinary hero, up to 30% a
# cast for one who has put enough into Luck to out-luck the boss. So a luck
# build can end a boss fight early, and nobody else can. Four icons each — see
# BOSS_ICONS.
const BOSS_TEMPLATES: Array[Dictionary] = [
	{name = "Ice Dragon",       lv = 12, icons = BOSS_ICONS,
		str = 12, def =  9, mag = 10, agl =  4,
		exp = 200, gold =  80, tier = 4, rank = 0, min_floor = 5, max_floor = -1,
		weakness = "fire", nulls = ["thunder"], absorb_element = "ice", light = "resist", dark = "resist",
		attack_elements = ["ice"], reach = "few", status_attack = "blind", ail = 25,
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
		weakness = "ice", nulls = ["fire"], absorb_element = "thunder", light = "resist", dark = "resist",
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
		light = "resist", dark = "resist",
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
		weakness = "fire", nulls = ["ice", "thunder"], phys = "resist",
		light = "resist", dark = "resist",
		attack_elements = ["dark", "ice", "thunder"], reach = "all",
		status_attack = "silence", ail = 25, support = "purge",
		negotiable = false, talk_difficulty = 0,
		sprite_id = "Void_Dragon",
		design_note = "The last fight. It answers to exactly one element out of six and shrugs at a "
				+ "blade, casts three lines room-wide, resists the banishing lines and purges anything put on it. "
				+ "Silence is the real danger — it can close the one door it is vulnerable through, "
				+ "which is why the corridor has an orb at the mouth and the player should arrive "
				+ "with more than one way to say fire."},
]



# ── The Abyss's bosses ────────────────────────────────────────────────────────
#
# One waits at the bottom of every fifth Abyss floor, in a corridor like the
# dragons' (Abyss.boss_floor). The Abyss has one life and no saves, so they are
# built like the monsters around them, at the floor's own level, and are a
# boss only by being alone with ABYSS_BOSS_MULT times the HP and the rewards,
# and two actions a turn. The six adults come first, the ancients after, and
# the Multihued is the end of the Abyss (Abyss.boss_for_depth, END_DEPTH). Each keeps its own chart: they are not rolled into
# an element the way the Abyss's ordinary monsters are.
const ABYSS_BOSS_MULT: int = 3
const ABYSS_BOSS_TEMPLATES: Array[Dictionary] = [
	{name = "Adult Green Dragon", rank = 1,
		str =  8, def =  6, mag =  8, agl =  5,
		weakness = "fire", light = "weak", dark = "drain",
		attack_element = "dark", reach = "all", status_attack = "poison", ail = 22, support = "mire",
		sprite_id = "Adult_Green_Dragon"},
	{name = "Adult White Dragon", rank = 1,
		str =  8, def =  6, mag =  8, agl =  5,
		weakness = "fire", absorb_element = "ice",
		attack_element = "ice", reach = "all", status_attack = "blind", ail = 22, support = "damp",
		sprite_id = "Adult_White_Dragon"},
	{name = "Adult Copper Dragon", rank = 1,
		str =  7, def =  5, mag =  8, agl =  8,
		weakness = "fire", absorb_element = "thunder",
		attack_element = "thunder", reach = "all", status_attack = "paralyzed", ail = 22, support = "quicken",
		sprite_id = "Adult_Copper_Dragon"},
	{name = "Adult Gold Dragon", rank = 1,
		str =  9, def =  6, mag =  8, agl =  4,
		weakness = "dark", nulls = ["fire"], light = "drain",
		attack_elements = ["fire", "light"], reach = "few", status_attack = "", ail = 22, support = "whet",
		sprite_id = "Adult_Gold_Dragon"},
	{name = "Adult Bone Dragon", rank = 1,
		str =  9, def =  7, mag =  7, agl =  3,
		weakness = "light", dark = "drain", phys = "resist",
		attack_element = "dark", reach = "few", status_attack = "silence", ail = 22, support = "sunder",
		unique = ["hp_leech"],
		sprite_id = "Adult_Bone_Dragon"},
	{name = "Adult Mercury Dragon", rank = 1,
		str =  6, def =  6, mag =  9, agl =  7,
		weakness = "thunder", reflect_element = "ice", light = "resist",
		attack_elements = ["ice", "light"], reach = "all", caster = true,
		status_attack = "silence", ail = 22, support = "quicken",
		sprite_id = "Adult_Mercury_Dragon"},
	{name = "Ancient Gold Dragon", rank = 2, ancient = true,
		str = 10, def =  7, mag =  9, agl =  5,
		weakness = "dark", absorb_element = "fire", light = "drain",
		attack_elements = ["fire", "light"], reach = "all", status_attack = "", ail = 25, support = "stoke",
		sprite_id = "Ancient_Gold_Dragon"},
	{name = "Ancient Blue Dragon", rank = 2, ancient = true,
		str =  9, def =  7, mag = 10, agl =  5,
		weakness = "fire", absorb_element = "ice", nulls = ["thunder"],
		attack_elements = ["ice", "thunder"], reach = "all", status_attack = "paralyzed", ail = 25, support = "ward",
		sprite_id = "Ancient_Blue_Dragon"},
	{name = "Ancient Silver Dragon", rank = 2, ancient = true,
		str =  9, def =  8, mag =  9, agl =  5,
		weakness = "dark", nulls = ["ice"], light = "drain",
		attack_elements = ["light", "ice"], reach = "all", status_attack = "blind", ail = 25, support = "purge",
		sprite_id = "Ancient_Silver_Dragon"},
	# The end of the Abyss (Abyss.END_DEPTH): always last.
	{name = "Ancient Multihued Dragon", rank = 2, ancient = true, final = true,
		str =  9, def =  7, mag = 10, agl =  6,
		weakness = "light", nulls = ["fire", "ice", "thunder"], dark = "resist",
		attack_elements = ["fire", "ice", "thunder", "dark"], reach = "all", caster = true,
		status_attack = "silence", ail = 25, support = "stoke",
		sprite_id = "Ancient_Multihued_Dragon"},
]


# An Abyss boss at this floor's level (see ABYSS_BOSS_TEMPLATES).
static func make_abyss_boss(floor_num: int, which: int) -> Enemy:
	var t: Dictionary = ABYSS_BOSS_TEMPLATES[clampi(which, 0, ABYSS_BOSS_TEMPLATES.size() - 1)]
	var e: Enemy = _build(t, floor_num)
	e.icons = 2
	e.negotiable = false
	e.talk_difficulty = 0
	e.unreadable = true
	e.tint = Color.WHITE
	e.max_hp *= ABYSS_BOSS_MULT
	e.hp = e.max_hp
	e.exp_reward *= ABYSS_BOSS_MULT
	e.gold_reward *= ABYSS_BOSS_MULT
	return e


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
	if Abyss.active and floor_num > Level.FLOOR_COUNT:
		return Abyss.make_group(floor_num)
	var count: int = 1 + randi() % clampi(floor_num, 1, 4)
	# The Abyss keeps no roster of its own: every demon of every band comes
	# up out of it, each slot from any tier, all built at this depth.
	if Level.is_abyss(floor_num):
		var mixed: Array[Enemy] = []
		for _i: int in count:
			mixed.append(_build(_pick_from_tier(1 + randi() % 4), floor_num))
		return mixed
	var tier: int = tier_for_floor(floor_num)
	var group: Array[Enemy] = [make_random(floor_num)]
	for _i: int in range(count - 1):
		var from: int = tier
		if tier > 1 and randi() % 2 == 0:
			from = 1 + randi() % (tier - 1)
		group.append(_build(_pick_from_tier(from), floor_num))
	return group


# Whether this is one of the four dragons.
func is_dragon() -> bool:
	for t: Dictionary in BOSS_TEMPLATES:
		if t["name"] == enemy_name:
			return true
	for t: Dictionary in ABYSS_BOSS_TEMPLATES:
		if t["name"] == enemy_name:
			return true
	return false


# How often Silence or Blind takes hold on a dragon.
const DRAGON_AILMENT_CHANCE: float = 0.2

# A dragon often shrugs off Silence and Blind. One takes away its element, the
# other its speed, and a single Silence Dust landing every time would turn a
# dragon into a punching bag. So they land one time in five: a long shot,
# never a plan. Poison and Paralysis always take hold.
# Rolls each time it is asked, so ask once per attempt.
func resists_status(status_id: String) -> bool:
	if not (is_dragon() or is_necromancer() or is_warden()) \
			or status_id not in [Status.SILENCE, Status.BLIND]:
		return false
	return randf() >= DRAGON_AILMENT_CHANCE


# ── The Necromancer ───────────────────────────────────────────────────────────
#
# The final boss, at the end of the corridor under the Abyss. Everything it
# does is its own, run by CombatScene._necro_act rather than the shared demon
# turn:
#   * Each of its phases it takes one of the four dragons' forms (ice, thunder,
#     fire or dark, never the one it just had) and wears that dragon's affinity
#     chart until its next phase. It casts only that element, one target at a
#     time, so the spell it opens with says what it is weak to.
#   * Each phase it raises one skeleton (up to three standing) at half its own
#     level. A minion fights with its own kind's attacks and carries its own
#     press-turn icon, so the Necromancer's two icons grow to five with three
#     minions up.
#   * It clears debuffs off its side (Steady) or buffs off yours (Purge) when
#     there is something to clear, and not every phase.
const NECROMANCER: String = "Necromancer"
const NECRO_FORMS: Array[String] = ["ice", "thunder", "fire", "dark"]
const NECRO_ICONS: int = 2
const NECRO_MINIONS_MAX: int = 3
# The art goes here when it exists; until then a stand-in sheet, tinted.
const NECRO_SPRITE: String = "Necromancer"
const NECRO_STAND_IN: String = "Wizard"
# The green circle a minion rises out of, on its own sheet.
const NECRO_SUMMON_FX: String = "res://resources/characterSprites/Necromancer/Necromancer_SummonFX.png"
const NECRO_STAND_IN_TINT: Color = Color(0.62, 0.50, 0.95)


# Its own sheet once it is drawn (characterSprites/Necromancer/Necromancer_Idle.png),
# the stand-in until then.
static func necro_sprite() -> String:
	var own: String = "res://resources/characterSprites/%s/%s_Idle.png" % [
			NECRO_SPRITE, NECRO_SPRITE]
	return NECRO_SPRITE if ResourceLoader.exists(own) else NECRO_STAND_IN
const NECRO_TEMPLATE: Dictionary = {
	name = NECROMANCER, str = 12, def = 12, mag = 17, agl = 9, tier = 4,
}


func is_necromancer() -> bool:
	return enemy_name == NECROMANCER


func is_warden() -> bool:
	return WARDEN_TRICKS.has(enemy_name)


# This warden's trick (see WARDEN_TRICKS), or "" for anything else.
func warden_trick() -> String:
	return WARDEN_TRICKS.get(enemy_name, "") as String


# A dragon, a warden or the Necromancer: what banishing judges by the boss odds.
func is_boss_class() -> bool:
	return is_dragon() or is_warden() or is_necromancer()


# What the bestiary and the affinity chart file what you learn under. The
# Necromancer keeps a separate chart per form, so a weakness found in its ice
# form is still known the next time it turns to ice, and never shown for fire.
func lore_name() -> String:
	if is_necromancer() and form != "":
		return "%s:%s" % [enemy_name, form]
	# A Frost Orc's chart is not an Orc's: learned and remembered on its own.
	if abyss_element != "":
		return "%s:%s" % [enemy_name, abyss_element]
	return enemy_name


static func make_necromancer(floor_num: int) -> Enemy:
	var t: Dictionary = NECRO_TEMPLATE
	var e: Enemy = Enemy.new()
	e.spawn_floor     = maxi(1, floor_num)
	e.enemy_name      = NECROMANCER
	e.lv              = maxi(2, floor_num * 2)
	var scale: float = 1.0 + float(e.lv - 1) * 0.22
	e.str             = maxi(1, roundi(float(t["str"]) * scale))
	e.def             = maxi(1, roundi(float(t["def"]) * scale))
	e.mag             = roundi(float(t["mag"]) * scale)
	e.agl             = maxi(1, roundi(float(t["agl"]) * scale))
	e.exp_to_next     = 0
	e.exp_reward      = exp_for_level(e.lv) * 5
	e.gold_reward     = e.lv * 20
	e.negotiable      = false
	e.talk_difficulty = 0
	e.talk_personality = "proud"
	e.caster          = true
	e.attack_reach    = Spell.SHAPE_ONE
	e.tier            = int(t["tier"])
	e.icons           = NECRO_ICONS
	e.unreadable      = true
	e.ailment_chance  = 0
	e.sprite_id = necro_sprite()
	e.tint = Color.WHITE if e.sprite_id == NECRO_SPRITE else NECRO_STAND_IN_TINT
	e.compute_max_hp()
	e.max_hp *= BOSS_HP_MULT
	e.hp = e.max_hp
	e.compute_max_mp()
	# Luck to match its level: out-lucking it for a banish takes a build, and
	# it crits more (CombatMath caps a monster's crit rate).
	e.luk = e.lv
	e.take_form(NECRO_FORMS[randi() % NECRO_FORMS.size()])
	return e


# Turns to a new form, never the one it has. Its chart becomes that element's
# dragon's, and that element is all it casts until the next turn.
func take_form(element: String) -> void:
	form = element
	for t: Dictionary in BOSS_TEMPLATES:
		var els: Array = _elements_from(t)
		if not els.is_empty() and els[0] == element:
			affinities = _affinities_from(t)
			break
	attack_elements.assign([element])
	attack_element = element


func next_form() -> String:
	var others: Array[String] = []
	for f: String in NECRO_FORMS:
		if f != form:
			others.append(f)
	return others[randi() % others.size()]


# A skeleton raised at half its master's level. Fights as its own kind does.
static func make_minion(master: Enemy) -> Enemy:
	var kinds: Array[String] = []
	for t: Dictionary in TEMPLATES:
		if "Skeleton" in (t["name"] as String):
			kinds.append(t["name"] as String)
	var e: Enemy = make_at_level(kinds[randi() % kinds.size()], maxi(1, master.lv / 2))
	e.summoned    = true
	e.negotiable  = false
	e.exp_reward  = 0
	e.gold_reward = 0
	e.icons       = 1
	e.tint        = Color(0.80, 0.78, 0.95)
	return e


# One boss per run of FLOOR_COUNT floors. The old index went negative on a
# short run and quietly handed back the LAST boss — the hardest one.
# `which` picks the dragon outright (the Abyss's roaming ones); otherwise the
# floor says.
static func make_boss(floor_num: int, which: int = -1) -> Enemy:
	var idx: int = clampi(floor_num / maxi(1, Level.BOSS_EVERY) - 1,
			0, BOSS_TEMPLATES.size() - 1) if which < 0 else clampi(which, 0, BOSS_TEMPLATES.size() - 1)
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
	e.exp_reward      = exp_for_level(e.lv) * 6
	e.gold_reward     = e.lv * 24
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
	# The same price a cast, BOSS_CASTS_MULT times the casts, and exactly that:
	# a well a point short of a whole cast used to leave one off.
	if not e.attack_elements.is_empty():
		var per_cast: int = e.skill_cost()
		e.cast_mult = BOSS_CASTS_MULT
		e.max_mp = per_cast * int(MAGAZINE.get(e.attack_reach, 6)) * BOSS_CASTS_MULT
		e.mp = e.max_mp
	# Luck to match its level: out-lucking it for a banish takes a build, and
	# it crits more (CombatMath caps a monster's crit rate).
	e.luk = e.lv
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
			e.luk = monster_luck(e.lv)
			e.exp_reward = exp_for_level(e.lv)
			e.gold_reward = maxi(4, e.lv * 3)
			e.compute_max_hp()
			e.compute_max_mp()
			return e
	return make_random(1)


# The warden for a given maze floor. Floors past the written ones fall back to
# the last warden rather than to a random demon, so the key always has a keeper.
# It is built at the floor's own level like anything else down there.
static func make_warden(floor_num: int, which: int = -1) -> Enemy:
	# One warden per band, standing in the middle of it, so the four of them map
	# one to one onto the four tiers. No rotation and no modulus to get wrong:
	# the floor says which band it is in and the band says which warden.
	# `which` picks one outright, for the Abyss, where they roam.
	var idx: int = clampi(tier_for_floor(floor_num) - 1,
			0, WARDEN_TEMPLATES.size() - 1) if which < 0 else clampi(which, 0, WARDEN_TEMPLATES.size() - 1)
	var t: Dictionary = WARDEN_TEMPLATES[idx]
	var e: Enemy = _build(t, floor_num)
	# Its own colours, like a boss. The depth tint exists so the same sprite read
	# twice in one tier is visibly deeper the second time; a warden is met once in
	# the whole run, so the tint has nothing to say and only fights the art.
	e.tint = Color.WHITE
	# A warden is the floor's locked door: a step above its neighbours, a step
	# below the boss waiting one floor down. Its stats are scaled at that level
	# too; they used to stay at the ordinary floor level the build had used,
	# with only HP and MP recomputed, so a warden hit like any other demon.
	e.lv = maxi(2, roundi(float(floor_num) * 1.75))
	var scale: float = 1.0 + float(e.lv - 1) * 0.22
	e.str = maxi(1, roundi(float(t["str"]) * scale))
	e.def = maxi(1, roundi(float(t["def"]) * scale))
	e.mag = roundi(float(t["mag"]) * scale)
	e.agl = maxi(1, roundi(float(t["agl"]) * scale))
	e.exp_reward = exp_for_level(e.lv) * 4
	e.gold_reward = e.lv * 12
	e.unreadable = true
	e.compute_max_hp()
	e.max_hp *= WARDEN_HP_MULT
	e.hp = e.max_hp
	e.compute_max_mp()
	# Luck to match its level: out-lucking it for a banish takes a build, and
	# it crits more (CombatMath caps a monster's crit rate).
	e.luk = e.lv
	return e


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


# A demon's luck: half its level. It used to sit at 1 everywhere, so a demon
# on the last floor crit no more often than one on the first and a hero's luck
# edge over any of them never shrank. Half keeps the deepest packs under the
# monster crit cap (CombatMath.MONSTER_CRIT_CAP); bosses carry their full level.
static func monster_luck(lv: int) -> int:
	return maxi(1, lv / 2)


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
# and a boss closing each one. The Abyss draws from all four (see make_group)
# and counts as tier IV for anything that needs one number.
static func tier_for_floor(floor_num: int) -> int:
	return clampi((floor_num - 1) / Level.BOSS_EVERY + 1, 1, 4)


# The band colour a roamer burns in. In the Abyss each one shows a random
# band's, so the floor reads as every band's demons at once.
static func roamer_tier(floor_num: int) -> int:
	return 1 + randi() % 4 if Level.is_abyss(floor_num) else tier_for_floor(floor_num)


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
	e.luk             = monster_luck(e.lv)
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
	e.figure_scale     = float(t.get("size", 1.0))
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
	return maxi(4, roundi(float(max_mp) / float(MAGAZINE.get(attack_reach, 6) * cast_mult)))


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
	var stone: Dictionary = Item.roll_keepsake(Item.STONE_FROM_KILL, Item.SEED_FROM_KILL)
	if not stone.is_empty():
		return stone
	if randi() % 100 < 65:
		return {}
	return Item.pick_drop(spawn_floor)
