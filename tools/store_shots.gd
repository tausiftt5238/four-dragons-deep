extends "res://tools/tutorial_shots.gd"
# Screenshots for the Steam store page, taken in the Steam build and saved at
# Steam's 1920x1080: a few floors from different bands, packs with the young
# dragons in them, a dragon, a talk, the party, the orb and the Abyss. They go
# to build/store/steam/, which git ignores — they show the real art, so they
# are never committed. Needs a real display and the real art in place:
#
#   tools/run.sh steam --script tools/store_shots.gd
#
# The walking and fight helpers are tutorial_shots.gd's. Like it, it puts this
# machine's autosave and records back when it is done.


func _initialize() -> void:
	OUT_DIR = "res://build/store/steam/"
	# With the display asleep, vsync holds every frame to about one a second.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	seed(20261007)
	var kept: Dictionary = {}
	for path: String in [SaveSystem.slot_path(SaveSystem.AUTO_SLOT), Records.PATH]:
		kept[path] = FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else null
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	GameBoot.pending_slot = 0
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Main
	root.add_child(main)
	await _frames(10)
	main._encounters_enabled = false
	_dress_party()
	for r: Roamer in main.roamers:
		r.visible = false

	await _walk_shot(1, "01-explore-floor1.png")
	await _walk_shot(12, "02-explore-floor12.png")
	await _fight_shot(7, ["Young Red Dragon", "Young Copper Dragon", "Young Silver Dragon"],
			"03-fight-young-dragons.png", true)
	await _boss_shot(10, "05-thunder-dragon.png")
	await _fight_shot(17, ["Mature Bronze Dragon", "Dark Demoness", "Warlock", "Mature Blue Dragon"],
			"06-fight-floor17.png")
	await _abyss_shot("07-abyss-fight.png")
	await _go_to_floor(1)
	await _wait(1.0)
	await _party_shot("08-party.png")
	await _orb_shot("09-orb.png")
	await _victory_shot("10-victory.png")
	await _hall_shot("11-necromancer-hall.png")
	Records.flush()
	for path: String in kept:
		if kept[path] == null:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		else:
			FileAccess.open(path, FileAccess.WRITE).store_string(kept[path] as String)
	quit()


# The Steam build draws a 960x540 canvas and scales it to the window, so the
# viewport hands back 960x540; doubled whole pixels make Steam's 1920x1080.
func _save(file: String) -> void:
	await _wait(0.4)
	var img: Image = root.get_texture().get_image()
	if img.get_width() < 1920:
		img.resize(1920, 1080, Image.INTERPOLATE_NEAREST)
	img.save_png(ProjectSettings.globalize_path(OUT_DIR + file))
	print("saved ", file)


# A mid-run party: a hero with some levels and gold, and a few bound demons,
# so the party row and the fights look like a game in progress.
func _dress_party() -> void:
	var p: PlayerCharacter = main.player_char
	p.gold = 4200
	for i: int in 17:
		p._level_up()
	# A fuller skill list than the opening one, and the whistle, so no shot
	# opens on an ambush with the menu greyed out.
	p.known_spells.assign(["analyze", "ember", "rime", "arc", "cure", "whet"])
	p.equipped_spells.assign(["analyze", "ember", "rime", "arc", "cure"])
	p.equipped_accessories.append(Accessory.sentrys_whistle())
	p.hp = p.max_hp
	p.mp = p.max_mp
	for d: Array in [["Baby Brass Dragon", 14], ["Werebear", 15], ["Juvenile Mercury Dragon", 16]]:
		p.remember_recruit(d[0] as String, d[1] as int)


func _go_to_floor(n: int) -> void:
	main.floor_num = n - 1
	# A descent fades out, builds the floor and fades back in: wait it out, or
	# a fight launched meanwhile has the new floor built under it.
	await main._descend()
	for r: Roamer in main.roamers:
		r.visible = false
	await _frames(10)
	_clear_popup()


func _walk_shot(floor_n: int, file: String) -> void:
	await _go_to_floor(floor_n)
	var lvl: Level = main.current_level
	_stand(lvl.player_start, lvl.player_start_facing)
	for cell: Vector2i in _path_away(main.player_pos, 24):
		for d: int in 4:
			if main.player_pos + Main.DIR_OFFSET[d] == cell:
				main.player_facing = d
		main._snap_cam_yaw()
		main._action_forward()
		if main.orb_open:
			main._close_orb()
		await _frames(2)
	_face_longest(main.player_pos)
	await _frames(10)
	_clear_popup()
	await _save(file)


func _fight_shot(floor_n: int, names: Array, file: String, talk: bool = false) -> void:
	await _go_to_floor(floor_n)
	var group: Array[Enemy] = []
	for n: Variant in names:
		group.append(Enemy.make_from_name(n as String, floor_n))
	main._launch_combat(group)
	await _frames(90)
	var scene: CombatScene = _combat_scene()
	await _save(file)
	if talk:
		scene.enemy = scene.foes[0]
		scene._show_talk_submenu()
		await _frames(15)
		await _save("04-talk-to-a-dragon.png")
	await _end_fight(scene)


# Not walked down to: a boss floor's own arrival runs the corridor. The fight
# is started from the floor above, as tutorial_shots.gd does it.
func _boss_shot(floor_n: int, file: String) -> void:
	await _go_to_floor(floor_n - 1)
	main.floor_num = floor_n
	if main.orb_open:
		main._close_orb()
		await _frames(30)
	main._start_boss_combat()
	await _frames(90)
	await _save(file)
	await _end_fight(_combat_scene())


# Monsters risen in the Abyss's elements, in their new colours.
func _abyss_shot(file: String) -> void:
	await _go_to_floor(22)
	var group: Array[Enemy] = []
	for pair: Array in [["Demon", "ice"], ["Young Red Dragon", "dark"], ["Orc", "fire"], ["Ghostfire", "thunder"]]:
		var e: Enemy = Enemy.make_from_name(pair[0] as String, 22)
		Abyss.apply_variant(e, pair[1] as String)
		group.append(e)
	main._launch_combat(group)
	await _frames(90)
	await _save(file)
	await _end_fight(_combat_scene())


func _party_shot(file: String) -> void:
	main._open_menu()
	await _frames(5)
	var menu: MenuUI = main.menu_layer.find_children("*", "MenuUI", true, false).back() as MenuUI
	menu._switch_tab("party")
	await _frames(60)
	await _save(file)
	main._close_menu()
	await _frames(30)


func _orb_shot(file: String) -> void:
	_stand(main.current_level.orb_cells[0], 0)
	main._open_orb("buy")
	await _frames(45)
	await _save(file)
	main._close_orb()


# A won fight: the results over the field, the party mid-hop.
func _victory_shot(file: String) -> void:
	await _go_to_floor(8)
	main._launch_combat([Enemy.make_from_name("Young Silver Dragon", 8), Enemy.make_from_name("Hellhound", 8)])
	await _wait(1.0)
	var scene: CombatScene = _combat_scene()
	for f: Enemy in scene.foes:
		f.hp = 0
	scene._refresh_hp()
	scene._end_combat("win")
	# A beat into the hops, caught with most of the party in the air.
	await _wait(0.62)
	var img: Image = root.get_texture().get_image()
	if img.get_width() < 1920:
		img.resize(1920, 1080, Image.INTERPOLATE_NEAREST)
	img.save_png(ProjectSettings.globalize_path(OUT_DIR + file))
	print("saved ", file)
	# Through the results and whatever level-ups follow, back to the corridor.
	for i: int in 20:
		if not main.in_combat:
			break
		for b: Node in root.find_children("*", "Button", true, false):
			if (b as Button).text in ["Continue", "Confirm", "Skip"] and (b as Button).is_visible_in_tree():
				(b as Button).pressed.emit()
				break
		await _wait(0.4)


# The bottom of the run: the walkway round the pit, the Necromancer on the pier.
func _hall_shot(file: String) -> void:
	await _go_to_floor(Level.FLOOR_COUNT)
	if main.orb_open:
		main._close_orb()
	_stand(Vector2i(6, 1), 2)
	await _wait(0.8)
	_clear_popup()
	await _save(file)
