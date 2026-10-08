# SidePanel
# The menu's and the orb's frame on a wide screen, in the fight's windows: a
# command window down the left naming the pages, and the page window beside
# it. Up and down walk the commands and the page follows the cursor; Right or
# the confirm button steps into the page, and Left (from the page's left edge)
# or cancel steps back out, to the command it belongs to; cancel from the
# commands closes. Each page remembers where its cursor was, so stepping out
# and back in lands where it left off. The phone keeps its own frame (MenuUI
# and OrbUI build it).
#
# The host fills `content` the way it always has; the theme set here dresses
# whatever it puts there in the same windows.
class_name SidePanel extends HBoxContainer

signal picked(id: String)
signal back_out

const TEXT: int = 14
const SMALL: int = 11
const GOLD: Color = Color(1.0, 0.86, 0.42)
const PALE: Color = Color(0.84, 0.86, 0.92)
const DIM: Color = Color(0.50, 0.50, 0.58)
const SEL: Color = Color(0.20, 0.24, 0.48)
const WIN_BG: Color = Color(0.063, 0.07, 0.18)
const WIN_EDGE: Color = Color(0.78, 0.80, 0.90)
const CMD_W: float = 142.0

var buttons: Dictionary = {}
var content: VBoxContainer
var scroll: ScrollContainer
var status: Label
var page_title: Label
var corner: Label     # the page window's top right: gold, for the orb
var _cmd_col: VBoxContainer
var _current: String = ""
# Commands that act rather than show a page (Close, Leave): the cursor
# passing over them does nothing; choosing one does.
var _actions: Array[String] = []
# Where the cursor was in each page when it last stepped out, as an index over
# the page's stops (page_focus_index), so stepping back in finds it again.
var _page_cursor: Dictionary = {}


# `commands` is a list of [id, label], with "" for a gap; `actions` are the
# ids that are not pages.
func _init(title: String, commands: Array, actions: Array[String]) -> void:
	_actions = actions
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_theme_constant_override("separation", 8)
	theme = _theme()

	var cmd_win: PanelContainer = _window()
	cmd_win.custom_minimum_size = Vector2(CMD_W, 0)
	add_child(cmd_win)
	_cmd_col = VBoxContainer.new()
	_cmd_col.add_theme_constant_override("separation", 2)
	cmd_win.add_child(_cmd_col)
	var head: Label = _label(title, TEXT, GOLD)
	_cmd_col.add_child(head)
	_cmd_col.add_child(_rule())
	for c: Array in commands:
		var id: String = c[0] as String
		if id == "":
			var gap: Control = Control.new()
			gap.custom_minimum_size = Vector2(0, 12)
			_cmd_col.add_child(gap)
			continue
		var b: Button = Button.new()
		b.text = c[1] as String
		b.toggle_mode = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for st: String in ["normal", "disabled"]:
			b.add_theme_stylebox_override(st, _box(Color(0, 0, 0, 0), 0))
		for st: String in ["hover", "focus", "pressed", "hover_pressed"]:
			b.add_theme_stylebox_override(st, _box(SEL, 0))
		b.add_theme_color_override("font_pressed_color", GOLD)
		b.add_theme_color_override("font_hover_pressed_color", GOLD)
		b.add_theme_color_override("font_focus_color", GOLD)
		b.pressed.connect(_on_pressed.bind(id))
		b.focus_entered.connect(_on_cursor.bind(id))
		_cmd_col.add_child(b)
		buttons[id] = b

	var page_win: PanelContainer = _window()
	page_win.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(page_win)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	page_win.add_child(col)
	var top: HBoxContainer = HBoxContainer.new()
	col.add_child(top)
	page_title = _label("", TEXT, GOLD)
	page_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(page_title)
	corner = _label("", TEXT, GOLD)
	top.add_child(corner)
	col.add_child(_rule())
	scroll = TouchScroll.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Never wider than its window: a row that asks for more is cut at the edge
	# rather than pushing the window over the map.
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.follow_focus = true
	col.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 6)
	scroll.add_child(content)
	# One line, always there: a message coming or going never moves the page.
	status = _label("", SMALL, Color(0.65, 0.90, 0.70))
	status.custom_minimum_size = Vector2(0, 16)
	status.clip_text = true
	status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(status)


# Main gives every Button a font size as it enters the tree, after _init made
# these; put the window size back once they are in.
func _ready() -> void:
	for b: Button in buttons.values():
		b.add_theme_font_size_override("font_size", TEXT)


func set_page(id: String, title: String) -> void:
	_current = id
	page_title.text = title
	for k: String in buttons:
		(buttons[k] as Button).set_pressed_no_signal(k == id)


func focus_commands() -> void:
	var b: Button = buttons.get(_current) as Button
	if b == null:
		for v: Button in buttons.values():
			if not v.disabled:
				b = v
				break
	if b != null:
		b.grab_focus()


# Into the page: where its cursor was when it last stepped out, or its first
# stop the first time.
func focus_page() -> void:
	var at: int = int(_page_cursor.get(_current, -1))
	if at >= 0 and at < _focusables(content).size():
		focus_page_at(at)
		return
	var first: Control = _first_focusable(content)
	if first != null:
		first.grab_focus()


# Out of the page, to its command, keeping the cursor's place.
func leave_page() -> void:
	var at: int = page_focus_index()
	if at >= 0:
		_page_cursor[_current] = at
	focus_commands()


# Choosing the command whose page is already up (the cursor put it there)
# steps into it, as Right does, rather than building it afresh.
func _on_pressed(id: String) -> void:
	if id == _current and id not in _actions:
		focus_page()
		return
	picked.emit(id)
	if id not in _actions:
		focus_page.call_deferred()


func _on_cursor(id: String) -> void:
	if id in _actions or id == _current:
		return
	picked.emit(id)


func _in_commands(c: Control) -> bool:
	return c != null and _cmd_col.is_ancestor_of(c)


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	var focus: Control = get_viewport().gui_get_focus_owner()
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if focus != null and not _in_commands(focus):
			leave_page()
		else:
			back_out.emit()
		return
	# Left inside the page moves left inside it (a row of x1 x5 x10); from its
	# left edge it steps out, to this page's command and not whichever one
	# happens to sit level with the cursor.
	if focus != null and content.is_ancestor_of(focus) and event.is_action_pressed("ui_left"):
		var next: Control = focus.find_valid_focus_neighbor(SIDE_LEFT)
		if next == null or not content.is_ancestor_of(next):
			get_viewport().set_input_as_handled()
			leave_page()
		return
	if _in_commands(focus) and event.is_action_pressed("ui_right"):
		get_viewport().set_input_as_handled()
		focus_page()
	elif focus == null and (event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down")):
		get_viewport().set_input_as_handled()
		focus_commands()


# Where the cursor is in the page, as an index over its buttons, so a page
# rebuilt under it (a purchase, an equip) can put the cursor back. -1 when it
# is not in the page.
func page_focus_index() -> int:
	var f: Control = get_viewport().gui_get_focus_owner()
	if f == null or not content.is_ancestor_of(f):
		return -1
	return _focusables(content).find(f)


func focus_page_at(i: int) -> void:
	if i < 0:
		return
	var all: Array[Control] = _focusables(content)
	if all.is_empty():
		focus_commands()
		return
	all[mini(i, all.size() - 1)].grab_focus()


static func _focusables(n: Node, out: Array[Control] = []) -> Array[Control]:
	for c: Node in n.get_children():
		if c.is_queued_for_deletion():
			continue
		if _stops_cursor(c):
			out.append(c as Control)
		_focusables(c, out)
	return out


# A button the cursor can land on, or a page's own stop (a Stats card, which
# marks itself with the "card" meta).
static func _stops_cursor(c: Node) -> bool:
	if not (c is Control) or (c as Control).focus_mode == Control.FOCUS_NONE:
		return false
	if c is BaseButton:
		return not (c as BaseButton).disabled
	return c.has_meta("card")


static func _first_focusable(n: Node) -> Control:
	for c: Node in n.get_children():
		if c is Control and not (c as Control).is_visible_in_tree():
			continue
		if _stops_cursor(c):
			return c as Control
		var deeper: Control = _first_focusable(c)
		if deeper != null:
			return deeper
	return null


# ── Looks ────────────────────────────────────────────────────────────────────

static func _box(bg: Color, edge_w: int, edge: Color = WIN_EDGE) -> StyleBoxFlat:
	var st: StyleBoxFlat = StyleBoxFlat.new()
	st.bg_color = bg
	st.border_color = edge
	st.set_border_width_all(edge_w)
	st.set_corner_radius_all(3)
	st.content_margin_left = 8
	st.content_margin_right = 8
	st.content_margin_top = 4
	st.content_margin_bottom = 4
	return st


static func _window() -> PanelContainer:
	var w: PanelContainer = PanelContainer.new()
	var st: StyleBoxFlat = StyleBoxFlat.new()
	st.bg_color = WIN_BG
	st.border_color = WIN_EDGE
	st.set_border_width_all(2)
	st.set_corner_radius_all(6)
	st.set_content_margin_all(10)
	w.add_theme_stylebox_override("panel", st)
	return w


static func _rule() -> ColorRect:
	var r: ColorRect = ColorRect.new()
	r.color = Color(WIN_EDGE, 0.30)
	r.custom_minimum_size = Vector2(0, 1)
	return r


static func _label(text: String, size: int, color: Color) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


# What the pages' own buttons, labels and rules look like inside the window:
# quiet rows that light up under the cursor, like the fight's lists.
static func _theme() -> Theme:
	var t: Theme = Theme.new()
	t.set_stylebox("normal", "Button", _box(Color(1, 1, 1, 0.05), 0))
	t.set_stylebox("hover", "Button", _box(SEL, 0))
	t.set_stylebox("pressed", "Button", _box(SEL, 1, GOLD))
	t.set_stylebox("hover_pressed", "Button", _box(SEL, 1, GOLD))
	t.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), 2, GOLD))
	t.set_stylebox("disabled", "Button", _box(Color(1, 1, 1, 0.02), 0))
	t.set_color("font_color", "Button", PALE)
	t.set_color("font_hover_color", "Button", GOLD)
	t.set_color("font_focus_color", "Button", GOLD)
	t.set_color("font_pressed_color", "Button", GOLD)
	t.set_color("font_hover_pressed_color", "Button", GOLD)
	t.set_color("font_disabled_color", "Button", Color(PALE, 0.35))
	t.set_color("font_color", "Label", PALE)
	var sep: StyleBoxLine = StyleBoxLine.new()
	sep.color = Color(WIN_EDGE, 0.30)
	sep.thickness = 1
	t.set_stylebox("separator", "HSeparator", sep)
	t.set_constant("separation", "HSeparator", 6)
	var empty: StyleBoxEmpty = StyleBoxEmpty.new()
	t.set_stylebox("panel", "PanelContainer", empty)
	t.set_stylebox("panel", "Panel", empty)
	return t
