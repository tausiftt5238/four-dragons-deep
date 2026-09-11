# CharacterSheet
# Base class for any entity that has RPG stats.
# Subclasses call compute_max_hp() and compute_max_mp() after setting stats.
class_name CharacterSheet extends Node

var lv:  int = 1
var str: int = 1
var def: int = 1
var mag: int = 1
var agl: int = 1
# Luck does not hit harder or dodge better. It decides the things that are
# already a coin flip: whether a swing crits, and whether a banishing cast
# finds purchase on a demon whose chart has no strong opinion either way.
var luk: int = 1
var exp: int = 0

var exp_to_next: int = 100
var hp:          int = 0
var max_hp:      int = 0
var mp:          int = 0
var max_mp:      int = 0

# Accumulated ±20% variance from per-level HP/MP rolls.
var _hp_bonus: int = 0
var _mp_bonus: int = 0

# Elemental affinity chart: element -> Affinity state. An element that is
# absent is Affinity.NORMAL. "phys" is a valid key, so ordinary attacks are
# scored on the same chart as magic.
var affinities: Dictionary = {}

# Set when this combatant chose Defend; cleared the next time it is struck.
var defending: bool = false

# ── Buff and debuff stages ────────────────────────────────────────────────────
#
# Nocturne-style: attack, defence and agility each sit on a stage from -CAP to
# +CAP, and every stage is worth BUFF_STEP either way. Stages are per battle —
# nothing carries out of a fight — and they stack, so four rounds of stacking
# is a real strategy rather than a rounding error.
const BUFF_CAP:  int   = 4
const BUFF_STEP: float = 0.15

const STAT_ATK: String = "atk"
const STAT_MAG: String = "mag"
const STAT_DEF: String = "def"
const STAT_AGL: String = "agl"

# Attack and magic are separate axes here, unlike Nocturne where one buff
# covers both — a caster and a fighter stack different things.
const STAT_KEYS: Array[String] = ["atk", "mag", "def", "agl"]

var stages: Dictionary = {"atk": 0, "mag": 0, "def": 0, "agl": 0}


func stage(key: String) -> int:
	return int(stages.get(key, 0))


# Applies a shift and returns what actually landed — 0 when already capped, so
# the caller can say "it is already as sharp as it gets" rather than lying.
func shift_stage(key: String, delta: int) -> int:
	var before: int = stage(key)
	var after: int = clampi(before + delta, -BUFF_CAP, BUFF_CAP)
	stages[key] = after
	return after - before


func stage_mult(key: String) -> float:
	return 1.0 + BUFF_STEP * float(stage(key))


func clear_buffs() -> void:
	for key: String in STAT_KEYS:
		if stage(key) > 0:
			stages[key] = 0


func clear_debuffs() -> void:
	for key: String in STAT_KEYS:
		if stage(key) < 0:
			stages[key] = 0


func reset_stages() -> void:
	stages = {"atk": 0, "mag": 0, "def": 0, "agl": 0}


# Agility as it counts in a fight. PlayerCharacter overrides to fold in gear.
func battle_agility() -> int:
	return agl


# Luck as it counts in a fight. PlayerCharacter overrides to fold in trinkets.
func battle_luck() -> int:
	return luk


# The affinity state this combatant has toward an element. Subclasses override
# to layer equipment on top of their innate chart.
func affinity_of(element: String) -> String:
	if element == "":
		return Affinity.NORMAL
	return affinities.get(element, Affinity.NORMAL) as String


func compute_max_hp() -> void:
	max_hp = lv * 10 + def * 3 + _hp_bonus
	hp = max_hp


func compute_max_mp() -> void:
	max_mp = lv * 4 + mag * 3 + _mp_bonus
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
	var old_max_hp: int = max_hp
	var old_max_mp: int = max_mp
	lv += 1
	exp_to_next = int(exp_to_next * randf_range(1.3, 1.7))
	_hp_bonus += roundi(10.0 * randf_range(0.8, 1.2)) - 10
	_mp_bonus += roundi(4.0 * randf_range(0.8, 1.2)) - 4
	compute_max_hp()
	compute_max_mp()
	hp = min(max_hp, hp + (max_hp - old_max_hp))
	mp = min(max_mp, mp + (max_mp - old_max_mp))


# Called by LevelUpUI after the player distributes their stat points.
# Applies bonus stats without resetting current HP/MP to max.
func apply_stat_bonus(bonus: Dictionary) -> void:
	var old_max_hp: int = max_hp
	var old_max_mp: int = max_mp
	str += bonus.get("str", 0)
	def += bonus.get("def", 0)
	mag += bonus.get("mag", 0)
	agl += bonus.get("agl", 0)
	luk += bonus.get("luk", 0)
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
