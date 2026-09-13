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

	# Tabs across the top in two rows of three, Load and Close sharing a row
	# under them, and the content filling everything below. A sidebar down the
	# left would eat a quarter of a 540-wide screen.
	var shell: VBoxContainer = VBoxContainer.new()
	shell.add_theme_constant_override("separation", 0)
	margin.add_child(shell)

	var header: VBoxContainer = VBoxContainer.new()
	header.add_theme_constant_override("separation", 4)
	shell.add_child(header)

	var grid: GridContainer = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	header.add_child(grid)

	for tab_id: String in ["stats", "party", "items", "equipment", "magic", "bestiary"]:
		var btn: Button = Button.new()
		# "Equipment" overpromises now that there is no weapon and no armour.
		btn.text        = "Carried" if tab_id == "equipment" else tab_id.capitalize()
		btn.toggle_mode = true
		btn.custom_minimum_size     = Vector2(0, 36)
		btn.size_flags_horizontal   = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_switch_tab.bind(tab_id))
		grid.add_child(btn)
		_tab_btns[tab_id] = btn

	header.add_child(HSeparator.new())

	var foot: HBoxContainer = HBoxContainer.new()
	foot.add_theme_constant_override("separation", 6)
	header.add_child(foot)

	var load_btn: Button = Button.new()
	load_btn.text = "Load  [F9]"
	load_btn.custom_minimum_size   = Vector2(0, 32)
	load_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	load_btn.pressed.connect(func(): load_requested.emit())
	foot.add_child(load_btn)

	var close_btn: Button = Button.new()
	close_btn.text = "Close  [ESC]"
	close_btn.custom_minimum_size   = Vector2(0, 32)
	close_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_btn.pressed.connect(func(): menu_closed.emit())
	foot.add_child(close_btn)

	var sep_wrap: MarginContainer = MarginContainer.new()
	sep_wrap.add_theme_constant_override("margin_top",    8)
	sep_wrap.add_theme_constant_override("margin_bottom", 8)
	sep_wrap.add_child(HSeparator.new())
	shell.add_child(sep_wrap)

	# ── Right content area ────────────────────────────────────────────────────
	var right: VBoxContainer = VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	shell.add_child(right)

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

