# MainSaves
# Saving and loading a run, split out of Main: the save and load screens,
# autosaves, turning the run into a save file and back, and putting the
# floor's roamers, key and door back the way they were. It works on the Main
# it belongs to.
class_name MainSaves extends RefCounted

var main: Main


func _init(host: Main) -> void:
	main = host


# ── Saving and loading ────────────────────────────────────────────────────────

func _open_save_menu() -> void:
	main.save_open = true
	main.hud_layer.visible = false
	if not is_instance_valid(main.save_layer):
		main.save_layer = CanvasLayer.new()
		main.save_layer.layer = 16
		main.add_child(main.save_layer)
		Layout.focus_arrivals(main.save_layer)
	var ui: SaveSlotUI = SaveSlotUI.new()
	ui.mode = "save"
	ui.slot_chosen.connect(_do_save)
	ui.cancelled.connect(_close_save_layer)
	main.save_layer.add_child(ui)


func _open_load_menu() -> void:
	main.save_open = true
	main.hud_layer.visible = false
	if not is_instance_valid(main.save_layer):
		main.save_layer = CanvasLayer.new()
		main.save_layer.layer = 16
		main.add_child(main.save_layer)
		Layout.focus_arrivals(main.save_layer)
	var ui: SaveSlotUI = SaveSlotUI.new()
	ui.mode = "load"
	ui.slot_chosen.connect(_do_load)
	ui.cancelled.connect(_close_save_layer)
	main.save_layer.add_child(ui)


func _close_save_layer() -> void:
	if is_instance_valid(main.save_layer):
		for child: Node in main.save_layer.get_children():
			child.queue_free()
	main.hud_layer.visible = true
	main.save_open = false


# Writes the autosave slot, but only from a moment a save can come back to:
# walking the floor. Mid-fight, mid-fade, in the Gauntlet or dead, it keeps the
# last one it wrote instead.
func _autosave() -> void:
	if main.player_char == null or main.current_level == null:
		return
	if main.in_combat or main._fading or main._in_gauntlet or main.chest_open or not main.player_char.is_alive():
		return
	SaveSystem.write(SaveSystem.ABYSS_SLOT if Abyss.active else SaveSystem.AUTO_SLOT,
			_gather_save_data())


func _do_save(slot: int) -> void:
	SaveSystem.write(slot, _gather_save_data())
	_close_save_layer()
	main._screens._show_hud_popup("Game saved to Slot %d." % slot)


func _do_load(slot: int, through_black: bool = true) -> void:
	var data: Dictionary = SaveSystem.read(slot)
	if data.is_empty():
		return
	# From the title the loading screen is already covering this; in the game
	# the floor would swap in plain view, so it goes through black.
	var fade: ScreenFade = null
	if through_black:
		main._fading = true
		fade = ScreenFade.cover(main.get_tree())
		await fade.covered
	_close_save_layer()
	_restore_save(data)
	if fade != null:
		await main.get_tree().process_frame
		main._fading = false
		fade.reveal()


func _gather_save_data() -> Dictionary:
	var p: PlayerCharacter = main.player_char
	var visited_serial: Dictionary = {}
	for sp: Variant in main.visited_by_map.keys():
		visited_serial[sp as String] = SaveSystem.pack_cells(main.visited_by_map[sp] as Dictionary)

	return {
		timestamp   = Time.get_datetime_string_from_system(),
		abyss       = Abyss.active,
		abyss_seed  = Abyss.run_seed,
		floor_num   = main.floor_num,
		play_time   = main.play_time,
		player_pos  = [main.player_pos.x, main.player_pos.y],
		player_facing = main.player_facing,
		player = p.to_save(),
		map = {
			scene       = "res://scenes/map.tscn",
			maze        = main.current_level.maze,
			exit_wall   = [main.current_level.exit_wall_pos.x,   main.current_level.exit_wall_pos.y],
			exit_pos    = [main.current_level.exit_pos.x,        main.current_level.exit_pos.y],
			trap_cells  = SaveSystem.pack_cell_map(main.current_level.trap_cells),
			roamers     = SaveSystem.pack_cells(_roamer_cells()),
			orbs        = SaveSystem.pack_cells(main.current_level.orb_cells),
			chests      = SaveSystem.pack_cell_map(main.current_level.chest_cells),
			looted      = SaveSystem.pack_cells(main.current_level.looted),
			warden      = SaveSystem.vec2i_key(main.current_level.warden_pos),
			key_pos     = SaveSystem.vec2i_key(main.current_level.key_pos),
			key_taken   = main.current_level.key_taken,
			found_traps = SaveSystem.pack_cell_map(main.current_level.found_traps),
			has_key     = main._has_key,
			door_open   = main._door_open,
			boss_beaten = main._boss_beaten,
		},
		visited = visited_serial,
	}


func _restore_save(data: Dictionary) -> void:
	main.in_combat = false
	main.menu_open = false
	if is_instance_valid(main.overlay_layer):
		for c: Node in main.overlay_layer.get_children():
			c.queue_free()
	if is_instance_valid(main.menu_layer):
		for c: Node in main.menu_layer.get_children():
			c.queue_free()

	main.player_char.load_save(data["player"] as Dictionary)

	main.floor_num = int(data["floor_num"])
	main.play_time = float(data.get("play_time", 0.0))
	Abyss.active = bool(data.get("abyss", false))
	Abyss.run_seed = int(data.get("abyss_seed", 0))
	main._show_floor_title()
	Music.play(Music.dungeon_track(main.floor_num))

	if is_instance_valid(main.dungeon):
		main.dungeon.queue_free()
		main.dungeon = null
	if is_instance_valid(main.current_level):
		main.current_level.queue_free()
		main.current_level = null

	var map_data: Dictionary = data["map"] as Dictionary
	var scene_path: String   = map_data["scene"] as String
	var packed: PackedScene  = load(scene_path) as PackedScene
	main.current_level = packed.instantiate() as Level
	# Same reason as the other one: the level builds itself in Main._ready, and the
	# generated layout is thrown away below anyway — but the shape it builds
	# (maze or boss corridor) has to match the floor being restored.
	main.current_level.floor_num = main.floor_num
	main.world.add_child(main.current_level)

	# Overwrite the freshly-generated maze with the saved layout. Not the
	# Necromancer's hall: it is always built off Level.NECRO_HALL, so a save
	# made in it, or in the corridor that stood there before, finds the hall.
	var necro_hall: bool = Level.is_hall_floor(main.floor_num)
	if not necro_hall:
		var raw_maze: Array = map_data["maze"] as Array
		var saved_maze: Array[Array] = []
		for row: Variant in raw_maze:
			saved_maze.append(row as Array)
		main.current_level.maze = saved_maze

		var ew: Array  = map_data["exit_wall"]   as Array
		var ep: Array  = map_data["exit_pos"]    as Array
		main.current_level.exit_wall_pos   = Vector2i(int(ew[0]), int(ew[1]))
		main.current_level.exit_pos        = Vector2i(int(ep[0]), int(ep[1]))
	main.current_level.next_scene      = scene_path
	main.current_level.trap_cells      = SaveSystem.unpack_cell_map(map_data.get("trap_cells", {}) as Dictionary)
	_pending_roamers              = map_data.get("roamers", []) as Array
	if not necro_hall:
		main.current_level.orb_cells.assign(
				SaveSystem.unpack_cells(map_data.get("orbs", []) as Array).keys())
	# Caches are saved, so a load does not re-roll where they were and whether
	# they were empty. An older save's "mimics" list is simply ignored.
	var saved_chests: Dictionary = map_data.get("chests", {}) as Dictionary
	if not saved_chests.is_empty():
		main.current_level.chest_cells = SaveSystem.unpack_cell_map(saved_chests, true)
		main.current_level.looted = SaveSystem.unpack_cells(
				map_data.get("looted", []) as Array)
	main.current_level.warden_pos      = SaveSystem.key_vec2i(
			map_data.get("warden", "-1,-1") as String)
	main.current_level.key_pos         = SaveSystem.key_vec2i(
			map_data.get("key_pos", "-1,-1") as String)
	main.current_level.key_taken       = bool(map_data.get("key_taken", false))
	main.current_level.found_traps     = SaveSystem.unpack_cell_map(
			map_data.get("found_traps", {}) as Dictionary)
	_pending_has_key              = bool(map_data.get("has_key", true))
	# Saves from before the door needed turning: holding the key meant open.
	_pending_door_open            = bool(map_data.get("door_open", _pending_has_key))

	# The boss corridor's dragon is down only if it was down when this was
	# saved. Left alone, a load after the win (the party fell further on, so
	# back to before the fight) kept it dead and the corridor walked through.
	main._boss_beaten = bool(map_data.get("boss_beaten", false))

	main._hazards._spark_steps = 0
	main.dungeon = Dungeon.new()
	main.world.add_child(main.dungeon)
	main.dungeon.build(main.current_level)
	main._hazards._show_sparks()
	main._hazards._sync_boss_banner()

	# Restore fog-of-war.
	var raw_visited: Dictionary = data["visited"] as Dictionary
	main.visited_by_map = {}
	for sp: Variant in raw_visited.keys():
		main.visited_by_map[sp as String] = SaveSystem.unpack_cells(raw_visited[sp as String] as Array)
	main.visited = main.visited_by_map.get(scene_path, {})

	_point_minimap_at_level()
	main._sync_minimap_palette()
	main._resize_minimap()

	var pos_arr: Array = data["player_pos"] as Array
	main.player_pos    = Vector2i(int(pos_arr[0]), int(pos_arr[1]))
	main.player_facing = int(data["player_facing"])
	# A save from the corridor that used to be the bottom can stand somewhere
	# the hall has no floor: back to where the hall is come into.
	if Level.is_hall_floor(main.floor_num) and not main._is_open(main.player_pos.x, main.player_pos.y):
		main.player_pos = main.current_level.player_start
		main.player_facing = main.current_level.player_start_facing

	main._sync_player()
	main._snap_cam_yaw()
	# Player position is set above, so the roamers land relative to where the
	# save actually left them.
	_restore_roamers()
	main.hud_layer.visible = true


# Roamer positions are saved so a reload does not shuffle the floor's threats.
var _pending_roamers: Array = []


# Every one of these is a reference INTO the level, and both the walk-in and the
# load-a-save path build a brand new Level — so all of them have to be repointed
# or the map is still describing the floor before this one.
#
# It lives in one function because it did not: _restore_save repointed three of
# the seven, so a loaded run came back with no orb, no chest and no sprung trap
# on the map while the level itself knew exactly where all of them were.
func _point_minimap_at_level() -> void:
	main.minimap_ctrl.maze        = main.current_level.maze
	main.minimap_ctrl.visited     = main.visited
	main.minimap_ctrl.exit_pos    = main.current_level.exit_wall_pos
	main.minimap_ctrl.orb_cells   = main.current_level.orb_cells
	main.minimap_ctrl.chest_cells = main.current_level.chest_cells
	main.minimap_ctrl.looted      = main.current_level.looted
	main.minimap_ctrl.found_traps = main.current_level.found_traps


# Where the roamers stand, for the save.
func _roamer_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for r: Roamer in main.roamers:
		if is_instance_valid(r):
			out.append(r.cell)
	return out


var _pending_has_key: bool = true
var _pending_door_open: bool = true


func _restore_roamers() -> void:
	for r: Roamer in main.roamers:
		if is_instance_valid(r):
			r.queue_free()
	main.roamers.clear()
	main._engaged.clear()
	main._warden = null
	main._steps_since_spawn = 0
	for key: Variant in _pending_roamers:
		var rm: Roamer = Roamer.new()
		rm.cell = SaveSystem.key_vec2i(key as String)
		rm.tier = Enemy.roamer_tier(main.floor_num)
		main.world.add_child(rm)
		main.roamers.append(rm)
	_pending_roamers = []

	main._has_key = _pending_has_key
	main._door_open = _pending_door_open
	main.minimap_ctrl.warden_pos = Vector2i(-1, -1)
	main.minimap_ctrl.key_pos = Vector2i(-1, -1)
	if not main._has_key and main.current_level.key_pos.x >= 0 and not main.current_level.key_taken:
		main.minimap_ctrl.key_pos = main.current_level.key_pos
	if not main._has_key and main.current_level.warden_pos.x >= 0:
		var w: Roamer = Roamer.new()
		w.warden = true
		w.cell = main.current_level.warden_pos
		main.world.add_child(w)
		main.roamers.append(w)
		main._warden = w
		main.minimap_ctrl.warden_pos = w.cell
	main.minimap_ctrl.queue_redraw()
	# A loaded run arrives here with the geometry already built, so the door is
	# hung once Main._has_key is known rather than during the build.
	main._roaming._sync_door()


func _on_node_added(node: Node) -> void:
	if node is RichTextLabel:
		(node as RichTextLabel).add_theme_font_override("normal_font", Main._UI_FONT)
	elif node is Label:
		(node as Label).add_theme_font_override("font", Main._UI_FONT)
	elif node is Button:
		var btn := node as Button
		btn.add_theme_font_override("font", Main._UI_FONT)
		# Thumb-sized on a phone; on a wide screen, under a mouse or a pad, the
		# size the fight's windows use.
		if Build.steam():
			btn.add_theme_font_size_override("font_size", SidePanel.TEXT)
		else:
			btn.add_theme_font_size_override("font_size", 20)
			var cur: Vector2 = btn.custom_minimum_size
			if cur.y > 0:
				btn.custom_minimum_size = Vector2(cur.x, roundf(cur.y * 1.5))
	elif node is Control:
		(node as Control).add_theme_font_override("font", Main._UI_FONT)

