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

var _host:   VBoxContainer
var _slots:  Array[MarginContainer] = []
var _filled: int = 0


func _init(parent: Control) -> void:
	_host = VBoxContainer.new()
	_host.add_theme_constant_override("separation", 2)
	_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(_host)
	for i: int in SLOT_COUNT:
		var slot: MarginContainer = MarginContainer.new()
		slot.custom_minimum_size = Vector2(0, SLOT_H)
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_host.add_child(slot)
		_slots.append(slot)


func remaining() -> int:
	return SLOT_COUNT - _filled


# Fills the next slot. Returns false when the page is full, so a caller can
# stop rather than silently dropping entries.
func add(title: String, title_color: Color, detail: String,
		value: String, value_color: Color,
		btn_text: String, disabled: bool, on_press: Callable) -> bool:
	if _filled >= SLOT_COUNT:
		return false
	var slot: MarginContainer = _slots[_filled]
	_filled += 1

	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	slot.add_child(col)

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
		value_lbl.custom_minimum_size = Vector2(96, 0)
		value_lbl.add_theme_color_override("font_color", value_color)
		head.add_child(value_lbl)

	if btn_text != "":
		var btn: Button = Button.new()
		btn.text = btn_text
		btn.custom_minimum_size = Vector2(BTN_W, BTN_H)
		btn.disabled = disabled
		if not disabled:
			btn.pressed.connect(on_press)
		head.add_child(btn)

	var detail_lbl: Label = Label.new()
	detail_lbl.text = detail
	detail_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_lbl.clip_text = true
	detail_lbl.add_theme_font_size_override("font_size", 11)
	detail_lbl.add_theme_color_override("font_color", Color(0.60, 0.62, 0.70))
	col.add_child(detail_lbl)
	return true


# A line of plain text where a row would go — "nothing here yet" and the like.
func add_note(text: String) -> void:
	if _filled >= SLOT_COUNT:
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
