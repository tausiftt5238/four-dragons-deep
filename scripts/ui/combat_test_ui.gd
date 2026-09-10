# CombatTestUI
# Standalone testing screen: configure player stats, pick an enemy, and fight.
# Accessible from the title screen. Hosts its own font hook since main.gd
# is not in the scene tree here.
class_name CombatTestUI extends Control

const _FONT := preload("res://resources/misc/OldSchoolAdventures-42j9.ttf") as FontFile

var _stats: Dictionary = {lv=1, str=5, def=4, mag=2, agl=3}
var _floor: int = 1
var _group_size: int = 4
var _group_lbl: Label
var _selected_enemy: String = ""

var _stat_lbls:   Dictionary = {}   # key -> Label showing current value
var _floor_lbl:   Label
var _hp_lbl:      Label
var _mp_lbl:      Label
var _preview_img: TextureRect
var _preview_name: Label
var _preview_info: Label
var _enemy_btns:  Dictionary = {}   # enemy name -> Button

var _setup_root: Control            # hidden while combat is running


func _ready() -> void:
	get_tree().node_added.connect(_apply_font)
	tree_exiting.connect(_on_tree_exiting)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	_select_enemy(Enemy.TEMPLATES[0]["name"] as String)


func _on_tree_exiting() -> void:
	if get_tree():
		get_tree().node_added.disconnect(_apply_font)


# Mirrors the font hook in main.gd so CombatScene nodes get the right font.
func _apply_font(node: Node) -> void:
	if node is RichTextLabel:
		(node as RichTextLabel).add_theme_font_override("normal_font", _FONT)
	elif node is Label:
		(node as Label).add_theme_font_override("font", _FONT)
		(node as Label).uppercase = true
	elif node is Button:
		(node as Button).add_theme_font_override("font", _FONT)
		(node as Button).text = (node as Button).text.to_upper()
	elif node is Control:
		(node as Control).add_theme_font_override("font", _FONT)


# ── Layout ────────────────────────────────────────────────────────────────────

func _build() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.04, 0.03, 0.07, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_setup_root = VBoxContainer.new()
	_setup_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	(_setup_root as VBoxContainer).add_theme_constant_override("separation", 0)
	add_child(_setup_root)

	_build_top_bar()

	(_setup_root as VBoxContainer).add_child(HSeparator.new())

	var content: HBoxContainer = HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 0)
	(_setup_root as VBoxContainer).add_child(content)

	_build_player_panel(content)
	content.add_child(VSeparator.new())
	_build_enemy_panel(content)

	(_setup_root as VBoxContainer).add_child(HSeparator.new())
	_build_fight_row()


func _build_top_bar() -> void:
	var m: MarginContainer = MarginContainer.new()
	for s: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		m.add_theme_constant_override(s, 10)
	(_setup_root as VBoxContainer).add_child(m)

	var bar: HBoxContainer = HBoxContainer.new()
	m.add_child(bar)

	var title: Label = Label.new()
	title.text = "COMBAT TESTING"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", Color(0.90, 0.75, 0.30))
	title.add_theme_font_size_override("font_size", 20)
	bar.add_child(title)

	var back: Button = Button.new()
	back.text = "Main Menu"
	back.custom_minimum_size = Vector2(130, 32)
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/title.tscn"))
	bar.add_child(back)


func _build_player_panel(parent: HBoxContainer) -> void:
	var m: MarginContainer = MarginContainer.new()
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for s: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		m.add_theme_constant_override(s, 16)
	parent.add_child(m)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 7)
	m.add_child(vbox)

	var hdr: Label = Label.new()
	hdr.text = "PLAYER STATS"
	hdr.add_theme_color_override("font_color", Color(0.70, 0.65, 0.50))
	vbox.add_child(hdr)
	vbox.add_child(HSeparator.new())

	for row: Array in [["lv", 1, 20], ["str", 1, 30], ["def", 1, 30], ["mag", 1, 30], ["agl", 1, 30]]:
		vbox.add_child(_make_stat_spinner(row[0] as String, int(row[1]), int(row[2])))

	vbox.add_child(HSeparator.new())

	_hp_lbl = Label.new()
	_hp_lbl.add_theme_color_override("font_color", Color(0.35, 0.85, 0.35))
	vbox.add_child(_hp_lbl)

	_mp_lbl = Label.new()
	_mp_lbl.add_theme_color_override("font_color", Color(0.40, 0.55, 1.0))
	vbox.add_child(_mp_lbl)

	_refresh_derived()


func _build_enemy_panel(parent: HBoxContainer) -> void:
	var m: MarginContainer = MarginContainer.new()
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for s: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		m.add_theme_constant_override(s, 16)
	parent.add_child(m)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 7)
	m.add_child(vbox)

	var hdr: Label = Label.new()
	hdr.text = "ENEMY"
	hdr.add_theme_color_override("font_color", Color(0.70, 0.65, 0.50))
	vbox.add_child(hdr)
	vbox.add_child(HSeparator.new())

	# Preview column + scrollable list side by side
	var mid: HBoxContainer = HBoxContainer.new()
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 14)
	vbox.add_child(mid)

	_build_enemy_preview(mid)
	mid.add_child(VSeparator.new())
	_build_enemy_list(mid)

	vbox.add_child(HSeparator.new())
	vbox.add_child(_make_floor_spinner())


func _build_enemy_preview(parent: HBoxContainer) -> void:
	var col: VBoxContainer = VBoxContainer.new()
	col.custom_minimum_size = Vector2(130, 0)
	col.add_theme_constant_override("separation", 6)
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(col)

	_preview_img = TextureRect.new()
	_preview_img.stretch_mode        = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview_img.custom_minimum_size = Vector2(96, 96)
	_preview_img.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_preview_img.texture_filter      = CanvasItem.TEXTURE_FILTER_NEAREST
	col.add_child(_preview_img)

	_preview_name = Label.new()
	_preview_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_preview_name.add_theme_color_override("font_color", Color(0.95, 0.82, 0.45))
	col.add_child(_preview_name)

	_preview_info = Label.new()
	_preview_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_preview_info.add_theme_color_override("font_color", Color(0.55, 0.55, 0.70))
	_preview_info.add_theme_font_size_override("font_size", 11)
	_preview_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_preview_info)


func _build_enemy_list(parent: HBoxContainer) -> void:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)

	var list: VBoxContainer = VBoxContainer.new()
	list.add_theme_constant_override("separation", 3)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	for tmpl: Dictionary in Enemy.TEMPLATES:
		var ename: String = tmpl["name"] as String
		var btn: Button = Button.new()
		btn.text = ename
		btn.custom_minimum_size = Vector2(0, 28)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_select_enemy.bind(ename))
		list.add_child(btn)
		_enemy_btns[ename] = btn


func _build_fight_row() -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.custom_minimum_size = Vector2(0, 56)
	(_setup_root as VBoxContainer).add_child(row)

	row.add_child(_make_group_spinner())

	var btn: Button = Button.new()
	btn.text = "FIGHT!"
	btn.custom_minimum_size = Vector2(220, 42)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.add_theme_color_override("font_color", Color(0.20, 1.0, 0.45))
	btn.pressed.connect(_on_fight)
	row.add_child(btn)


# ── Spinners ──────────────────────────────────────────────────────────────────

# How many copies of the selected demon to field, so 4-v-4 can be tried here.
func _make_group_spinner() -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var lbl: Label = Label.new()
	lbl.text = "PACK"
	lbl.custom_minimum_size = Vector2(44, 0)
	lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(lbl)

	var minus: Button = Button.new()
	minus.text = "-"
	minus.custom_minimum_size = Vector2(26, 26)
	minus.pressed.connect(func():
		_group_size = max(1, _group_size - 1)
		_group_lbl.text = str(_group_size)
	)
	row.add_child(minus)

	_group_lbl = Label.new()
	_group_lbl.text = str(_group_size)
	_group_lbl.custom_minimum_size = Vector2(34, 0)
	_group_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_group_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_group_lbl)

	var plus: Button = Button.new()
	plus.text = "+"
	plus.custom_minimum_size = Vector2(26, 26)
	plus.pressed.connect(func():
		_group_size = min(4, _group_size + 1)
		_group_lbl.text = str(_group_size)
	)
	row.add_child(plus)

	return row


func _make_stat_spinner(key: String, min_val: int, max_val: int) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var lbl: Label = Label.new()
	lbl.text = key.to_upper()
	lbl.custom_minimum_size = Vector2(38, 0)
	lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(lbl)

	var minus: Button = Button.new()
	minus.text = "-"
	minus.custom_minimum_size = Vector2(26, 26)
	minus.pressed.connect(func():
		_stats[key] = max(min_val, _stats[key] - 1)
		_refresh_derived()
	)
	row.add_child(minus)

	var val_lbl: Label = Label.new()
	val_lbl.text = str(_stats[key])
	val_lbl.custom_minimum_size = Vector2(34, 0)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(val_lbl)
	_stat_lbls[key] = val_lbl

	var plus: Button = Button.new()
	plus.text = "+"
	plus.custom_minimum_size = Vector2(26, 26)
	plus.pressed.connect(func():
		_stats[key] = min(max_val, _stats[key] + 1)
		_refresh_derived()
	)
	row.add_child(plus)

	return row


func _make_floor_spinner() -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var lbl: Label = Label.new()
	lbl.text = "FLOOR"
	lbl.custom_minimum_size = Vector2(44, 0)
	lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(lbl)

	var minus: Button = Button.new()
	minus.text = "-"
	minus.custom_minimum_size = Vector2(26, 26)
	minus.pressed.connect(func():
		_floor = max(1, _floor - 1)
		_floor_lbl.text = str(_floor)
		_update_enemy_preview()
	)
	row.add_child(minus)

	_floor_lbl = Label.new()
	_floor_lbl.text = str(_floor)
	_floor_lbl.custom_minimum_size = Vector2(34, 0)
	_floor_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_floor_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_floor_lbl)

	var plus: Button = Button.new()
	plus.text = "+"
	plus.custom_minimum_size = Vector2(26, 26)
	plus.pressed.connect(func():
		_floor = min(10, _floor + 1)
		_floor_lbl.text = str(_floor)
		_update_enemy_preview()
	)
	row.add_child(plus)

	return row


# ── State updates ─────────────────────────────────────────────────────────────

func _refresh_derived() -> void:
	for key: String in _stat_lbls:
		(_stat_lbls[key] as Label).text = str(_stats[key])
	var hp: int = _stats["lv"] * 10 + _stats["def"] * 3
	var mp: int = _stats["lv"] * 4  + _stats["mag"] * 3
	_hp_lbl.text = "HP  %d" % hp
	_mp_lbl.text = "MP  %d" % mp


func _select_enemy(ename: String) -> void:
	# Deselect previous
	if _enemy_btns.has(_selected_enemy):
		(_enemy_btns[_selected_enemy] as Button).modulate = Color(1, 1, 1)
	_selected_enemy = ename
	if _enemy_btns.has(ename):
		(_enemy_btns[ename] as Button).modulate = Color(0.35, 1.0, 0.55)
	_update_enemy_preview()


func _update_enemy_preview() -> void:
	var tmpl: Dictionary = {}
	for t: Dictionary in Enemy.TEMPLATES:
		if t["name"] == _selected_enemy:
			tmpl = t
			break
	if tmpl.is_empty():
		return

	var sprite: String = tmpl.get("sprite", "")
	if sprite != "":
		_preview_img.texture = load(sprite) as Texture2D
	else:
		_preview_img.texture = load("res://icon.svg") as Texture2D

	_preview_name.text = tmpl["name"] as String

	var bonus: int = _floor - 1
	var lines: Array[String] = []
	lines.append("STR %d  DEF %d  MAG %d" % [
		int(tmpl["str"]) + bonus, int(tmpl["def"]) + bonus, int(tmpl["mag"]) + bonus])
	lines.append("HP  %d" % ((_floor) * 10 + (int(tmpl["def"]) + bonus) * 3))
	var w: String = tmpl.get("weakness", "") as String
	if w != "":
		lines.append("Weak: %s" % w.capitalize())
	var ae: String = tmpl.get("attack_element", "") as String
	if ae != "":
		lines.append("Atk: %s" % ae.capitalize())
	_preview_info.text = "\n".join(lines)


# ── Fight ─────────────────────────────────────────────────────────────────────

func _on_fight() -> void:
	if _selected_enemy.is_empty():
		return

	var test_player: PlayerCharacter = PlayerCharacter.new()
	add_child(test_player)
	# Override with configured stats; strip equipment so base stats are pure
	test_player.lv              = _stats["lv"]
	test_player.str             = _stats["str"]
	test_player.def             = _stats["def"]
	test_player.mag             = _stats["mag"]
	test_player.agl             = _stats["agl"]
	test_player.equipped_weapon = {}
	test_player.equipped_armor  = {}
	test_player.compute_max_hp()
	test_player.compute_max_mp()

	var group: Array[Enemy] = []
	for _i: int in range(_group_size):
		var foe: Enemy = Enemy.make_from_name(_selected_enemy, _floor)
		add_child(foe)
		group.append(foe)

	var packed: PackedScene = load("res://scenes/combat.tscn") as PackedScene
	var scene: CombatScene  = packed.instantiate() as CombatScene
	scene.player = test_player
	scene.foes   = group.duplicate()
	scene.combat_ended.connect(func(result: String) -> void:
		for f: Enemy in group:
			f.queue_free()
		test_player.queue_free()
		_show_result(result)
	)

	_setup_root.hide()
	add_child(scene)


func _show_result(result: String) -> void:
	var overlay: Control = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.03, 0.03, 0.06, 0.96)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(bg)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 20)
	center.add_child(vbox)

	var msg_map: Dictionary = {
		win="VICTORY!", lose="DEFEATED...", flee="ESCAPED!", talk="NEGOTIATED!"
	}
	var color_map: Dictionary = {
		win=Color(0.30, 1.0, 0.45), lose=Color(0.90, 0.20, 0.20),
		flee=Color(0.95, 0.82, 0.30), talk=Color(0.50, 0.90, 0.70)
	}

	var res_lbl: Label = Label.new()
	res_lbl.text = msg_map.get(result, result.to_upper()) as String
	res_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	res_lbl.add_theme_color_override("font_color",
		color_map.get(result, Color.WHITE) as Color)
	res_lbl.add_theme_font_size_override("font_size", 34)
	vbox.add_child(res_lbl)

	var sub: Label = Label.new()
	sub.text = "%s  (floor %d)" % [_selected_enemy, _floor]
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", Color(0.55, 0.55, 0.65))
	vbox.add_child(sub)

	var btn_row: HBoxContainer = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	vbox.add_child(btn_row)

	var again_btn: Button = Button.new()
	again_btn.text = "Fight Again"
	again_btn.custom_minimum_size = Vector2(150, 38)
	again_btn.pressed.connect(func() -> void:
		overlay.queue_free()
		_setup_root.show()
	)
	btn_row.add_child(again_btn)

	var menu_btn: Button = Button.new()
	menu_btn.text = "Main Menu"
	menu_btn.custom_minimum_size = Vector2(150, 38)
	menu_btn.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/title.tscn")
	)
	btn_row.add_child(menu_btn)
