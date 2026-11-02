# MarqueeLabel
# A one-line Label that never widens what it sits in, and never shrinks its
# font: a line too long for its width scrolls instead, like a shop's banner. It
# rests on its start, runs left until its end shows, rests there, then jumps
# back to the start and goes again. A line that fits just sits still.
#
# Callers treat it as any Label: set `.text`, the alignment and the font
# colour and size overrides as usual. The label draws nothing of its own; a
# copy of it inside, kept in step every frame, is what slides.
class_name MarqueeLabel extends Label

# How long it rests at each end, in seconds.
const REST: float = 1.4
# How fast it runs, in pixels a second.
const SPEED: float = 32.0

var _inner: Label
var _t: float = 0.0


func _init() -> void:
	clip_text = true
	clip_contents = true
	text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	self_modulate = Color(1, 1, 1, 0)
	_inner = Label.new()
	_inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_inner, false, Node.INTERNAL_MODE_FRONT)


func _process(delta: float) -> void:
	if _inner.text != text:
		_inner.text = text
		_t = 0.0
	var fs: int = get_theme_font_size("font_size")
	var font: Font = get_theme_font("font")
	_inner.add_theme_font_override("font", font)
	_inner.add_theme_font_size_override("font_size", fs)
	_inner.add_theme_color_override("font_color", get_theme_color("font_color"))
	_inner.vertical_alignment = vertical_alignment

	var line_w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs).x \
			if font != null else 0.0
	var over: float = line_w - size.x
	if over <= 0.0:
		_inner.horizontal_alignment = horizontal_alignment
		_inner.position = Vector2.ZERO
		_inner.size = size
		_t = 0.0
		return
	_inner.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_inner.size = Vector2(line_w, size.y)
	var run: float = over / SPEED
	_t = fmod(_t + delta, REST + run + REST)
	_inner.position = Vector2(-over * clampf((_t - REST) / run, 0.0, 1.0), 0.0)
