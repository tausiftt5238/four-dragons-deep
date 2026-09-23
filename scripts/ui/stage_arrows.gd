# StageArrows
# A combatant's buff and debuff stages as arrows instead of "ATK+2 AGL-1".
#
# Four fixed places, one per stat in STAT_KEYS order (ATK, MAG, DEF, AGL), each
# in that stat's colour. A raised stat points its arrows up, a lowered one
# down, one arrow per stage up to the cap, in a 2x2 block. A stat at zero leaves its place
# empty, so a stat is always found in the same spot and in the same colour.
#
# Drawn, and sized by its container: it takes no width of its own, so it can
# never widen the slot it sits in.
class_name StageArrows extends Control

const COLORS: Dictionary = {
	"atk": Color(1.00, 0.55, 0.22),   # orange
	"mag": Color(0.80, 0.52, 1.00),   # violet
	"def": Color(0.42, 0.72, 1.00),   # blue
	"agl": Color(0.45, 0.95, 0.48),   # green
}
const HEIGHT: float = 22.0

var member: CharacterSheet = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0, HEIGHT)


static func color_of(key: String) -> Color:
	return COLORS.get(key, Color.WHITE) as Color


# The same colours on a stat's name wherever it is written, so the arrows can
# be read without a legend: STR (and ATK) orange, MAG violet, DEF blue, AGL
# green. Anything else — LUK, HP, MP — keeps `fallback`.
static func tint_for(stat_name: String, fallback: Color) -> Color:
	match stat_name.to_lower():
		"str", "atk", "attack": return COLORS["atk"]
		"mag", "magic":         return COLORS["mag"]
		"def", "defence":       return COLORS["def"]
		"agl", "agility":       return COLORS["agl"]
	return fallback


func _draw() -> void:
	if member == null or size.x <= 0.0:
		return
	var keys: Array[String] = CharacterSheet.STAT_KEYS
	var group_w: float = size.x / float(keys.size())
	# Each stat's arrows sit in a 2x2 block rather than a line of four, which
	# doubles how big each one can be in a quarter of a battle column. Filled
	# left to right, top row first, so the count reads like dice.
	var cell: Vector2 = Vector2(minf(group_w * 0.5, size.y * 0.9), size.y * 0.5)
	var w: float = cell.x * 0.78
	var h: float = cell.y * 0.80
	for i: int in keys.size():
		var key: String = keys[i]
		var st: int = member.stage(key)
		if st == 0:
			continue
		var n: int = mini(absi(st), CharacterSheet.BUFF_CAP)
		var col: Color = color_of(key)
		var left: float = group_w * float(i) + (group_w - cell.x * 2.0) * 0.5
		for j: int in n:
			var at: Vector2 = Vector2(left + cell.x * (float(j % 2) + 0.5),
					cell.y * (float(j / 2) + 0.5))
			_arrow(at, w, h, st > 0, col)


func _arrow(at: Vector2, w: float, h: float, up: bool, col: Color) -> void:
	var tip: float = -h * 0.5 if up else h * 0.5
	var pts: PackedVector2Array = PackedVector2Array([
		at + Vector2(0.0, tip),
		at + Vector2(w * 0.5, -tip),
		at + Vector2(-w * 0.5, -tip),
	])
	draw_colored_polygon(pts, col)
