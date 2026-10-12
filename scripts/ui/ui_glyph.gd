# UIGlyph
# The small shapes the UI needs, drawn rather than typed.
#
# Every Label in the game is forced onto OldSchoolAdventures by Main's
# node_added hook, and that font carries no geometric glyphs: the press-turn
# pips (U+25CF, U+25D0) and both target markers (U+25B2, U+25BC) all came out
# as tofu boxes on the phone. Drawing them costs a _draw() and can never be
# missing from a font.
class_name UIGlyph extends Control

enum Shape { PIPS, CARET_DOWN, CARET_UP, CARET_RIGHT }

const PIP_R:    float = 4.0
const PIP_STEP: float = 12.0
const CARET_W:  float = 11.0
const CARET_H:  float = 7.0

# Press-turn icons are Ghostfire's head, cut from its
# Flying strip and played like a portrait: the whole flaming skull while the
# icon is in hand, the bare skull once it is half spent — every flame pixel
# gone, the ones licking round the skull too (_bare_skulls). The
# party's burn blue (the Abyss's ice recolour), the foes' their own red.
const GHOST_SHEET: String = "res://resources/characterSprites/Ghostfire/Ghostfire_Flying.png"
const GHOST_FRAMES: int = 6
const GHOST_FRAME_W: int = 100
const GHOST_FPS: float = AnimatedPortrait.DEFAULT_FPS
# Within a frame: the rows drawn. GHOST_BASE is the row under the skull at
# rest, which sits on the glyph's baseline. The two tallest frames throw a
# wisp a few rows higher; it is cut, or the foes' flames lick into the party's
# skulls on the phone, where the two rows sit 1px apart.
const GHOST_FULL:  Rect2i = Rect2i(46, 30, 13, 23)
const GHOST_SKULL: Rect2i = Rect2i(46, 40, 13, 13)
const GHOST_BASE:  int = 52
const GHOST_H:     float = 22.0
const GHOST_STEP:  float = 15.0

var shape: Shape = Shape.PIPS
var tint: Color = Color(1.0, 0.92, 0.45)

# PIPS only: icons still in hand, then the half-spent ones.
var full:  int = 0
var spent: int = 0
var ghost: Texture2D = null   # set by ghost_pips(): heads instead of dots
var skulls: Array[Texture2D] = []   # each frame's head with its flames taken off
var _frame: int = 0
var _clock: float = 0.0

static var _skull_cache: Array[Texture2D] = []


static func pips(color: Color) -> UIGlyph:
	var g: UIGlyph = UIGlyph.new()
	g.shape = Shape.PIPS
	g.tint = color
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	g.custom_minimum_size = Vector2(PIP_STEP * 4.0, PIP_R * 2.0 + 4.0)
	return g


static func ghost_pips(blue: bool) -> UIGlyph:
	var g: UIGlyph = pips(Color(0.55, 0.95, 1.0) if blue else Color(1.0, 0.45, 0.45))
	if blue:
		g.material = Abyss.palette_material("ice", "Ghostfire")
	g.ghost = load(GHOST_SHEET) as Texture2D
	g.skulls = _bare_skulls(g.ghost)
	g.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	g.custom_minimum_size = Vector2(GHOST_STEP * 4.0, GHOST_H)
	return g


# The flames are the sprite's bright reds and oranges; the skull is greys and
# a near-black red, so anything both saturated and bright is cleared.
static func _bare_skulls(sheet: Texture2D) -> Array[Texture2D]:
	if _skull_cache.is_empty():
		var strip: Image = sheet.get_image()
		strip.decompress()
		strip.convert(Image.FORMAT_RGBA8)
		for f: int in GHOST_FRAMES:
			var img: Image = strip.get_region(
					Rect2i(GHOST_SKULL.position + Vector2i(f * GHOST_FRAME_W, 0), GHOST_SKULL.size))
			for y: int in img.get_height():
				for x: int in img.get_width():
					var c: Color = img.get_pixel(x, y)
					if c.s > 0.5 and c.v > 0.4:
						img.set_pixel(x, y, Color(0, 0, 0, 0))
			_skull_cache.append(ImageTexture.create_from_image(img))
	return _skull_cache


static func caret(down: bool, color: Color) -> UIGlyph:
	var g: UIGlyph = UIGlyph.new()
	g.shape = Shape.CARET_DOWN if down else Shape.CARET_UP
	g.tint = color
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.custom_minimum_size = Vector2(0, CARET_H + 4.0)
	return g


# The same triangle turned on its side, for pointing at a name in a list.
static func caret_right(color: Color) -> UIGlyph:
	var g: UIGlyph = UIGlyph.new()
	g.shape = Shape.CARET_RIGHT
	g.tint = color
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.custom_minimum_size = Vector2(CARET_H + 4.0, CARET_W)
	return g


func set_pips(in_hand: int, half: int) -> void:
	if in_hand == full and half == spent:
		return
	full = in_hand
	spent = half
	queue_redraw()


func _process(delta: float) -> void:
	if ghost == null or not is_visible_in_tree() or full + spent <= 0:
		return
	_clock += delta
	if _clock >= 1.0 / GHOST_FPS:
		_clock = fmod(_clock, 1.0 / GHOST_FPS)
		_frame = (_frame + 1) % GHOST_FRAMES
		queue_redraw()


func _draw() -> void:
	match shape:
		Shape.PIPS:    _draw_pips()
		Shape.CARET_DOWN: _draw_caret(true)
		Shape.CARET_UP:   _draw_caret(false)
		Shape.CARET_RIGHT: _draw_caret_right()


func _draw_pips() -> void:
	var y: float = size.y * 0.5
	# Nothing left to spend reads as a dash, which is also drawn — the em dash
	# this replaced was one of the few shapes the font did have, and relying on
	# that was luck rather than design.
	if full <= 0 and spent <= 0:
		draw_line(Vector2(1.0, y), Vector2(PIP_R * 2.0 + 1.0, y),
				Color(tint, 0.55), 1.5)
		return
	if ghost != null:
		_draw_ghosts()
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


# Each head stands on the same baseline, so a bare skull sits where the skull
# of a full one would, and all of them bob together.
func _draw_ghosts() -> void:
	var base: float = floorf((size.y + GHOST_H) * 0.5)
	var shift: Vector2i = Vector2i(_frame * GHOST_FRAME_W, 0)
	var x: float = 0.0
	for i: int in full + spent:
		if i < full:
			var src: Rect2 = Rect2(GHOST_FULL.position + shift, GHOST_FULL.size)
			draw_texture_rect_region(ghost, Rect2(Vector2(x, base - (GHOST_BASE - GHOST_FULL.position.y)),
					src.size), src)
		else:
			draw_texture(skulls[_frame], Vector2(x, base - (GHOST_BASE - GHOST_SKULL.position.y)))
		x += GHOST_STEP


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


func _draw_caret_right() -> void:
	var left: float = (size.x - CARET_H) * 0.5
	var cy: float = size.y * 0.5
	draw_colored_polygon(PackedVector2Array([
		Vector2(left, cy - CARET_W * 0.5),
		Vector2(left + CARET_H, cy),
		Vector2(left, cy + CARET_W * 0.5),
	]), tint)
