class_name CombatNegBribe extends RefCounted

var _s
var _demand_item: Dictionary = {}


func _init(scene) -> void:
	_s = scene


func start() -> void:
	_s._hide_actions()
	_s._set_back(_s._show_talk_submenu)
	_s._right_title.text = "Bribe"
	_s._right_title.add_theme_color_override("font_color", Color(1.0, 0.75, 0.2))
	_s._submenu_clear()

	var wants: String = _s.enemy.bribe_wants
	var demand: Dictionary = {}
	for item: Dictionary in _s.player.inventory:
		if item["type"] != "consumable":
			continue
		match wants:
			"potion":
				if item.get("hp_restore", 0) > 0 or item.get("mp_restore", 0) > 0 \
						or item.has("cures_status"):
					demand = item
					break
			"throwable":
				if item.has("inflicts_status") or item.has("element"):
					demand = item
					break
			_:
				demand = item
				break
	_demand_item = demand

	var gold_cost: int = _s.enemy.gold_reward
	if not demand.is_empty():
		_s._log("[color=orange]%s: \"Hand over your %s... or pay %d gold!\"[/color]" % [
				_s.enemy.enemy_name, demand["name"], gold_cost])
		var give_btn: Button = Button.new()
		give_btn.text                = "Give %s" % demand["name"]
		give_btn.custom_minimum_size = Vector2(0, 32)
		give_btn.pressed.connect(func() -> void: await _resolve("give"))
		_s._submenu_add(give_btn)
	else:
		_s._log("[color=orange]%s: \"Pay me %d gold or face my wrath!\"[/color]" % [
				_s.enemy.enemy_name, gold_cost])

	var gold_btn: Button = Button.new()
	gold_btn.text                = "Pay %d Gold" % gold_cost
	gold_btn.custom_minimum_size = Vector2(0, 32)
	gold_btn.disabled            = _s.player.gold < gold_cost
	gold_btn.pressed.connect(func() -> void: await _resolve("gold"))
	_s._submenu_add(gold_btn)

	var refuse_btn: Button = Button.new()
	refuse_btn.text                = "Refuse"
	refuse_btn.custom_minimum_size = Vector2(0, 32)
	refuse_btn.pressed.connect(func() -> void: await _resolve("refuse"))
	_s._submenu_add(refuse_btn)


func _resolve(choice: String) -> void:
	_s._show_main_actions()
	_s._set_buttons(false)
	match choice:
		"give":
			_s.player.remove_item(_demand_item, 1)
			_s._log("[color=lime]You hand over the %s.\n%s pockets it and lets you go.[/color]" % [
					_demand_item["name"], _s.enemy.enemy_name])
			await _s.get_tree().create_timer(1.5).timeout
			if is_instance_valid(_s):
				await _s._foe_departs("bribe")
		"gold":
			_s.player.gold -= _s.enemy.gold_reward
			_s._log("[color=lime]You pay %d gold.\n%s counts it and backs away.[/color]" % [
					_s.enemy.gold_reward, _s.enemy.enemy_name])
			await _s.get_tree().create_timer(1.5).timeout
			if is_instance_valid(_s):
				await _s._foe_departs("bribe")
		"refuse":
			_s._log("[color=red]%s: \"Wrong answer!\"[/color]" % _s.enemy.enemy_name)
			var p_hp_before: int = _s.player.hp
			var e_msg: String    = _s._apply_enemy_turn()
			_s._refresh_hp()
			if _s.player.hp < p_hp_before:
				_s._shake_portrait(_s._player_portrait)
			_s._log(e_msg)
			if not _s.player.is_alive():
				await _s.get_tree().create_timer(1.8).timeout
				if is_instance_valid(_s):
					_s._end_combat("lose")
				return
			await _s.get_tree().create_timer(1.1).timeout
			if is_instance_valid(_s):
				await _s._talk_attempt_failed()
