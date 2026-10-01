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

# The first level used to cost 100, which nothing on the opening floors could
# pay. A tier-one demon sits at level 2-3 and exp_for_level is 10 + lv*lv/2, so
# floor one paid 12 a fight against a 100 bill -- nine fights for one level,
# where floors three onward wanted two. The opening was the grind, in the one
# place the player has no levels, no gear and one spell.
#
# 60 roughly halves that (floor one to five fights, floor two to one or two)
# and leaves the rest of the run where it was: the cost compounds from here at
# x1.15-1.25 a level, so by floor ten the difference has washed out -- measured
# at 3.1 fights per level against 3.5, and floor twenty at 6.9 against 7.2.
var exp_to_next: int = 60
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

# A mirror held up by an Attack Mirror ("phys") or a Magic Mirror ("magic"):
# every attack of that kind is repelled until the party's next phase begins.
# Read through affinity_of, so every path that already handles a repel —
# swings, casts, spreads, banishing — turns it back with no mirror code of
# its own. CombatScene clears it.
var mirror: String = ""

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
	if mirrors(element):
		return Affinity.REPEL
	return affinities.get(element, Affinity.NORMAL) as String


# Whether a held mirror turns this element back. Magic is everything but phys.
func mirrors(element: String) -> bool:
	if mirror == "" or element == "":
		return false
	return (element == Affinity.PHYS) == (mirror == "phys")


func compute_max_hp() -> void:
	max_hp = lv * 10 + def * 3 + _hp_bonus
	hp = max_hp


func compute_max_mp() -> void:
	max_mp = lv * 4 + mag * 3 + _mp_bonus
	mp = max_mp


# What actually came off or went back on, after the floor and the ceiling —
# the battle screen floats these over the portrait. A banish that deals twice
# max HP reports what was left, and a heal at full reports nothing.
signal hp_lost(amount: int)
signal hp_gained(amount: int)


func take_damage(amount: int) -> int:
	var before: int = hp
	hp = max(0, hp - amount)
	if before > hp:
		hp_lost.emit(before - hp)
	return amount


func heal(amount: int) -> void:
	var before: int = hp
	hp = min(max_hp, hp + amount)
	if hp > before:
		hp_gained.emit(hp - before)


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
	# Gentler than it was. At x1.3-1.7 the player reached level 13 by floor
	# twenty and stopped mattering; a boss set at twice the floor number needs
	# a curve that keeps climbing all the way down.
	exp_to_next = int(exp_to_next * randf_range(1.15, 1.25))
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

# Every ailment wears off after this many of the afflicted's own turns.
const STATUS_TURNS: int = 3
# status id -> turns left. Only read for ids in active_statuses; an id that
# got there some other way (a save, a clear) counts as freshly applied.
var status_turns: Dictionary = {}

func apply_status(status_id: String) -> void:
	if status_id not in active_statuses:
		active_statuses.append(status_id)
		status_turns[status_id] = STATUS_TURNS

# One of this member's turns has passed. Returns the ailments that wore off.
func tick_statuses() -> Array[String]:
	var worn: Array[String] = []
	for id: String in active_statuses.duplicate():
		var left: int = int(status_turns.get(id, STATUS_TURNS)) - 1
		if left <= 0:
			remove_status(id)
			worn.append(id)
		else:
			status_turns[id] = left
	return worn

func remove_status(status_id: String) -> void:
	active_statuses.erase(status_id)
	status_turns.erase(status_id)

func has_status(status_id: String) -> bool:
	return status_id in active_statuses


# What Blind leaves of agility. Half is a steep cut: an even swing that lands
# 95% lands about 63% blind, and a blind target gets hit nearly every time.
const BLIND_AGL_MULT: float = 0.5

# Everything that scales agility in a fight: buff stages and Blind.
func agility_mult() -> float:
	var m: float = stage_mult(STAT_AGL)
	if has_status(Status.BLIND):
		m *= BLIND_AGL_MULT
	return m

# A potion, an ether or a cure taken by this member: HP, MP and ailments only.
# Anyone in the party can drink one — the hero and every monster alike — so it
# lives here rather than on the hero. Returns what it did, for the log.
func apply_restorative(item: Dictionary) -> String:
	var msg: String = ""
	var hp_val: int  = int(item.get("hp_restore", 0))
	var mp_val: int  = int(item.get("mp_restore", 0))
	var cure: String = item.get("cures_status", "") as String
	if hp_val > 0:
		var before: int = hp
		heal(hp_val)
		msg += "Restored %d HP. " % (hp - before)
	if mp_val > 0:
		var before_mp: int = mp
		restore_mp(mp_val)
		msg += "Restored %d MP. " % (mp - before_mp)
	if cure == "all":
		active_statuses.clear()
		msg += "Cured all ailments."
	elif cure != "":
		if has_status(cure):
			remove_status(cure)
			msg += "Cured %s." % Status.get_data(cure).get("name", cure)
		else:
			msg += "Not afflicted."
	return msg.strip_edges()


# Whether a restorative would do anything for this member right now.
func could_use(item: Dictionary) -> bool:
	if int(item.get("hp_restore", 0)) > 0 and hp < max_hp:
		return true
	if int(item.get("mp_restore", 0)) > 0 and mp < max_mp:
		return true
	var cure: String = item.get("cures_status", "") as String
	if cure == "all":
		return not active_statuses.is_empty()
	return cure != "" and has_status(cure)


func poison_tick() -> int:
	if not has_status(Status.POISON):
		return 0
	var dmg: int = max(1, max_hp / 10)
	take_damage(dmg)
	return dmg
