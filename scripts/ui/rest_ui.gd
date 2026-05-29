class_name RestUI extends Control

signal rest_closed

var player: PlayerCharacter

var _hp_label:    Label
var _mp_label:    Label
var _gold_label:  Label
var _heal_btn:    Button
var _mp_btn:      Button
var _cure_btn:    Button
var _msg_label:   Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_refresh()


func _build_ui() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.06, 0.04, 0.08, 0.96)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(360, 0)
	center.add_child(panel)

	var m: MarginContainer = MarginContainer.new()
	for s: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		m.add_theme_constant_override(s, 20)
	panel.add_child(m)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	m.add_child(vbox)

	var title: Label = Label.new()
	title.text = "INN"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(1.0, 0.75, 0.25))
	title.add_theme_font_size_override("font_size", 22)
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	_hp_label = Label.new()
	_hp_label.add_theme_color_override("font_color", Color(0.45, 0.90, 0.45))
	vbox.add_child(_hp_label)

	_mp_label = Label.new()
	_mp_label.add_theme_color_override("font_color", Color(0.45, 0.60, 1.0))
	vbox.add_child(_mp_label)

	_gold_label = Label.new()
	_gold_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.30))
	vbox.add_child(_gold_label)

	vbox.add_child(HSeparator.new())

	_heal_btn = Button.new()
	_heal_btn.custom_minimum_size = Vector2(0, 36)
	_heal_btn.pressed.connect(_on_heal_hp)
	vbox.add_child(_heal_btn)

	_mp_btn = Button.new()
	_mp_btn.custom_minimum_size = Vector2(0, 36)
	_mp_btn.pressed.connect(_on_recover_mp)
	vbox.add_child(_mp_btn)

	_cure_btn = Button.new()
	_cure_btn.custom_minimum_size = Vector2(0, 36)
	_cure_btn.pressed.connect(_on_cure_ailments)
	vbox.add_child(_cure_btn)

	vbox.add_child(HSeparator.new())

	_msg_label = Label.new()
	_msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.50))
	vbox.add_child(_msg_label)

	var leave_btn: Button = Button.new()
	leave_btn.text = "Leave"
	leave_btn.custom_minimum_size = Vector2(0, 32)
	leave_btn.pressed.connect(func() -> void: rest_closed.emit())
	vbox.add_child(leave_btn)


func _hp_cost() -> int:
	return (player.max_hp - player.hp) * 2


func _mp_cost() -> int:
	return (player.max_mp - player.mp) * 5


func _cure_cost() -> int:
	return player.active_statuses.size() * 50


func _refresh() -> void:
	_hp_label.text   = "HP:    %d / %d" % [player.hp,  player.max_hp]
	_mp_label.text   = "MP:    %d / %d" % [player.mp,  player.max_mp]
	_gold_label.text = "Gold:  %d"       % player.gold

	var hp_cost: int = _hp_cost()
	var mp_cost: int = _mp_cost()
	var cure_cost: int = _cure_cost()

	if hp_cost > 0:
		_heal_btn.text     = "Heal HP  —  %d gold" % hp_cost
		_heal_btn.disabled = player.gold < hp_cost
	else:
		_heal_btn.text     = "HP is full"
		_heal_btn.disabled = true

	if mp_cost > 0:
		_mp_btn.text     = "Recover MP  —  %d gold" % mp_cost
		_mp_btn.disabled = player.gold < mp_cost
	else:
		_mp_btn.text     = "MP is full"
		_mp_btn.disabled = true

	if cure_cost > 0:
		_cure_btn.text     = "Cure Ailments  —  %d gold" % cure_cost
		_cure_btn.disabled = player.gold < cure_cost
	else:
		_cure_btn.text     = "No Ailments"
		_cure_btn.disabled = true

	_msg_label.text = ""


func _on_heal_hp() -> void:
	var cost: int = _hp_cost()
	player.gold -= cost
	player.heal(player.max_hp - player.hp)
	_msg_label.text = "HP fully restored."
	_refresh()


func _on_recover_mp() -> void:
	var cost: int = _mp_cost()
	player.gold -= cost
	player.restore_mp(player.max_mp - player.mp)
	_msg_label.text = "MP fully restored."
	_refresh()


func _on_cure_ailments() -> void:
	var cost: int = _cure_cost()
	player.gold -= cost
	player.active_statuses.clear()
	_msg_label.text = "All ailments cured."
	_refresh()
