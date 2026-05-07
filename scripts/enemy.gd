# Enemy
# Base class for all hostile entities. Inherits RPG stats from CharacterSheet.
# Use make_random() to generate a floor-scaled enemy without adding it to the tree.
class_name Enemy extends CharacterSheet

var enemy_name: String = "Unknown"
var exp_reward: int    = 20

# Template data for all enemy types. Stats are base values for floor 1.
const TEMPLATES: Array[Dictionary] = [
	{name = "Slime",    str = 2, def = 1, mag = 0, agl = 1, exp = 15},
	{name = "Goblin",   str = 4, def = 2, mag = 0, agl = 4, exp = 25},
	{name = "Skeleton", str = 5, def = 3, mag = 1, agl = 2, exp = 30},
	{name = "Wraith",   str = 3, def = 1, mag = 5, agl = 5, exp = 40},
	{name = "Troll",    str = 7, def = 5, mag = 0, agl = 1, exp = 50},
]


static func make_random(floor_num: int) -> Enemy:
	var e: Enemy = Enemy.new()
	var t: Dictionary = TEMPLATES[randi() % TEMPLATES.size()]
	var bonus: int = floor_num - 1
	e.enemy_name = t["name"]
	e.lv         = max(1, floor_num + randi() % 2)
	e.str        = t["str"] + bonus
	e.def        = t["def"] + bonus
	e.mag        = t["mag"] + bonus
	e.agl        = t["agl"]
	e.exp_to_next = 0  # enemies don't level up
	e.exp_reward  = t["exp"] * floor_num
	e.compute_max_hp()
	return e
