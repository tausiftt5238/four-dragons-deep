class_name CombatNegRecruit extends RefCounted

var _s
var _talk_trust:  int = 0
var _talk_rounds: int = 0


func _init(scene) -> void:
	_s = scene


func start() -> void:
	_talk_trust  = 0
	_talk_rounds = 2
	_s._hide_actions()
	_show_submenu()


func _show_submenu() -> void:
	_s._set_back(_s._show_talk_submenu)
	_s._right_title.text = "RECRUIT  %d/4" % _talk_trust
	_s._right_title.add_theme_color_override("font_color", Color(0.40, 1.0, 0.60))
	for child: Node in _s._right_list.get_children():
		child.queue_free()

	_s._right_list.add_child(_s._dim_label("Round %d of 2" % (3 - _talk_rounds)))

	var opts: Array[Array] = [
		["Flatter", "\"You're incredible!\""],
		["Pride",   "\"Prove your strength.\""],
		["Safety",  "\"I'll protect you.\""],
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
	var personality_match: bool = false
	match _s.enemy.talk_personality:
		"cowardly": personality_match = (approach == "Safety")
		"proud":    personality_match = (approach == "Pride")
		"greedy":   personality_match = (approach == "Flatter")
		"lonely":   personality_match = (approach == "Flatter") or (approach == "Safety")

	var gain: int = randi() % 4 + (2 if personality_match else 0) - _s.enemy.talk_difficulty
	gain          = max(0, gain)
	_talk_trust  += gain
	_talk_rounds -= 1

	var reaction: String
	if gain >= 3:   reaction = _good_reaction()
	elif gain >= 1: reaction = _neutral_reaction()
	else:           reaction = _bad_reaction()
	_s._log("[color=aqua]%s[/color]" % reaction)

	if _talk_trust >= 4:
		_s._show_main_actions()
		_s._set_buttons(false)
		if not (_s.enemy.enemy_name in _s.player.recruited):
			_s.player.recruited.append(_s.enemy.enemy_name)
		_s._log("[color=yellow]%s agrees to join you![/color]" % _s.enemy.enemy_name)
		await _s.get_tree().create_timer(1.5).timeout
		if is_instance_valid(_s):
			_s._end_combat("talk")
		return

	if _talk_rounds <= 0:
		_s._show_main_actions()
		_s._set_buttons(false)
		_s._log("[color=red]%s: \"Enough talk!\"[/color]" % _s.enemy.enemy_name)
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
			_s._set_buttons(true)
			_s._refresh_button_states()
		return

	await _s.get_tree().create_timer(0.7).timeout
	if is_instance_valid(_s):
		_show_submenu()


func _good_reaction() -> String:
	match _s.enemy.talk_personality:
		"cowardly": return "%s: \"Y-you'd really protect me? ...maybe I'll consider it.\"" % _s.enemy.enemy_name
		"proud":    return "%s: \"You recognize my power. I'll hear you out.\"" % _s.enemy.enemy_name
		"greedy":   return "%s: \"Heh, finally someone smart. Keep talking.\"" % _s.enemy.enemy_name
		"lonely":   return "%s: \"You really mean that? ...I'm listening.\"" % _s.enemy.enemy_name
	return "%s seems interested." % _s.enemy.enemy_name


func _neutral_reaction() -> String:
	match _s.enemy.talk_personality:
		"cowardly": return "%s: \"Hmm... not convinced yet, but go on.\"" % _s.enemy.enemy_name
		"proud":    return "%s: \"Interesting. You might be worth my time.\"" % _s.enemy.enemy_name
		"greedy":   return "%s: \"You've got my attention. What else?\"" % _s.enemy.enemy_name
		"lonely":   return "%s: \"...I suppose you're not so bad.\"" % _s.enemy.enemy_name
	return "%s hesitates." % _s.enemy.enemy_name


func _bad_reaction() -> String:
	match _s.enemy.talk_personality:
		"cowardly": return "%s: \"That's not going to work on me!\"" % _s.enemy.enemy_name
		"proud":    return "%s: \"Ha! Is that the best you've got?\"" % _s.enemy.enemy_name
		"greedy":   return "%s: \"Words are cheap. Show me something real.\"" % _s.enemy.enemy_name
		"lonely":   return "%s: \"...You don't really mean that.\"" % _s.enemy.enemy_name
	return "%s is unmoved." % _s.enemy.enemy_name
