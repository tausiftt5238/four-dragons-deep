# SlashFX
# The cut drawn over a portrait when something connects with a swing rather
# than a spell. Two strokes sweep across and fade.
#
# Drawn rather than animated from frames for the same reason UIGlyph is drawn:
# it has to sit over a portrait of any size, on either side of the fight, and
# scale with a phone viewport. A stroke that draws itself can do that; a sprite
# sheet would need a size per slot.
class_name SlashFX extends Control

# The stroke snaps in and lingers as it fades — a symmetrical in-out reads as a
# wipe rather than a cut.
const _DRAW_TIME: float = 0.11
const _FADE_TIME: float = 0.24

# The sweep: top-right down to bottom-left, the way a swing falls.
const _FROM: Vector2 = Vector2(0.54, -0.54)
const _TO:   Vector2 = Vector2(-0.54, 0.54)

# Offsets of each stroke, as a fraction of the square the slash is drawn in.
# They run ALONG (1,1), which is perpendicular to the sweep — offset any other
# way and the two strokes slide down the same line and merge into one bar.
const _STROKES: Array[Vector2] = [Vector2(-0.05, -0.05), Vector2(0.12, 0.12)]

# How far behind the leading point the stroke trails while it is being drawn.
const _TAIL: float = 0.55

# Half-width of the white core at its belly, as a fraction of the square.
const _CORE_W: float = 0.018

var tint: Color = Color(1.0, 0.94, 0.82)

var t: float = 0.0:
	set(value):
		t = value
		queue_redraw()


# Cuts across `over` and cleans itself up. Safe to call on a portrait that is
# about to be rebuilt: the effect is a child, so it goes with it.
static func strike(over: Control, color: Color = Color(1.0, 0.94, 0.82)) -> void:
	if over == null or not is_instance_valid(over):
		return
	var fx: SlashFX = SlashFX.new()
	fx.tint = color
	fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	over.add_child(fx)
	var tw: Tween = fx.create_tween()
	tw.tween_property(fx, "t", 1.0, _DRAW_TIME + _FADE_TIME)
	tw.tween_callback(fx.queue_free)


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return

	var split: float = _DRAW_TIME / (_DRAW_TIME + _FADE_TIME)
	# Cubic ease-out on the way in: most of the length is laid down in the first
	# frames, which is what makes it land like a hit instead of a wipe.
	var grow: float = 1.0 - pow(1.0 - minf(t / split, 1.0), 3.0)
	var fade: float = 0.0 if t < split else (t - split) / (1.0 - split)
	var alpha: float = 1.0 - fade * fade
	if alpha <= 0.0:
		return

	# Kept to a centred square off the shorter side. A portrait is letterboxed
	# around its sprite, so a cut across the full rect would swing through empty
	# space beside a narrow demon.
	var span: float = minf(size.x, size.y) * 1.06
	var mid: Vector2 = size * 0.5

	for i: int in range(_STROKES.size()):
		var off: Vector2 = _STROKES[i]
		var from: Vector2 = mid + (_FROM + off) * span
		var to: Vector2   = mid + (_TO + off) * span
		var tip: Vector2  = from.lerp(to, grow)
		var tail: Vector2 = from.lerp(to, maxf(0.0, grow - _TAIL))
		var run: float = tip.distance_to(tail)
		if run < 1.0:
			continue
		# Tapered to a point at both ends rather than stroked: a line has square
		# caps at any width, and at slash thickness those read as a plank.
		var across: Vector2 = (tip - tail).orthogonal() / run
		var belly: Vector2 = tail.lerp(tip, 0.5)
		var w: float = maxf(1.0, span * _CORE_W) * (1.0 if i == 0 else 0.62)
		_blade(belly, tail, tip, across, w * 3.2,
				Color(tint.r, tint.g, tint.b, alpha * 0.33))
		_blade(belly, tail, tip, across, w, Color(1.0, 1.0, 1.0, alpha))


func _blade(belly: Vector2, tail: Vector2, tip: Vector2, across: Vector2,
		w: float, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
			tail, belly + across * w, tip, belly - across * w]), col)
