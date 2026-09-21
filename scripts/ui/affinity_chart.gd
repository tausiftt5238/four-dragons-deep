# AffinityChart
# The five-slot chart that appears under a demon once it has been Analyzed.
# One box per element, left to right: fire, ice, thunder, light, dark. Phys is
# not here — it is the one thing every swing is, so a column for it would be
# noise on every demon in the game.
#
# A slot carries the element's icon and, when the demon is not simply normal to
# it, the letter for what it does with it:
#   W weak     S strong (resists)     N nothing (nulls)
#   R reflects (repels)               D drains
#
# Drawn rather than built from Labels: five slots x four foes is twenty nodes
# rebuilt every time anything on the field changes, and the icons have to line
# up with the letters whatever width the column ends up.
class_name AffinityChart extends Control

const FONT: FontFile = preload("res://resources/misc/OldSchoolAdventures-42j9.ttf")

# Left to right, as the user asked for them.
const SLOTS: Array[String] = ["fire", "ice", "thunder", "light", "dark"]

const SPRITES: Dictionary = {
	"fire":    "res://resources/spellFX/fire.png",
	"ice":     "res://resources/spellFX/ice.png",
	"thunder": "res://resources/spellFX/thunder.png",
}

# Tall enough to stack the icon over the letter. They were overlaid at first
# and the icon lost: you could see the demon was weak to SOMETHING without
# being able to tell to what, which is the only thing the chart is for.
const ROW_HEIGHT: float = 34.0

var foe: Enemy = null

static var _tex: Dictionary = {}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	custom_minimum_size = Vector2(0, ROW_HEIGHT)


# One letter for what the demon does with that line. Empty means it just takes
# it, and the slot stays quiet.
static func mark_for(state: String) -> String:
	match state:
		Affinity.WEAK:   return "W"
		Affinity.RESIST: return "S"
		Affinity.NULL:   return "N"
		Affinity.REPEL:  return "R"
		Affinity.DRAIN:  return "D"
	return ""


static func _icon(element: String) -> Texture2D:
	if not SPRITES.has(element):
		return null
	if not _tex.has(element):
		_tex[element] = load(SPRITES[element]) as Texture2D
	return _tex[element] as Texture2D


func _draw() -> void:
	if foe == null or size.x <= 0.0:
		return
	var slot_w: float = size.x / float(SLOTS.size())
	var pad: float = clampf(slot_w * 0.08, 1.0, 3.0)
	var box_w: float = slot_w - pad * 2.0
	var box_h: float = minf(size.y, ROW_HEIGHT) - 2.0

	for i: int in range(SLOTS.size()):
		var element: String = SLOTS[i]
		var state: String = foe.affinity_of(element)
		var mark: String = mark_for(state)
		var at: Rect2 = Rect2(float(i) * slot_w + pad, 1.0, box_w, box_h)
		_draw_slot(at, element, state, mark)


func _draw_slot(at: Rect2, element: String, state: String, mark: String) -> void:
	var lit: bool = mark != ""
	var tint: Color = Affinity.color(state) if lit else Color(0.42, 0.46, 0.54)

	draw_rect(at, Color(0.06, 0.07, 0.10, 0.85), true)
	draw_rect(at, Color(tint.r, tint.g, tint.b, 0.95 if lit else 0.40), false, 1.0)

	# A lit slot gives its lower strip to the letter; a quiet one is all icon.
	var strip: float = at.size.y * 0.36 if lit else 0.0
	var top: Rect2 = Rect2(at.position, Vector2(at.size.x, at.size.y - strip))
	var mid: Vector2 = top.position + top.size * 0.5
	var side: float = minf(top.size.x, top.size.y) * 0.88

	var tex: Texture2D = _icon(element)
	if tex != null:
		draw_texture_rect(tex,
				Rect2(mid.x - side * 0.5, mid.y - side * 0.5, side, side),
				false, Color(1.0, 1.0, 1.0, 0.95))
	elif element == "light":
		_draw_light(mid, side * 0.5, 0.95)
	else:
		_draw_dark(mid, side * 0.5, 0.95)

	if not lit:
		return
	# The strip carries the state's colour behind the letter, so the row can be
	# read down its bottom edge without picking out glyphs at all.
	var bar: Rect2 = Rect2(at.position.x, at.position.y + at.size.y - strip,
			at.size.x, strip)
	draw_rect(bar, Color(tint.r, tint.g, tint.b, 0.22), true)

	var fs: int = int(clampf(strip * 1.05, 8.0, 15.0))
	var w: float = FONT.get_string_size(mark, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs).x
	var base: Vector2 = Vector2(bar.position.x + (bar.size.x - w) * 0.5,
			bar.position.y + bar.size.y - maxf(1.0, strip * 0.18))
	draw_string(FONT, base, mark, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs, tint)


# No sprite for either of these, and they should not borrow one: light and dark
# expel rather than burn. A struck flare and a hole with a rim.
func _draw_light(mid: Vector2, r: float, a: float) -> void:
	var col: Color = Color(1.0, 0.94, 0.62, a)
	for i: int in range(8):
		var ang: float = TAU * float(i) / 8.0
		var dir: Vector2 = Vector2(cos(ang), sin(ang))
		draw_line(mid + dir * r * 0.45, mid + dir * r, col, maxf(1.0, r * 0.16), true)
	draw_circle(mid, r * 0.38, Color(1.0, 0.99, 0.88, a))


func _draw_dark(mid: Vector2, r: float, a: float) -> void:
	draw_arc(mid, r * 0.86, 0.0, TAU, 20, Color(0.62, 0.34, 1.0, a),
			maxf(1.0, r * 0.20), true)
	draw_circle(mid, r * 0.60, Color(0.05, 0.02, 0.10, a))
