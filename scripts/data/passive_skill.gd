class_name PassiveSkill extends RefCounted

const DATA: Dictionary = {
	"counter":    {name="Counter",    desc="25% chance to retaliate when struck."},
	"last_stand": {name="Last Stand", desc="Attack deals double damage when HP < 25%."},
	"meditate":   {name="Meditate",   desc="Recover 2 MP at the end of each round."},
	"vampiric":   {name="Vampiric",   desc="Physical attacks heal 20% of damage dealt."},
	"resilience": {name="Resilience", desc="25% chance to resist status ailments."},
	"scholar":    {name="Scholar",    desc="Spell damage increased by 25%."},
	"quick":      {name="Quick",      desc="Always act before the enemy."},
	"scavenger":  {name="Scavenger",  desc="Enemies more likely to drop items."},
}


static func get_data(skill_id: String) -> Dictionary:
	return DATA.get(skill_id, {name=skill_id, desc=""})


static func random_pick(count: int, exclude: Array[String] = []) -> Array[String]:
	var pool: Array[String] = []
	for k: String in DATA.keys():
		if k not in exclude:
			pool.append(k)
	pool.shuffle()
	var result: Array[String] = []
	for i: int in range(min(count, pool.size())):
		result.append(pool[i])
	return result
