# MenuUI
# In-game pause menu. Set .player before adding to the scene tree, then listen
# for menu_closed to clean up. Tab content is built by MenuTabs.
class_name MenuUI extends Control

signal menu_closed
signal load_requested
signal title_requested


var player: PlayerCharacter

var _active_tab:  String = "stats"
var page: Dictionary = {}
var _tab_btns:    Dictionary = {}
var _scroll: ScrollContainer
var _content:     VBoxContainer
var _status_line: Label
var _tabs:        MenuTabs
var _side: SidePanel   # the wide screen's frame; null on a phone

const _PAGE_NAMES: Dictionary = {stats = "Stats", party = "Party", items = "Items",
		equipment = "Equip", magic = "Magic", bestiary = "Bestiary", system = "System"}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_shell()
	_tabs = MenuTabs.new(self)
	_switch_tab("stats")


# ── Shell (chrome that never changes) ────────────────────────────────────────

func _build_shell() -> void:
	if Layout.landscape():
		_build_side()
		return
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.03, 0.03, 0.05, 0.93)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var panel: Panel = Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 12)
	panel.add_child(margin)

	# The content on top, and every button that moves between pages along the
	# bottom: two rows of three tabs with System and Close under them, where a
	# thumb already is. A sidebar down the left would eat a quarter of a
	# 540-wide screen.
	var shell: VBoxContainer = VBoxContainer.new()
	shell.add_theme_constant_override("separation", 6)
	margin.add_child(shell)

	var scroll: ScrollContainer = TouchScroll.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.add_child(scroll)
	_scroll = scroll

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 8)
	scroll.add_child(_content)

	_status_line = Label.new()
	_status_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_line.add_theme_color_override("font_color", Color(0.9, 0.85, 0.45))
	_status_line.custom_minimum_size = Vector2(0, 22)
	# Wrapped, or a long message sets the menu's width and pushes the rows'
	# buttons and the tab grid off a phone screen.
	_status_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	shell.add_child(_status_line)

	shell.add_child(HSeparator.new())

	var grid: GridContainer = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	shell.add_child(grid)

	for tab_id: String in ["stats", "party", "items", "equipment", "magic", "bestiary"]:
		var btn: Button = Button.new()
		btn.text        = tab_id.capitalize()
		btn.toggle_mode = true
		btn.custom_minimum_size     = Vector2(0, 36)
		btn.size_flags_horizontal   = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_switch_tab.bind(tab_id))
		# Off in the Abyss: every kind in five elements is a list nobody
		# would read. Fights still show each one's chart as it is learned.
		if tab_id == "bestiary" and Abyss.active:
			btn.disabled = true
		grid.add_child(btn)
		_tab_btns[tab_id] = btn

	# Everything that is not about the run itself — Options, loading, going
	# back to the title — sits behind one System button, so the footer is
	# two buttons a thumb cannot miss.
	var foot: HBoxContainer = HBoxContainer.new()
	foot.add_theme_constant_override("separation", 6)
	shell.add_child(foot)

	var system_btn: Button = Button.new()
	system_btn.text = "System"
	system_btn.toggle_mode = true
	system_btn.custom_minimum_size   = Vector2(0, 32)
	system_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	system_btn.pressed.connect(_switch_tab.bind("system"))
	foot.add_child(system_btn)
	_tab_btns["system"] = system_btn

	var close_btn: Button = Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size   = Vector2(0, 32)
	close_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_btn.pressed.connect(func(): menu_closed.emit())
	foot.add_child(close_btn)


# A wide screen: the command window and the page window (SidePanel), beside
# the map Main has pushed to the right.
func _build_side() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.04, 0.03, 0.07)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var cmds: Array = []
	for id: String in ["stats", "party", "items", "equipment", "magic", "bestiary"]:
		cmds.append([id, _PAGE_NAMES[id]])
	cmds.append_array([["", ""], ["system", "System"], ["close", "Close"]])
	_side = SidePanel.new("Menu", cmds, ["close"] as Array[String])
	_side.offset_left = 8
	_side.offset_top = 8
	_side.offset_bottom = -8
	add_child(_side)
	_side.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_KEEP_SIZE, 8)
	_side.picked.connect(func(id: String) -> void:
		if id == "close":
			menu_closed.emit()
		else:
			_switch_tab(id))
	_side.back_out.connect(func() -> void: menu_closed.emit())
	_content = _side.content
	_scroll = _side.scroll
	_status_line = _side.status
	_tab_btns = _side.buttons
	if Abyss.active:
		(_tab_btns["bestiary"] as Button).disabled = true
	_side.focus_commands.call_deferred()


# ── System page ───────────────────────────────────────────────────────────────

func _build_system() -> void:
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(col)

	var options_btn: Button = _system_button("Options")
	options_btn.pressed.connect(func():
		var ui: OptionsUI = OptionsUI.new()
		ui.closed.connect(func(): ui.queue_free())
		add_child(ui))
	col.add_child(options_btn)

	var load_btn: Button = _system_button("Load Game")
	load_btn.pressed.connect(func(): load_requested.emit())
	col.add_child(load_btn)

	# Back to the title, for a new run without reloading the page. Two taps,
	# since anything not saved at an orb goes with it.
	var title_btn: Button = _system_button("Title")
	title_btn.pressed.connect(func():
		if title_btn.text == "Title":
			title_btn.text = "Sure? Tap again"
			_set_status("Unsaved progress will be lost.")
		else:
			title_requested.emit())
	col.add_child(title_btn)


func _system_button(text: String) -> Button:
	var btn: Button = Button.new()
	btn.text = text
	btn.custom_minimum_size   = Vector2(0, 40)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return btn


# ── Tab routing ───────────────────────────────────────────────────────────────

func add_list(parent: Control, entries: Array[String], fill: Callable) -> void:
	SlotList.listed(parent, entries, fill)


# Collapsible shelves that open into the page — see SlotList.sections.
func add_sections(parent: Control, key: String, groups: Array, fill: Callable) -> void:
	SlotList.sections(parent, page, key, groups, fill)


func _switch_tab(tab_id: String) -> void:
	# A seed or stone half handed out is dropped by going to another tab.
	if tab_id != _active_tab:
		set_meta(MenuTabItems.GIVING, "")
	_active_tab      = tab_id
	_scroll.scroll_vertical = 0
	_status_line.text = ""
	if _side != null:
		_side.set_page(tab_id, _PAGE_NAMES.get(tab_id, "") as String)
	else:
		for id: String in _tab_btns:
			_tab_btns[id].button_pressed = (id == tab_id)
	for child: Node in _content.get_children():
		child.queue_free()
	match tab_id:
		"stats":     _tabs.build_stats()
		"items":     _tabs.build_items()
		"equipment": _tabs.build_equipment()
		"party":     _tabs.build_party()
		"magic":     _tabs.build_magic()
		"bestiary":  _tabs.build_bestiary()
		"system":    _build_system()


# Rebuilds the tab after an action — Equip, Use, Sell — without throwing the
# player back to the top of a list they had scrolled down.
func _refresh() -> void:
	var at: int = _scroll.scroll_vertical
	var cursor: int = _side.page_focus_index() if _side != null else -1
	# The action that asked for the refresh has just said what it did; the
	# rebuild clears the line, so put it back.
	var said: String = _status_line.text
	_switch_tab(_active_tab)
	_status_line.text = said
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(_scroll):
		_scroll.scroll_vertical = at
	if _side != null and is_instance_valid(_side):
		_side.focus_page_at(cursor)


func _set_status(msg: String) -> void:
	_status_line.text = msg

