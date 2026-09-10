class_name CombatNegThreaten extends RefCounted

var _s
var _talk_fear:   int = 0
var _talk_rounds: int = 0


func _init(scene) -> void:
	_s = scene


func start() -> void:
	_talk_fear   = 0
	_talk_rounds = 2
	_s._hide_actions()
	_show_submenu()


func _show_submenu() -> void:
	_s._set_back(_s._show_talk_submenu)
	var threshold: int = 3 + _s.enemy.talk_difficulty
	_s._right_title.text = "THREATEN  %d/%d" % [_talk_fear, threshold]
	_s._right_title.add_theme_color_override("font_color", Color(1.0, 0.40, 0.20))
	for child: Node in _s._right_list.get_children():
		child.queue_free()

	_s._right_list.add_child(_s._dim_label("Round %d of 2" % (3 - _talk_rounds)))

	var opts: Array[Array] = [
		["Boast",      "\"I'll crush you!\""],
		["Intimidate", "\"You're outmatched.\""],
		["Bluff",      "\"Surrender or die!\""],
	]
	for opt: Array in opts:
		var btn: Button = Button.new()
		var key: String = opt[0] as String
		btn.text                = opt[1] as String
		btn.custom_minimum_size = Vector2(0, 28)
		btn.pressed.connect(func() -> void: await _resolve(key))
		_s._right_list.add_child(btn)


func _resolve(approach: String) -> void:
	_s._right_back_btn.hide()
	var threshold: int   = 3 + _s.enemy.talk_difficulty
	var gain: int        = 0
	var insta_fail: bool = false

	match approach:
		"Boast":
			gain = max(0, _s.player.effective_str() - _s.enemy.str + randi() % 3)
		"Intimidate":
			gain = max(0, _s.player.effective_mag() - _s.enemy.talk_difficulty + randi() % 3)
		"Bluff":
			var roll: int = randi() % 6
			if roll <= 1:
				insta_fail = true
			else:
				gain = roll - 1

	if insta_fail:
		_s._show_main_actions()
		_s._set_buttons(false)
		_s._log("[color=red]%s: \"You're bluffing! Have at you!\"[/color]" % _s.enemy.enemy_name)
		var p_hp_before: int = _s.player.hp
		var e_msg: String    = _s._apply_enemy_turn() + "\n" + _s._apply_enemy_turn()
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
		return

	_talk_fear   += gain
	_talk_rounds -= 1

	if _talk_fear >= threshold:
		_s._show_main_actions()
		_s._set_buttons(false)
		_s._log("[color=orange]%s[/color]" % _scared_reaction())
		_s._log("[color=lime]%s backs down![/color]" % _s.enemy.enemy_name)
		await _s.get_tree().create_timer(1.5).timeout
		if is_instance_valid(_s):
			await _s._foe_departs("talk")
		return

	_s._log("[color=orange]%s[/color]" % _defiant_reaction(gain))

	if _talk_rounds <= 0:
		_s._show_main_actions()
		_s._set_buttons(false)
		_s._log("[color=red]%s decides to fight![/color]" % _s.enemy.enemy_name)
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
		return

	await _s.get_tree().create_timer(0.7).timeout
	if is_instance_valid(_s):
		_show_submenu()


func _scared_reaction() -> String:
	match _s.enemy.talk_personality:
		"cowardly": return "%s: \"OK OK! I'll go! Don't hurt me!\"" % _s.enemy.enemy_name
		"proud":    return "%s: \"...I'll let you go this time.\"" % _s.enemy.enemy_name
		"greedy":   return "%s: \"Fine! Not worth dying over this!\"" % _s.enemy.enemy_name
		"lonely":   return "%s: \"...I just wanted company. I'm leaving.\"" % _s.enemy.enemy_name
	return "%s: \"I'll go.\"" % _s.enemy.enemy_name


func _defiant_reaction(gain: int) -> String:
	if gain <= 0:
		match _s.enemy.talk_personality:
			"cowardly": return "%s: \"Y-you don't scare me that much!\"" % _s.enemy.enemy_name
			"proud":    return "%s: \"Ha! Is that a threat?\"" % _s.enemy.enemy_name
			"greedy":   return "%s: \"My life's worth more than you think!\"" % _s.enemy.enemy_name
			"lonely":   return "%s: \"...Why won't you just leave me alone?\"" % _s.enemy.enemy_name
	else:
		match _s.enemy.talk_personality:
			"cowardly": return "%s: \"W-wait... maybe we can work this out...\"" % _s.enemy.enemy_name
			"proud":    return "%s: \"You're... stronger than you look.\"" % _s.enemy.enemy_name
			"greedy":   return "%s: \"Alright, maybe this isn't worth the risk...\"" % _s.enemy.enemy_name
			"lonely":   return "%s: \"Stop... please...\"" % _s.enemy.enemy_name
	return "%s hesitates." % _s.enemy.enemy_name
