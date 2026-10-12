# NameEntry
# Where the hero gets a name, when the captain cannot remember it (IntroUI).
# Laid into the dialogue box's place and the same size, so nothing around it
# moves.
#
# On a PC, Pokémon's way: ten slots for the name and a board of letters under
# them, walked with the arrows or the d-pad. Yes puts the letter down, no
# takes the last one back (so does Backspace), and Done at the bottom ends it.
# Z and X are yes and no, so the board is all there is: typing would put a
# "z" down every time a letter was chosen.
#
# On a phone the board would be too small to hit, so it is a text field
# instead, and the phone's own keyboard comes up for it.
#
# The name starts as "Hero", her guess. The first letter put down replaces it
# rather than going on the end; a name left empty is "Hero" again.
class_name NameEntry extends PanelContainer

signal named(hero_name: String)
# On a phone: the field has the keyboard up (true) or has let it go.
signal typing(on: bool)

const _FONT := preload("res://resources/misc/OldSchoolAdventures-42j9.ttf") as FontFile

const MAX_LEN: int = 10
const DEFAULT: String = "Hero"
const GOLD: Color = Color(0.90, 0.75, 0.30)
const INK: Color = Color(0.88, 0.86, 0.92)
const DIM: Color = Color(0.40, 0.37, 0.46)

# The board, a row at a time. Every row is as long as the first.
const BOARD: Array[String] = [
	"ABCDEFGHIJKLM",
	"NOPQRSTUVWXYZ",
	"abcdefghijklm",
	"nopqrstuvwxyz",
	"0123456789-'.",
]

var _name: String = DEFAULT
# Still her guess: the next letter replaces it.
var _guess: bool = true
var _slots: Array[Label] = []
var _done_btn: Button
var _field: LineEdit
var _first: Button
var _grid: GridContainer
var _actions: Array[Button] = []


func _init() -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.06, 0.11)
	style.border_color = GOLD
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	# The dialogue box's 16, less at the top and bottom on a PC for the
	# board's five rows to fit in it.
	style.set_content_margin_all(16)
	if Build.steam():
		style.content_margin_top = 10
		style.content_margin_bottom = 10
	add_theme_stylebox_override("panel", style)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	add_child(col)
	col.add_child(_label("What do they call you?", GOLD))
	if Build.steam():
		_build_board(col)
	else:
		_build_field(col)


func _ready() -> void:
	if _first != null:
		_wrap()
		_first.grab_focus()
	_paint()


# The cursor goes round the board rather than off it: the title screen's
# buttons are still there behind the intro, and an arrow past an edge would
# find them. Off the bottom is the top row again, off the right is the left.
func _wrap() -> void:
	var cols: int = BOARD[0].length()
	var rows: int = BOARD.size()
	var keys: Array[Node] = _grid.get_children()
	for i: int in keys.size():
		var key: Button = keys[i] as Button
		var r: int = i / cols
		var c: int = i % cols
		var below: Button = _actions[c * _actions.size() / cols] if r == rows - 1 \
				else keys[i + cols] as Button
		var above: Button = _actions[c * _actions.size() / cols] if r == 0 \
				else keys[i - cols] as Button
		key.focus_neighbor_bottom = key.get_path_to(below)
		key.focus_neighbor_top = key.get_path_to(above)
		key.focus_neighbor_left = key.get_path_to(keys[r * cols + (c + cols - 1) % cols])
		key.focus_neighbor_right = key.get_path_to(keys[r * cols + (c + 1) % cols])
	for a: int in _actions.size():
		var b: Button = _actions[a]
		# Over the middle of its third of the board.
		var c: int = (a * cols + cols / 2) / _actions.size()
		b.focus_neighbor_top = b.get_path_to(keys[(rows - 1) * cols + c])
		b.focus_neighbor_bottom = b.get_path_to(keys[c])
		b.focus_neighbor_left = b.get_path_to(_actions[(a + _actions.size() - 1) % _actions.size()])
		b.focus_neighbor_right = b.get_path_to(_actions[(a + 1) % _actions.size()])


# Ten slots, each a letter over a line; the next one to fill has a gold line.
func _build_board(col: VBoxContainer) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 4)
	col.add_child(row)
	for i: int in MAX_LEN:
		var slot: Label = _label("", INK)
		slot.custom_minimum_size = Vector2(26, 26)
		slot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var line: ColorRect = ColorRect.new()
		line.color = DIM
		line.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		line.offset_top = -2
		line.offset_left = 3
		line.offset_right = -3
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(line)
		slot.set_meta("line", line)
		row.add_child(slot)
		_slots.append(slot)

	var grid: GridContainer = GridContainer.new()
	_grid = grid
	grid.columns = BOARD[0].length()
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 0)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(grid)
	for r: String in BOARD:
		for c: String in r:
			var key: Button = _key(c, Vector2(46, 24))
			key.pressed.connect(_put.bind(c))
			grid.add_child(key)
			if _first == null:
				_first = key

	var actions: HBoxContainer = HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 12)
	col.add_child(actions)
	var space: Button = _key("Space", Vector2(140, 26))
	space.pressed.connect(_put.bind(" "))
	actions.add_child(space)
	var del: Button = _key("Delete", Vector2(140, 26))
	# Its own press sounds like going back already (Sfx).
	del.set_meta("back", true)
	del.pressed.connect(_take_back.bind(false))
	actions.add_child(del)
	_done_btn = _key("Done", Vector2(140, 26))
	_done_btn.add_theme_color_override("font_color", GOLD)
	_done_btn.pressed.connect(_finish)
	actions.add_child(_done_btn)
	_actions.assign([space, del, _done_btn])


# The name in a field, the phone's keyboard under it, Done beside it.
func _build_field(col: VBoxContainer) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	col.add_child(row)
	_field = LineEdit.new()
	_field.text = DEFAULT
	_field.max_length = MAX_LEN
	_field.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_field.select_all_on_focus = true
	_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_field.custom_minimum_size = Vector2(0, 56)
	_field.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_DEFAULT
	_field.add_theme_font_override("font", _FONT)
	_field.add_theme_font_size_override("font_size", 24)
	_field.text_submitted.connect(func(_t: String) -> void: _finish())
	_field.focus_entered.connect(func() -> void: typing.emit(true))
	_field.focus_exited.connect(func() -> void: typing.emit(false))
	row.add_child(_field)
	_done_btn = _key("Done", Vector2(110, 56))
	_done_btn.add_theme_color_override("font_color", GOLD)
	_done_btn.pressed.connect(_finish)
	row.add_child(_done_btn)
	var hint: Label = _label("Tap the name to change it.", DIM)
	hint.add_theme_font_size_override("font_size", 16)
	col.add_child(hint)


# The line under the box while the board is up, in place of "Z to
# continue": the pad's icons once a pad is in hand (ButtonHint).
static func hint_line(font_size: int, color: Color) -> Control:
	var line: HBoxContainer = HBoxContainer.new()
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	line.add_theme_constant_override("separation", 28)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(ButtonHint.new("yes", "to write", font_size, color))
	line.add_child(ButtonHint.new("no", "to erase", font_size, color))
	return line


func _unhandled_input(event: InputEvent) -> void:
	if _field != null:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_take_back()
		return
	var k: InputEventKey = event as InputEventKey
	if k != null and k.pressed and not k.echo and k.keycode == KEY_BACKSPACE:
		get_viewport().set_input_as_handled()
		_take_back()


func _put(c: String) -> void:
	if _guess:
		_name = ""
		_guess = false
	if _name.length() >= MAX_LEN or (c == " " and (_name == "" or _name.ends_with(" "))):
		return
	_name += c
	if _name.length() >= MAX_LEN:
		_done_btn.grab_focus()
	_paint()


func _take_back(sound: bool = true) -> void:
	if _guess:
		_name = ""
		_guess = false
	elif _name != "":
		_name = _name.left(-1)
	if sound:
		Sfx.play("back")
	_paint()


func _finish() -> void:
	var chosen: String = (_field.text if _field != null else _name).strip_edges()
	named.emit(chosen if chosen != "" else DEFAULT)


func _paint() -> void:
	for i: int in _slots.size():
		var slot: Label = _slots[i]
		slot.text = _name[i] if i < _name.length() else ""
		slot.add_theme_color_override("font_color", DIM if _guess else INK)
		var line: ColorRect = slot.get_meta("line") as ColorRect
		line.color = GOLD if i == mini(_name.length(), MAX_LEN - 1) and not _guess else DIM


func _key(text: String, at_least: Vector2) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.custom_minimum_size = at_least
	b.add_theme_font_override("font", _FONT)
	b.add_theme_font_size_override("font_size", 20 if Build.steam() else 24)
	if Build.steam():
		# No padding, so the board fits the dialogue box; the cursor is a
		# gold frame round the letter.
		for state: String in ["normal", "disabled"]:
			b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		b.add_theme_stylebox_override("hover", _key_style(Color(1, 1, 1, 0.06), Color(0, 0, 0, 0)))
		b.add_theme_stylebox_override("pressed", _key_style(Color(1, 1, 1, 0.12), GOLD))
		b.add_theme_stylebox_override("focus", _key_style(Color(0, 0, 0, 0), GOLD))
	return b


func _key_style(fill: Color, edge: Color) -> StyleBoxFlat:
	var st: StyleBoxFlat = StyleBoxFlat.new()
	st.bg_color = fill
	st.border_color = edge
	st.set_border_width_all(2 if edge.a > 0.0 else 0)
	st.set_corner_radius_all(3)
	st.set_content_margin_all(0)
	return st


func _label(text: String, color: Color) -> Label:
	var lbl: Label = Label.new()
	lbl.text = text
	lbl.add_theme_font_override("font", _FONT)
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", color)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl
