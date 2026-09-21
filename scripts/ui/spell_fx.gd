# SpellFX
# The motes thrown over a portrait when a spell lands on it: the element's own
# 16x16 sprite, several of them, popping in and drifting off.
#
# How many is the RUNG, not the reach. A wide cast already shows its width by
# bursting on every portrait it touches, so counting the reach twice would make
# Pyre on a lone demon look identical to Ember.
class_name SpellFX extends Control

const SPRITES: Dictionary = {
	"fire":    "res://resources/spellFX/fire.png",
	"ice":     "res://resources/spellFX/ice.png",
	"thunder": "res://resources/spellFX/thunder.png",
}

const _LIFE: float = 0.62

# Fraction of the run each mote spends alive. The rest is its stagger, so the
# burst arrives as a scatter rather than all at once.
const _MOTE_LIFE: float = 0.58

var element: String = "fire"
var motes: Array[Dictionary] = []

var _tex: Texture2D = null

var t: float = 0.0:
	set(value):
		t = value
		queue_redraw()


# Light and dark have no sprite and are not meant to: they expel rather than
# burn, and the fight already says so in its own colour.
static func has_art(elem: String) -> bool:
	return SPRITES.has(elem)


# Rung I throws three, II five, III eight.
static func count_for(rung: float) -> int:
	if rung >= Spell.POWER_III:
		return 8
	if rung >= Spell.POWER_II:
		return 5
	return 3


# The one entry point combat calls. Fire, ice and thunder have sprites; light
# and dark are drawn by BanishFX and phys is the slash, so neither lands here.
static func cast(over: Control, elem: String, rung: float = Spell.POWER_I) -> void:
	if BanishFX.handles(elem):
		BanishFX.burst(over, elem, rung)
		return
	burst(over, elem, rung)


static func burst(over: Control, elem: String, rung: float = Spell.POWER_I) -> void:
	if over == null or not is_instance_valid(over) or not has_art(elem):
		return
	var fx: SpellFX = SpellFX.new()
	fx.element = elem
	fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fx._seed(count_for(rung))
	over.add_child(fx)
	var tw: Tween = fx.create_tween()
	tw.tween_property(fx, "t", 1.0, _LIFE)
	tw.tween_callback(fx.queue_free)


# Scattered once, up front. Rolling in _draw would reshuffle the burst on every
# frame and it would boil rather than drift.
func _seed(count: int) -> void:
	_tex = load(SPRITES[element]) as Texture2D
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	motes.clear()
	for i: int in range(count):
		motes.append({
			at    = Vector2(rng.randf_range(-0.34, 0.34), rng.randf_range(-0.38, 0.38)),
			drift = Vector2(rng.randf_range(-0.12, 0.12), rng.randf_range(-0.30, -0.10)),
			spin  = rng.randf_range(-0.5, 0.5),
			lean  = rng.randf_range(-0.35, 0.35),
			# Spread over whatever is left of the run once a mote's own life is
			# taken out, so the last one still finishes inside the tween.
			delay = (float(i) / maxf(1.0, float(count))) * (1.0 - _MOTE_LIFE),
			size  = rng.randf_range(0.82, 1.18),
		})


func _draw() -> void:
	if _tex == null or size.x <= 0.0 or size.y <= 0.0:
		return
	var span: float = minf(size.x, size.y) * 1.06
	var mid: Vector2 = size * 0.5
	# Shrinks a little as the count climbs, so eight motes read as a storm
	# rather than as one solid block of sprite.
	var box: float = span * 0.34 * (1.0 - 0.022 * float(motes.size()))

	for m: Dictionary in motes:
		var local: float = (t - float(m["delay"])) / _MOTE_LIFE
		if local <= 0.0 or local >= 1.0:
			continue
		# Overshoots on the way in and settles: a mote that simply fades up
		# reads as a decal laid on the portrait rather than as an impact.
		var grow: float = 1.0
		if local < 0.25:
			grow = (local / 0.25) * 1.25
		elif local < 0.40:
			grow = 1.25 - ((local - 0.25) / 0.15) * 0.25
		var alpha: float = 1.0 if local < 0.55 else 1.0 - (local - 0.55) / 0.45

		var at: Vector2 = mid + (Vector2(m["at"]) + Vector2(m["drift"]) * local) * span
		var side: float = box * float(m["size"]) * grow * 0.5
		draw_set_transform(at, float(m["lean"]) + float(m["spin"]) * local,
				Vector2.ONE)
		draw_texture_rect(_tex, Rect2(-side, -side, side * 2.0, side * 2.0),
				false, Color(1.0, 1.0, 1.0, alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
