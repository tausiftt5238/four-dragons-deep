# StatusOverlay
# Draws a fighter's ailments over its battle portrait, so what is wrong with it
# reads at a glance without the status line:
#   Poison     purple bubbles rising off it
#   Blind      a pair of sunglasses
#   Silence    a speech bubble with "..." in it
#   Paralysis  yellow zig-zags crackling down both sides
# All drawn in code, no art: a stand-in until each gets its own sprite. Laid
# over the portrait at full size; reads the member's statuses every frame, so
# nothing has to tell it when one lands or lifts.
class_name StatusOverlay extends Control

const POISON_FILL:  Color = Color(0.62, 0.26, 0.86, 0.80)
const POISON_EDGE:  Color = Color(0.85, 0.62, 1.00, 0.95)
const SHADES:       Color = Color(0.06, 0.06, 0.08)
const SHADES_SHINE: Color = Color(0.55, 0.60, 0.70)
const BUBBLE_FILL:  Color = Color(0.97, 0.97, 0.95)
const BUBBLE_EDGE:  Color = Color(0.10, 0.10, 0.12)
const SPARK_GLOW:   Color = Color(1.00, 0.86, 0.20)
const SPARK_CORE:   Color = Color(1.00, 1.00, 0.85)

# Where the eyes sit, as a share of the portrait's height. Sprites differ, so
# this is a guess that suits most of them.
const EYE_LINE: float = 0.38

var member: CharacterSheet
var _time: float = 0.0


func _init(who: CharacterSheet) -> void:
	member = who
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	if member == null or not member.is_alive() or member.active_statuses.is_empty():
		return
	# Work in a square centred in the rect: the portrait keeps its aspect.
	var s: float = minf(size.x, size.y)
	var o: Vector2 = (size - Vector2(s, s)) / 2.0
	if member.has_status(Status.PARALYZED):
		_draw_sparks(o, s)
	if member.has_status(Status.POISON):
		_draw_bubbles(o, s)
	if member.has_status(Status.BLIND):
		_draw_shades(o, s)
	if member.has_status(Status.SILENCE):
		_draw_speech(o, s)


# Four bubbles on a loop, each swelling as it rises, wobbling side to side and
# thinning out near the top.
func _draw_bubbles(o: Vector2, s: float) -> void:
	for i: int in 4:
		var t: float = fmod(_time * 0.45 + float(i) * 0.25, 1.0)
		var x: float = s * (0.30 + 0.40 * fmod(float(i) * 0.618, 1.0)) \
				+ sin(t * 7.0 + float(i) * 2.0) * s * 0.05
		var y: float = s * (0.85 - 0.70 * t)
		var r: float = s * (0.035 + 0.035 * t)
		var a: float = 1.0 - smoothstep(0.65, 1.0, t)
		var c: Vector2 = o + Vector2(x, y)
		draw_circle(c, r, Color(POISON_FILL, POISON_FILL.a * a))
		draw_arc(c, r, 0.0, TAU, 16, Color(POISON_EDGE, POISON_EDGE.a * a), 1.5)
		draw_circle(c + Vector2(-r * 0.35, -r * 0.35), r * 0.25,
				Color(1.0, 1.0, 1.0, 0.8 * a))


# Two dark lenses on a bridge, with arms out to the sides and a glint that
# slides across now and then.
func _draw_shades(o: Vector2, s: float) -> void:
	var cy: float = o.y + s * EYE_LINE
	var cx: float = o.x + s * 0.5
	var lw: float = s * 0.17
	var lh: float = s * 0.10
	var gap: float = s * 0.05
	var left: Rect2 = Rect2(cx - gap / 2.0 - lw, cy - lh / 2.0, lw, lh)
	var right: Rect2 = Rect2(cx + gap / 2.0, cy - lh / 2.0, lw, lh)
	var thick: float = maxf(2.0, s * 0.02)
	# Arms first, so the lenses sit over their ends.
	draw_line(Vector2(left.position.x - s * 0.05, cy - lh * 0.3),
			Vector2(left.position.x, cy - lh * 0.3), SHADES, thick)
	draw_line(Vector2(right.end.x, cy - lh * 0.3),
			Vector2(right.end.x + s * 0.05, cy - lh * 0.3), SHADES, thick)
	draw_line(Vector2(left.end.x, cy - lh * 0.25), Vector2(right.position.x, cy - lh * 0.25),
			SHADES, thick)
	for lens: Rect2 in [left, right]:
		draw_rect(lens, SHADES)
		# A flatter bottom edge reads more like lenses than two boxes.
		draw_rect(Rect2(lens.position.x + lw * 0.15, lens.end.y, lw * 0.7, lh * 0.25), SHADES)
	# Glint: a short diagonal that crosses both lenses every couple of seconds.
	var g: float = fmod(_time * 0.5, 1.0)
	if g < 0.35:
		for lens: Rect2 in [left, right]:
			var gx: float = lens.position.x + lens.size.x * (g / 0.35)
			draw_line(Vector2(gx, lens.position.y + 1.0),
					Vector2(gx - lh * 0.6, lens.end.y - 1.0), SHADES_SHINE, maxf(1.5, s * 0.012))


# A speech bubble off the top corner, its tail pointing back at the fighter,
# bobbing gently, with three dots that appear one after another.
func _draw_speech(o: Vector2, s: float) -> void:
	var bw: float = s * 0.38
	var bh: float = s * 0.22
	var bob: float = sin(_time * 2.4) * s * 0.012
	var box: Rect2 = Rect2(o.x + s - bw - s * 0.02, o.y + s * 0.03 + bob, bw, bh)
	var edge: float = maxf(1.5, s * 0.015)
	var tail: PackedVector2Array = [
		Vector2(box.position.x + bw * 0.22, box.end.y - 1.0),
		Vector2(box.position.x + bw * 0.42, box.end.y - 1.0),
		Vector2(box.position.x + bw * 0.08, box.end.y + bh * 0.42),
	]
	draw_colored_polygon(tail, BUBBLE_FILL)
	draw_polyline(PackedVector2Array([tail[1], tail[2], tail[0]]), BUBBLE_EDGE, edge)
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = BUBBLE_FILL
	sb.border_color = BUBBLE_EDGE
	sb.set_border_width_all(int(edge))
	sb.set_corner_radius_all(int(bh * 0.45))
	draw_style_box(sb, box)
	# Cover the seam where the tail meets the bubble.
	draw_line(tail[0] + Vector2(edge, -edge), tail[1] + Vector2(-edge, -edge), BUBBLE_FILL, edge * 1.6)
	var shown: int = 1 + int(fmod(_time * 2.0, 4.0))
	for i: int in mini(shown, 3):
		var dx: float = box.position.x + bw * (0.28 + 0.22 * float(i))
		draw_circle(Vector2(dx, box.position.y + bh * 0.52), s * 0.022, BUBBLE_EDGE)


# A jagged bolt down each side, re-drawn with a new shape a few times a second
# and dimming every third beat, so it crackles rather than sits there. Dims
# rather than vanishes: a frame caught on the off beat still shows it.
func _draw_sparks(o: Vector2, s: float) -> void:
	var beat: int = int(_time * 9.0)
	var a: float = 0.35 if beat % 3 == 0 else 1.0
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = beat
	for side: int in 2:
		var x0: float = o.x + (s * 0.10 if side == 0 else s * 0.90)
		var pts: PackedVector2Array = []
		var steps: int = 6
		for k: int in steps + 1:
			var y: float = o.y + s * (0.18 + 0.64 * float(k) / float(steps))
			var swing: float = s * rng.randf_range(0.03, 0.07)
			var dir: float = 1.0 if k % 2 == 0 else -1.0
			pts.append(Vector2(x0 + dir * swing, y))
		draw_polyline(pts, Color(SPARK_GLOW, a), maxf(3.0, s * 0.03))
		draw_polyline(pts, Color(SPARK_CORE, a), maxf(1.0, s * 0.01))
