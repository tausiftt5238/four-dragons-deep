# FitLabel
# A one-line Label that never widens what it sits in. Its text takes no width
# of its own (clip_text), and the font steps down from `base_size` until the
# text fits the width the container gave it, stopping at `min_size`. Anything
# still too long at the floor is cut with an ellipsis rather than spilling.
#
# Refits whenever its text or width changes, so callers set `.text` as usual.
class_name FitLabel extends Label

var base_size: int = 13
var min_size:  int = 8

var _fit_text: String = ""
var _fit_w: float = -1.0


func _init(base: int = 13, floor_size: int = 8) -> void:
	base_size = base
	min_size = floor_size
	clip_text = true
	text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_theme_font_size_override("font_size", base_size)


func _process(_delta: float) -> void:
	if text == _fit_text and is_equal_approx(size.x, _fit_w):
		return
	_fit_text = text
	_fit_w = size.x
	add_theme_font_size_override("font_size", fit_size(get_theme_font("font"),
			text, size.x, base_size, min_size))


# The largest size from `base` down to `floor_size` at which `line` fits `width`.
static func fit_size(font: Font, line: String, width: float,
		base: int, floor_size: int) -> int:
	if font == null or width <= 0.0:
		return base
	var fs: int = base
	while fs > floor_size and font.get_string_size(line,
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs).x > width:
		fs -= 1
	return fs
