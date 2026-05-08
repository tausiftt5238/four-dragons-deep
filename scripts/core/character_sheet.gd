# CharacterSheet
# Base class for any entity that has RPG stats.
# Subclasses call compute_max_hp() and compute_max_mp() after setting stats.
class_name CharacterSheet extends Node

var lv:  int = 1
var str: int = 1
var def: int = 1
var mag: int = 1
var agl: int = 1
var exp: int = 0

var exp_to_next: int = 100
var hp:          int = 0
var max_hp:      int = 0
var mp:          int = 0
var max_mp:      int = 0


func compute_max_hp() -> void:
	max_hp = lv * 10 + def * 3
	hp = max_hp


func compute_max_mp() -> void:
	max_mp = lv * 4 + mag * 3
	mp = max_mp


func take_damage(amount: int) -> int:
	hp = max(0, hp - amount)
	return amount


func heal(amount: int) -> void:
	hp = min(max_hp, hp + amount)


func restore_mp(amount: int) -> void:
	mp = min(max_mp, mp + amount)


func is_alive() -> bool:
	return hp > 0


func gain_exp(amount: int) -> void:
	exp += amount
	while exp >= exp_to_next:
		exp -= exp_to_next
		_level_up()


func _level_up() -> void:
	lv  += 1
	str += 1
	def += 1
	mag += 1
	agl += 1
	exp_to_next = int(exp_to_next * 1.5)
	var old_max_hp: int = max_hp
	var old_max_mp: int = max_mp
	compute_max_hp()
	compute_max_mp()
	hp = min(max_hp, hp + (max_hp - old_max_hp))
	mp = min(max_mp, mp + (max_mp - old_max_mp))


# ── Status ailments ───────────────────────────────────────────────────────────

var active_statuses: Array[String] = []

func apply_status(status_id: String) -> void:
	if status_id not in active_statuses:
		active_statuses.append(status_id)

func remove_status(status_id: String) -> void:
	active_statuses.erase(status_id)

func has_status(status_id: String) -> bool:
	return status_id in active_statuses

func poison_tick() -> int:
	if not has_status(Status.POISON):
		return 0
	var dmg: int = max(1, max_hp / 10)
	take_damage(dmg)
	return dmg
