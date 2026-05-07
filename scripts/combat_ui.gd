# CombatUI
# Full-screen overlay that runs one turn-based combat encounter.
# Build it, set .player and .enemy, add it to a CanvasLayer, then listen for
# combat_ended("win"|"lose"|"flee"). The node frees itself when combat concludes.
class_name CombatUI extends Control

signal combat_ended(result: String)

var player: PlayerCharacter
var enemy:  Enemy

# Set true after the player chose Defend; consumed on the next enemy attack.
var _defending: bool = false

var _enemy_hp_bar:    ProgressBar
var _player_hp_bar:   ProgressBar
var _enemy_hp_label:  Label
var _player_hp_label: Label
var _log_label:       RichTextLabel
var _btn_row:         HBoxContainer
var _log_first_line:  bool = true


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_refresh_hp()
	_log("[color=yellow]A %s appeared![/color]" % enemy.enemy_name)


# ── UI construction ───────────────────────────────────────────────────────────

func _build_ui() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.04, 0.03, 0.06, 0.90)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Centred combat panel (480 × 520)
	var panel: Panel = Panel.new()
	panel.anchor_left   = 0.5
	panel.anchor_right  = 0.5
	panel.anchor_top    = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left   = -240
	panel.offset_right  = 240
	panel.offset_top    = -260
	panel.offset_bottom = 260
	add_child(panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left",   16)
	margin.add_theme_constant_override("margin_right",  16)
	margin.add_theme_constant_override("margin_top",    14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	# ── Enemy section ──
	var enemy_name_lbl: Label = Label.new()
	enemy_name_lbl.text = enemy.enemy_name.to_upper()
	enemy_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	enemy_name_lbl.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	vbox.add_child(enemy_name_lbl)

	_enemy_hp_label = Label.new()
	_enemy_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_enemy_hp_label)

	_enemy_hp_bar = _make_progress_bar(enemy.max_hp)
	vbox.add_child(_enemy_hp_bar)

	vbox.add_child(HSeparator.new())

	# ── Combat log ──
	_log_label = RichTextLabel.new()
	_log_label.bbcode_enabled  = true
	_log_label.scroll_active   = true
	_log_label.scroll_following = true  # auto-scroll to bottom on new text
	_log_label.custom_minimum_size = Vector2(0, 150)
	_log_label.add_theme_color_override("default_color", Color(0.88, 0.84, 0.74))
	vbox.add_child(_log_label)

	vbox.add_child(HSeparator.new())

	# ── Player section ──
	_player_hp_label = Label.new()
	_player_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_player_hp_label.add_theme_color_override("font_color", Color(0.35, 0.65, 0.95))
	vbox.add_child(_player_hp_label)

	_player_hp_bar = _make_progress_bar(player.max_hp)
	vbox.add_child(_player_hp_bar)

	# ── Action buttons ──
	_btn_row = HBoxContainer.new()
	_btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_btn_row.add_theme_constant_override("separation", 6)
	vbox.add_child(_btn_row)

	for action: String in ["Attack", "Defend", "Magic", "Item", "Flee"]:
		var btn: Button = Button.new()
		btn.text = action
		btn.custom_minimum_size = Vector2(76, 36)
		btn.pressed.connect(_on_action.bind(action))
		_btn_row.add_child(btn)


func _make_progress_bar(max_val: int) -> ProgressBar:
	var bar: ProgressBar = ProgressBar.new()
	bar.min_value = 0
	bar.max_value = max_val
	bar.value     = max_val
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 18)
	return bar


# ── Helpers ───────────────────────────────────────────────────────────────────

func _log(line: String) -> void:
	if not _log_first_line:
		_log_label.append_text("\n")
	_log_first_line = false
	_log_label.append_text(line)


func _refresh_hp() -> void:
	_enemy_hp_label.text  = "%s  HP %d / %d" % [enemy.enemy_name, enemy.hp, enemy.max_hp]
	_enemy_hp_bar.value   = enemy.hp

	_player_hp_label.text = "HP %d/%d    MP %d/%d    LV %d" % \
		[player.hp, player.max_hp, player.mp, player.max_mp, player.lv]
	_player_hp_bar.value  = player.hp


func _set_buttons(enabled: bool) -> void:
	for child: Node in _btn_row.get_children():
		if child is Button:
			(child as Button).disabled = not enabled


# ── Action handler ────────────────────────────────────────────────────────────

func _on_action(action: String) -> void:
	_set_buttons(false)

	# Flee is resolved before the normal combat round.
	if action == "Flee":
		await _do_flee()
		return

	# Item: use first available consumable. No turn consumed if pack is empty.
	if action == "Item":
		var found: Dictionary = {}
		for item: Dictionary in player.inventory:
			if item["type"] == "consumable":
				found = item
				break
		if found.is_empty():
			_log("No usable items.")
			_set_buttons(true)
			return
		# Falls through to round resolution with "Item" as the player action.

	# Magic: check MP before entering round resolution.
	if action == "Magic" and player.mp < 8:
		_log("[color=gray]Not enough MP to cast![/color]")
		_set_buttons(true)
		return

	# Resolve a full combat round. Higher effective AGL acts first.
	if enemy.agl > player.effective_agl():
		await _round_enemy_first(action)
	else:
		await _round_player_first(action)


# ── Round resolution ──────────────────────────────────────────────────────────

func _round_player_first(action: String) -> void:
	var p_msg: String = _apply_player_action(action)
	_refresh_hp()
	if not enemy.is_alive():
		_log(p_msg + "\n[color=lime]%s was defeated![/color]" % enemy.enemy_name)
		await get_tree().create_timer(1.8).timeout
		_end_combat("win")
		return
	var e_msg: String = _apply_enemy_turn()
	_refresh_hp()
	_log(p_msg + "\n" + e_msg)
	if not player.is_alive():
		await get_tree().create_timer(1.8).timeout
		_end_combat("lose")
		return
	await get_tree().create_timer(1.1).timeout
	if is_instance_valid(self):
		_set_buttons(true)


func _round_enemy_first(action: String) -> void:
	var e_msg: String = _apply_enemy_turn()
	_refresh_hp()
	if not player.is_alive():
		_log(e_msg + "\n[color=red]You were defeated...[/color]")
		await get_tree().create_timer(1.8).timeout
		_end_combat("lose")
		return
	var p_msg: String = _apply_player_action(action)
	_refresh_hp()
	_log(e_msg + "\n" + p_msg)
	if not enemy.is_alive():
		_log("[color=lime]%s was defeated![/color]" % enemy.enemy_name)
		await get_tree().create_timer(1.8).timeout
		_end_combat("win")
		return
	await get_tree().create_timer(1.1).timeout
	if is_instance_valid(self):
		_set_buttons(true)


# ── Individual action logic ───────────────────────────────────────────────────

func _apply_player_action(action: String) -> String:
	match action:
		"Attack":
			var dmg: int = max(1, player.effective_str() - enemy.def / 2 + randi() % 3)
			enemy.take_damage(dmg)
			return "You strike!  [color=orange]%s takes %d damage.[/color]" % [enemy.enemy_name, dmg]
		"Defend":
			_defending = true
			return "[color=cyan]You brace yourself. DEF doubled until next hit.[/color]"
		"Magic":
			player.mp -= 8
			var dmg: int = max(1, player.effective_mag() * 2 - enemy.def / 3 + randi() % 4)
			enemy.take_damage(dmg)
			return "You cast a spell!  [color=violet]%s takes %d magic damage.[/color]" % [enemy.enemy_name, dmg]
		"Item":
			# Use the first consumable found (already validated in _on_action).
			for item: Dictionary in player.inventory:
				if item["type"] == "consumable":
					var result: String = player.use_item(item)
					return "[color=aqua]Used %s. %s[/color]" % [item["name"], result]
	return ""


func _apply_enemy_turn() -> String:
	# _defending is consumed here so it only protects against one attack.
	var eff_def: int = player.effective_def() * (2 if _defending else 1)
	_defending = false
	var dmg: int = max(1, enemy.str - eff_def / 2 + randi() % 3)
	player.take_damage(dmg)
	return "[color=red]%s attacks you for %d damage![/color]" % [enemy.enemy_name, dmg]


func _do_flee() -> void:
	# Higher or equal effective AGL guarantees escape; otherwise 50 % chance.
	if player.effective_agl() >= enemy.agl or randi() % 2 == 0:
		_log("You slip away into the darkness.")
		await get_tree().create_timer(0.9).timeout
		_end_combat("flee")
	else:
		# Failed flee — enemy gets a free hit.
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


func _end_combat(result: String) -> void:
	combat_ended.emit(result)
	queue_free()
