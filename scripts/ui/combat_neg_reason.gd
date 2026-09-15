class_name CombatNegReason extends RefCounted

var _s
var _talk_trust:  int = 0
var _talk_rounds: int = 0


func _init(scene) -> void:
	_s = scene


func start() -> void:
	_talk_trust  = 0
	_talk_rounds = Negotiation.ROUNDS
	_s._hide_actions()
	_show_submenu()


func _show_submenu() -> void:
	_s._set_back(_s._show_talk_submenu)
	_s._right_title.text = "Negotiate  %d/%d" % [_talk_trust, Negotiation.needed(_s.enemy)]
	_s._right_title.add_theme_color_override("font_color", Color(0.50, 1.0, 0.70))
	_s._submenu_clear()

	_s._submenu_add(_s._dim_label("Round %d of %d" % [
			Negotiation.ROUNDS - _talk_rounds + 1, Negotiation.ROUNDS]))

	var opts: Array[String] = ["Survival", "Logic", "Gain"]
	for key: String in opts:
		var btn: Button = _s._big_button(key, "", false)
		btn.pressed.connect(func() -> void: await _resolve(key))
		_s._submenu_add(btn)


func _resolve(approach: String) -> void:
	_s._right_back_btn.hide()
	var matched: bool = Negotiation.matches(
			Negotiation.REASON_MATCH, _s.enemy.talk_personality, approach)
	var gain: int = Negotiation.roll(matched)
	_talk_trust  += gain
	_talk_rounds -= 1

	var reaction: String
	if gain >= 3:   reaction = _good_reaction()
	elif gain >= 1: reaction = _neutral_reaction()
	else:           reaction = _bad_reaction()
	_s._log("[color=aqua]%s[/color]" % reaction)

	if _talk_trust >= Negotiation.needed(_s.enemy):
		_s._show_main_actions()
		_s._set_buttons(false)
		_s.player.gold += _s.enemy.gold_reward / 2
		_s._log("[color=lime]%s backs down. You pocket %d gold.[/color]" % [
				_s.enemy.enemy_name, _s.enemy.gold_reward / 2])
		await _s.get_tree().create_timer(1.5).timeout
		if is_instance_valid(_s):
			await _s._foe_departs("talk")
		return

	if _talk_rounds <= 0:
		_s._show_main_actions()
		_s._set_buttons(false)
		_s._log("[color=red]%s: \"Enough words!\"[/color]" % _s.enemy.enemy_name)
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


func _good_reaction() -> String:
	match _s.enemy.talk_personality:
		"cowardly": return "%s: \"Hmm... fair point. Maybe this isn't worth the trouble.\"" % _s.enemy.enemy_name
		"proud":    return "%s: \"You argue well. I'll think on it.\"" % _s.enemy.enemy_name
		"greedy":   return "%s: \"...You're right. What do I gain from this?\"" % _s.enemy.enemy_name
		"lonely":   return "%s: \"That... actually makes sense.\"" % _s.enemy.enemy_name
	return "%s considers your words." % _s.enemy.enemy_name


func _neutral_reaction() -> String:
	match _s.enemy.talk_personality:
		"cowardly": return "%s: \"You have a point... but I'm not convinced yet.\"" % _s.enemy.enemy_name
		"proud":    return "%s: \"Keep going. I'm listening.\"" % _s.enemy.enemy_name
		"greedy":   return "%s: \"Interesting. Tell me more.\"" % _s.enemy.enemy_name
		"lonely":   return "%s: \"...Maybe. Keep talking.\"" % _s.enemy.enemy_name
	return "%s hesitates." % _s.enemy.enemy_name


func _bad_reaction() -> String:
	match _s.enemy.talk_personality:
		"cowardly": return "%s: \"Nice try, but I'm not buying it.\"" % _s.enemy.enemy_name
		"proud":    return "%s: \"Your argument is weak.\"" % _s.enemy.enemy_name
		"greedy":   return "%s: \"Words are cheap.\"" % _s.enemy.enemy_name
		"lonely":   return "%s: \"That's not what I want to hear.\"" % _s.enemy.enemy_name
	return "%s is unmoved." % _s.enemy.enemy_name
