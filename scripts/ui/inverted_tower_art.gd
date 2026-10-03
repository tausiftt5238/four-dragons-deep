# InvertedTowerArt
# The Inverted Tower as the intro shows it: a spire hanging down from the
# ground into the dark, drawn in edges like the dungeon itself, each band of
# floors in the colour its walls will be. Faint embers drift up out of the
# broken seal at the top: what has been getting out.
class_name InvertedTowerArt extends Control

const BANDS: int = 5
const FLOORS_PER_BAND: int = 2
const EMBERS: int = 18

var _embers: Array[Dictionary] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i: int in EMBERS:
		_embers.append(_new_ember(randf()))


func _new_ember(age: float) -> Dictionary:
	return {x = randf_range(-0.12, 0.12), age = age, speed = randf_range(0.12, 0.25),
			size = randf_range(1.5, 3.0), drift = randf_range(-0.05, 0.05)}


func _process(delta: float) -> void:
	for e: Dictionary in _embers:
		e["age"] = float(e["age"]) + delta * float(e["speed"])
		if float(e["age"]) >= 1.0:
			e.merge(_new_ember(0.0), true)
	queue_redraw()


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	var cx: float = w / 2.0
	var ground: float = h * 0.22
	var top_half: float = w * 0.26
	var floor_h: float = (h - ground - 8.0) / float(BANDS * FLOORS_PER_BAND)

	# The surface: a line of earth the tower hangs from.
	draw_line(Vector2(w * 0.04, ground), Vector2(w * 0.96, ground),
			Color(0.35, 0.30, 0.40), 2.0)

	# Floors, each a little narrower than the one above, banded by colour.
	var n: int = BANDS * FLOORS_PER_BAND
	for i: int in n:
		var band: int = i / FLOORS_PER_BAND
		var col: Color = Level.TIER_WIRE[band]
		var y0: float = ground + i * floor_h
		var y1: float = y0 + floor_h
		var hw0: float = top_half * (1.0 - float(i) / float(n + 1))
		var hw1: float = top_half * (1.0 - float(i + 1) / float(n + 1))
		var quad: PackedVector2Array = [Vector2(cx - hw0, y0), Vector2(cx + hw0, y0),
				Vector2(cx + hw1, y1), Vector2(cx - hw1, y1)]
		draw_colored_polygon(quad, Color(col.r * 0.10, col.g * 0.10, col.b * 0.13))
		quad.append(quad[0])
		draw_polyline(quad, Color(col, 0.85), 1.5)
		# A slit of a window on each floor.
		var wy: float = (y0 + y1) / 2.0
		draw_line(Vector2(cx - 3.0, wy), Vector2(cx + 3.0, wy), Color(col, 0.5), 2.0)

	# The broken seal: a dome over the mouth, cracked open at the crown.
	var seal: Vector2 = Vector2(cx, ground)
	var seal_col: Color = Color(0.75, 0.55, 1.0, 0.8)
	draw_arc(seal, top_half * 0.55, PI * 1.0, PI * 1.42, 16, seal_col, 2.0)
	draw_arc(seal, top_half * 0.55, PI * 1.58, PI * 2.0, 16, seal_col, 2.0)

	# What is getting out.
	for e: Dictionary in _embers:
		var age: float = float(e["age"])
		var x: float = cx + (float(e["x"]) + float(e["drift"]) * age) * w
		var y: float = ground - age * ground * 0.95
		var a: float = sin(age * PI) * 0.8
		draw_circle(Vector2(x, y), float(e["size"]), Color(1.0, 0.45, 0.25, a))
