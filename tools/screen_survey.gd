extends SceneTree
# Opens every screen outside the dungeon in turn (the title, its tutorial and
# load list, the intro, level up, a fight's result, a demon's level up, a
# chest, the save slots, the Abyss cards, the ending, the credits, game over)
# and saves a screenshot of each, for checking a build's layout at a glance:
#
#   S=/some/dir tools/run.sh steam    --resolution 1920x1080 --script tools/screen_survey.gd
#   S=/some/dir tools/run.sh portable --resolution 540x1170  --script tools/screen_survey.gd
#
# It plays in a throwaway run; this machine's autosave and records are put
# back afterwards.
var S: String = OS.get_environment("S")
var V: String = Build.variant()

func _shot(n: String) -> void:
	await create_timer(0.7).timeout
	root.get_viewport().get_texture().get_image().save_png("%s/sv_%s_%s.png" % [S, V, n])

func _clear(layer: Node) -> void:
	if layer == null: return
	for c in layer.get_children(): c.queue_free()
	await process_frame

func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var kept: Dictionary = {}
	for path: String in [SaveSystem.slot_path(SaveSystem.AUTO_SLOT), Records.PATH]:
		kept[path] = FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else null
	var t: Node = (load("res://scenes/title.tscn") as PackedScene).instantiate()
	root.add_child(t)
	await _shot("title")
	t._on_tutorial()
	await _shot("tutorial")
	for c in t.get_children():
		if c is TutorialUI: c.queue_free()
	t._on_load_game()
	await _shot("title_load")
	t.queue_free()
	var intro: IntroUI = IntroUI.new()
	root.add_child(intro)
	await create_timer(2.5).timeout
	await _shot("intro")
	intro.queue_free()

	var m: Main = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Main
	root.add_child(m)
	for i in 10: await process_frame
	if m.orb_open: m._close_orb()
	var p: PlayerCharacter = m.player_char
	p.remember_recruit("Demon", 3); p.active_demons.assign(["Hellbat", "Demon"])
	var before: Dictionary = m._player_snapshot()
	p.gain_exp(400)
	var after: Dictionary = m._player_snapshot()
	m._show_level_up(before, after)
	await _shot("level_up")
	await _clear(m.overlay_layer)
	m._show_combat_result(120, 45, Item.health_potion(), {}, {})
	await _shot("combat_result")
	await _clear(m.overlay_layer)
	var dl: Array[Dictionary] = m._demon_level_ups({"Hellbat": 1}, m._demon_snapshots())
	if not dl.is_empty():
		m._show_demon_level_ups(dl)
		await _shot("demon_level_up")
		await _clear(m.overlay_layer)
	var wall: Vector2i = m.current_level.chest_cells.keys()[0]
	m._open_chest(wall)
	await _shot("chest")
	m._close_chest()
	m._open_save_menu()
	await _shot("save_menu")
	m._close_save_layer()
	m._tell_abyss_unlocked()
	await _shot("abyss_unlocked")
	await _clear(m.overlay_layer)
	m._ask_replace_abyss_hero(m._gather_save_data()["player"])
	await _shot("abyss_replace")
	await _clear(m.overlay_layer)
	var end: EndingUI = EndingUI.new()
	end.team.assign(["Hellbat", "Demon_A"])
	m._get_overlay_layer().add_child(end)
	await create_timer(3.0).timeout
	await _shot("ending")
	end._to_credits()
	await create_timer(1.5).timeout
	await _shot("credits")
	await _clear(m.overlay_layer)
	p.hp = 0
	m._show_game_over()
	await create_timer(2.0).timeout
	await _shot("game_over")
	Records.flush()
	for path: String in kept:
		if kept[path] == null:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		else:
			FileAccess.open(path, FileAccess.WRITE).store_string(kept[path] as String)
	quit()
