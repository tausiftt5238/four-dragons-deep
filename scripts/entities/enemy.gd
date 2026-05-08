# Enemy
# Base class for all hostile entities. Inherits RPG stats from CharacterSheet.
# Use make_random() to generate a floor-scaled enemy without adding it to the tree.
class_name Enemy extends CharacterSheet

var enemy_name:    String = "Unknown"
var exp_reward:    int    = 20
var gold_reward:   int    = 5
var status_attack: String = ""

# Template data for all enemy types. Stats are base values for floor 1.
const TEMPLATES: Array[Dictionary] = [
	{name="Slime",    str=2, def=1, mag=0, agl=1, exp=15, gold=5,  status_attack="poison"},
	{name="Goblin",   str=4, def=2, mag=0, agl=4, exp=25, gold=8,  status_attack=""},
	{name="Skeleton", str=5, def=3, mag=1, agl=2, exp=30, gold=10, status_attack="immobilize"},
	{name="Wraith",   str=3, def=1, mag=5, agl=5, exp=40, gold=13, status_attack="silence"},
	{name="Troll",    str=7, def=5, mag=0, agl=1, exp=50, gold=17, status_attack="immobilize"},
]



static func make_random(floor_num: int) -> Enemy:
	var e: Enemy = Enemy.new()
	var t: Dictionary = TEMPLATES[randi() % TEMPLATES.size()]
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
	e.status_attack = t.get("status_attack", "")
	e.compute_max_hp()
	return e


# Returns a random item drop, or an empty dict if nothing drops (65% no-drop).
func roll_drop() -> Dictionary:
	if randi() % 100 < 65:
		return {}
	var table: Array[Dictionary] = Item.drop_table()
	return table[randi() % table.size()]
