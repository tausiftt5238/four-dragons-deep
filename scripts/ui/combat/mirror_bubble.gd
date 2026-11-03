# MirrorBubble
# An Attack Mirror or a Magic Mirror held up, drawn as a glass bubble round the
# fighter: gold for an Attack Mirror, violet for a Magic Mirror (the colour the
# log writes a mirror in).
#
# Two layers make the figure sit inside it: a disc behind the portrait, and the
# bubble's skin over it (a faint wash, a brighter band at the rim, a glint up
# on the left). attach() lays both on a portrait. Each reads the member's mirror
# every frame and redraws only when it changes, so nothing has to tell it when
# one goes up or breaks.
class_name MirrorBubble extends Control

const PHYS_TINT:  Color = Color(1.00, 0.82, 0.40)
const MAGIC_TINT: Color = Color(0.82, 0.44, 1.00)
const GLINT:      Color = Color(1.0, 1.0, 1.0)

var member: CharacterSheet
var front: bool = false
var _shown: String = ""


func _init(who: CharacterSheet, over: bool) -> void:
	member = who
	front = over
	# The disc goes under the portrait's own texture, the skin over it.
	show_behind_parent = not over
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


# Both layers on `portrait`, for `who`.
static func attach(portrait: Control, who: CharacterSheet) -> void:
	portrait.add_child(MirrorBubble.new(who, false))
	portrait.add_child(MirrorBubble.new(who, true))


func _process(_delta: float) -> void:
	if member.mirror != _shown:
		_shown = member.mirror
		queue_redraw()


func _draw() -> void:
	if _shown == "" or size.x <= 0.0:
		return
	var tint: Color = PHYS_TINT if _shown == "phys" else MAGIC_TINT
	var c: Vector2 = size / 2.0
	var r: float = minf(size.x, size.y) * 0.5
	if not front:
		draw_circle(c, r, Color(tint, 0.22))
		return
	# The skin: a light wash over the figure, thicker towards the rim.
	draw_circle(c, r, Color(tint, 0.16))
	draw_arc(c, r - 5.0, 0.0, TAU, 64, Color(tint, 0.22), 8.0, true)
	draw_arc(c, r, 0.0, TAU, 64, Color(tint.lightened(0.3), 0.85), 2.0, true)
	# A glint up on the left, a fainter one low on the right.
	draw_arc(c, r - 9.0, deg_to_rad(195.0), deg_to_rad(255.0), 20, Color(GLINT, 0.6), 3.0, true)
	draw_circle(c + Vector2(-r * 0.42, -r * 0.5), 3.0, Color(GLINT, 0.7))
	draw_arc(c, r - 9.0, deg_to_rad(20.0), deg_to_rad(45.0), 10, Color(GLINT, 0.25), 2.0, true)
