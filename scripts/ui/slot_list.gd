# SlotList
# One row shape for every list in the game, and a fixed number of them.
#
# Two rules, both learned from a phone screenshot rather than a guess:
#
#   * A row is always SLOT_H tall, whatever it holds. Letting a description
#     decide the height gave a four-line row next to a one-line row and a
#     panel that changed size as you switched tabs.
#   * A page always draws SLOT_COUNT rows. Short lists leave empty slots
#     rather than shrinking the panel, so nothing under the list moves when
#     the contents change.
#
# The shape itself is the shop's: name and price and the button on one line,
# with whatever explains the choice wrapped underneath at full width. The
# alternative — five fixed columns — is what crushed spell descriptions into
# a seventy-pixel gutter that wrapped every four characters.
#
# Note on sizing: Main installs a global node_added hook that forces every
# Button to font size 20, uppercases it, and multiplies its minimum height by
# 1.5. Button text must therefore be SHORT, and heights set here are two
# thirds of what they end up.
class_name SlotList extends RefCounted

const SLOT_COUNT: int = 6
const SLOT_H:     int = 96
const BTN_W:      int = 150
const BTN_H:      int = 24     # becomes 36 after the restyle hook
const EXTRA_H:    int = 34     # one AffinityChart row
const DETAIL_SIZE: int = 11    # the detail line's font size
const _DETAIL_FONT: FontFile = preload("res://resources/misc/OldSchoolAdventures-42j9.ttf")

var _host:   VBoxContainer
var _slots:  Array[MarginContainer] = []
var _filled: int = 0


var _count: int = SLOT_COUNT

# A wide screen is read under a mouse or a pad, not tapped with a thumb: rows
# half the height, buttons narrower, the same shape.
static func slot_h() -> int:
	return 58 if Build.steam() else SLOT_H


static func btn_w() -> int:
	return 96 if Build.steam() else BTN_W


# `count` is SLOT_COUNT for a page; a section sizes itself to what it holds and
# leaves the scrolling to the page.
func _init(parent: Control, count: int = SLOT_COUNT) -> void:
	_count = maxi(1, count)
	_host = VBoxContainer.new()
	_host.add_theme_constant_override("separation", 2)
	_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(_host)
	for i: int in _count:
		var slot: MarginContainer = MarginContainer.new()
		slot.custom_minimum_size = Vector2(0, slot_h())
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_host.add_child(slot)
		_slots.append(slot)


func remaining() -> int:
	return _count - _filled


# Fills the next slot with one action. Returns false when the page is full, so
# a caller can stop rather than silently dropping entries.
func add(title: String, title_color: Color, detail: String,
		value: String, value_color: Color,
		btn_text: String, disabled: bool, on_press: Callable) -> bool:
	var actions: Array[Dictionary] = []
	if btn_text != "":
		actions.append({text = btn_text, disabled = disabled, press = on_press})
	return add_entry(title, title_color, detail, value, value_color, actions)


# The same slot with however many actions a row needs. Items carry three —
# belt, use and discard — and three buttons at font size 20 only fit because
# they share the width the single-button case gives to one.
# `detail_lines` is how many lines the detail can take: a row is built for one,
# and each more makes it taller by one line of the detail's font. Fixed by the
# caller, not measured from the text, so every row of a list is the same
# height whatever its own detail says.
func add_entry(title: String, title_color: Color, detail: String,
		value: String, value_color: Color, actions: Array[Dictionary],
		icon: Texture2D = null, extra: Control = null, detail_lines: int = 1) -> bool:
	if _filled >= _count:
		return false
	var slot: MarginContainer = _slots[_filled]
	_filled += 1
	# A row that carries an extra line (an affinity chart) is taller by exactly
	# that line, so the description keeps the room it always had.
	var h: float = slot_h()
	if extra != null:
		h += EXTRA_H
	h += float(maxi(0, detail_lines - 1)) * ceilf(_DETAIL_FONT.get_height(DETAIL_SIZE))
	slot.custom_minimum_size.y = h

	var outer: HBoxContainer = HBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	slot.add_child(outer)

	if icon != null:
		var pic: TextureRect = TextureRect.new()
		pic.texture = icon
		pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		pic.custom_minimum_size = Vector2(40, 40) if Build.steam() else Vector2(72, 72)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		outer.add_child(pic)

	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_child(col)

	var head: HBoxContainer = HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	col.add_child(head)

	var name_lbl: Label = Label.new()
	name_lbl.text = title
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_lbl.clip_text = true
	name_lbl.add_theme_color_override("font_color", title_color)
	head.add_child(name_lbl)

	if value != "":
		var value_lbl: Label = Label.new()
		value_lbl.text = value
		value_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		# No fixed width: values run from "x3" to "Floors 1-2", and reserving
		# the widest for all of them stole room three buttons needed.
		value_lbl.custom_minimum_size = Vector2(0, 0)
		value_lbl.add_theme_color_override("font_color", value_color)
		head.add_child(value_lbl)

	# One action gets a comfortable button; three share the same total width.
	var each: int = btn_w()
	if actions.size() == 2:
		each = 72 if Build.steam() else 108
	elif actions.size() >= 3:
		each = 52 if Build.steam() else 92
	for act: Dictionary in actions:
		var btn: Button = Button.new()
		btn.text = act.get("text", "") as String
		btn.clip_text = true
		btn.custom_minimum_size = Vector2(each, BTN_H)
		btn.disabled = bool(act.get("disabled", false))
		if not btn.disabled:
			btn.pressed.connect(act["press"] as Callable)
		head.add_child(btn)

	if extra != null:
		extra.custom_minimum_size.y = EXTRA_H
		col.add_child(extra)

	# BBCode rather than a plain Label so a row can colour part of its line —
	# a shop row marks each stat green or red against what is already worn.
	# fit_content stays off and scrolling is disabled: the slot's own height is
	# what decides the row, and a detail line must never change it.
	var detail_lbl: RichTextLabel = RichTextLabel.new()
	detail_lbl.bbcode_enabled = true
	detail_lbl.text = detail
	detail_lbl.fit_content = false
	detail_lbl.scroll_active = false
	detail_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_lbl.add_theme_font_size_override("normal_font_size", DETAIL_SIZE)
	detail_lbl.add_theme_color_override("default_color", Color(0.60, 0.62, 0.70))
	col.add_child(detail_lbl)
	return true


# A line of plain text where a row would go — "nothing here yet" and the like.
func add_note(text: String) -> void:
	if _filled >= _count:
		return
	var slot: MarginContainer = _slots[_filled]
	_filled += 1
	var lbl: Label = Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.62))
	slot.add_child(lbl)


# ── Whole lists ───────────────────────────────────────────────────────────────
#
# Every entry, one after another, and the page's own scroll does the rest. This
# used to be a page of six behind Back/More; a swipe is what a phone expects,
# and it keeps the whole list one gesture away. Never fewer than SLOT_COUNT
# rows, so a short list still fills the panel it did before.
static func listed(parent: Control, entries: Array, fill: Callable) -> void:
	var list: SlotList = SlotList.new(parent, maxi(SLOT_COUNT, entries.size()))
	for entry: Variant in entries:
		fill.call(list, entry)


# ── Sections ──────────────────────────────────────────────────────────────────
#
# A long mixed shelf split by kind: Weapons, Armour, Trinkets. Each is a header
# that opens and closes on a tap, and an open one lays every row it has out in
# the page, rather than pages behind Back/More. The page's own scroll is the
# only one: a scroll box per shelf nested inside it fought it for the drag on a
# phone, and a swipe would move the wrong one or neither.
#
# `groups` is [{title, entries}]; empty ones are left out. Which are open lives
# in `state` under `key`, because a purchase rebuilds the whole tab and the
# player should land where they were.
static func sections(parent: Control, state: Dictionary, key: String,
		groups: Array, fill: Callable) -> void:
	var first: bool = true
	for group: Dictionary in groups:
		var entries: Array = group.get("entries", []) as Array
		if entries.is_empty():
			continue
		var title: String = group.get("title", "") as String
		var open_key: String = "%s:%s:open" % [key, title]
		# Nothing is open on a first visit except the first shelf, so the tab
		# never opens onto a column of closed headers.
		var open: bool = bool(state.get(open_key, first))
		first = false

		var header: Button = Button.new()
		header.alignment = HORIZONTAL_ALIGNMENT_LEFT
		header.custom_minimum_size = Vector2(0, 26)
		header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		parent.add_child(header)

		var box: VBoxContainer = VBoxContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.visible = open
		parent.add_child(box)

		var list: SlotList = SlotList.new(box, entries.size())
		for entry: Variant in entries:
			fill.call(list, entry)

		var label: Callable = func(is_open: bool) -> String:
			return "%s  %s   (%d)" % ["-" if is_open else "+", title, entries.size()]
		header.text = label.call(open)
		header.pressed.connect(func() -> void:
			box.visible = not box.visible
			state[open_key] = box.visible
			header.text = label.call(box.visible))

