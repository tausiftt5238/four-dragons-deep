# StageArrows
# A combatant's buff and debuff stages as arrows instead of "ATK+2 AGL-1".
#
# Four fixed places, one per stat in STAT_KEYS order (ATK, MAG, DEF, AGL), each
# in that stat's colour. A raised stat stacks chevrons upward, a lowered one
# downward, one chevron per stage up to the cap. A stat at zero leaves its place
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
const HEIGHT: float = 26.0
# How far each chevron sits above the one under it, as a share of its height.
const STEP: float = 0.62

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
	var cap: int = CharacterSheet.BUFF_CAP
	var group_w: float = size.x / float(keys.size())
	# Stacked one on top of the next, like rank stripes: a full stack of four
	# fills the strip's height, and each chevron sits STEP of its own height
	# above the last so they read as separate marks rather than one shape.
	var line: float = maxf(2.0, size.y * 0.09)
	var ch_h: float = (size.y - line) / (1.0 + STEP * float(cap - 1))
	var ch_w: float = minf(group_w * 0.62, ch_h * 2.6)
	for i: int in keys.size():
		var key: String = keys[i]
		var st: int = member.stage(key)
		if st == 0:
			continue
		var up: bool = st > 0
		var n: int = mini(absi(st), cap)
		var col: Color = color_of(key)
		var cx: float = group_w * (float(i) + 0.5)
		# A buff builds up from the bottom and a debuff down from the top, so
		# the stack grows the way the stat went.
		for j: int in n:
			var off: float = ch_h * STEP * float(j)
			var top: float = size.y - line * 0.5 - ch_h - off if up else line * 0.5 + off
			_chevron(cx, top, ch_w, ch_h, up, col, line)


func _chevron(cx: float, top: float, w: float, h: float, up: bool,
		col: Color, width: float) -> void:
	var tip_y: float = top if up else top + h
	var foot_y: float = top + h if up else top
	draw_polyline(PackedVector2Array([
		Vector2(cx - w * 0.5, foot_y),
		Vector2(cx, tip_y),
		Vector2(cx + w * 0.5, foot_y),
	]), col, width, true)
