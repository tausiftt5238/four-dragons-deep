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

var _host:   VBoxContainer
var _slots:  Array[MarginContainer] = []
var _filled: int = 0


var _count: int = SLOT_COUNT


# `count` is SLOT_COUNT for a page; a section sizes itself to what it holds and
# lets its own scroll bar do the paging.
func _init(parent: Control, count: int = SLOT_COUNT) -> void:
	_count = maxi(1, count)
	_host = VBoxContainer.new()
	_host.add_theme_constant_override("separation", 2)
	_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(_host)
	for i: int in _count:
		var slot: MarginContainer = MarginContainer.new()
		slot.custom_minimum_size = Vector2(0, SLOT_H)
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
func add_entry(title: String, title_color: Color, detail: String,
		value: String, value_color: Color, actions: Array[Dictionary],
		icon: Texture2D = null, extra: Control = null) -> bool:
	if _filled >= _count:
		return false
	var slot: MarginContainer = _slots[_filled]
	_filled += 1
	# A row that carries an extra line (an affinity chart) is taller by exactly
	# that line, so the description keeps the room it always had.
	if extra != null:
		slot.custom_minimum_size.y = SLOT_H + EXTRA_H

	var outer: HBoxContainer = HBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	slot.add_child(outer)

	if icon != null:
		var pic: TextureRect = TextureRect.new()
		pic.texture = icon
		pic.custom_minimum_size = Vector2(48, 48)
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
	var each: int = BTN_W
	if actions.size() == 2:
		each = 108
	elif actions.size() >= 3:
		each = 92
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
	detail_lbl.add_theme_font_size_override("normal_font_size", 11)
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


# ── Paging ────────────────────────────────────────────────────────────────────
#
# Draws one page of `entries` into a fixed set of slots, with a footer to turn
# the page when there are more than fit. `state` holds the current page under
# `key`, because the thing that builds these lists is rebuilt on every refresh
# and cannot remember where it was.
static func paged(parent: Control, state: Dictionary, key: String,
		entries: Array, fill: Callable, on_change: Callable) -> void:
	var pages: int = maxi(1, ceili(float(entries.size()) / float(SLOT_COUNT)))
	var at: int = clampi(int(state.get(key, 0)), 0, pages - 1)
	state[key] = at

	var list: SlotList = SlotList.new(parent)
	var first: int = at * SLOT_COUNT
	for i: int in range(first, mini(first + SLOT_COUNT, entries.size())):
		fill.call(list, entries[i])

	if pages <= 1:
		return

	var foot: HBoxContainer = HBoxContainer.new()
	foot.add_theme_constant_override("separation", 8)
	parent.add_child(foot)

	var prev: Button = Button.new()
	prev.text = "Back"
	prev.custom_minimum_size = Vector2(120, 24)
	prev.disabled = at == 0
	prev.pressed.connect(func() -> void:
		state[key] = at - 1
		on_change.call())
	foot.add_child(prev)

	var where: Label = Label.new()
	where.text = "%d / %d" % [at + 1, pages]
	where.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	where.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	where.add_theme_color_override("font_color", Color(0.60, 0.62, 0.68))
	foot.add_child(where)

	var next: Button = Button.new()
	next.text = "More"
	next.custom_minimum_size = Vector2(120, 24)
	next.disabled = at >= pages - 1
	next.pressed.connect(func() -> void:
		state[key] = at + 1
		on_change.call())
	foot.add_child(next)


# ── Sections ──────────────────────────────────────────────────────────────────
#
# A long mixed shelf split by kind: Weapons, Armour, Trinkets. Each is a header
# that opens and closes on a tap, and an open one shows every row it has in a
# box of its own with its own scroll bar, rather than pages behind Back/More.
#
# `groups` is [{title, entries}]; empty ones are left out. Which are open and
# how far each is scrolled live in `state` under `key`, because a purchase
# rebuilds the whole tab and the player should land where they were.
const SECTION_ROWS: int = 3


static func sections(parent: Control, state: Dictionary, key: String,
		groups: Array, fill: Callable) -> void:
	var first: bool = true
	for group: Dictionary in groups:
		var entries: Array = group.get("entries", []) as Array
		if entries.is_empty():
			continue
		var title: String = group.get("title", "") as String
		var open_key: String = "%s:%s:open" % [key, title]
		var scroll_key: String = "%s:%s:scroll" % [key, title]
		# Nothing is open on a first visit except the first shelf, so the tab
		# never opens onto a column of closed headers.
		var open: bool = bool(state.get(open_key, first))
		first = false

		var header: Button = Button.new()
		header.alignment = HORIZONTAL_ALIGNMENT_LEFT
		header.custom_minimum_size = Vector2(0, 26)
		header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		parent.add_child(header)

		var box: ScrollContainer = ScrollContainer.new()
		box.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		box.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS \
				if entries.size() > SECTION_ROWS else ScrollContainer.SCROLL_MODE_DISABLED
		box.custom_minimum_size = Vector2(0,
				mini(entries.size(), SECTION_ROWS) * (SLOT_H + 2))
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

		# Put the scroll back where it was once the rows have been laid out;
		# before that the bar has no range and the value would be clamped to 0.
		var bar: VScrollBar = box.get_v_scroll_bar()
		var saved: float = float(state.get(scroll_key, 0.0))
		var restore: Dictionary = {pending = saved > 0.0}
		bar.changed.connect(func() -> void:
			if restore["pending"] and bar.max_value > 0.0:
				restore["pending"] = false
				bar.value = saved)
		bar.value_changed.connect(func(v: float) -> void:
			if not restore["pending"]:
				state[scroll_key] = v)
