# MainScreens
# The screens Main lays over the dungeon, split out of it: the results of a
# fight, level-ups, game over, the endings (the Necromancer, the demo, the
# Abyss) and the questions they ask. It works on the Main it belongs to.
class_name MainScreens extends RefCounted

var main: Main


func _init(host: Main) -> void:
	main = host


# ── Screens over the dungeon: results, level-ups, endings ─────────────────────

func _show_combat_result(exp: int, gold: int, item: Dictionary,
		lv_before: Dictionary, lv_after: Dictionary,
		demon_ups: Array[Dictionary] = []) -> void:
	var ui: CombatResultUI = CombatResultUI.new()
	ui.over_battle = is_instance_valid(_victory_layer)
	ui.exp_gained  = exp
	ui.gold_gained = gold
	ui.item_drop   = item
	ui.dismissed.connect(func():
		ui.queue_free()
		if not lv_before.is_empty():
			_show_level_up(lv_before, lv_after, demon_ups)
		else:
			_show_demon_level_ups(demon_ups)
	)
	_get_overlay_layer().add_child(ui)


# Each demon that grew gets its own popup, one after another, and the corridor
# comes back after the last of them.
func _show_demon_level_ups(queue: Array[Dictionary]) -> void:
	if queue.is_empty():
		_resume_from_overlay()
		return
	var entry: Dictionary = queue[0]
	var rest: Array[Dictionary] = queue.slice(1)
	var ui: DemonLevelUpUI = DemonLevelUpUI.new()
	ui.demon_name = entry["name"] as String
	ui.before     = entry["before"] as Dictionary
	ui.after      = entry["after"] as Dictionary
	ui.learned    = entry["learned"] as Array
	ui.offers     = entry.get("offers", []) as Array
	ui.player     = main.player_char
	ui.dismissed.connect(func():
		ui.queue_free()
		_show_demon_level_ups(rest)
	)
	_get_overlay_layer().add_child(ui)


var _victory_layer: CanvasLayer = null
var _victory_foes: Array[Enemy] = []


func _clear_victory() -> void:
	if is_instance_valid(_victory_layer):
		_victory_layer.queue_free()
	_victory_layer = null
	for foe: Enemy in _victory_foes:
		if is_instance_valid(foe):
			foe.queue_free()
	_victory_foes = []


func _resume_from_overlay() -> void:
	_clear_victory()
	main.hud_layer.visible = true
	main.in_combat = false
	# A fight and everything after it is over; this is a good place to be.
	main._saves._autosave.call_deferred()
	if main._reopen_orb_tab != "":
		var tab: String = main._reopen_orb_tab
		main._reopen_orb_tab = ""
		main._open_orb(tab)
		return
	if main._pending_congratulations:
		main._pending_congratulations = false
		_show_congratulations()
	elif main._pending_demo_end:
		main._pending_demo_end = false
		_show_demo_end()
	elif main._pending_abyss_end:
		main._pending_abyss_end = false
		_show_abyss_end()


# The Abyss's last boss is down: the descent is over. The captain comes down
# for the hero, and it is back to the title; the run is done with, so its save
# goes, and the hero who cleared the game waits for the next descent as before.
func _show_abyss_end() -> void:
	if main._fading:
		return
	Records.add("abyss_cleared")
	Abyss.note_depth(Abyss.END_DEPTH)
	Abyss.wipe_run()
	Records.flush()
	main.in_combat = true
	main._fading = true
	var fade: ScreenFade = ScreenFade.cover(main.get_tree(), "", 0.8)
	await fade.covered
	main.hud_layer.visible = false
	var ui: IntroUI = IntroUI.new()
	ui.lines = IntroUI.ABYSS_END_LINES
	ui.hero_name = main.player_char.hero_name
	ui.closing_text = "The end of the Abyss."
	_get_overlay_layer().add_child(ui)
	fade.reveal()
	await ui.finished
	var out: ScreenFade = ScreenFade.cover(main.get_tree())
	await out.covered
	Abyss.active = false
	main.get_tree().change_scene_to_file("res://scenes/title.tscn")
	out.reveal()


# The demo's last boss is down: the captain thanks the hero and points at the
# full game, and then it is back to the title. Saved first, so Continue comes
# back to the dragon's corridor rather than before it.
func _show_demo_end() -> void:
	if main._fading:
		return
	main._saves._autosave()
	Records.flush()
	main.in_combat = true
	main._fading = true
	var fade: ScreenFade = ScreenFade.cover(main.get_tree(), "", 0.8)
	await fade.covered
	main.hud_layer.visible = false
	var ui: IntroUI = IntroUI.new()
	ui.lines = IntroUI.DEMO_LINES
	ui.hero_name = main.player_char.hero_name
	ui.closing_text = "Thank you for playing the demo."
	_get_overlay_layer().add_child(ui)
	fade.reveal()
	await ui.finished
	var out: ScreenFade = ScreenFade.cover(main.get_tree())
	await out.covered
	main.get_tree().change_scene_to_file("res://scenes/title.tscn")
	out.reveal()


# The Necromancer is down: through black into the climb home and the credits,
# and from there back to the title. The run is over.
func _show_congratulations() -> void:
	main.in_combat = true
	main._fading = true
	# The Abyss opens. The first hero to clear it is the one who goes down into
	# it; after that the player is asked, once the credits are done, whether
	# this one should take the old one's place.
	var cleared: Dictionary = main._saves._gather_save_data()["player"] as Dictionary
	var ask: bool = Abyss.has_hero()
	var abyss: bool = Abyss.in_build()
	if abyss:
		Abyss.unlock(cleared, not ask)
	Records.add("runs_won")
	Records.set_min("fastest_clear", main.play_time)
	var fade: ScreenFade = ScreenFade.cover(main.get_tree(), "", 0.8)
	await fade.covered
	main.hud_layer.visible = false
	var ui: EndingUI = EndingUI.new()
	# Whoever is still walking with the hero walks home with him.
	for demon_name: String in main.player_char.active_demons:
		var d: Enemy = main.player_char.bound_demon(demon_name)
		if d.sprite_id != "":
			ui.team.append(d.sprite_id)
		d.free()
	ui.finished.connect(func() -> void:
		if not abyss:
			pass
		elif ask:
			await _ask_replace_abyss_hero(cleared)
		else:
			await _tell_abyss_unlocked()
		var out: ScreenFade = ScreenFade.cover(main.get_tree())
		await out.covered
		main.get_tree().change_scene_to_file("res://scenes/title.tscn")
		out.reveal()
	)
	_get_overlay_layer().add_child(ui)
	fade.reveal(0.8)


# After a second (or later) clear: keep the Abyss hero there is, or put this
# one in its place. Both are shown by level, so the choice is an informed one.
signal _abyss_hero_chosen


# The first clear: say so, or nobody would know the mode is there.
func _tell_abyss_unlocked() -> void:
	var panel: Control = Control.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var veil: ColorRect = ColorRect.new()
	veil.color = Color(0.03, 0.02, 0.06, 1.0)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(veil)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(center)
	var col: VBoxContainer = VBoxContainer.new()
	# Wider on a wide screen, where the phone's width would break the lines.
	col.custom_minimum_size = Vector2(600 if Build.steam() else 440, 0)
	col.add_theme_constant_override("separation", 18)
	center.add_child(col)
	for row: Array in [["CONGRATULATIONS!", 26, Color(0.90, 0.75, 0.30)],
			["You have unlocked\nABYSS MODE", 28, Color(0.78, 0.60, 1.0)],
			["An endless descent for the hero who beat the Necromancer. Find it on the title screen, below Load Game.",
				18, Color(0.85, 0.83, 0.92)]]:
		var l: Label = Label.new()
		l.text = row[0] as String
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		# The one long word stays whole rather than losing its "!" to a line
		# of its own.
		if not (row[0] as String).begins_with("CONGRAT"):
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_font_override("font", Main._UI_FONT)
		l.add_theme_font_size_override("font_size", int(row[1]))
		l.add_theme_color_override("font_color", row[2] as Color)
		col.add_child(l)
	var b: Button = Button.new()
	b.text = "CONTINUE"
	b.custom_minimum_size = Vector2(0, 50)
	b.add_theme_font_override("font", Main._UI_FONT)
	b.pressed.connect(func() -> void: _abyss_hero_chosen.emit())
	col.add_child(b)
	Sfx.play("recruit")
	_get_overlay_layer().add_child(panel)
	await _abyss_hero_chosen
	panel.queue_free()


func _ask_replace_abyss_hero(cleared: Dictionary) -> void:
	var old_lv: int = int(Abyss.cleared_hero().get("lv", 1))
	var new_lv: int = int(cleared.get("lv", 1))
	var panel: Control = Control.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var veil: ColorRect = ColorRect.new()
	veil.color = Color(0.03, 0.02, 0.06, 1.0)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(veil)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(center)
	var col: VBoxContainer = VBoxContainer.new()
	col.custom_minimum_size = Vector2(600 if Build.steam() else 440, 0)
	col.add_theme_constant_override("separation", 16)
	center.add_child(col)
	var head: Label = Label.new()
	head.text = "THE ABYSS"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_font_override("font", Main._UI_FONT)
	head.add_theme_font_size_override("font_size", 36)
	head.add_theme_color_override("font_color", Color(0.78, 0.60, 1.0))
	col.add_child(head)
	var q: Label = Label.new()
	q.text = "Which hero goes down into the Abyss?\n\nThe one waiting there now is level %d.\nThe one who just won is level %d." % [old_lv, new_lv]
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	q.add_theme_font_override("font", Main._UI_FONT)
	q.add_theme_font_size_override("font_size", 18)
	col.add_child(q)
	for pair: Array in [["KEEP THE ONE THERE (LV %d)" % old_lv, false],
			["SEND THIS HERO (LV %d)" % new_lv, true]]:
		var b: Button = Button.new()
		b.text = pair[0] as String
		b.custom_minimum_size = Vector2(0, 50)
		b.add_theme_font_override("font", Main._UI_FONT)
		var replace: bool = pair[1]
		b.pressed.connect(func() -> void:
			if replace:
				Abyss.unlock(cleared, true)
			_abyss_hero_chosen.emit())
		col.add_child(b)
	_get_overlay_layer().add_child(panel)
	await _abyss_hero_chosen
	panel.queue_free()


func _player_snapshot() -> Dictionary:
	return {
		lv=main.player_char.lv, str=main.player_char.str, def=main.player_char.def,
		mag=main.player_char.mag, agl=main.player_char.agl, luk=main.player_char.luk,
		max_hp=main.player_char.max_hp, max_mp=main.player_char.max_mp,
	}


func _get_overlay_layer() -> CanvasLayer:
	if not is_instance_valid(main.overlay_layer):
		main.overlay_layer = CanvasLayer.new()
		main.overlay_layer.layer = 25
		main.add_child(main.overlay_layer)
		Layout.focus_arrivals(main.overlay_layer)
	return main.overlay_layer


func _show_level_up(before: Dictionary, after: Dictionary,
		demon_ups: Array[Dictionary] = []) -> void:
	var ui: LevelUpUI = LevelUpUI.new()
	ui.before  = before
	ui.after   = after
	ui.player  = main.player_char
	ui.dismissed.connect(func():
		ui.queue_free()
		_show_demon_level_ups(demon_ups)
	)
	_get_overlay_layer().add_child(ui)


func _show_game_over() -> void:
	Sfx.play("game_over")
	Records.add("deaths")
	# The Abyss has one life: the run is over, and so is its save. The captain
	# hauls the hero back up first, and the depth reached comes after.
	if Abyss.active:
		Abyss.wipe_run()
		var rescue: IntroUI = IntroUI.new()
		rescue.rescue = true
		rescue.lines = IntroUI.RESCUE_LINES
		rescue.hero_name = main.player_char.hero_name
		rescue.closing_text = "Abyss %d. Back in the light." % Abyss.depth_of(main.floor_num)
		_get_overlay_layer().add_child(rescue)
		await rescue.finished
		rescue.queue_free()
	var ui: GameOverUI = GameOverUI.new()
	ui.abyss_depth = Abyss.depth_of(main.floor_num) if Abyss.active else 0
	ui.load_game.connect(func():
		ui.queue_free()
		main.in_combat = false
		main._saves._open_load_menu()
	)
	ui.main_menu.connect(func():
		main.get_tree().change_scene_to_file("res://scenes/title.tscn")
	)
	_get_overlay_layer().add_child(ui)


func _show_hud_popup(text: String, color: Color = Color(1.0, 0.88, 0.28)) -> void:
	main._hud_popup.text = text
	main._hud_popup.add_theme_color_override("font_color", color)
	main._hud_popup.modulate.a = 1.0
	if is_instance_valid(main._hud_popup_tween):
		main._hud_popup_tween.kill()
	main._hud_popup_tween = main.create_tween()
	main._hud_popup_tween.tween_interval(1.8)
	main._hud_popup_tween.tween_property(main._hud_popup, "modulate:a", 0.0, 0.6)


