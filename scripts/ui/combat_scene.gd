# CombatScene
# Final-Fantasy-style combat layout:
#   top    – combat log (slim strip)
#   middle – enemy sprite + name + HP bar (fills remaining space)
#   bottom – [portrait/HP/MP/status] | [action buttons] | [item/magic submenu]
class_name CombatScene extends Control

signal combat_ended(result: String)

var player: PlayerCharacter
var enemy:  Enemy

var _defending: bool = false

var _log_label:      RichTextLabel
var _log_first_line: bool = true

var _player_lv_lbl:  Label
var _player_hp_bar:  ProgressBar
var _player_hp_lbl:  Label
var _player_mp_bar:  ProgressBar
var _player_mp_lbl:  Label
var _player_sts_lbl: Label

var _player_portrait: TextureRect
var _enemy_portrait:  TextureRect

var _enemy_hp_bar: ProgressBar
var _enemy_hp_lbl: Label

var _action_vbox: VBoxContainer
var _buttons: Dictionary = {}

var _right_title:    Label
var _right_back_btn: Button
var _right_list:     VBoxContainer



func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_refresh_hp()
	_refresh_button_states()
	_log("[color=yellow]A %s appeared![/color]" % enemy.enemy_name)


# ── UI construction ───────────────────────────────────────────────────────────

func _build_ui() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.06, 0.04, 0.10, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root: VBoxContainer = VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	_build_log_strip(root)
	_build_enemy_area(root)
	_build_bottom_bar(root)


func _build_log_strip(parent: Control) -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 80)
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	parent.add_child(panel)

	var m: MarginContainer = MarginContainer.new()
	for s: String in ["margin_left","margin_right","margin_top","margin_bottom"]:
		m.add_theme_constant_override(s, 8)
	panel.add_child(m)

	_log_label = RichTextLabel.new()
	_log_label.bbcode_enabled   = true
	_log_label.scroll_active    = true
	_log_label.scroll_following = true
	_log_label.add_theme_color_override("default_color", Color(0.88, 0.84, 0.74))
	m.add_child(_log_label)


func _build_enemy_area(parent: Control) -> void:
	var area: VBoxContainer = VBoxContainer.new()
	area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	area.alignment = BoxContainer.ALIGNMENT_CENTER
	area.add_theme_constant_override("separation", 8)
	parent.add_child(area)

	var icon: TextureRect = TextureRect.new()
	icon.texture               = load("res://icon.svg") as Texture2D
	icon.stretch_mode          = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size   = Vector2(130, 130)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.modulate              = Color(0.95, 0.28, 0.28)
	area.add_child(icon)
	_enemy_portrait = icon

	var name_lbl: Label = Label.new()
	name_lbl.text                 = enemy.enemy_name.to_upper()
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_color_override("font_color", Color(0.95, 0.35, 0.35))
	area.add_child(name_lbl)

	var hp_wrap: MarginContainer = MarginContainer.new()
	hp_wrap.custom_minimum_size   = Vector2(280, 0)
	hp_wrap.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	area.add_child(hp_wrap)

	var hp_col: VBoxContainer = VBoxContainer.new()
	hp_col.add_theme_constant_override("separation", 3)
	hp_wrap.add_child(hp_col)

	_enemy_hp_bar = _make_bar(enemy.max_hp)
	_enemy_hp_bar.add_theme_stylebox_override("fill", _bar_fill(Color(0.82, 0.12, 0.12)))
	hp_col.add_child(_enemy_hp_bar)

	_enemy_hp_lbl = Label.new()
	_enemy_hp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_enemy_hp_lbl.add_theme_color_override("font_color", Color(0.90, 0.60, 0.60))
	hp_col.add_child(_enemy_hp_lbl)


func _build_bottom_bar(parent: Control) -> void:
	var sep: HSeparator = HSeparator.new()
	parent.add_child(sep)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.size_flags_vertical = Control.SIZE_SHRINK_END
	hbox.add_theme_constant_override("separation", 0)
	parent.add_child(hbox)

	_build_player_col(hbox)
	_add_vsep(hbox)
	_build_action_col(hbox)
	_add_vsep(hbox)
	_build_submenu_col(hbox)


func _add_vsep(parent: Control) -> void:
	parent.add_child(VSeparator.new())


func _build_player_col(parent: Control) -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.size_flags_horizontal   = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 1.0
	parent.add_child(panel)

	var m: MarginContainer = MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for s: String in ["margin_left","margin_right","margin_top","margin_bottom"]:
		m.add_theme_constant_override(s, 10)
	panel.add_child(m)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	m.add_child(hbox)

	var portrait: TextureRect = TextureRect.new()
	portrait.texture             = load("res://icon.svg") as Texture2D
	portrait.stretch_mode        = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.custom_minimum_size = Vector2(72, 72)
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	portrait.modulate            = Color(0.55, 0.60, 0.78)
	hbox.add_child(portrait)
	_player_portrait = portrait

	var stats: VBoxContainer = VBoxContainer.new()
	stats.add_theme_constant_override("separation", 4)
	stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
	hbox.add_child(stats)

	var name_lbl: Label = Label.new()
	name_lbl.text = "HERO"
	name_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 1.0))
	stats.add_child(name_lbl)

	_player_lv_lbl = Label.new()
	_player_lv_lbl.add_theme_color_override("font_color", Color(0.60, 0.60, 0.85))
	stats.add_child(_player_lv_lbl)

	stats.add_child(_make_stat_row("HP",
		Color(0.35, 0.85, 0.35), Color(0.15, 0.65, 0.15), Color(0.45, 0.85, 0.45),
		func(b: ProgressBar) -> void: _player_hp_bar = b,
		func(l: Label)       -> void: _player_hp_lbl = l))

	stats.add_child(_make_stat_row("MP",
		Color(0.40, 0.55, 1.0), Color(0.20, 0.30, 0.90), Color(0.55, 0.65, 1.0),
		func(b: ProgressBar) -> void: _player_mp_bar = b,
		func(l: Label)       -> void: _player_mp_lbl = l))

	_player_sts_lbl = Label.new()
	_player_sts_lbl.add_theme_color_override("font_color", Color(0.90, 0.78, 0.30))
	_player_sts_lbl.add_theme_font_size_override("font_size", 11)
	stats.add_child(_player_sts_lbl)


func _make_stat_row(tag: String,
		tag_color: Color, bar_color: Color, val_color: Color,
		set_bar: Callable, set_lbl: Callable) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)

	var tag_lbl: Label = Label.new()
	tag_lbl.text               = tag
	tag_lbl.custom_minimum_size = Vector2(22, 0)
	tag_lbl.add_theme_color_override("font_color", tag_color)
	row.add_child(tag_lbl)

	var bar: ProgressBar = _make_bar(1)
	bar.add_theme_stylebox_override("fill", _bar_fill(bar_color))
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(bar)
	set_bar.call(bar)

	var val: Label = Label.new()
	val.custom_minimum_size = Vector2(68, 0)
	val.add_theme_color_override("font_color", val_color)
	row.add_child(val)
	set_lbl.call(val)

	return row


func _build_action_col(parent: Control) -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.size_flags_horizontal   = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 1.0
	parent.add_child(panel)

	var m: MarginContainer = MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for s: String in ["margin_left","margin_right","margin_top","margin_bottom"]:
		m.add_theme_constant_override(s, 10)
	panel.add_child(m)

	_action_vbox = VBoxContainer.new()
	_action_vbox.add_theme_constant_override("separation", 4)
	_action_vbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_action_vbox.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
	m.add_child(_action_vbox)

	for action: String in ["Attack", "Magic", "Item", "Defend", "Flee"]:
		var btn: Button = Button.new()
		btn.text                = action
		btn.custom_minimum_size = Vector2(140, 30)
		btn.pressed.connect(_on_action.bind(action))
		_action_vbox.add_child(btn)
		_buttons[action] = btn


func _build_submenu_col(parent: Control) -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.size_flags_horizontal   = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 1.0
	parent.add_child(panel)

	var m: MarginContainer = MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for s: String in ["margin_left","margin_right","margin_top","margin_bottom"]:
		m.add_theme_constant_override(s, 10)
	panel.add_child(m)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	m.add_child(vbox)

	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	vbox.add_child(header)

	_right_back_btn = Button.new()
	_right_back_btn.text = "< Back"
	_right_back_btn.pressed.connect(_show_main_actions)
	_right_back_btn.hide()
	header.add_child(_right_back_btn)

	_right_title = Label.new()
	_right_title.text = "—"
	_right_title.add_theme_color_override("font_color", Color(0.50, 0.50, 0.50))
	header.add_child(_right_title)

	vbox.add_child(HSeparator.new())

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	_right_list = VBoxContainer.new()
	_right_list.add_theme_constant_override("separation", 4)
	_right_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_right_list)


# ── Helpers ───────────────────────────────────────────────────────────────────

func _make_bar(max_val: int) -> ProgressBar:
	var bar: ProgressBar = ProgressBar.new()
	bar.min_value           = 0
	bar.max_value           = max(1, max_val)
	bar.value               = max_val
	bar.show_percentage     = false
	bar.custom_minimum_size = Vector2(0, 14)
	return bar


func _bar_fill(color: Color) -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = color
	return s


func _shake_portrait(node: TextureRect) -> void:
	node.pivot_offset = node.size / 2.0
	var tween: Tween = create_tween()
	tween.tween_property(node, "scale", Vector2(1.18, 0.82), 0.05)
	tween.tween_property(node, "scale", Vector2(0.88, 1.14), 0.06)
	tween.tween_property(node, "scale", Vector2(1.07, 0.94), 0.05)
	tween.tween_property(node, "scale", Vector2(1.0,  1.0),  0.05)


func _log(line: String) -> void:
	if not _log_first_line:
		_log_label.append_text("\n")
	_log_first_line = false
	_log_label.append_text(line)


func _refresh_hp() -> void:
	_player_lv_lbl.text = "LV %d" % player.lv

	_player_hp_bar.max_value = player.max_hp
	_player_hp_bar.value     = player.hp
	_player_hp_lbl.text      = "%d/%d" % [player.hp, player.max_hp]

	_player_mp_bar.max_value = player.max_mp
	_player_mp_bar.value     = player.mp
	_player_mp_lbl.text      = "%d/%d" % [player.mp, player.max_mp]

	_player_sts_lbl.text = _format_statuses(player.active_statuses)

	_enemy_hp_bar.max_value = enemy.max_hp
	_enemy_hp_bar.value     = enemy.hp
	_enemy_hp_lbl.text      = "HP %d / %d" % [enemy.hp, enemy.max_hp]


func _format_statuses(statuses: Array[String]) -> String:
	if statuses.is_empty():
		return ""
	var names: Array[String] = []
	for s: String in statuses:
		names.append(Status.get_data(s).get("name", s))
	return "  ".join(names)


func _set_buttons(enabled: bool) -> void:
	for btn: Button in _buttons.values():
		btn.disabled = not enabled


func _refresh_button_states() -> void:
	if player.has_status(Status.SILENCE):
		_buttons["Magic"].disabled = true
	if player.has_status(Status.IMMOBILIZE):
		_buttons["Attack"].disabled = true


# ── Submenus ──────────────────────────────────────────────────────────────────

func _show_actions() -> void:
	_action_vbox.modulate.a = 1.0
	for btn: Button in _buttons.values():
		btn.mouse_filter = Control.MOUSE_FILTER_STOP


func _hide_actions() -> void:
	_action_vbox.modulate.a = 0.0
	for btn: Button in _buttons.values():
		btn.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _show_main_actions() -> void:
	_show_actions()
	_right_back_btn.hide()
	_right_title.text = "—"
	_right_title.add_theme_color_override("font_color", Color(0.50, 0.50, 0.50))
	for child: Node in _right_list.get_children():
		child.queue_free()


func _show_magic_submenu() -> void:
	_hide_actions()
	_right_back_btn.show()
	_right_title.text = "MAGIC"
	_right_title.add_theme_color_override("font_color", Color(0.80, 0.50, 1.0))
	for child: Node in _right_list.get_children():
		child.queue_free()

	if player.known_spells.is_empty():
		_right_list.add_child(_dim_label("No spells known."))
		return

	for spell_id: String in player.known_spells:
		var data: Dictionary = Spell.DATA.get(spell_id, {name = spell_id, mp = 8})
		var btn: Button = Button.new()
		btn.text                = "%s  (%d MP)" % [data["name"], data["mp"]]
		btn.custom_minimum_size = Vector2(0, 28)
		btn.disabled            = player.mp < data["mp"]
		btn.pressed.connect(_on_cast_spell.bind(spell_id))
		_right_list.add_child(btn)


func _show_item_submenu() -> void:
	_hide_actions()
	_right_back_btn.show()
	_right_title.text = "ITEMS"
	_right_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.40))
	for child: Node in _right_list.get_children():
		child.queue_free()

	var found: bool = false
	for item: Dictionary in player.inventory:
		if item["type"] == "consumable":
			found = true
			var btn: Button = Button.new()
			btn.text                = "%s  x%d" % [item["name"], item.get("qty", 1)]
			btn.custom_minimum_size = Vector2(0, 28)
			btn.pressed.connect(_on_use_item.bind(item))
			_right_list.add_child(btn)

	if not found:
		_right_list.add_child(_dim_label("No items."))


func _dim_label(text: String) -> Label:
	var lbl: Label = Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", Color(0.40, 0.40, 0.40))
	return lbl


# ── Action handler ────────────────────────────────────────────────────────────

func _on_action(action: String) -> void:
	match action:
		"Magic":
			_show_magic_submenu()
			return
		"Item":
			_show_item_submenu()
			return
		"Flee":
			_set_buttons(false)
			await _do_flee()
			return

	_set_buttons(false)
	_dispatch_round(action)


func _on_cast_spell(spell_id: String) -> void:
	_show_main_actions()
	_set_buttons(false)
	_dispatch_round("Magic:" + spell_id)


func _on_use_item(item: Dictionary) -> void:
	_show_main_actions()
	_set_buttons(false)
	_dispatch_round("Item:" + item["id"])


func _dispatch_round(action: String) -> void:
	if enemy.agl > player.effective_agl():
		await _round_enemy_first(action)
	else:
		await _round_player_first(action)


# ── Round resolution ──────────────────────────────────────────────────────────

func _round_player_first(action: String) -> void:
	var e_hp_before: int = enemy.hp
	var p_msg: String = _apply_player_action(action)
	_refresh_hp()
	if enemy.hp < e_hp_before:
		_shake_portrait(_enemy_portrait)
	if not enemy.is_alive():
		_log(p_msg + "\n[color=lime]%s was defeated![/color]" % enemy.enemy_name)
		await get_tree().create_timer(1.8).timeout
		_end_combat("win")
		return
	var p_hp_before: int = player.hp
	var e_msg: String = _apply_enemy_turn()
	_refresh_hp()
	if player.hp < p_hp_before:
		_shake_portrait(_player_portrait)
	_log(p_msg + "\n" + e_msg)
	if not player.is_alive():
		await get_tree().create_timer(1.8).timeout
		_end_combat("lose")
		return
	await _do_end_of_round()


func _round_enemy_first(action: String) -> void:
	var p_hp_before: int = player.hp
	var e_msg: String = _apply_enemy_turn()
	_refresh_hp()
	if player.hp < p_hp_before:
		_shake_portrait(_player_portrait)
	if not player.is_alive():
		_log(e_msg + "\n[color=red]You were defeated...[/color]")
		await get_tree().create_timer(1.8).timeout
		_end_combat("lose")
		return
	var e_hp_before: int = enemy.hp
	var p_msg: String = _apply_player_action(action)
	_refresh_hp()
	if enemy.hp < e_hp_before:
		_shake_portrait(_enemy_portrait)
	_log(e_msg + "\n" + p_msg)
	if not enemy.is_alive():
		_log("[color=lime]%s was defeated![/color]" % enemy.enemy_name)
		await get_tree().create_timer(1.8).timeout
		_end_combat("win")
		return
	await _do_end_of_round()


func _do_end_of_round() -> void:
	var p_hp_before: int = player.hp
	var e_hp_before: int = enemy.hp
	var tick_msg: String = _do_poison_ticks()
	if not tick_msg.is_empty():
		_log(tick_msg)
		_refresh_hp()
		if player.hp < p_hp_before:
			_shake_portrait(_player_portrait)
		if enemy.hp < e_hp_before:
			_shake_portrait(_enemy_portrait)
	if not player.is_alive():
		await get_tree().create_timer(1.8).timeout
		_end_combat("lose")
		return
	if not enemy.is_alive():
		_log("[color=lime]%s succumbed to poison![/color]" % enemy.enemy_name)
		await get_tree().create_timer(1.8).timeout
		_end_combat("win")
		return
	await get_tree().create_timer(1.1).timeout
	if is_instance_valid(self):
		_set_buttons(true)
		_refresh_button_states()


func _do_poison_ticks() -> String:
	var msgs: Array[String] = []
	var p_dmg: int = player.poison_tick()
	if p_dmg > 0:
		msgs.append("[color=chartreuse]Poison deals %d damage to you![/color]" % p_dmg)
	var e_dmg: int = enemy.poison_tick()
	if e_dmg > 0:
		msgs.append("[color=violet]Poison deals %d damage to %s![/color]" % [e_dmg, enemy.enemy_name])
	return "\n".join(msgs)


# ── Individual action logic ───────────────────────────────────────────────────

func _apply_player_action(action: String) -> String:
	if player.has_status(Status.PARALYZED) and randi() % 4 == 0:
		return "[color=yellow]Paralyzed! You cannot act this turn.[/color]"
	if action.begins_with("Magic:"):
		return _cast_spell(action.substr(6))
	if action.begins_with("Item:"):
		return _use_item_by_id(action.substr(5))
	match action:
		"Attack":
			var dmg: int = max(1, player.effective_str() - enemy.def / 2 + randi() % 3)
			enemy.take_damage(dmg)
			return "You strike!  [color=orange]%s takes %d damage.[/color]" % [enemy.enemy_name, dmg]
		"Defend":
			_defending = true
			return "[color=cyan]You brace yourself. DEF doubled until next hit.[/color]"
	return ""


func _cast_spell(spell_id: String) -> String:
	var data: Dictionary = Spell.DATA.get(spell_id, {name = "Spell", mp = 8})
	var mp_cost: int = data.get("mp", 8)
	if player.mp < mp_cost:
		return "[color=gray]Not enough MP![/color]"
	player.mp -= mp_cost

	var spell_type: String = data.get("type", "dmg")

	if spell_type == "ailment":
		var target_status: String = data.get("status", "")
		if target_status == "":
			return "Nothing happened."
		if enemy.has_status(target_status):
			return "%s is already %s." % [enemy.enemy_name, Status.get_data(target_status).get("name", target_status)]
		enemy.apply_status(target_status)
		return "You cast %s!  [color=violet]%s is now %s.[/color]" % [
			data["name"], enemy.enemy_name, Status.get_data(target_status).get("name", target_status)]

	if spell_type == "heal":
		var heal_amt: int = data.get("heal", 30)
		var before: int = player.hp
		player.heal(max(1, heal_amt + player.effective_mag()))
		return "[color=lime]You cast %s! Restored %d HP.[/color]" % [data["name"], player.hp - before]

	# damage spell — apply elemental weakness
	var dmg: int = max(1, player.effective_mag() * 2 - enemy.def / 3 + randi() % 4)
	var element: String = data.get("element", "")
	var weak_tag: String = ""
	if element != "" and enemy.weakness == element:
		dmg *= 2
		weak_tag = "  [color=yellow]WEAKNESS![/color]"
	enemy.take_damage(dmg)
	return "You cast %s!%s  [color=violet]%s takes %d magic damage.[/color]" % [
		data["name"], weak_tag, enemy.enemy_name, dmg]


func _use_item_by_id(item_id: String) -> String:
	for item: Dictionary in player.inventory:
		if item["id"] == item_id and item["type"] == "consumable":
			var inflicts: String = item.get("inflicts_status", "")
			if inflicts != "":
				var sname: String = Status.get_data(inflicts).get("name", inflicts)
				player.remove_item(item, 1)
				if enemy.has_status(inflicts):
					return "[color=aqua]Used %s.[/color] %s is already %s." % [item["name"], enemy.enemy_name, sname]
				enemy.apply_status(inflicts)
				return "[color=aqua]Used %s![/color]  [color=violet]%s is now %s.[/color]" % [item["name"], enemy.enemy_name, sname]
			var element: String = item.get("element", "")
			var base_dmg: int = item.get("dmg", 0)
			if element != "" and base_dmg > 0:
				var dmg: int = base_dmg
				var weak_tag: String = ""
				if enemy.weakness == element:
					dmg *= 2
					weak_tag = "  [color=yellow]WEAKNESS![/color]"
				enemy.take_damage(dmg)
				player.remove_item(item, 1)
				return "[color=aqua]Used %s![/color]%s  [color=violet]%s takes %d damage.[/color]" % [
					item["name"], weak_tag, enemy.enemy_name, dmg]
			var result: String = player.use_item(item)
			return "[color=aqua]Used %s. %s[/color]" % [item["name"], result]
	return "[color=gray]Item not found.[/color]"


func _apply_enemy_turn() -> String:
	if enemy.has_status(Status.PARALYZED) and randi() % 4 == 0:
		return "[color=yellow]%s is paralyzed and cannot act![/color]" % enemy.enemy_name

	var eff_def: int = player.effective_def() * (2 if _defending else 1)
	_defending = false

	# 30% chance of status attack if enemy has one and player lacks the status
	if enemy.status_attack != "" and not player.has_status(enemy.status_attack) and randi() % 10 < 3:
		var sdata: Dictionary = Status.get_data(enemy.status_attack)
		var dmg: int = max(1, enemy.str / 2 - eff_def / 3 + randi() % 2)
		player.take_damage(dmg)
		player.apply_status(enemy.status_attack)
		return "[color=red]%s attacks for %d and inflicts %s![/color]" % [
			enemy.enemy_name, dmg, sdata.get("name", enemy.status_attack)]

	var dmg: int = max(1, enemy.str - eff_def / 2 + randi() % 3)
	player.take_damage(dmg)
	return "[color=red]%s attacks you for %d damage![/color]" % [enemy.enemy_name, dmg]


func _do_flee() -> void:
	if player.effective_agl() >= enemy.agl or randi() % 2 == 0:
		_log("You slip away into the darkness.")
		await get_tree().create_timer(0.9).timeout
		_end_combat("flee")
	else:
		var e_msg: String = _apply_enemy_turn()
		_refresh_hp()
		_log("[color=yellow]Failed to escape![/color]\n" + e_msg)
		if not player.is_alive():
			await get_tree().create_timer(1.8).timeout
			_end_combat("lose")
			return
		await get_tree().create_timer(1.1).timeout
		if is_instance_valid(self):
			_set_buttons(true)
			_refresh_button_states()


func _end_combat(result: String) -> void:
	combat_ended.emit(result)
	queue_free()
