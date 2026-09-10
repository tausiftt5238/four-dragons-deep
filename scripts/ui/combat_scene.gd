# CombatScene
# Press-turn combat. Layout:
#   top    – combat log (slim strip)
#   middle – enemy sprite + name + HP bar (fills remaining space)
#   strip  – press-turn icons for both sides
#   bottom – [party roster] | [action buttons] | [item/magic submenu]
#
# A side opens its phase with one icon per living combatant and keeps acting
# until the icons run out, so weakness hits and criticals buy extra actions for
# whoever landed them — see PressTurn for the exact economy. The detective and
# his bound demons share the player side; summoning binds one into the party,
# which is what raises the icon count on the following phase.
class_name CombatScene extends Control

signal combat_ended(result: String)

var player: PlayerCharacter

# Every demon in this encounter. `enemy` is whichever one the player currently
# has targeted — it is kept as a plain field because the CombatNeg* handlers
# all address the demon they are talking to through it.
var foes: Array[Enemy] = []
var enemy: Enemy

# One row widget per foe: {foe, portrait, name_lbl, bar, hp_lbl, marker}.
var _foe_rows: Array[Dictionary] = []
var _foe_turn_idx: int = 0

# Demons removed by a successful negotiation rather than killed.
var _departed: Array[Enemy] = []

# The detective plus every demon he has bound this battle. Index 0 is always
# the detective; _actor is the member currently holding the turn.
const MAX_PARTY: int = 4
var party: Array[CharacterSheet] = []
var _actor_idx: int = 0

var _press:     PressTurn
var _foe_press: PressTurn

var _negotiation: CombatNegotiation

# When set, enemy actions ignore target selection and swing at this member.
# Used by the negotiation handlers, where the detective is the one talking.
var _force_target: CharacterSheet = null

var _log_label:      RichTextLabel
var _log_first_line: bool = true

var _player_name_lbl: Label
var _player_lv_lbl:  Label
var _player_hp_bar:  ProgressBar
var _player_hp_lbl:  Label
var _player_mp_bar:  ProgressBar
var _player_mp_lbl:  Label
var _player_sts_lbl: Label

var _player_portrait: TextureRect

var _icon_lbl:     Label   # player-side press-turn icons
var _foe_icon_lbl: Label   # enemy-side press-turn icons
var _party_box:    VBoxContainer
var _party_rows:   Array[Dictionary] = []   # {member, name_lbl, bar, val_lbl}


var _action_vbox: VBoxContainer
var _buttons: Dictionary = {}

var _right_title:    Label
var _right_back_btn: Button
var _right_list:     VBoxContainer
var _back_target:    Callable



func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if foes.is_empty() and enemy != null:
		foes = [enemy]      # single-foe callers still work unchanged
	_assign_battle_tags()
	enemy = foes[0]
	party = [player]
	_press     = PressTurn.new()
	_foe_press = PressTurn.new()
	_build_ui()
	_rebuild_party_rows()
	_refresh_hp()
	_negotiation = CombatNegotiation.new(self)
	_log("[color=yellow]%s[/color]" % _encounter_line())
	_begin_player_phase()


# ── UI construction ───────────────────────────────────────────────────────────

func _build_ui() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.04, 0.02, 0.08, 0.78)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root: VBoxContainer = VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	_build_log_strip(root)
	_build_enemy_area(root)
	_build_icon_strip(root)
	_build_bottom_bar(root)


# The press-turn readout. Both sides are always visible so the player can see a
# phase about to snowball against them, not just their own banked halves.
func _build_icon_strip(parent: Control) -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 30)
	panel.size_flags_vertical = Control.SIZE_SHRINK_END
	parent.add_child(panel)

	var m: MarginContainer = MarginContainer.new()
	for side: String in ["margin_left", "margin_right"]:
		m.add_theme_constant_override(side, 12)
	panel.add_child(m)

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	m.add_child(row)

	_icon_lbl = Label.new()
	_icon_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_icon_lbl.add_theme_color_override("font_color", Color(0.55, 0.95, 1.0))
	row.add_child(_icon_lbl)

	_foe_icon_lbl = Label.new()
	_foe_icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_foe_icon_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_foe_icon_lbl.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
	row.add_child(_foe_icon_lbl)


func _build_log_strip(parent: Control) -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 65)
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

	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	m.add_child(col)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	col.add_child(hbox)

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

	_player_name_lbl = Label.new()
	_player_name_lbl.text = PlayerCharacter.DISPLAY_NAME.to_upper()
	stats.add_child(_player_name_lbl)

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

	_party_box = VBoxContainer.new()
	_party_box.add_theme_constant_override("separation", 3)
	col.add_child(_party_box)


# ── Party roster ──────────────────────────────────────────────────────────────

# One compact row per bound demon, rebuilt whenever the party changes.
func _rebuild_party_rows() -> void:
	for child: Node in _party_box.get_children():
		child.queue_free()
	_party_rows.clear()

	for i: int in range(1, party.size()):
		var member: CharacterSheet = party[i]
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 5)

		var name_lbl: Label = Label.new()
		name_lbl.custom_minimum_size = Vector2(96, 0)
		name_lbl.add_theme_font_size_override("font_size", 11)
		row.add_child(name_lbl)

		var bar: ProgressBar = _make_bar(member.max_hp)
		bar.custom_minimum_size = Vector2(0, 9)
		bar.add_theme_stylebox_override("fill", _bar_fill(Color(0.30, 0.70, 0.45)))
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(bar)

		var val_lbl: Label = Label.new()
		val_lbl.custom_minimum_size = Vector2(58, 0)
		val_lbl.add_theme_font_size_override("font_size", 11)
		val_lbl.add_theme_color_override("font_color", Color(0.55, 0.80, 0.65))
		row.add_child(val_lbl)

		_party_box.add_child(row)
		_party_rows.append({member = member, name_lbl = name_lbl,
				bar = bar, val_lbl = val_lbl})


func _refresh_party_rows() -> void:
	for i: int in range(_party_rows.size()):
		var r: Dictionary = _party_rows[i]
		var member: CharacterSheet = r["member"] as CharacterSheet
		var name_lbl: Label = r["name_lbl"] as Label
		var bar: ProgressBar = r["bar"] as ProgressBar
		var is_actor: bool = (party[_actor_idx] == member) if _actor_idx < party.size() else false
		var label_text: String = (member as Enemy).enemy_name.to_upper()
		name_lbl.text = ("> " if is_actor else "  ") + label_text
		if not member.is_alive():
			name_lbl.add_theme_color_override("font_color", Color(0.40, 0.30, 0.30))
		elif is_actor:
			name_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.45))
		else:
			name_lbl.add_theme_color_override("font_color", Color(0.62, 0.82, 0.70))
		bar.max_value = member.max_hp
		bar.value     = member.hp
		(r["val_lbl"] as Label).text = "%d/%d" % [member.hp, member.max_hp]


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

	for action: String in ["Attack", "Skill", "Magic", "Item", "Defend", "Talk", "Summon", "Flee"]:
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
	_right_back_btn.pressed.connect(_on_back_pressed)
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
	_log_label.append_text(_uppercase_text(line))


func _uppercase_text(text: String) -> String:
	var result := ""
	var in_tag := false
	for ch: String in text:
		if ch == "[":
			in_tag = true
			result += ch
		elif ch == "]":
			in_tag = false
			result += ch
		else:
			result += ch.to_upper() if not in_tag else ch
	return result




func _refresh_icons() -> void:
	if _press == null or _foe_press == null:
		return
	if _press.has_turns():
		_icon_lbl.text = "PRESS  %s      %s'S TURN" % [
				_press.icons_string(), _actor_name().to_upper()]
	else:
		_icon_lbl.text = "PRESS  —"
	if _foe_press.has_turns():
		_foe_icon_lbl.text = "%s  %s" % [enemy.enemy_name.to_upper(),
				_foe_press.icons_string()]
	else:
		_foe_icon_lbl.text = "%s  —" % enemy.enemy_name.to_upper()


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



# ── Submenus ──────────────────────────────────────────────────────────────────

func _set_back(cb: Callable) -> void:
	_back_target = cb
	_right_back_btn.show()


func _on_back_pressed() -> void:
	if _back_target.is_valid():
		_back_target.call()


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
	_set_back(_show_main_actions)
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
	_set_back(_show_main_actions)
	_right_title.text = "ITEMS"
	_right_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.40))
	for child: Node in _right_list.get_children():
		child.queue_free()

	var found: bool = false
	for item: Dictionary in player.inventory:
		if item["type"] == "consumable":
			found = true
			var is_throwable: bool = item.has("inflicts_status") \
				or (item.has("element") and item.get("dmg", 0) > 0)
			var btn: Button = Button.new()
			btn.text                = "%s  x%d" % [item["name"], item.get("qty", 1)]
			btn.custom_minimum_size = Vector2(0, 28)
			btn.disabled            = not is_throwable and not player.can_use_item(item)
			btn.pressed.connect(_on_use_item.bind(item))
			_right_list.add_child(btn)

	if not found:
		_right_list.add_child(_dim_label("No items."))


func _show_talk_submenu() -> void:
	_hide_actions()
	_set_back(_show_main_actions)
	_right_title.text = "TALK  %s" % enemy.display_name().to_upper()
	_right_title.add_theme_color_override("font_color", Color(0.50, 1.0, 0.70))
	for child: Node in _right_list.get_children():
		child.queue_free()

	var opts: Array[Array] = [
		["Reason",   "Negotiate"],
		["Bribe",    "Bribe"],
		["Threaten", "Threaten"],
		["Recruit",  "Recruit"],
	]
	for opt: Array in opts:
		var btn: Button = Button.new()
		btn.text                = opt[1] as String
		btn.custom_minimum_size = Vector2(0, 28)
		if opt[0] == "Recruit" and enemy.enemy_name in player.recruited:
			btn.text     = "Recruit (have)"
			btn.disabled = true
		btn.pressed.connect(_on_talk.bind(opt[0] as String))
		_right_list.add_child(btn)



func _on_talk(approach: String) -> void:
	_negotiation.start(approach)


func _dim_label(text: String) -> Label:
	var lbl: Label = Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", Color(0.40, 0.40, 0.40))
	return lbl


# ── Action handler ────────────────────────────────────────────────────────────




# ── Round resolution ──────────────────────────────────────────────────────────





# ── Damage helpers ────────────────────────────────────────────────────────────

func _apply_variance(dmg: int) -> int:
	return max(1, roundi(dmg * randf_range(0.8, 1.2)))

func _roll_crit() -> bool:
	return randi() % 10 == 0


# ── Individual action logic ───────────────────────────────────────────────────



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
				var state: String = enemy.affinity_of(element)
				var dmg: int = base_dmg
				player.remove_item(item, 1)
				if state == Affinity.DRAIN:
					enemy.heal(dmg)
					return "[color=aqua]Used %s![/color]  [color=lime]%s absorbs it and recovers %d HP![/color]" % [
						item["name"], enemy.enemy_name, dmg]
				if state == Affinity.REPEL:
					player.take_damage(dmg)
					return "[color=aqua]Used %s![/color]  [color=#d070ff]Repelled! You take %d damage![/color]" % [
						item["name"], dmg]
				dmg = max(1, roundi(dmg * Affinity.multiplier(state)))
				var weak_tag: String = "  [color=yellow]WEAK![/color]" if state == Affinity.WEAK else ""
				enemy.take_damage(dmg)
				return "[color=aqua]Used %s![/color]%s  [color=violet]%s takes %d damage.[/color]" % [
					item["name"], weak_tag, enemy.enemy_name, dmg]
			var result: String = player.use_item(item)
			return "[color=aqua]Used %s. %s[/color]" % [item["name"], result]
	return "[color=gray]Item not found.[/color]"



func _check_counter() -> String:
	if "counter" not in player.passive_skills or not player.is_alive() or randi() % 4 != 0:
		return ""
	var dmg: int = _apply_variance(player.effective_str() - enemy.def / 2)
	var crit: bool = _roll_crit()
	if crit:
		dmg = int(dmg * 1.75)
	dmg = max(1, dmg)
	enemy.take_damage(dmg)
	var crit_tag: String = " [CRITICAL!]" if crit else ""
	return "\n[color=orange]Counter! You strike back for %d damage!%s[/color]" % [dmg, crit_tag]



func _end_combat(result: String) -> void:
	combat_ended.emit(result)
	queue_free()


# ── Phase flow ────────────────────────────────────────────────────────────────

func _living_party() -> Array[CharacterSheet]:
	var out: Array[CharacterSheet] = []
	for m: CharacterSheet in party:
		if m.is_alive():
			out.append(m)
	return out


func _actor() -> CharacterSheet:
	return party[clampi(_actor_idx, 0, party.size() - 1)]


func _actor_is_player() -> bool:
	return _actor_idx == 0


func _member_name(member: CharacterSheet) -> String:
	if member == player:
		return PlayerCharacter.DISPLAY_NAME
	return (member as Enemy).enemy_name


func _actor_name() -> String:
	return _member_name(_actor())


func _next_living(from_idx: int) -> int:
	for step: int in range(1, party.size() + 1):
		var idx: int = (from_idx + step) % party.size()
		if party[idx].is_alive():
			return idx
	return from_idx


# One icon per living party member. A demon bound during this phase does not
# add its icon until the next one, which is what stops summoning from looping.
func _begin_player_phase() -> void:
	_press.begin(_living_party().size())
	_actor_idx = 0 if party[0].is_alive() else _next_living(0)
	_prompt_actor()


func _prompt_actor() -> void:
	_refresh_hp()
	_show_main_actions()
	_set_buttons(true)
	_refresh_button_states()


# Every player-side action funnels through here, so the icon economy has
# exactly one owner and the phase can only end in one place.

func _do_end_of_round() -> void:
	var tick_msg: String = _do_poison_ticks()
	if not tick_msg.is_empty():
		_log(tick_msg)
		_refresh_hp()
	if _living_party().is_empty():
		await get_tree().create_timer(1.6).timeout
		if is_instance_valid(self):
			_end_combat("lose")
		return
	if not enemy.is_alive():
		_log("[color=lime]%s succumbed to poison![/color]" % enemy.enemy_name)
		await get_tree().create_timer(1.6).timeout
		if is_instance_valid(self):
			_end_combat("win")
		return
	if "meditate" in player.passive_skills:
		var mp_gain: int = min(2, player.max_mp - player.mp)
		if mp_gain > 0:
			player.mp += mp_gain
	await get_tree().create_timer(0.7).timeout
	if is_instance_valid(self):
		_begin_player_phase()



# ── Player-side actions ───────────────────────────────────────────────────────

func _on_action(action: String) -> void:
	match action:
		"Magic":
			_show_magic_submenu()
			return
		"Item":
			_show_item_submenu()
			return
		"Talk":
			_with_target(func() -> void:
				if not enemy.negotiable:
					_log("[color=gray]%s won't listen.[/color]" % enemy.display_name())
					_show_main_actions()
					_set_buttons(true)
					_refresh_button_states()
					return
				_show_talk_submenu())
			return
		"Summon":
			_show_summon_submenu()
			return
		"Flee":
			_set_buttons(false)
			await _do_flee()
			return

	_with_target(func() -> void: await _commit_action(action))


func _commit_action(action: String) -> void:
	_show_main_actions()
	_set_buttons(false)
	var res: Dictionary = _resolve_action(action)
	_log(res["msg"] as String)
	await _after_action(res["cost"] as String)


func _on_cast_spell(spell_id: String) -> void:
	# Healing needs no target; anything thrown at the line-up does.
	var data: Dictionary = Spell.DATA.get(spell_id, {})
	if data.get("type", "dmg") == "heal":
		await _commit_spell(spell_id)
		return
	_with_target(func() -> void: await _commit_spell(spell_id))


func _commit_spell(spell_id: String) -> void:
	_show_main_actions()
	_set_buttons(false)
	var res: Dictionary = _cast_spell(spell_id)
	_log(res["msg"] as String)
	await _after_action(res["cost"] as String)


func _on_use_item(item: Dictionary) -> void:
	var offensive: bool = item.has("inflicts_status") \
			or (item.has("element") and item.get("dmg", 0) > 0)
	if not offensive:
		await _commit_item(item)
		return
	_with_target(func() -> void: await _commit_item(item))


func _commit_item(item: Dictionary) -> void:
	_show_main_actions()
	_set_buttons(false)
	_log(_use_item_by_id(item["id"] as String))
	await _after_action(PressTurn.COST_FULL)


# Returns { msg, cost } — the log line and what the action cost in icons.
func _resolve_action(action: String) -> Dictionary:
	var actor: CharacterSheet = _actor()
	if actor.has_status(Status.PARALYZED) and randi() % 4 == 0:
		return {msg = "[color=yellow]%s is paralyzed and cannot act![/color]" % _actor_name(),
				cost = PressTurn.COST_FULL}
	if action.begins_with("Magic:"):
		return _cast_spell(action.substr(6))
	match action:
		"Attack":
			return _resolve_attack()
		"Skill":
			return _resolve_skill()
		"Defend":
			actor.defending = true
			return {msg = "[color=cyan]%s braces. DEF doubled until struck.[/color]" % _actor_name(),
					cost = PressTurn.COST_FULL}
	return {msg = "", cost = PressTurn.COST_FULL}


func _resolve_attack() -> Dictionary:
	var actor: CharacterSheet = _actor()
	var atk: int = player.effective_str() if _actor_is_player() else actor.str
	if _actor_is_player() and "last_stand" in player.passive_skills \
			and player.hp * 4 < player.max_hp:
		atk *= 2
	var crit: bool = CombatMath.roll_crit()
	var res: Dictionary = CombatMath.resolve(atk - enemy.def / 2, Affinity.PHYS, enemy, crit)
	return _land_hit(res, Affinity.PHYS, "%s strikes!" % _actor_name())


# A bound demon's own element. This is the whole reason to carry a varied
# roster rather than the three strongest things you have met.
func _resolve_skill() -> Dictionary:
	var actor: Enemy = _actor() as Enemy
	var element: String = actor.attack_element
	if element == "":
		return {msg = "[color=gray]%s has nothing to call on.[/color]" % actor.enemy_name,
				cost = PressTurn.COST_FULL}
	var crit: bool = CombatMath.roll_crit()
	var res: Dictionary = CombatMath.resolve(actor.mag * 2 - enemy.def / 3, element, enemy, crit)
	return _land_hit(res, element, "%s calls up %s!" % [
			actor.enemy_name, Affinity.element_name(element)])


# Applies a resolved hit to the enemy and turns the outcome into an icon cost.
func _land_hit(res: Dictionary, element: String, prefix: String) -> Dictionary:
	var outcome: String = res["outcome"] as String
	var dmg: int        = res["dmg"] as int
	var crit: bool      = res["crit"] as bool
	var actor: CharacterSheet = _actor()

	match outcome:
		"drain":
			enemy.heal(dmg)
			return {msg = "%s  [color=lime]%s absorbs it and recovers %d HP![/color]" % [
					prefix, enemy.display_name(), dmg], cost = PressTurn.COST_LOST}
		"repel":
			actor.take_damage(dmg)
			if actor == player:
				_shake_portrait(_player_portrait)
			return {msg = "%s  [color=#d070ff]Repelled! %s takes %d damage![/color]" % [
					prefix, _member_name(actor), dmg], cost = PressTurn.COST_LOST}
		"null":
			return {msg = "%s  [color=#999999]No effect.[/color]" % prefix,
					cost = PressTurn.COST_MISS}

	enemy.take_damage(dmg)
	var pr: TextureRect = _foe_portrait(enemy)
	if pr != null:
		_shake_portrait(pr)
	var extra: String = ""
	if _actor_is_player() and element == Affinity.PHYS \
			and "vampiric" in player.passive_skills:
		var heal_amt: int = max(1, dmg / 5)
		player.heal(heal_amt)
		extra = "  [color=lime]Vampiric: +%d HP.[/color]" % heal_amt
	var downed: String = ""
	if not enemy.is_alive():
		downed = "  [color=lime]%s goes down![/color]" % enemy.display_name()
	return {msg = "%s%s  [color=orange]%s takes %d damage.[/color]%s%s" % [
			prefix, CombatMath.outcome_tag(outcome, crit), enemy.display_name(),
			dmg, extra, downed],
			cost = CombatMath.cost_for(outcome, crit)}


func _cast_spell(spell_id: String) -> Dictionary:
	var data: Dictionary = Spell.DATA.get(spell_id, {name = "Spell", mp = 8})
	var mp_cost: int = data.get("mp", 8)
	if player.mp < mp_cost:
		return {msg = "[color=gray]Not enough MP![/color]", cost = PressTurn.COST_FULL}
	player.mp -= mp_cost

	var spell_type: String = data.get("type", "dmg")

	if spell_type == "ailment":
		var target_status: String = data.get("status", "")
		if target_status == "" or enemy.has_status(target_status):
			return {msg = "[color=gray]Nothing happened.[/color]", cost = PressTurn.COST_FULL}
		enemy.apply_status(target_status)
		return {msg = "You cast %s!  [color=violet]%s is now %s.[/color]" % [
				data["name"], enemy.enemy_name,
				Status.get_data(target_status).get("name", target_status)],
				cost = PressTurn.COST_FULL}

	if spell_type == "heal":
		var heal_amt: int = data.get("heal", 30)
		var before: int = player.hp
		player.heal(max(1, heal_amt + player.effective_mag()))
		return {msg = "[color=lime]You cast %s! Restored %d HP.[/color]" % [
				data["name"], player.hp - before], cost = PressTurn.COST_FULL}

	var element: String = data.get("element", "")
	var base: int = player.effective_mag() * 2 - enemy.def / 3
	if "scholar" in player.passive_skills:
		base = int(base * 1.25)
	var crit: bool = CombatMath.roll_crit()
	var res: Dictionary = CombatMath.resolve(base, element, enemy, crit)
	return _land_hit(res, element, "You cast %s!" % data["name"])


# ── Enemy side ────────────────────────────────────────────────────────────────

# Picks a target and resolves one enemy action. Returns { msg, cost }.

func _pick_target(element: String) -> CharacterSheet:
	if _force_target != null and _force_target.is_alive():
		return _force_target
	var living: Array[CharacterSheet] = _living_party()
	if living.size() <= 1:
		return living[0]
	var exposed: Array[CharacterSheet] = []
	for m: CharacterSheet in living:
		if m.affinity_of(element) == Affinity.WEAK:
			exposed.append(m)
	if not exposed.is_empty() and randi() % 10 < 7:
		return exposed[randi() % exposed.size()]
	return living[randi() % living.size()]


func _defense_of(member: CharacterSheet) -> int:
	if member == player:
		return player.effective_def()
	return member.def


func _try_enemy_status(actor: Enemy, target: CharacterSheet) -> String:
	if actor.status_attack == "" or target.has_status(actor.status_attack):
		return ""
	var chance: int = clampi(15 + (actor.lv - player.lv) * 3, 5, 40)
	if randi() % 100 >= chance:
		return ""
	var sname: String = Status.get_data(actor.status_attack).get("name", actor.status_attack)
	if target == player and "resilience" in player.passive_skills and randi() % 4 == 0:
		return "  [color=lime]Resilience resists %s![/color]" % sname
	target.apply_status(actor.status_attack)
	return "  [color=violet]%s is now %s.[/color]" % [_member_name(target), sname]


# Kept for the CombatNeg* handlers: one provoked swing at the detective, taken
# outside the icon economy because a failed negotiation is its own risk.
func _apply_enemy_turn() -> String:
	_force_target = player
	var res: Dictionary = _enemy_act(enemy)
	_force_target = null
	return res["msg"] as String


# Called by the CombatNeg* handlers when an attempt ends without a deal. The
# attempt cost the actor its turn, so the phase moves on.
func _talk_attempt_failed() -> void:
	await _after_action(PressTurn.COST_FULL)


# ── Summoning ─────────────────────────────────────────────────────────────────

func _available_summons() -> Array[String]:
	var bound: Array[String] = []
	for i: int in range(1, party.size()):
		bound.append((party[i] as Enemy).enemy_name)
	var out: Array[String] = []
	for name: String in player.recruited:
		if name not in bound:
			out.append(name)
	return out


func _show_summon_submenu() -> void:
	_hide_actions()
	_set_back(_show_main_actions)
	_right_title.text = "SUMMON"
	_right_title.add_theme_color_override("font_color", Color(0.40, 1.0, 0.55))
	for child: Node in _right_list.get_children():
		child.queue_free()

	var options: Array[String] = _available_summons()
	if options.is_empty():
		_right_list.add_child(_dim_label("Nothing left to call."))
		return
	for summon_name: String in options:
		var btn: Button = Button.new()
		btn.text                = summon_name
		btn.custom_minimum_size = Vector2(0, 28)
		btn.pressed.connect(_on_summon.bind(summon_name))
		_right_list.add_child(btn)


# Binding costs a full icon and the demon joins at the detective's own level.
# Its icon arrives with the next phase, not this one.
func _on_summon(summon_name: String) -> void:
	_show_main_actions()
	_set_buttons(false)
	var demon: Enemy = Enemy.make_from_name(summon_name, max(1, player.lv))
	add_child(demon)
	party.append(demon)
	_rebuild_party_rows()
	_log("[color=#7fe0a0]%s answers the call.[/color]" % demon.enemy_name)
	await _after_action(PressTurn.COST_FULL)


# ── Fleeing ───────────────────────────────────────────────────────────────────


# ── Button state ──────────────────────────────────────────────────────────────


# ── The enemy line-up ─────────────────────────────────────────────────────────

# Three Bats need telling apart before anything else reads correctly.
func _assign_battle_tags() -> void:
	var counts: Dictionary = {}
	for f: Enemy in foes:
		counts[f.enemy_name] = int(counts.get(f.enemy_name, 0)) + 1
	var seen: Dictionary = {}
	const TAGS: Array[String] = ["A", "B", "C", "D"]
	for f: Enemy in foes:
		if int(counts[f.enemy_name]) > 1:
			var i: int = int(seen.get(f.enemy_name, 0))
			f.battle_tag = TAGS[mini(i, TAGS.size() - 1)]
			seen[f.enemy_name] = i + 1


func _encounter_line() -> String:
	if foes.size() == 1:
		return "%s appeared!" % foes[0].enemy_name
	var names: Array[String] = []
	for f: Enemy in foes:
		names.append(f.display_name())
	return "%s appeared!" % ", ".join(names)


func _living_foes() -> Array[Enemy]:
	var out: Array[Enemy] = []
	for f: Enemy in foes:
		if f.is_alive():
			out.append(f)
	return out


# Keeps the targeted foe on something that is still standing.
func _ensure_target() -> void:
	if enemy != null and enemy.is_alive():
		return
	var living: Array[Enemy] = _living_foes()
	if not living.is_empty():
		enemy = living[0]


func _build_enemy_area(parent: Control) -> void:
	var area: HBoxContainer = HBoxContainer.new()
	area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	area.alignment = BoxContainer.ALIGNMENT_CENTER
	area.add_theme_constant_override("separation", 6)
	parent.add_child(area)

	for f: Enemy in foes:
		area.add_child(_build_foe_column(f))


# One column per demon. Identical geometry across the row so a four-strong
# pack reads as one line-up rather than four separate widgets.
func _build_foe_column(foe: Enemy) -> Control:
	var col: VBoxContainer = VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_END
	col.add_theme_constant_override("separation", 3)

	var icon: TextureRect = TextureRect.new()
	if foe.sprite_path != "":
		icon.texture        = load(foe.sprite_path) as Texture2D
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	else:
		icon.texture  = load("res://icon.svg") as Texture2D
		icon.modulate = Color(0.95, 0.28, 0.28)
	icon.stretch_mode          = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_horizontal = Control.SIZE_FILL
	icon.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	col.add_child(icon)

	# The marker sits directly over the name so it reads as pointing at this
	# demon rather than floating at the top of the column.
	var marker: Label = Label.new()
	marker.text                 = "\u25bc"
	marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	marker.add_theme_font_size_override("font_size", 12)
	marker.add_theme_color_override("font_color", Color(1.0, 0.92, 0.45))
	col.add_child(marker)

	var name_lbl: Label = Label.new()
	name_lbl.text                 = foe.display_name().to_upper()
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 13)
	col.add_child(name_lbl)

	var bar_wrap: MarginContainer = MarginContainer.new()
	for side: String in ["margin_left", "margin_right"]:
		bar_wrap.add_theme_constant_override(side, 14)
	col.add_child(bar_wrap)

	var bar: ProgressBar = _make_bar(foe.max_hp)
	bar.custom_minimum_size = Vector2(0, 10)
	bar.add_theme_stylebox_override("fill", _bar_fill(Color(0.82, 0.12, 0.12)))
	bar_wrap.add_child(bar)

	var hp_lbl: Label = Label.new()
	hp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_lbl.add_theme_font_size_override("font_size", 11)
	hp_lbl.add_theme_color_override("font_color", Color(0.90, 0.60, 0.60))
	col.add_child(hp_lbl)

	_foe_rows.append({foe = foe, portrait = icon, name_lbl = name_lbl,
			bar = bar, hp_lbl = hp_lbl, marker = marker})
	return col


func _foe_portrait(foe: Enemy) -> TextureRect:
	for r: Dictionary in _foe_rows:
		if r["foe"] == foe:
			return r["portrait"] as TextureRect
	return null


# ── Target picking ────────────────────────────────────────────────────────────

# Runs `cb` once a target is settled. With one demon left there is nothing to
# choose, so the step is skipped rather than clicked through.
func _with_target(cb: Callable) -> void:
	var living: Array[Enemy] = _living_foes()
	if living.size() <= 1:
		_ensure_target()
		cb.call()
		return
	_hide_actions()
	_set_back(_show_main_actions)
	_right_title.text = "TARGET"
	_right_title.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45))
	for child: Node in _right_list.get_children():
		child.queue_free()
	for foe: Enemy in living:
		var btn: Button = Button.new()
		btn.text                = "%s   %d/%d" % [foe.display_name(), foe.hp, foe.max_hp]
		btn.custom_minimum_size = Vector2(0, 28)
		btn.pressed.connect(func() -> void:
			enemy = foe
			_refresh_hp()
			cb.call())
		_right_list.add_child(btn)


# ── Refresh ───────────────────────────────────────────────────────────────────

func _refresh_hp() -> void:
	_player_lv_lbl.text = "LV %d" % player.lv

	_player_hp_bar.max_value = player.max_hp
	_player_hp_bar.value     = player.hp
	_player_hp_lbl.text      = "%d/%d" % [player.hp, player.max_hp]

	_player_mp_bar.max_value = player.max_mp
	_player_mp_bar.value     = player.mp
	_player_mp_lbl.text      = "%d/%d" % [player.mp, player.max_mp]

	_player_sts_lbl.text = _format_statuses(player.active_statuses)

	var hero_acting: bool = _actor_is_player() and _press != null and _press.has_turns()
	_player_name_lbl.text = ("> " if hero_acting else "") \
			+ PlayerCharacter.DISPLAY_NAME.to_upper()
	_player_name_lbl.add_theme_color_override("font_color",
			Color(1.0, 0.92, 0.45) if hero_acting else Color(0.85, 0.85, 1.0))

	_refresh_foe_rows()
	_refresh_party_rows()
	_refresh_icons()


func _refresh_foe_rows() -> void:
	var multiple: bool = _living_foes().size() > 1
	for r: Dictionary in _foe_rows:
		var foe: Enemy = r["foe"] as Enemy
		var alive: bool = foe.is_alive()
		var targeted: bool = (foe == enemy) and alive
		(r["marker"] as Label).visible = targeted and multiple
		(r["portrait"] as TextureRect).modulate.a = 1.0 if alive else 0.18
		var name_lbl: Label = r["name_lbl"] as Label
		if not alive:
			name_lbl.add_theme_color_override("font_color", Color(0.38, 0.30, 0.30))
		elif targeted:
			name_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.45))
		else:
			name_lbl.add_theme_color_override("font_color", Color(0.95, 0.35, 0.35))
		var bar: ProgressBar = r["bar"] as ProgressBar
		bar.max_value = foe.max_hp
		bar.value     = foe.hp
		(bar.get_parent() as Control).visible = alive
		var hp_lbl: Label = r["hp_lbl"] as Label
		hp_lbl.text = "%d / %d" % [foe.hp, foe.max_hp] if alive else "DOWN"


# ── Phase flow ────────────────────────────────────────────────────────────────

func _after_action(cost: String) -> void:
	var collapsed: bool = (cost == PressTurn.COST_LOST and _press.total() > 0)
	_press.spend(cost)
	_ensure_target()
	_refresh_hp()

	if _living_foes().is_empty():
		await get_tree().create_timer(1.6).timeout
		if is_instance_valid(self):
			_end_combat("win")
		return

	if _living_party().is_empty():
		_log("[color=red]You were defeated...[/color]")
		await get_tree().create_timer(1.8).timeout
		if is_instance_valid(self):
			_end_combat("lose")
		return

	if collapsed:
		_log("[color=#d070ff]Your phase collapses.[/color]")

	if _press.has_turns():
		await get_tree().create_timer(0.5).timeout
		if is_instance_valid(self):
			_actor_idx = _next_living(_actor_idx)
			_prompt_actor()
		return

	await _enemy_phase()


func _enemy_phase() -> void:
	_set_buttons(false)
	_show_main_actions()
	# One icon per demon still standing — the same rule the player side runs on,
	# which is what makes a pack of four genuinely dangerous.
	var living: Array[Enemy] = _living_foes()
	var total: int = 0
	for f: Enemy in living:
		total += maxi(1, f.icons)
	_foe_press.begin(maxi(1, total))
	_foe_turn_idx = 0
	_refresh_hp()
	await get_tree().create_timer(0.6).timeout

	while is_instance_valid(self) and _foe_press.has_turns() \
			and not _living_foes().is_empty() and not _living_party().is_empty():
		var actors: Array[Enemy] = _living_foes()
		var actor: Enemy = actors[_foe_turn_idx % actors.size()]
		_foe_turn_idx += 1
		var res: Dictionary = _enemy_act(actor)
		_log(res["msg"] as String)
		_foe_press.spend(res["cost"] as String)
		_refresh_hp()
		if _foe_press.has_turns() and not _living_party().is_empty() \
				and not _living_foes().is_empty():
			await get_tree().create_timer(0.8).timeout

	if not is_instance_valid(self):
		return
	if _living_party().is_empty():
		_log("[color=red]You were defeated...[/color]")
		await get_tree().create_timer(1.8).timeout
		if is_instance_valid(self):
			_end_combat("lose")
		return
	if _living_foes().is_empty():
		await get_tree().create_timer(1.6).timeout
		if is_instance_valid(self):
			_end_combat("win")
		return

	await _do_end_of_round()


func _do_poison_ticks() -> String:
	var msgs: Array[String] = []
	for m: CharacterSheet in party:
		if not m.is_alive():
			continue
		var dmg: int = m.poison_tick()
		if dmg > 0:
			msgs.append("[color=chartreuse]Poison deals %d damage to %s![/color]" % [
					dmg, _member_name(m)])
	for f: Enemy in foes:
		if not f.is_alive():
			continue
		var e_dmg: int = f.poison_tick()
		if e_dmg > 0:
			msgs.append("[color=violet]Poison deals %d damage to %s![/color]" % [
					e_dmg, f.display_name()])
			if not f.is_alive():
				msgs.append("[color=lime]%s succumbed to poison![/color]" % f.display_name())
	return "\n".join(msgs)


# ── Enemy actions ─────────────────────────────────────────────────────────────

func _enemy_act(actor: Enemy) -> Dictionary:
	if actor.has_status(Status.PARALYZED) and randi() % 4 == 0:
		return {msg = "[color=yellow]%s is paralyzed and cannot act![/color]" % actor.display_name(),
				cost = PressTurn.COST_FULL}

	var element: String = Affinity.PHYS
	var base: int = actor.str
	if actor.attack_element != "" and randi() % 10 < 4:
		element = actor.attack_element
		base    = actor.mag * 2

	var target: CharacterSheet = _pick_target(element)
	var eff_def: int = _defense_of(target) * (2 if target.defending else 1)
	target.defending = false

	var crit: bool = CombatMath.roll_crit()
	var res: Dictionary = CombatMath.resolve(base - eff_def / 2, element, target, crit)
	var outcome: String = res["outcome"] as String
	var dmg: int        = res["dmg"] as int
	var tname: String   = _member_name(target)
	var ename: String   = actor.display_name()
	var verb: String    = "attacks" if element == Affinity.PHYS \
			else "uses %s on" % Affinity.element_name(element)

	match outcome:
		"drain":
			target.heal(dmg)
			return {msg = "[color=lime]%s %s %s — absorbed! %s recovers %d HP.[/color]" % [
					ename, verb, tname, tname, dmg], cost = PressTurn.COST_LOST}
		"repel":
			actor.take_damage(dmg)
			var pr: TextureRect = _foe_portrait(actor)
			if pr != null:
				_shake_portrait(pr)
			return {msg = "[color=#d070ff]%s %s %s — repelled! %s takes %d damage.[/color]" % [
					ename, verb, tname, ename, dmg], cost = PressTurn.COST_LOST}
		"null":
			return {msg = "[color=#999999]%s %s %s — no effect.[/color]" % [ename, verb, tname],
					cost = PressTurn.COST_MISS}

	target.take_damage(dmg)
	if target == player:
		_shake_portrait(_player_portrait)
	var msg: String = "[color=red]%s %s %s for %d damage.[/color]%s%s" % [
			ename, verb, tname, dmg, CombatMath.outcome_tag(outcome, crit),
			_try_enemy_status(actor, target)]
	if target == player:
		msg += _check_counter()
	return {msg = msg, cost = CombatMath.cost_for(outcome, crit)}


# ── Fleeing ───────────────────────────────────────────────────────────────────

func _do_flee() -> void:
	var fastest: int = 0
	for f: Enemy in _living_foes():
		fastest = maxi(fastest, f.agl)
	if player.effective_agl() >= fastest or randi() % 2 == 0:
		_log("You slip away into the dark.")
		await get_tree().create_timer(0.9).timeout
		if is_instance_valid(self):
			_end_combat("flee")
		return
	_log("[color=yellow]Failed to escape![/color]")
	await _after_action(PressTurn.COST_FULL)


# ── A demon leaving the fight ─────────────────────────────────────────────────

# A successful negotiation removes one demon, not the encounter. The battle
# only ends here if it was the last one standing.
func _foe_departs(reason: String) -> void:
	var leaving: Enemy = enemy
	foes.erase(leaving)
	for r: Dictionary in _foe_rows:
		if r["foe"] == leaving:
			(r["portrait"] as TextureRect).modulate.a = 0.0
			(r["name_lbl"] as Label).text = ""
			((r["bar"] as ProgressBar).get_parent() as Control).visible = false
			(r["hp_lbl"] as Label).text = "GONE"
			(r["marker"] as Label).visible = false
	_departed.append(leaving)
	_ensure_target()
	if foes.is_empty():
		await get_tree().create_timer(0.4).timeout
		if is_instance_valid(self):
			_end_combat(reason)
		return
	_refresh_hp()
	await _after_action(PressTurn.COST_FULL)


# ── Button state ──────────────────────────────────────────────────────────────

func _refresh_button_states() -> void:
	var is_p: bool  = _actor_is_player()
	var actor: CharacterSheet = _actor()
	_buttons["Attack"].disabled = actor.has_status(Status.IMMOBILIZE)
	_buttons["Skill"].disabled  = is_p or (actor as Enemy).attack_element == ""
	_buttons["Magic"].disabled  = not is_p or player.has_status(Status.SILENCE) \
			or player.known_spells.is_empty()
	_buttons["Item"].disabled   = not is_p
	_buttons["Talk"].disabled   = not is_p or _living_foes().is_empty()
	_buttons["Summon"].disabled = not is_p or party.size() >= MAX_PARTY \
			or _available_summons().is_empty()
	_buttons["Flee"].disabled   = not is_p

