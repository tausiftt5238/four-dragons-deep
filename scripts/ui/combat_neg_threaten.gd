class_name CombatNegThreaten extends RefCounted

var _s
var _talk_fear:   int = 0
var _talk_rounds: int = 0


func _init(scene) -> void:
	_s = scene


func start() -> void:
	_talk_fear   = 0
	_talk_rounds = Negotiation.ROUNDS
	_s._hide_actions()
	_show_submenu()


func _show_submenu() -> void:
	_s._set_back(_s._show_talk_submenu)
	_s._right_title.text = "Threaten  %d/%d" % [
			_talk_fear, Negotiation.needed(_s.enemy)]
	_s._right_title.add_theme_color_override("font_color", Color(1.0, 0.40, 0.20))
	_s._submenu_clear()

	_s._submenu_add(_s._dim_label("Round %d of %d" % [
			Negotiation.ROUNDS - _talk_rounds + 1, Negotiation.ROUNDS]))

	var opts: Array[String] = ["Boast", "Intimidate", "Bluff"]
	for key: String in opts:
		var btn: Button = _s._big_button(key, "", false)
		btn.pressed.connect(func() -> void: await _resolve(key))
		_s._submenu_add(btn)


func _resolve(approach: String) -> void:
	_s._right_back_btn.hide()
	# Fear runs on the same two-round track trust does, and reads the same way:
	# bring the stat the threat is made of and you roll well, bring the wrong
	# one and you do not.
	#
	# It used to be a subtraction — your STR minus its STR — which meant Boast
	# gave four fear against a floor-three Goblin and exactly zero against
	# anything from floor twelve down, because their stats climb and the
	# threshold climbed with them. A ratio does not rot.
	var threshold: int   = Negotiation.needed(_s.enemy)
	var gain: int        = 0
	var insta_fail: bool = false

	match approach:
		"Boast":
			gain = Negotiation.roll(_s.player.effective_str() >= _s.enemy.str)
		"Intimidate":
			gain = Negotiation.roll(_s.player.effective_mag() >= _s.enemy.mag)
		"Bluff":
			# The gamble: better than either read when it lands, and it hands
			# them two free swings when it does not.
			if randi() % 5 == 0:
				insta_fail = true
			else:
				gain = 1 + randi() % 3

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
