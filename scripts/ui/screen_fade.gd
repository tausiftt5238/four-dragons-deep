# ScreenFade
# Black over everything, for the moments the game changes underneath you: a new
# run starting, a save loading, the stairs down. Cover, do the work while the
# screen is dark, then reveal.
#
#     var fade: ScreenFade = ScreenFade.cover(get_tree(), "Floor 6")
#     await fade.covered
#     ... swap whatever needs swapping ...
#     fade.reveal()
#
# It hangs off the tree root, above even the loading screen, so it can cover a
# scene change and lift on the far side of it.
class_name ScreenFade extends CanvasLayer

signal covered

const _FONT := preload("res://resources/misc/OldSchoolAdventures-42j9.ttf") as FontFile
const COVER_TIME: float = 0.4
const REVEAL_TIME: float = 0.5

var _veil: ColorRect
var _caption: Label


static func cover(tree: SceneTree, caption: String = "",
		duration: float = COVER_TIME) -> ScreenFade:
	var f: ScreenFade = ScreenFade.new()
	tree.root.add_child(f)
	f._fade_in(caption, duration)
	return f


func _ready() -> void:
	layer = 110


func _fade_in(caption: String, duration: float) -> void:
	_veil = ColorRect.new()
	_veil.color = Color(0.02, 0.015, 0.035)
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Nothing underneath can be pressed while it is changing.
	_veil.mouse_filter = Control.MOUSE_FILTER_STOP
	_veil.modulate.a = 0.0
	add_child(_veil)

	if caption != "":
		_caption = Label.new()
		_caption.text = caption
		_caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_caption.add_theme_font_override("font", _FONT)
		_caption.add_theme_font_size_override("font_size", 30)
		_caption.add_theme_color_override("font_color", Color(0.90, 0.75, 0.30))
		_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_caption.modulate.a = 0.0
		add_child(_caption)

	var t: Tween = create_tween()
	t.tween_property(_veil, "modulate:a", 1.0, duration)
	if _caption != null:
		t.tween_property(_caption, "modulate:a", 1.0, 0.25)
		# Long enough to read before the floor comes up.
		t.tween_interval(0.45)
	t.tween_callback(func() -> void: covered.emit())


func reveal(duration: float = REVEAL_TIME) -> void:
	var t: Tween = create_tween()
	if _caption != null:
		t.tween_property(_caption, "modulate:a", 0.0, 0.2)
	t.tween_property(_veil, "modulate:a", 0.0, duration)
	t.tween_callback(queue_free)
