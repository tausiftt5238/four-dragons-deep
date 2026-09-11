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
const TEMPLATES: Array[Dictionary] = [
	# --- Floor 1-2 ---
	{name="Bat",            str=2,  def=1,  mag=0,  agl=5, exp=12,  gold=4,  status_attack="",           weakness="fire", min_floor=1, max_floor=2,  negotiable=true,  talk_difficulty=1, personality="cowardly", wants="any",       sprite="res://resources/enemySprites/Bat.png", phys="weak", lv=1, ail=5},
	{name="Slug",           str=2,  def=2,  mag=0,  agl=1, exp=18,  gold=6,  status_attack="poison",     weakness="fire",    min_floor=1, max_floor=2,  negotiable=false, talk_difficulty=0, sprite="res://resources/enemySprites/Slug.png", phys="resist", lv=1, ail=5},
	{name="GiantRat",       str=3,  def=2,  mag=0,  agl=3, exp=20,  gold=6,  status_attack="",           weakness="fire", min_floor=1, max_floor=2,  negotiable=true,  talk_difficulty=1, personality="cowardly", wants="potion",    sprite="res://resources/enemySprites/GiantRat.png", lv=1, ail=5},
	{name="Cave Bat",       str=3,  def=2,  mag=3,  agl=6, exp=16,  gold=5,  status_attack="",           weakness="fire", min_floor=1, max_floor=2,  negotiable=true,  talk_difficulty=1, personality="cowardly", wants="any",       sprite="res://resources/enemySprites/BatB.png", phys="weak", lv=2, ail=5, attack_element="thunder"},
	{name="Giant Slug",     str=3,  def=3,  mag=0,  agl=1, exp=22,  gold=7,  status_attack="poison",     weakness="fire",    min_floor=1, max_floor=2,  negotiable=false, talk_difficulty=0, sprite="res://resources/enemySprites/SlugB.png", phys="resist", lv=2, ail=5},
	{name="Dire Rat",       str=4,  def=3,  mag=0,  agl=4, exp=25,  gold=8,  status_attack="poison",     weakness="fire", min_floor=1, max_floor=2,  negotiable=true,  talk_difficulty=1, personality="cowardly", wants="potion",    sprite="res://resources/enemySprites/GiantRatB.png", lv=2, ail=5},
	# --- Floor 1-3 ---
	{name="Goblin",         str=4,  def=2,  mag=0,  agl=4, exp=25,  gold=8,  status_attack="",           weakness="fire", min_floor=1, max_floor=3,  negotiable=true,  talk_difficulty=2, personality="greedy",   wants="throwable", sprite="res://resources/enemySprites/Goblin.png", phys="weak", lv=2, ail=5},
	{name="GelatinousCube", str=2,  def=4,  mag=0,  agl=1, exp=22,  gold=7,  status_attack="immobilize", weakness="fire",    min_floor=1, max_floor=3,  negotiable=false, talk_difficulty=0, sprite="res://resources/enemySprites/GelatinousCube.png", attack_element="ice", phys="resist", lv=2, ail=5},
	{name="Hobgoblin",      str=5,  def=3,  mag=0,  agl=5, exp=32,  gold=10, status_attack="",           weakness="fire", min_floor=1, max_floor=3,  negotiable=true,  talk_difficulty=2, personality="greedy",   wants="throwable", sprite="res://resources/enemySprites/GoblinB.png", phys="weak", lv=3, ail=5},
	{name="Ooze",           str=3,  def=5,  mag=0,  agl=1, exp=28,  gold=9,  status_attack="immobilize", weakness="fire",    min_floor=1, max_floor=3,  negotiable=false, talk_difficulty=0, sprite="res://resources/enemySprites/GelatinousCubeB.png", attack_element="ice", phys="resist", lv=3, ail=5},
	# --- Floor 2-4 ---
	{name="Skeleton",       str=5,  def=3,  mag=1,  agl=2, exp=30,  gold=10, status_attack="immobilize", weakness="fire",    min_floor=2, max_floor=4,  negotiable=false, talk_difficulty=0, sprite="res://resources/enemySprites/Skeleton.png", phys="resist", lv=5, ail=12},
	{name="GiantHornet",    str=4,  def=2,  mag=0,  agl=6, exp=28,  gold=9,  status_attack="poison",     weakness="ice",     min_floor=2, max_floor=4,  negotiable=false, talk_difficulty=0, sprite="res://resources/enemySprites/GiantHornet.png", phys="weak", lv=5, ail=12},
	{name="Bandit",         str=5,  def=3,  mag=3,  agl=5, exp=32,  gold=12, status_attack="",           weakness="thunder", min_floor=2, max_floor=4,  negotiable=true,  talk_difficulty=2, personality="greedy",   wants="any",       sprite="res://resources/enemySprites/Bandit.png", phys="weak", lv=5, ail=12, attack_element="fire"},
	{name="WildBoar",       str=6,  def=3,  mag=0,  agl=2, exp=30,  gold=9,  status_attack="",           weakness="ice", min_floor=2, max_floor=4,  negotiable=true,  talk_difficulty=2, personality="cowardly", wants="potion",    sprite="res://resources/enemySprites/WildBoar.png", lv=5, ail=12},
	{name="AnimatedPlant",  str=3,  def=3,  mag=4,  agl=1, exp=28,  gold=8,  status_attack="poison",     weakness="fire",    min_floor=2, max_floor=4,  negotiable=false, talk_difficulty=0, sprite="res://resources/enemySprites/AnimatedPlant.png", lv=5, ail=12},
	{name="Bone Knight",    str=6,  def=4,  mag=2,  agl=2, exp=38,  gold=12, status_attack="immobilize", weakness="fire",    min_floor=2, max_floor=4,  negotiable=false, talk_difficulty=0, sprite="res://resources/enemySprites/SkeletonB.png", phys="resist", lv=6, ail=12},
	{name="Queen Hornet",   str=5,  def=3,  mag=0,  agl=7, exp=35,  gold=11, status_attack="poison",     weakness="ice",     min_floor=2, max_floor=4,  negotiable=false, talk_difficulty=0, sprite="res://resources/enemySprites/GiantHornetB.png", phys="weak", lv=6, ail=12},
	{name="Veteran Bandit", str=6,  def=4,  mag=0,  agl=5, exp=40,  gold=15, status_attack="",           weakness="thunder", min_floor=2, max_floor=4,  negotiable=true,  talk_difficulty=3, personality="greedy",   wants="any",       sprite="res://resources/enemySprites/BanditB.png", phys="weak", lv=6, ail=12},
	{name="Tusked Boar",    str=7,  def=4,  mag=0,  agl=2, exp=38,  gold=11, status_attack="",           weakness="ice", min_floor=2, max_floor=4,  negotiable=true,  talk_difficulty=2, personality="cowardly", wants="potion",    sprite="res://resources/enemySprites/WildBoarB.png", lv=6, ail=12},
	{name="Thornvine",      str=4,  def=4,  mag=5,  agl=1, exp=35,  gold=10, status_attack="poison",     weakness="fire",    min_floor=2, max_floor=4,  negotiable=false, talk_difficulty=0, sprite="res://resources/enemySprites/AnimatedPlantB.png", lv=6, ail=12},
	# --- Floor 3+ ---
	{name="Treant",         str=6,  def=6,  mag=0,  agl=1, exp=45,  gold=14, status_attack="immobilize", weakness="fire",    min_floor=3, max_floor=-1, negotiable=false, talk_difficulty=0, sprite="res://resources/enemySprites/Treant.png", phys="resist", lv=8, ail=18},
	{name="Orc",            str=7,  def=4,  mag=0,  agl=2, exp=38,  gold=12, status_attack="",           weakness="ice",     min_floor=3, max_floor=5,  negotiable=true,  talk_difficulty=3, personality="proud",    wants="throwable", sprite="res://resources/enemySprites/Orc.png", lv=8, ail=18},
	{name="Fairy",          str=2,  def=2,  mag=6,  agl=7, exp=42,  gold=14, status_attack="silence",    weakness="thunder", min_floor=3, max_floor=-1, negotiable=true,  talk_difficulty=3, personality="lonely",   wants="potion",    sprite="res://resources/enemySprites/Fairy.png",         attack_element="thunder", absorb_element="thunder", phys="weak", support="mire", lv=8, ail=18},
	{name="Elder Treant",   str=7,  def=7,  mag=0,  agl=1, exp=55,  gold=17, status_attack="immobilize", weakness="fire",    min_floor=3, max_floor=-1, negotiable=false, talk_difficulty=0, sprite="res://resources/enemySprites/TreantB.png", phys="resist", icons=2, lv=9, ail=18},
	{name="Orc Warchief",   str=8,  def=5,  mag=0,  agl=2, exp=46,  gold=15, status_attack="",           weakness="ice",     min_floor=3, max_floor=5,  negotiable=true,  talk_difficulty=4, personality="proud",    wants="throwable", sprite="res://resources/enemySprites/OrcB.png", icons=2, support="whet", lv=9, ail=18},
	{name="Dark Fairy",     str=3,  def=3,  mag=7,  agl=8, exp=50,  gold=17, status_attack="silence",    weakness="thunder", min_floor=3, max_floor=-1, negotiable=true,  talk_difficulty=3, personality="lonely",   wants="potion",    sprite="res://resources/enemySprites/FairyB.png",        attack_element="thunder", absorb_element="thunder", phys="weak", support="mire", lv=9, ail=18},
	# --- Floor 4+ ---
	{name="Ogre",           str=9,  def=5,  mag=0,  agl=1, exp=55,  gold=18, status_attack="",           weakness="ice",     min_floor=4, max_floor=-1, negotiable=true,  talk_difficulty=4, personality="proud",    wants="any",       sprite="res://resources/enemySprites/Ogre.png", icons=2, lv=11, ail=22},
	{name="Wizard",         str=2,  def=2,  mag=8,  agl=4, exp=52,  gold=16, status_attack="silence",    weakness="ice",     min_floor=4, max_floor=-1, negotiable=true,  talk_difficulty=3, personality="proud",    wants="potion",    sprite="res://resources/enemySprites/Wizard.png",        attack_element="fire",    reflect_element="fire", phys="weak", support="whet", lv=11, ail=22},
	{name="Stone Ogre",     str=10, def=6,  mag=0,  agl=1, exp=65,  gold=22, status_attack="",           weakness="ice",     min_floor=4, max_floor=-1, negotiable=true,  talk_difficulty=5, personality="proud",    wants="any",       sprite="res://resources/enemySprites/OgreB.png", icons=2, support="ward", lv=12, ail=22},
	{name="Dark Wizard",    str=3,  def=3,  mag=9,  agl=4, exp=62,  gold=20, status_attack="silence",    weakness="ice",     min_floor=4, max_floor=-1, negotiable=true,  talk_difficulty=4, personality="proud",    wants="potion",    sprite="res://resources/enemySprites/WizardB.png",       attack_element="fire",    reflect_element="fire", phys="weak", support="stoke", lv=12, ail=22},
]

# Boss templates — one per 5-floor milestone, cycling every 4 bosses.
const BOSS_TEMPLATES: Array[Dictionary] = [
	{name="Shadow Knight", str=12, def=8,  mag=2,  agl=3, exp=200, gold=80,  status_attack="immobilize", weakness="thunder", min_floor=5,  max_floor=-1, negotiable=false, talk_difficulty=0, sprite="", icons=3, support="ward", lv=12, ail=25},
	{name="Bone Sorcerer", str=5,  def=6,  mag=14, agl=4, exp=280, gold=110, status_attack="silence",    weakness="ice",     min_floor=10, max_floor=-1, negotiable=false, talk_difficulty=0, sprite="", attack_element="fire", icons=3, support="stoke", lv=14, ail=25},
	{name="Iron Titan",    str=16, def=12, mag=0,  agl=1, exp=360, gold=140, status_attack="paralyzed",  weakness="thunder", min_floor=15, max_floor=-1, negotiable=false, talk_difficulty=0, sprite="", icons=4, support="ward", lv=16, ail=25},
	{name="Void Drake",    str=14, def=10, mag=12, agl=5, exp=450, gold=180, status_attack="",           weakness="ice",     min_floor=20, max_floor=-1, negotiable=false, talk_difficulty=0, sprite="", attack_element="thunder", icons=4, support="damp", lv=18, ail=25},
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


static func all_templates() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	result.append_array(TEMPLATES)
	result.append_array(BOSS_TEMPLATES)
	return result



static func make_from_name(enemy_name: String, floor_num: int = 1) -> Enemy:
	for tmpl: Dictionary in TEMPLATES:
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
