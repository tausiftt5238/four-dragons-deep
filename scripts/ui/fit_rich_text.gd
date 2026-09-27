# FitRichText
# FitLabel for a BBCode strip — the buff/debuff and ailment lines under a
# combatant. A fixed number of lines tall (reserved even when empty, so nothing
# above it moves), no width of its own, and the font steps down until the
# widest line fits.
class_name FitRichText extends RichTextLabel

var base_size: int = 10
var min_size:  int = 7
var lines:     int = 1

var _fit_text: String = ""
var _fit_w: float = -1.0


func _init(base: int = 10, floor_size: int = 7, line_count: int = 1) -> void:
	base_size = base
	min_size = floor_size
	lines = maxi(1, line_count)
	bbcode_enabled = true
	fit_content = false
	scroll_active = false
	autowrap_mode = TextServer.AUTOWRAP_OFF
	clip_contents = true
	custom_minimum_size = Vector2(0, (base_size + 4) * lines)
	add_theme_font_size_override("normal_font_size", base_size)


func _process(_delta: float) -> void:
	if text == _fit_text and is_equal_approx(size.x, _fit_w):
		return
	_fit_text = text
	_fit_w = size.x
	# Measured against the widest line, since each line has the whole width.
	var widest: String = ""
	var font: Font = get_theme_font("normal_font")
	for line: String in get_parsed_text().split("\n"):
		if font != null and font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT,
				-1.0, base_size).x > font.get_string_size(widest,
				HORIZONTAL_ALIGNMENT_LEFT, -1.0, base_size).x:
			widest = line
	add_theme_font_size_override("normal_font_size", FitLabel.fit_size(
			font, widest, size.x, base_size, min_size))
