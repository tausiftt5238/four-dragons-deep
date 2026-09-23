# KeyIcon
# The HUD's "you are carrying the key" marker: a key drawn in the violet the map
# already uses for it, on a dark tile. Drawn rather than a sprite because there
# is no key art, and a glyph in the same colour as the map's diamond reads as
# the same object.
class_name KeyIcon extends Control

const C_KEY:  Color = Color(0.78, 0.58, 1.00, 1.00)
const C_BACK: Color = Color(0.04, 0.03, 0.08, 0.72)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(48, 48)


func _draw() -> void:
	var s: float = minf(size.x, size.y)
	var box: Rect2 = Rect2((size - Vector2(s, s)) * 0.5, Vector2(s, s))
	draw_rect(box, C_BACK, true)
	draw_rect(box, Color(C_KEY.r, C_KEY.g, C_KEY.b, 0.8), false, 2.0)

	# Bow on the left, shaft to the right, two teeth hanging off its end.
	var w: float = maxf(2.0, s * 0.09)
	var mid_y: float = box.position.y + s * 0.5
	var bow: Vector2 = Vector2(box.position.x + s * 0.30, mid_y)
	var r: float = s * 0.14
	draw_arc(bow, r, 0.0, TAU, 24, C_KEY, w, true)
	var shaft_start: float = bow.x + r
	var shaft_end: float = box.position.x + s * 0.82
	draw_line(Vector2(shaft_start, mid_y), Vector2(shaft_end, mid_y), C_KEY, w, true)
	for at: float in [0.0, s * 0.13]:
		var x: float = shaft_end - at - w * 0.5
		draw_line(Vector2(x, mid_y), Vector2(x, mid_y + s * 0.14), C_KEY, w, true)
