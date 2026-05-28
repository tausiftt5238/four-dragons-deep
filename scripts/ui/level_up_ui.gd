# LevelUpUI
# Shown after a battle win causes a level-up.
# HP and MP increases are shown automatically; the player distributes
# 3 points per level gained among STR, DEF, MAG, and AGL.
class_name LevelUpUI extends Control

signal dismissed

var before:  Dictionary       # snapshot before gain_exp
var after:   Dictionary       # snapshot after gain_exp (HP/MP already updated)
var player:  PlayerCharacter  # live reference for apply_stat_bonus

const POINTS_PER_LEVEL: int = 3

var _pts_remaining: int = 0
var _allocated:     Dictionary = {str=0, def=0, mag=0, agl=0}

var _vbox:          VBoxContainer
var _remaining_lbl: Label
var _alloc_lbls:    Dictionary = {}   # stat_key → Label showing pending allocation
var _confirm_btn:   Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var levels_gained: int = after["lv"] - before["lv"]
	_pts_remaining = POINTS_PER_LEVEL * levels_gained
	_build()


func _build() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.04, 0.03, 0.06, 0.88)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var panel: Panel = Panel.new()
	panel.anchor_left   = 0.5;  panel.anchor_right  = 0.5
	panel.anchor_top    = 0.5;  panel.anchor_bottom = 0.5
	panel.offset_left   = -210; panel.offset_right  = 210
	panel.offset_top    = -280; panel.offset_bottom = 280
	add_child(panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for s: String in ["margin_left","margin_right","margin_top","margin_bottom"]:
		margin.add_theme_constant_override(s, 20)
	panel.add_child(margin)

	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 10)
	margin.add_child(_vbox)
	var vbox: VBoxContainer = _vbox

	# ── Header ────────────────────────────────────────────────────────────────
	var header: Label = Label.new()
	header.text = "✦   LEVEL UP!   ✦"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_color_override("font_color", Color(1.0, 0.88, 0.18))
	header.add_theme_font_size_override("font_size", 24)
	vbox.add_child(header)

	var lv_lbl: Label = Label.new()
	lv_lbl.text = "LEVEL  %d  →  %d" % [before["lv"], after["lv"]]
	lv_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lv_lbl.add_theme_color_override("font_color", Color(0.90, 0.82, 0.50))
	vbox.add_child(lv_lbl)

	vbox.add_child(HSeparator.new())

	# ── Auto-increases (HP / MP) ──────────────────────────────────────────────
	var auto_lbl: Label = Label.new()
	auto_lbl.text = "Auto-increases"
	auto_lbl.add_theme_color_override("font_color", Color(0.60, 0.60, 0.60))
	auto_lbl.add_theme_font_size_override("font_size", 12)
	vbox.add_child(auto_lbl)

	var auto_grid: GridContainer = GridContainer.new()
	auto_grid.columns = 3
	auto_grid.add_theme_constant_override("h_separation", 16)
	auto_grid.add_theme_constant_override("v_separation", 4)
	vbox.add_child(auto_grid)

	_auto_row(auto_grid, "Max HP", before["max_hp"], after["max_hp"])
	_auto_row(auto_grid, "Max MP", before["max_mp"], after["max_mp"])

	vbox.add_child(HSeparator.new())

	# ── Stat point allocation ─────────────────────────────────────────────────
	var pts_row: HBoxContainer = HBoxContainer.new()
	pts_row.add_theme_constant_override("separation", 8)
	vbox.add_child(pts_row)

	var invest_lbl: Label = Label.new()
	invest_lbl.text = "Invest  %d  points:" % (POINTS_PER_LEVEL * (after["lv"] - before["lv"]))
	invest_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	invest_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.55))
	pts_row.add_child(invest_lbl)

	_remaining_lbl = Label.new()
	_remaining_lbl.add_theme_color_override("font_color", Color(1.0, 0.75, 0.20))
	pts_row.add_child(_remaining_lbl)

	var alloc_grid: GridContainer = GridContainer.new()
	alloc_grid.columns = 4   # Name | base | [-][+] | pending
	alloc_grid.add_theme_constant_override("h_separation", 10)
	alloc_grid.add_theme_constant_override("v_separation", 6)
	vbox.add_child(alloc_grid)

	for stat: String in ["str", "def", "mag", "agl"]:
		_alloc_row(alloc_grid, stat)

	vbox.add_child(HSeparator.new())

	# ── Confirm ───────────────────────────────────────────────────────────────
	var btn_row: HBoxContainer = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	_confirm_btn = Button.new()
	_confirm_btn.text = "Confirm"
	_confirm_btn.custom_minimum_size = Vector2(130, 36)
	_confirm_btn.pressed.connect(_on_confirm)
	btn_row.add_child(_confirm_btn)

	_refresh_ui()


func _auto_row(grid: GridContainer, label: String, b: int, a: int) -> void:
	var n: Label = Label.new()
	n.text = label
	n.custom_minimum_size = Vector2(60, 0)
	grid.add_child(n)

	var bv: Label = Label.new()
	bv.text = str(b)
	bv.add_theme_color_override("font_color", Color(0.60, 0.60, 0.60))
	bv.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bv.custom_minimum_size  = Vector2(36, 0)
	grid.add_child(bv)

	var diff: int = a - b
	var av: Label = Label.new()
	av.text = "→ %d  (+%d)" % [a, diff] if diff > 0 else "→ %d" % a
	av.add_theme_color_override("font_color",
		Color(0.35, 0.95, 0.45) if diff > 0 else Color(0.80, 0.80, 0.80))
	grid.add_child(av)


func _alloc_row(grid: GridContainer, stat: String) -> void:
	var name_lbl: Label = Label.new()
	name_lbl.text = stat.to_upper()
	name_lbl.custom_minimum_size = Vector2(40, 0)
	grid.add_child(name_lbl)

	var base_lbl: Label = Label.new()
	base_lbl.text = str(after[stat])
	base_lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	base_lbl.custom_minimum_size   = Vector2(24, 0)
	base_lbl.horizontal_alignment  = HORIZONTAL_ALIGNMENT_RIGHT
	grid.add_child(base_lbl)

	var btn_box: HBoxContainer = HBoxContainer.new()
	btn_box.add_theme_constant_override("separation", 4)
	grid.add_child(btn_box)

	var minus_btn: Button = Button.new()
	minus_btn.text = "−"
	minus_btn.custom_minimum_size = Vector2(28, 26)
	minus_btn.pressed.connect(_on_minus.bind(stat))
	btn_box.add_child(minus_btn)

	var plus_btn: Button = Button.new()
	plus_btn.text = "+"
	plus_btn.custom_minimum_size = Vector2(28, 26)
	plus_btn.pressed.connect(_on_plus.bind(stat))
	btn_box.add_child(plus_btn)

	var alloc_lbl: Label = Label.new()
	alloc_lbl.custom_minimum_size  = Vector2(48, 0)
	alloc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	alloc_lbl.add_theme_color_override("font_color", Color(0.40, 0.95, 0.55))
	grid.add_child(alloc_lbl)
	_alloc_lbls[stat] = alloc_lbl


func _on_plus(stat: String) -> void:
	if _pts_remaining <= 0:
		return
	_allocated[stat] += 1
	_pts_remaining   -= 1
	_refresh_ui()


func _on_minus(stat: String) -> void:
	if _allocated[stat] <= 0:
		return
	_allocated[stat] -= 1
	_pts_remaining   += 1
	_refresh_ui()


func _refresh_ui() -> void:
	_remaining_lbl.text = "Remaining:  %d" % _pts_remaining
	_remaining_lbl.add_theme_color_override("font_color",
		Color(1.0, 0.40, 0.30) if _pts_remaining > 0 else Color(0.40, 0.95, 0.45))

	for stat: String in _alloc_lbls:
		var pts: int = _allocated[stat]
		var lbl: Label = _alloc_lbls[stat] as Label
		lbl.text = "+ %d" % pts if pts > 0 else "—"

	_confirm_btn.disabled = _pts_remaining > 0


func _on_confirm() -> void:
	player.apply_stat_bonus(_allocated)
	_show_skill_picker()


func _show_skill_picker() -> void:
	for c: Node in _vbox.get_children():
		c.queue_free()
	_vbox.alignment = BoxContainer.ALIGNMENT_CENTER

	var header: Label = Label.new()
	header.text = "✦   choose a skill   ✦"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_color_override("font_color", Color(0.60, 0.88, 1.0))
	header.add_theme_font_size_override("font_size", 20)
	_vbox.add_child(header)

	_vbox.add_child(HSeparator.new())

	var choices: Array[String] = PassiveSkill.random_pick(3, player.passive_skills)

	if choices.is_empty():
		var lbl: Label = Label.new()
		lbl.text = "All skills mastered!"
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_color_override("font_color", Color(0.80, 0.80, 0.80))
		_vbox.add_child(lbl)
		var cont: Button = Button.new()
		cont.text = "Continue"
		cont.custom_minimum_size = Vector2(160, 34)
		cont.pressed.connect(func(): dismissed.emit())
		var row: HBoxContainer = HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_child(cont)
		_vbox.add_child(row)
		return

	for skill_id: String in choices:
		var sdata: Dictionary = PassiveSkill.get_data(skill_id)
		_vbox.add_child(HSeparator.new())

		var btn: Button = Button.new()
		btn.text = sdata["name"] as String
		btn.custom_minimum_size = Vector2(300, 34)
		btn.pressed.connect(_on_skill_chosen.bind(skill_id))
		_vbox.add_child(btn)

		var desc: Label = Label.new()
		desc.text = sdata["desc"] as String
		desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc.add_theme_color_override("font_color", Color(0.60, 0.60, 0.60))
		desc.add_theme_font_size_override("font_size", 11)
		_vbox.add_child(desc)


func _on_skill_chosen(skill_id: String) -> void:
	player.passive_skills.append(skill_id)
	dismissed.emit()
