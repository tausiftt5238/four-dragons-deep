# Enemy
# Base class for all hostile entities. Inherits RPG stats from CharacterSheet.
# Use make_random() to generate a floor-scaled enemy without adding it to the tree.
class_name Enemy extends CharacterSheet

var enemy_name:      String = "Unknown"
var exp_reward:      int    = 20
var gold_reward:     int    = 5
var status_attack:   String = ""
var weakness:        String = ""
var negotiable:      bool   = true
var talk_difficulty: int    = 2
var sprite_path:     String = ""
var attack_element:  String = ""

# Template data for all enemy types. Stats are base values for floor 1.
# min_floor / max_floor control which dungeon floors they appear on.
# max_floor = -1 means no upper limit.
const TEMPLATES: Array[Dictionary] = [
	# --- Floor 1-2 ---
	{name="Bat",           str=2, def=1, mag=0, agl=5, exp=12, gold=4,  status_attack="",           weakness="thunder", min_floor=1, max_floor=2,  negotiable=true,  talk_difficulty=1, sprite="res://resources/enemySprites/Bat.png"},
	{name="Slug",          str=2, def=2, mag=0, agl=1, exp=18, gold=6,  status_attack="poison",     weakness="fire",    min_floor=1, max_floor=2,  negotiable=false, talk_difficulty=0, sprite="res://resources/enemySprites/Slug.png"},
	{name="GiantRat",      str=3, def=2, mag=0, agl=3, exp=20, gold=6,  status_attack="",           weakness="thunder", min_floor=1, max_floor=2,  negotiable=true,  talk_difficulty=1, sprite="res://resources/enemySprites/GiantRat.png"},
	# --- Floor 1-3 ---
	{name="Goblin",        str=4, def=2, mag=0, agl=4, exp=25, gold=8,  status_attack="",           weakness="thunder", min_floor=1, max_floor=3,  negotiable=true,  talk_difficulty=2, sprite="res://resources/enemySprites/Goblin.png"},
	{name="GelatinousCube",str=2, def=4, mag=0, agl=1, exp=22, gold=7,  status_attack="immobilize", weakness="fire",    min_floor=1, max_floor=3,  negotiable=false, talk_difficulty=0, sprite="res://resources/enemySprites/GelatinousCube.png", attack_element="ice"},
	# --- Floor 2-4 ---
	{name="Skeleton",      str=5, def=3, mag=1, agl=2, exp=30, gold=10, status_attack="immobilize", weakness="fire",    min_floor=2, max_floor=4,  negotiable=false, talk_difficulty=0, sprite="res://resources/enemySprites/Skeleton.png"},
	{name="GiantHornet",   str=4, def=2, mag=0, agl=6, exp=28, gold=9,  status_attack="poison",     weakness="ice",     min_floor=2, max_floor=4,  negotiable=false, talk_difficulty=0, sprite="res://resources/enemySprites/GiantHornet.png"},
	{name="Bandit",        str=5, def=3, mag=0, agl=5, exp=32, gold=12, status_attack="",           weakness="thunder", min_floor=2, max_floor=4,  negotiable=true,  talk_difficulty=2, sprite="res://resources/enemySprites/Bandit.png"},
	{name="WildBoar",      str=6, def=3, mag=0, agl=2, exp=30, gold=9,  status_attack="",           weakness="thunder", min_floor=2, max_floor=4,  negotiable=true,  talk_difficulty=2, sprite="res://resources/enemySprites/WildBoar.png"},
	{name="AnimatedPlant", str=3, def=3, mag=4, agl=1, exp=28, gold=8,  status_attack="poison",     weakness="fire",    min_floor=2, max_floor=4,  negotiable=false, talk_difficulty=0, sprite="res://resources/enemySprites/AnimatedPlant.png"},
	# --- Floor 3+ ---
	{name="Treant",        str=6, def=6, mag=0, agl=1, exp=45, gold=14, status_attack="immobilize", weakness="fire",    min_floor=3, max_floor=-1, negotiable=false, talk_difficulty=0, sprite="res://resources/enemySprites/Treant.png"},
	{name="Orc",           str=7, def=4, mag=0, agl=2, exp=38, gold=12, status_attack="",           weakness="ice",     min_floor=3, max_floor=5,  negotiable=true,  talk_difficulty=3, sprite="res://resources/enemySprites/Orc.png"},
	{name="Fairy",         str=2, def=2, mag=6, agl=7, exp=42, gold=14, status_attack="silence",    weakness="thunder", min_floor=3, max_floor=-1, negotiable=true,  talk_difficulty=3, sprite="res://resources/enemySprites/Fairy.png",         attack_element="thunder"},
	# --- Floor 4+ ---
	{name="Ogre",          str=9, def=5, mag=0, agl=1, exp=55, gold=18, status_attack="",           weakness="ice",     min_floor=4, max_floor=-1, negotiable=true,  talk_difficulty=4, sprite="res://resources/enemySprites/Ogre.png"},
	{name="Wizard",        str=2, def=2, mag=8, agl=4, exp=52, gold=16, status_attack="silence",    weakness="ice",     min_floor=4, max_floor=-1, negotiable=true,  talk_difficulty=3, sprite="res://resources/enemySprites/Wizard.png",         attack_element="fire"},
]



static func make_random(floor_num: int) -> Enemy:
	var e: Enemy = Enemy.new()
	var pool: Array[Dictionary] = []
	for tmpl: Dictionary in TEMPLATES:
		if floor_num >= tmpl["min_floor"] and (tmpl["max_floor"] == -1 or floor_num <= tmpl["max_floor"]):
			pool.append(tmpl)
	if pool.is_empty():
		pool = TEMPLATES  # fallback: use all if nothing matches
	var t: Dictionary = pool[randi() % pool.size()]
	var bonus: int = floor_num - 1
	e.enemy_name  = t["name"]
	e.lv          = max(1, floor_num + randi() % 2)
	e.str         = t["str"] + bonus
	e.def         = t["def"] + bonus
	e.mag         = t["mag"] + bonus
	e.agl         = t["agl"]
	e.exp_to_next = 0  # enemies don't level up
	e.exp_reward  = t["exp"] * floor_num
	e.gold_reward   = (t["gold"] + randi() % 5) * floor_num
	e.status_attack   = t.get("status_attack", "")
	e.weakness        = t.get("weakness", "")
	e.negotiable      = t.get("negotiable", true)
	e.talk_difficulty = t.get("talk_difficulty", 2)
	e.sprite_path     = t.get("sprite", "")
	e.attack_element  = t.get("attack_element", "")
	e.compute_max_hp()
	return e


# Returns a random item drop, or an empty dict if nothing drops (65% no-drop).
func roll_drop() -> Dictionary:
	if randi() % 100 < 65:
		return {}
	var table: Array[Dictionary] = Item.drop_table()
	return table[randi() % table.size()]
