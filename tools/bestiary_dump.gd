extends SceneTree

const OUT := "/tmp/claude-1000/-home-ttausif-game-project-first-person-dungeon-crawler/30c2fcae-cc3a-4bc2-bd80-fd3c4418a61c/scratchpad/bestiary.json"


func _row(t: Dictionary, lo: Enemy, hi: Enemy) -> Dictionary:
	var chart: Dictionary = {}
	for e: String in Affinity.ELEMENTS:
		chart[e] = lo.affinity_of(e)
	var sup: String = t.get("support", "") as String
	var sd: Dictionary = Spell.get_data(sup)
	return {
		name = t["name"],
		rank = int(t.get("rank", 0)),
		icons = int(t.get("icons", 1)),
		needs_art = bool(t.get("needs_art", false)),
		lv_lo = lo.lv, lv_hi = hi.lv,
		hp_lo = lo.max_hp, hp_hi = hi.max_hp,
		exp_lo = lo.exp_reward, exp_hi = hi.exp_reward,
		gold_lo = lo.gold_reward, gold_hi = hi.gold_reward,
		chart = chart,
		attack_element = t.get("attack_element", ""),
		status_attack = t.get("status_attack", ""),
		ail = int(t.get("ail", 0)),
		ail_spell = _ail_spell(t.get("status_attack", "") as String),
		ail_mp = _ail_mp(t.get("status_attack", "") as String),
		ail_land = CombatScene.ail_landing_chance(int(t.get("ail", 0))),
		support = sup,
		support_name = sd.get("name", ""),
		support_type = sd.get("type", ""),
		support_stat = sd.get("stat", ""),
		support_delta = int(sd.get("delta", 0)),
		support_scope = sd.get("scope", ""),
		support_clears = sd.get("clears", ""),
		support_mp = int(sd.get("mp", 0)),
		support_desc = sd.get("desc", ""),
		negotiable = bool(t.get("negotiable", true)),
		talk_difficulty = int(t.get("talk_difficulty", 0)),
		personality = t.get("personality", ""),
		wants = t.get("wants", ""),
	}


func _ail_spell(status_id: String) -> String:
	if not CombatScene.AIL_SPELLS.has(status_id):
		return ""
	return Spell.get_data(CombatScene.AIL_SPELLS[status_id] as String).get("name", "") as String


func _ail_mp(status_id: String) -> int:
	if not CombatScene.AIL_SPELLS.has(status_id):
		return 0
	return int(Spell.get_data(CombatScene.AIL_SPELLS[status_id] as String).get("mp", 0))


func _build(name: String, fl: int, kind: String) -> Enemy:
	match kind:
		"warden": return Enemy.make_warden(fl)
		"boss":   return Enemy.make_boss(fl)
	return Enemy.make_from_name(name, fl)


func _initialize() -> void:
	var out: Dictionary = {tiers = [], wardens = [], bosses = [], spells = {}}

	for tier: int in [1, 2, 3, 4]:
		var first: int = (tier - 1) * Level.BOSS_EVERY + 1
		var last: int  = tier * Level.BOSS_EVERY
		var rows: Array = []
		for t: Dictionary in Enemy.TEMPLATES:
			if int(t.get("tier", 1)) != tier:
				continue
			var lo: Enemy = _build(t["name"] as String, first, "")
			var hi: Enemy = _build(t["name"] as String, last, "")
			rows.append(_row(t, lo, hi))
			lo.free()
			hi.free()
		var boss: Enemy = Enemy.make_boss(last)
		out["tiers"].append({
			tier = tier, first = first, last = last,
			boss_lv = boss.lv, rows = rows,
		})
		boss.free()

	# Wardens, at the shallowest and deepest maze floor each actually appears on.
	for i: int in Enemy.WARDEN_TEMPLATES.size():
		var t: Dictionary = Enemy.WARDEN_TEMPLATES[i]
		var floors: Array[int] = []
		for fl: int in range(1, Level.FLOOR_COUNT + 1):
			if Level.is_boss_floor(fl):
				continue
			var w: Enemy = Enemy.make_warden(fl)
			if w.enemy_name == t["name"]:
				floors.append(fl)
			w.free()
		if floors.is_empty():
			continue
		var lo: Enemy = Enemy.make_warden(floors[0])
		var hi: Enemy = Enemy.make_warden(floors[floors.size() - 1])
		var row: Dictionary = _row(t, lo, hi)
		row["floors"] = floors
		out["wardens"].append(row)
		lo.free()
		hi.free()

	for fl: int in [5, 10, 15, 20]:
		var b: Enemy = Enemy.make_boss(fl)
		var t: Dictionary = {}
		for cand: Dictionary in Enemy.BOSS_TEMPLATES:
			if cand["name"] == b.enemy_name:
				t = cand
				break
		var row: Dictionary = _row(t, b, b)
		row["floor"] = fl
		out["bosses"].append(row)
		b.free()

	for id: String in Spell.DATA:
		out["spells"][id] = Spell.DATA[id]

	var f: FileAccess = FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "\t"))
	f.close()
	print("wrote ", OUT)
	quit()
