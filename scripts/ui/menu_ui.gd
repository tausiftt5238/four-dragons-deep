# MenuUI
# In-game pause menu. Set .player before adding to the scene tree, then listen
# for menu_closed to clean up. Tab content is built by MenuTabs.
class_name MenuUI extends Control

signal menu_closed
signal load_requested


var player: PlayerCharacter

var _active_tab:  String = "stats"
var _tab_btns:    Dictionary = {}
var _content:     VBoxContainer
var _status_line: Label
var _tabs:        MenuTabs


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_shell()
	_tabs = MenuTabs.new(self)
	_switch_tab("stats")


# ── Shell (chrome that never changes) ────────────────────────────────────────

func _build_shell() -> void:
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

	# Held upright, a 138px sidebar eats a quarter of the screen and leaves the
	# content too narrow to hold a row. So the shell turns: tabs across the top,
	# content filling everything under them.
	var upright: bool = not _is_landscape()

	var shell: BoxContainer = VBoxContainer.new() if upright else HBoxContainer.new()
	shell.add_theme_constant_override("separation", 0)
	margin.add_child(shell)
	var hbox: BoxContainer = shell

	var sidebar: BoxContainer
	if upright:
		sidebar = VBoxContainer.new()
		sidebar.add_theme_constant_override("separation", 4)
	else:
		sidebar = VBoxContainer.new()
		sidebar.add_theme_constant_override("separation", 4)
		sidebar.custom_minimum_size = Vector2(138, 0)
	hbox.add_child(sidebar)

	# Upright, the six tabs run across in two rows of three; the Load and Close
	# buttons sit beside each other under them instead of at the foot of a
	# column that no longer exists.
	var tab_host: Container = sidebar
	if upright:
		var grid: GridContainer = GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 4)
		grid.add_theme_constant_override("v_separation", 4)
		sidebar.add_child(grid)
		tab_host = grid

	for tab_id: String in ["stats", "party", "items", "equipment", "magic", "bestiary"]:
		var btn: Button = Button.new()
		# "Equipment" overpromises now that there is no weapon and no armour.
		btn.text        = "Carried" if tab_id == "equipment" else tab_id.capitalize()
		btn.toggle_mode = true
		btn.custom_minimum_size     = Vector2(0, 36)
		btn.size_flags_horizontal   = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_switch_tab.bind(tab_id))
		tab_host.add_child(btn)
		_tab_btns[tab_id] = btn

	if not upright:
		var spacer: Control = Control.new()
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		sidebar.add_child(spacer)

	sidebar.add_child(HSeparator.new())

	# Upright these two share one row; in a column they stack as before.
	var foot: Container = sidebar
	if upright:
		var foot_row: HBoxContainer = HBoxContainer.new()
		foot_row.add_theme_constant_override("separation", 6)
		sidebar.add_child(foot_row)
		foot = foot_row

	var load_btn: Button = Button.new()
	load_btn.text = "Load  [F9]"
	load_btn.custom_minimum_size   = Vector2(0, 32)
	load_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	load_btn.pressed.connect(func(): load_requested.emit())
	foot.add_child(load_btn)

	if not upright:
		sidebar.add_child(HSeparator.new())

	var close_btn: Button = Button.new()
	close_btn.text = "Close  [ESC]"
	close_btn.custom_minimum_size   = Vector2(0, 32)
	close_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_btn.pressed.connect(func(): menu_closed.emit())
	foot.add_child(close_btn)

	# The divider turns with the shell.
	var sep_wrap: MarginContainer = MarginContainer.new()
	if upright:
		sep_wrap.add_theme_constant_override("margin_top",    8)
		sep_wrap.add_theme_constant_override("margin_bottom", 8)
		sep_wrap.add_child(HSeparator.new())
	else:
		sep_wrap.add_theme_constant_override("margin_left",  10)
		sep_wrap.add_theme_constant_override("margin_right", 10)
		sep_wrap.add_child(VSeparator.new())
	hbox.add_child(sep_wrap)

	# ── Right content area ────────────────────────────────────────────────────
	var right: VBoxContainer = VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	hbox.add_child(right)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(scroll)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 8)
	scroll.add_child(_content)

	right.add_child(HSeparator.new())

	_status_line = Label.new()
	_status_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_line.add_theme_color_override("font_color", Color(0.9, 0.85, 0.45))
	_status_line.custom_minimum_size = Vector2(0, 22)
	right.add_child(_status_line)


# ── Tab routing ───────────────────────────────────────────────────────────────

func _is_landscape() -> bool:
	var size: Vector2 = get_viewport_rect().size
	return size.x >= size.y


func _switch_tab(tab_id: String) -> void:
	_active_tab      = tab_id
	_status_line.text = ""
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


func _refresh() -> void:
	_switch_tab(_active_tab)


func _set_status(msg: String) -> void:
	_status_line.text = msg

