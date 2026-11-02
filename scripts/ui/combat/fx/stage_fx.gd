# StageFX
# A buff or a debuff landing on someone: rings in the stat's own colour (the
# StageArrows colours — ATK orange, MAG violet, DEF blue, AGL green) climbing
# up the figure when the stat rises, sinking down it when it falls.
#
# Drawn, like SlashFX, so it sits over a portrait of any size on either side of
# the fight. The rings are flat ellipses seen from a little above, so they read
# as going round the figure; the back half is dimmer than the front, which is
# all the depth an overlay can give them.
class_name StageFX extends Control

# Three rings, one after another.
const _RINGS: int = 3
const _GAP: float = 0.16
const _RUN: float = 0.62
const _LIFE: float = _RUN + _GAP * float(_RINGS - 1)

# Ring width against the shorter side, how flat it is, and where it travels
# between (fractions of the height, top to bottom).
const _WIDTH: float = 0.78
const _FLAT: float = 0.30
const _LOW: float = 0.86
const _HIGH: float = 0.14

var tint: Color = Color.WHITE
var rising: bool = true

var t: float = 0.0:
	set(value):
		t = value
		queue_redraw()


# Rings over `over` in `stat`'s colour, up for a rise and down for a fall.
# Safe on a portrait about to be rebuilt: the effect is a child, so it goes too.
static func play(over: Control, stat: String, delta: int) -> void:
	if over == null or not is_instance_valid(over) or delta == 0:
		return
	var fx: StageFX = StageFX.new()
	fx.tint = StageArrows.color_of(stat)
	fx.rising = delta > 0
	fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	over.add_child(fx)
	var tw: Tween = fx.create_tween()
	tw.tween_property(fx, "t", _LIFE, _LIFE)
	tw.tween_callback(fx.queue_free)


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var w: float = minf(size.x, size.y) * _WIDTH
	var rx: float = w * 0.5
	var ry: float = rx * _FLAT
	var line: float = maxf(1.5, w * 0.035)
	for i: int in _RINGS:
		var p: float = (t - _GAP * float(i)) / _RUN
		if p <= 0.0 or p >= 1.0:
			continue
		# Eased so it leaves quickly and settles; in and out over the first and
		# last fifth of its run.
		var e: float = 1.0 - pow(1.0 - p, 2.0)
		var y: float = lerpf(_LOW, _HIGH, e) if rising else lerpf(_HIGH, _LOW, e)
		var a: float = minf(1.0, minf(p, 1.0 - p) * 5.0)
		var c: Vector2 = Vector2(size.x * 0.5, size.y * y)
		_ring(c, rx, ry, line, a)


func _ring(c: Vector2, rx: float, ry: float, line: float, a: float) -> void:
	var back: PackedVector2Array = PackedVector2Array()
	var front: PackedVector2Array = PackedVector2Array()
	for k: int in 25:
		var ang: float = PI + PI * float(k) / 24.0
		back.append(c + Vector2(cos(ang) * rx, sin(ang) * ry))
		front.append(c + Vector2(cos(ang - PI) * rx, sin(ang - PI) * ry))
	var col: Color = Color(tint.r, tint.g, tint.b, a)
	# A soft glow under each half, then the line itself.
	draw_polyline(back, Color(col, a * 0.18), line * 3.0, true)
	draw_polyline(back, Color(col, a * 0.45), line, true)
	draw_polyline(front, Color(col, a * 0.30), line * 3.0, true)
	draw_polyline(front, Color(col.lerp(Color.WHITE, 0.35), a), line, true)
