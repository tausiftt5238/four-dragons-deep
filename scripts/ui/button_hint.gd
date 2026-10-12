# ButtonHint
# A button's mark and what it does, "[Z] Act" or "Z to continue": the key's
# name on a keyboard, the pad's own icon (Controls.pad_icon) once a pad is
# what you last touched. It follows a rebinding and the switch between the two
# by itself.
#
# The mark sits in a slot as wide as the wider of the two, so swapping a key
# for an icon never moves the words next to it.
class_name ButtonHint extends HBoxContainer

const _FONT := preload("res://resources/misc/OldSchoolAdventures-42j9.ttf") as FontFile

var action: String = "yes"
# The words after the mark; "" for the mark alone.
var text: String = "":
	set(v):
		text = v
		if _words != null:
			_words.text = v
			_words.visible = v != ""
# A key's name goes in brackets, "[Z]", where the hint is a line of others.
var brackets: bool = false

var _slot: Control
var _icon: TextureRect
var _key: Label
var _words: Label
var _shown: String = ""


func _init(for_action: String = "yes", words: String = "", font_size: int = 13,
		color: Color = Color(0.85, 0.86, 0.93), bracketed: bool = false) -> void:
	action = for_action
	brackets = bracketed
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 6)
	_slot = Control.new()
	_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slot.size_flags_vertical = Control.SIZE_FILL
	add_child(_slot)
	_icon = TextureRect.new()
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slot.add_child(_icon)
	_key = _label(font_size, color)
	_key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_key.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_slot.add_child(_key)
	_words = _label(font_size, color)
	_words.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_words)
	text = words


# The line under a screen that waits for you: "Z to continue", or the pad's
# yes icon, or on a phone "tap to continue". Centred across whatever it is
# anchored to.
static func continue_line(font_size: int, color: Color) -> Control:
	if not Build.steam():
		var tap: Label = Label.new()
		tap.text = Controls.continue_hint()
		tap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tap.add_theme_font_override("font", _FONT)
		tap.add_theme_font_size_override("font_size", font_size)
		tap.add_theme_color_override("font_color", color)
		tap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return tap
	var line: ButtonHint = ButtonHint.new("yes", "to continue", font_size, color)
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	return line


func _label(font_size: int, color: Color) -> Label:
	var l: Label = Label.new()
	l.add_theme_font_override("font", _FONT)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _ready() -> void:
	_paint()


# Cheap enough to ask every frame, and it catches a rebinding in Options as
# well as the hand moving from the keys to the pad.
func _process(_delta: float) -> void:
	_paint()


func _paint() -> void:
	var key_text: String = Controls.key_name(Controls.key_of(action))
	if brackets:
		key_text = "[%s]" % key_text
	var tex: Texture2D = Controls.pad_icon(Controls.pad_of(action))
	var pad: bool = Controls.using_pad and tex != null
	var now: String = "%s|%s|%d" % [key_text, pad, Controls.pad_of(action)]
	if now == _shown:
		return
	_shown = now
	_key.text = key_text
	_icon.texture = tex
	_key.visible = not pad
	_icon.visible = pad
	# As wide and tall as the wider and taller of the two marks.
	var key_size: Vector2 = _key.get_combined_minimum_size()
	var icon_size: Vector2 = tex.get_size() if tex != null else Vector2.ZERO
	_slot.custom_minimum_size = Vector2(maxf(key_size.x, icon_size.x),
			maxf(key_size.y, icon_size.y))
