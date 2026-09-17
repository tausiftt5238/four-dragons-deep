# UIGlyph
# The small shapes the UI needs, drawn rather than typed.
#
# Every Label in the game is forced onto OldSchoolAdventures by Main's
# node_added hook, and that font carries no geometric glyphs: the press-turn
# pips (U+25CF, U+25D0) and both target markers (U+25B2, U+25BC) all came out
# as tofu boxes on the phone. Drawing them costs a _draw() and can never be
# missing from a font.
class_name UIGlyph extends Control

enum Shape { PIPS, CARET_DOWN, CARET_UP }

const PIP_R:    float = 4.0
const PIP_STEP: float = 12.0
const CARET_W:  float = 11.0
const CARET_H:  float = 7.0

var shape: Shape = Shape.PIPS
var tint: Color = Color(1.0, 0.92, 0.45)

# PIPS only: icons still in hand, then the half-spent ones.
var full:  int = 0
var spent: int = 0


static func pips(color: Color) -> UIGlyph:
	var g: UIGlyph = UIGlyph.new()
	g.shape = Shape.PIPS
	g.tint = color
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	g.custom_minimum_size = Vector2(PIP_STEP * 4.0, PIP_R * 2.0 + 4.0)
	return g


static func caret(down: bool, color: Color) -> UIGlyph:
	var g: UIGlyph = UIGlyph.new()
	g.shape = Shape.CARET_DOWN if down else Shape.CARET_UP
	g.tint = color
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.custom_minimum_size = Vector2(0, CARET_H + 4.0)
	return g


func set_pips(in_hand: int, half: int) -> void:
	if in_hand == full and half == spent:
		return
	full = in_hand
	spent = half
	queue_redraw()


func _draw() -> void:
	match shape:
		Shape.PIPS:    _draw_pips()
		Shape.CARET_DOWN: _draw_caret(true)
		Shape.CARET_UP:   _draw_caret(false)


func _draw_pips() -> void:
	var y: float = size.y * 0.5
	# Nothing left to spend reads as a dash, which is also drawn — the em dash
	# this replaced was one of the few shapes the font did have, and relying on
	# that was luck rather than design.
	if full <= 0 and spent <= 0:
		draw_line(Vector2(1.0, y), Vector2(PIP_R * 2.0 + 1.0, y),
				Color(tint, 0.55), 1.5)
		return
	var x: float = PIP_R + 1.0
	for i: int in full:
		draw_circle(Vector2(x, y), PIP_R, tint)
		x += PIP_STEP
	for i: int in spent:
		# A blinking icon: the ring is still there, only half of it is filled.
		var c: Vector2 = Vector2(x, y)
		draw_arc(c, PIP_R, 0.0, TAU, 16, tint, 1.0)
		var half: PackedVector2Array = PackedVector2Array()
		half.append(c)
		for step: int in range(9):
			var a: float = PI * 0.5 + PI * float(step) / 8.0
			half.append(c + Vector2(cos(a), sin(a)) * PIP_R)
		draw_colored_polygon(half, tint)
		x += PIP_STEP


func _draw_caret(down: bool) -> void:
	var cx: float = size.x * 0.5
	var top: float = (size.y - CARET_H) * 0.5
	var pts: PackedVector2Array = PackedVector2Array()
	if down:
		pts.append(Vector2(cx - CARET_W * 0.5, top))
		pts.append(Vector2(cx + CARET_W * 0.5, top))
		pts.append(Vector2(cx, top + CARET_H))
	else:
		pts.append(Vector2(cx, top))
		pts.append(Vector2(cx + CARET_W * 0.5, top + CARET_H))
		pts.append(Vector2(cx - CARET_W * 0.5, top + CARET_H))
	draw_colored_polygon(pts, tint)
