# BanishFX
# Light and dark have no sprite and should not have one: they expel rather than
# burn, so they read as something happening TO the space a demon stands in.
#
# Light blooms — a core that flares and rings that spread off it.
# Dark collapses — a hole that opens, with everything around it falling in.
#
# Both are drawn, which is what lets them spread past the portrait they are
# parented to; a sprite would be clipped to its own box.
class_name BanishFX extends Control

const _LIFE: float = 0.66

var dark: bool = false
var arms: int = 6
var rings: int = 3

var _spokes: Array[float] = []

var t: float = 0.0:
	set(value):
		t = value
		queue_redraw()


static func handles(elem: String) -> bool:
	return elem == Affinity.LIGHT or elem == Affinity.DARK


# Same rungs as the elemental motes: a bigger cast opens a wider hole and
# throws more rings.
static func burst(over: Control, elem: String, rung: float = Spell.POWER_I) -> void:
	if over == null or not is_instance_valid(over) or not handles(elem):
		return
	var fx: BanishFX = BanishFX.new()
	fx.dark = (elem == Affinity.DARK)
	var step: int = 0
	if rung >= Spell.POWER_III:
		step = 2
	elif rung >= Spell.POWER_II:
		step = 1
	fx.rings = 2 + step
	fx.arms  = 6 + step * 4
	fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx._seed()
	over.add_child(fx)
	var tw: Tween = fx.create_tween()
	tw.tween_property(fx, "t", 1.0, _LIFE)
	tw.tween_callback(fx.queue_free)


func _seed() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	_spokes.clear()
	for i: int in range(arms):
		# Evenly spaced, then jittered, so it never reads as a clock face.
		_spokes.append(TAU * float(i) / float(arms) + rng.randf_range(-0.22, 0.22))


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var span: float = minf(size.x, size.y) * 1.06
	var mid: Vector2 = size * 0.5
	if dark:
		_draw_dark(mid, span)
	else:
		_draw_light(mid, span)


# A flare at the centre and rings leaving it. The rings are what "spread" is:
# they carry on past the edge of the portrait and fade as they go.
func _draw_light(mid: Vector2, span: float) -> void:
	var fade: float = 1.0 if t < 0.5 else 1.0 - (t - 0.5) / 0.5

	# Rays first, and short — they belong to the flare. An earlier build ran
	# them the full width and they crossed every ring, which turned the whole
	# thing into a wireframe globe instead of a light coming on.
	if t < 0.34:
		var ray_a: float = (1.0 - t / 0.34) * fade
		var reach: float = span * lerpf(0.13, 0.34, minf(t / 0.20, 1.0))
		for ang: float in _spokes:
			var dir: Vector2 = Vector2(cos(ang), sin(ang))
			draw_line(mid + dir * span * 0.06, mid + dir * reach,
					Color(1.0, 0.96, 0.82, ray_a * 0.65),
					maxf(1.0, span * 0.014), true)

	# Rings, thin and fading as they widen. Staggered wide enough apart that no
	# more than two are on screen together.
	for i: int in range(rings):
		var local: float = (t - float(i) * 0.17) / 0.52
		if local <= 0.0 or local >= 1.0:
			continue
		var out: float = 1.0 - pow(1.0 - local, 2.2)
		var r: float = span * lerpf(0.12, 0.80, out)
		var a: float = pow(1.0 - local, 1.6) * fade
		draw_arc(mid, r, 0.0, TAU, 44,
				Color(1.0, 0.95, 0.78, a * 0.7), maxf(1.2, span * 0.013), true)

	# The flare itself, over the top: stacked discs rather than one hard edge,
	# so it blooms instead of reading as a printed dot.
	var core: float = span * 0.17 * (1.0 - pow(1.0 - minf(t / 0.20, 1.0), 3.0))
	if t > 0.40:
		core *= maxf(0.0, 1.0 - (t - 0.40) / 0.60)
	if core > 0.5:
		draw_circle(mid, core * 3.0, Color(1.0, 0.90, 0.62, fade * 0.10))
		draw_circle(mid, core * 1.9, Color(1.0, 0.94, 0.72, fade * 0.20))
		draw_circle(mid, core * 1.2, Color(1.0, 0.98, 0.86, fade * 0.55))
		draw_circle(mid, core, Color(1.0, 1.0, 0.96, fade))


# A hole that opens, with the light around it drawn in. The streaks run inward,
# which is the whole difference between this and the flare above.
func _draw_dark(mid: Vector2, span: float) -> void:
	var fade: float = 1.0 if t < 0.62 else 1.0 - (t - 0.62) / 0.38

	# Opens fast, holds, then shuts — the collapse is the point.
	var open: float = 1.0 - pow(1.0 - minf(t / 0.30, 1.0), 3.0)
	var shut: float = 1.0 if t < 0.72 else maxf(0.0, 1.0 - (t - 0.72) / 0.28)
	# Kept small on purpose. At 0.30 of the span the disc covered the demon
	# outright and the fight lost the thing it was happening to.
	var r: float = span * 0.19 * open * shut

	# The infall. These are the spread: they reach out past the portrait and
	# close on the rim, so the pull is what reads rather than the hole.
	for ang: float in _spokes:
		var local: float = (t - 0.03) / 0.62
		if local <= 0.0 or local >= 1.0:
			continue
		var dir: Vector2 = Vector2(cos(ang), sin(ang))
		var far: float = span * lerpf(0.95, 0.26, 1.0 - pow(1.0 - local, 1.7))
		var near: float = maxf(r, far - span * 0.26 * (1.0 - local * 0.6))
		if far <= near:
			continue
		draw_line(mid + dir * far, mid + dir * near,
				Color(0.66, 0.36, 1.0, pow(1.0 - local, 1.3) * fade * 0.9),
				maxf(1.0, span * 0.016), true)

	if r > 0.5:
		# Rim first, then the hole over it, so the disc always cuts the ring.
		draw_arc(mid, r * 1.22, 0.0, TAU, 40,
				Color(0.58, 0.28, 1.0, fade * 0.8), maxf(1.5, span * 0.022), true)
		draw_circle(mid, r * 1.10, Color(0.18, 0.06, 0.34, fade * 0.5))
		draw_circle(mid, r, Color(0.01, 0.0, 0.03, fade))
