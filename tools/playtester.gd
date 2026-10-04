extends SceneTree
# An automated playtester: plays a run of Four Dragons Deep by itself, making
# the best decisions it can, and writes down how it went.
#
# It drives the real game through the same functions the screen's buttons
# call, the way tools/trailer.gd does, so what it plays is the game itself:
# walking the maze, picking up keys, opening chests, fighting with the press
# turn economy in mind, talking monsters into the party, resting, shopping and
# gearing up at orbs, and taking each dragon on.
#
# What it knows: the whole map of the floor it is on (it does not explore
# blind), and a monster's chart only once the game has shown it (a hit, an
# Analyze or a kill), the same as a player. When it talks a monster round it
# picks the line that matches the monster's temper, as a player who has
# scanned it would.
#
#   godot --path . --script tools/playtester.gd            plain run, real time
#
# Settings, all optional, as environment variables:
#   PLAYTEST_OUT    directory for report.md and events.log (default: .godot/playtest)
#   PLAYTEST_SPEED  Engine.time_scale (default 1; 8 or so for a fast headless run)
#   PLAYTEST_SEED   random seed (default: from the clock)
#   PLAYTEST_LOAD   save slot to start from (default: a new game)
#   PLAYTEST_STOP   floor to stop on: arriving there it saves to PLAYTEST_SLOT and quits
#   PLAYTEST_SLOT   the slot it saves into (default 3)
#   PLAYTEST_HOURS  stop after this much game time (default 6)
#   PLAYTEST_HUD    1 to caption the screen with what the bot is doing (for video)
#
# Recording: run it under Movie Maker, e.g.
#   godot --path . --resolution 540x1170 --fixed-fps 30 \
#       --write-movie out/run.avi --script tools/playtester.gd
#
# The machine's own saves are copied aside at the start and put back at the
# end, so a playtest never costs you a run.

const FONT: FontFile = preload("res://resources/misc/OldSchoolAdventures-42j9.ttf")

var main: Main
var out_dir: String = ""
var speed: float = 1.0
var stop_floor: int = -1
var bot_slot: int = 3
var max_seconds: float = 6.0 * 3600.0

var _events: FileAccess
var _backup: Dictionary = {}      # save path -> its text, put back at the end
var _t0: float = 0.0
var _done: bool = false
var _result: String = "unfinished"

# Bookkeeping for the report.
var fights: int = 0
var fights_won: int = 0
var fights_lost: int = 0
var fled: int = 0
var deaths: int = 0
var recruits: Array[String] = []
var items_used: Dictionary = {}
var spent: Dictionary = {rest = 0, gear = 0, scrolls = 0, supplies = 0}
var floor_log: Array[Dictionary] = []
var boss_log: Array[Dictionary] = []
var notes: Array[String] = []
# What the bot has seen of monsters' charts, "lore|element" -> affinity. Kept
# across a reload, which rolls the game's own bestiary back with the save: a
# player who has just died to the Thunder Dragon remembers what it drank.
var _memory: Dictionary = {}
var _boss_losses: Dictionary = {}     # floor -> times the boss there has won

# Per-floor memory.
var _orbs_done: Dictionary = {}       # cell -> true, orbs shopped at on this floor
var _orb_floor: int = -1
var _last_orb_cell: Vector2i = Vector2i(-99, -99)
var _stuck_ticks: int = 0
var _wander: Vector2i = Vector2i(-1, -1)
var _wander_ticks: int = 0            # steps spent looking for roamers with none in sight
var _no_prey: bool = false            # this floor has given up on hunting
var _last_why: String = ""
var _progress_t: float = 0.0          # game time of the last fight or new floor
var _last_pos: Vector2i = Vector2i(-99, -99)
var _talked: Dictionary = {}          # foe instance id -> true, one try each
var _fight_start_hp: int = 0
var _fight_turns: int = 0
var _boss_fight: bool = false
var _boss_name: String = ""
# How hard this fight hits: the most the party has lost to one enemy phase, per
# member, and what each had when our phase last ended.
var _phase_hit: Dictionary = {}       # member instance id -> worst loss seen
var _hp_after_us: Dictionary = {}     # member instance id -> hp when our phase ended


# ── Boot ─────────────────────────────────────────────────────────────────────

func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	OS.low_processor_usage_mode = false
	out_dir = OS.get_environment("PLAYTEST_OUT")
	if out_dir == "":
		out_dir = ProjectSettings.globalize_path("res://.godot/playtest")
	DirAccess.make_dir_recursive_absolute(out_dir)
	speed = maxf(0.1, float(OS.get_environment("PLAYTEST_SPEED"))) \
			if OS.get_environment("PLAYTEST_SPEED") != "" else 1.0
	Engine.time_scale = speed
	var seed_env: String = OS.get_environment("PLAYTEST_SEED")
	var s: int = int(seed_env) if seed_env != "" else int(Time.get_unix_time_from_system())
	seed(s)
	if OS.get_environment("PLAYTEST_STOP") != "":
		stop_floor = int(OS.get_environment("PLAYTEST_STOP"))
	if OS.get_environment("PLAYTEST_SLOT") != "":
		bot_slot = int(OS.get_environment("PLAYTEST_SLOT"))
	if OS.get_environment("PLAYTEST_HOURS") != "":
		max_seconds = float(OS.get_environment("PLAYTEST_HOURS")) * 3600.0
	var load_env: String = OS.get_environment("PLAYTEST_LOAD")
	var loading: int = int(load_env) if load_env != "" else 0
	_events = FileAccess.open(out_dir.path_join("events.log"),
			FileAccess.READ_WRITE if loading > 0 and FileAccess.file_exists(
				out_dir.path_join("events.log")) else FileAccess.WRITE)
	if _events:
		_events.seek_end()
	_backup_saves(loading)
	GameBoot.pending_slot = loading
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Main
	root.add_child(main)
	for i: int in 20:
		await process_frame
	_t0 = main.play_time
	if OS.get_environment("PLAYTEST_HUD") == "1":
		_build_hud()
	_event("start seed=%d floor=%d lv=%d %s" % [s, main.floor_num, main.player_char.lv,
			"(loaded slot %d)" % loading if loading > 0 else "(new game)"])
	_note_floor()
	await _run()
	_finish()


# Kept on disk as well as in memory, so a playtest killed partway still leaves
# the machine's saves recoverable: .godot/playtest_saves_backup/. If that folder
# is already there, an earlier run never finished, and what is in it (not what
# is in the save folder now) is the real thing.
const BACKUP_DIR: String = "res://.godot/playtest_saves_backup"


func _backup_saves(loading: int) -> void:
	var dir: String = ProjectSettings.globalize_path(BACKUP_DIR)
	var stale: bool = DirAccess.dir_exists_absolute(dir) and loading == 0
	if stale:
		_restore_from_disk(dir)
		print("PLAYTEST restored saves left behind by an unfinished playtest")
	DirAccess.make_dir_recursive_absolute(dir)
	for slot: int in range(1, SaveSystem.AUTO_SLOT + 1):
		var p: String = SaveSystem.slot_path(slot)
		# The slot a later segment loads from is the bot's own; keep it.
		if slot == bot_slot and loading == bot_slot:
			continue
		var name: String = p.get_file()
		if loading > 0 and FileAccess.file_exists(dir.path_join(name + ".none")) \
				or loading > 0 and FileAccess.file_exists(dir.path_join(name)):
			# A later segment: the first one already backed this slot up.
			_backup[p] = FileAccess.get_file_as_string(dir.path_join(name)) \
					if FileAccess.file_exists(dir.path_join(name)) else null
			continue
		_backup[p] = FileAccess.get_file_as_string(p) if FileAccess.file_exists(p) else null
		if _backup[p] == null:
			FileAccess.open(dir.path_join(name + ".none"), FileAccess.WRITE)
		else:
			FileAccess.open(dir.path_join(name), FileAccess.WRITE).store_string(_backup[p] as String)


func _restore_from_disk(dir: String) -> void:
	for slot: int in range(1, SaveSystem.AUTO_SLOT + 1):
		var p: String = SaveSystem.slot_path(slot)
		var name: String = p.get_file()
		if FileAccess.file_exists(dir.path_join(name)):
			FileAccess.open(p, FileAccess.WRITE).store_string(
					FileAccess.get_file_as_string(dir.path_join(name)))
		elif FileAccess.file_exists(dir.path_join(name + ".none")) and FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	for f: String in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	DirAccess.remove_absolute(dir)


func _restore_saves() -> void:
	for p: String in _backup:
		var keep_bot: bool = p == SaveSystem.slot_path(bot_slot) and stop_floor > 0 \
				and _result == "stopped"
		if keep_bot:
			continue    # the next segment loads it
		if _backup[p] == null:
			if FileAccess.file_exists(p):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
		else:
			var f: FileAccess = FileAccess.open(p, FileAccess.WRITE)
			f.store_string(_backup[p] as String)
	# The run is over (or this segment hands on to the next): the disk copy
	# goes once nothing more will load from the bot's slot.
	if not (stop_floor > 0 and _result == "stopped"):
		var dir: String = ProjectSettings.globalize_path(BACKUP_DIR)
		for f2: String in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir.path_join(f2))
		DirAccess.remove_absolute(dir)


var _hud: Label = null
var _hud_floor: Label = null


func _build_hud() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 128
	root.add_child(layer)
	var band: ColorRect = ColorRect.new()
	band.color = Color(0, 0, 0, 0.55)
	band.anchor_right = 1.0
	# Just above the battle menu (CombatScene.MENU_STRIP_H from the bottom),
	# which is open floor in a fight and the lower corridor on the walk.
	var top: float = 1170.0 - float(CombatScene.MENU_STRIP_H) - 50.0
	band.offset_top = top
	band.offset_bottom = top + 48.0
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(band)
	_hud_floor = Label.new()
	_hud_floor.add_theme_font_override("font", FONT)
	_hud_floor.add_theme_font_size_override("font_size", 13)
	_hud_floor.add_theme_color_override("font_color", Color(0.90, 0.75, 0.30))
	_hud_floor.position = Vector2(8, top + 2.0)
	_hud_floor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_hud_floor)
	_hud = Label.new()
	_hud.add_theme_font_override("font", FONT)
	_hud.add_theme_font_size_override("font_size", 13)
	_hud.add_theme_color_override("font_color", Color(0.92, 0.94, 1.0))
	_hud.position = Vector2(8, top + 22.0)
	_hud.size = Vector2(524, 24)
	_hud.clip_text = true
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_hud)


func _hud_say(line: String) -> void:
	if _hud == null:
		return
	var t: String = line.strip_edges()
	if t.begins_with("|"):
		return
	t = t.replace("heading for ", "> ")
	var cut: int = t.find("  over ")
	if cut > 0:
		t = t.substr(0, cut)
	var b: int = t.rfind(" [")
	if b > 0 and t.ends_with("]"):
		t = t.substr(0, b)
	_hud.text = t
	var p: PlayerCharacter = main.player_char if is_instance_valid(main) else null
	if p:
		_hud_floor.text = "PLAYTEST BOT   Floor %d   Lv %d   %d g   deaths %d" % [
				main.floor_num, p.lv, p.gold, deaths]


func _event(line: String) -> void:
	_hud_say(line)
	var stamp: String = "[F%02d %6.0fs]" % [main.floor_num if main else 0,
			main.play_time if main else 0.0]
	print("PLAYTEST ", stamp, " ", line)
	if _events:
		_events.store_line("%s %s" % [stamp, line])
		_events.flush()


# ── The loop ─────────────────────────────────────────────────────────────────

func _run() -> void:
	while not _done:
		await process_frame
		if not is_instance_valid(main) or main.get_tree() == null:
			_result = "left the game scene"
			return
		if main.play_time - _t0 > max_seconds:
			_result = "time limit"
			return
		await _tick()


func _tick() -> void:
	var ending: Node = _find_in(main.overlay_layer, "EndingUI")
	if ending != null:
		_result = "won"
		_event("THE NECROMANCER FALLS. Run won at lv %d." % main.player_char.lv)
		await _wait(6.0)
		_done = true
		return
	var over: Node = _find_in(main.overlay_layer, "GameOverUI")
	if over != null:
		await _on_game_over(over)
		return
	var scene: CombatScene = _combat_scene()
	if scene != null:
		await _combat_tick(scene)
		return
	if main.in_combat:
		await _overlay_tick()
		return
	if main.chest_open:
		await _chest_tick()
		return
	if main.orb_open:
		await _orb_tick()
		return
	if main.save_open:
		main._close_save_layer()
		return
	if main.menu_open:
		main._close_menu()
		return
	if main._fading or _find_in(root, "ScreenFade") != null:
		return
	if main.floor_num != _orb_floor:
		_new_floor()
	if stop_floor > 0 and main.floor_num >= stop_floor:
		main._do_save(bot_slot)
		_result = "stopped"
		_event("segment ends on floor %d (saved to slot %d)" % [main.floor_num, bot_slot])
		_done = true
		return
	await _walk_tick()


func _new_floor() -> void:
	_progress_t = main.play_time
	_orb_floor = main.floor_num
	_no_prey = false
	_wander_ticks = 0
	_orbs_done.clear()
	_last_orb_cell = Vector2i(-99, -99)
	_note_floor()


func _note_floor() -> void:
	var p: PlayerCharacter = main.player_char
	var row: Dictionary = {floor = main.floor_num, lv = p.lv, gold = p.gold,
			time = int(main.play_time), demons = ", ".join(p.recruited),
			weapon = p.equipped_weapon.get("name", "-"), armor = p.equipped_armor.get("name", "-")}
	if not floor_log.is_empty() and int(floor_log[-1]["floor"]) == main.floor_num:
		return
	floor_log.append(row)
	_event("arrive floor %d: lv %d, %d gold, party [%s], %s / %s" % [main.floor_num, p.lv,
			p.gold, ", ".join(p.active_demons), row["weapon"], row["armor"]])


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


# ── Finding things on screen ─────────────────────────────────────────────────

func _find_in(from: Node, cls: String) -> Node:
	if from == null or not is_instance_valid(from):
		return null
	for n: Node in from.find_children("*", cls, true, false):
		if not n.is_queued_for_deletion():
			return n
	return null


func _combat_scene() -> CombatScene:
	for c: Node in main.get_children():
		if c is CanvasLayer:
			for cc: Node in c.get_children():
				if cc is CombatScene and not cc.is_queued_for_deletion():
					return cc as CombatScene
	return null


# The first visible, live button whose own text or a label inside it is `text`.
func _button(from: Node, text: String) -> Button:
	if from == null:
		return null
	var want: String = text.to_lower()
	for n: Node in from.find_children("*", "Button", true, false):
		var b: Button = n as Button
		if not b.is_visible_in_tree() or b.disabled:
			continue
		if b.text.to_lower() == want:
			return b
		for l: Node in b.find_children("*", "Label", true, false):
			if (l as Label).text.to_lower() == want:
				return b
	return null


func _press(from: Node, text: String) -> bool:
	var b: Button = _button(from, text)
	if b == null:
		return false
	b.pressed.emit()
	return true


# ── Overlays after a fight ───────────────────────────────────────────────────

func _overlay_tick() -> void:
	var layer: CanvasLayer = main.overlay_layer
	var lvl: LevelUpUI = _find_in(layer, "LevelUpUI") as LevelUpUI
	if lvl != null:
		await _wait(0.8)
		_allocate(lvl)
		await _wait(0.6)
		lvl._on_confirm()
		return
	var dlv: Node = _find_in(layer, "DemonLevelUpUI")
	if dlv != null:
		await _wait(0.7)
		if _button(dlv, "Learn") != null:
			_press(dlv, "Learn")
		elif _button(dlv, "Continue") != null:
			_press(dlv, "Continue")
		elif _forget_for(dlv):
			pass
		else:
			_press(dlv, "Skip")
		return
	var res: Node = _find_in(layer, "CombatResultUI")
	if res != null:
		await _wait(1.0)
		_press(res, "Continue")
		return


# Three points a level, toward a hero who casts first and swings second: MAG
# for the spells that read weaknesses, AGL so they land and the party moves
# first, DEF for HP and a guard, LUK for crits and fewer ambushes, a little STR.
const BUILD: Dictionary = {mag = 0.36, agl = 0.20, def = 0.22, luk = 0.12, str = 0.10}


func _allocate(ui: LevelUpUI) -> void:
	var p: PlayerCharacter = main.player_char
	var cur: Dictionary = {mag = p.mag, agl = p.agl, def = p.def, luk = p.luk, str = p.str}
	while ui._pts_remaining > 0:
		var total: float = 0.0
		for k: String in cur:
			total += float(cur[k])
		var best: String = "mag"
		var gap: float = -INF
		for k: String in BUILD:
			var g: float = float(BUILD[k]) * (total + 1.0) - float(cur[k])
			if g > gap:
				gap = g
				best = k
		cur[best] = int(cur[best]) + 1
		ui._on_plus(best)


# A full demon offered something new: forget a support it already has two of,
# or the weakest line, only for a new element it does not carry.
func _forget_for(_ui: Node) -> bool:
	return false


const MAX_DEATHS: int = 30


func _on_game_over(ui: Node) -> void:
	deaths += 1
	_event("DIED (death %d) at lv %d" % [deaths, main.player_char.lv])
	await _wait(2.0)
	if deaths >= MAX_DEATHS:
		_result = "died %d times" % MAX_DEATHS
		_done = true
		return
	var slot: int = bot_slot if SaveSystem.read(bot_slot).size() > 0 else SaveSystem.AUTO_SLOT
	if SaveSystem.read(slot).is_empty():
		_result = "died with no save"
		_done = true
		return
	ui.queue_free()
	main.in_combat = false
	_event("reloading slot %d" % slot)
	await main._do_load(slot, true)
	await _wait(1.0)
	_new_floor()


func _chest_tick() -> void:
	await _wait(0.5)
	if _press(main.chest_layer, "Open it"):
		await _wait(1.4)
		return
	if _press(main.chest_layer, "Close"):
		await _wait(0.3)
		return


# ── Walking ──────────────────────────────────────────────────────────────────

const COST_STEP: int = 1
const COST_ORB: int = 4        # stepping on an orb opens it
const COST_SPARK: int = 6
const COST_LAVA: int = 40
const COST_ROAMER: int = 3


# Where a step from `c` toward `d` really ends: across ice until it stops, and
# through a teleporter to its twin.
func _land(c: Vector2i, d: int) -> Vector2i:
	var lvl: Level = main.current_level
	var n: Vector2i = c + Main.DIR_OFFSET[d]
	if not main._is_open(n.x, n.y):
		return Vector2i(-99, -99)
	var guard: int = 0
	while Level.hazard_kind(lvl.trap_cells.get(n, "") as String) == Level.HAZARD_ICE and guard < 32:
		guard += 1
		var m: Vector2i = n + Main.DIR_OFFSET[d]
		if not main._is_open(m.x, m.y):
			break
		n = m
	var here: String = lvl.trap_cells.get(n, "") as String
	if Level.hazard_kind(here) == Level.HAZARD_TELE:
		var to: Vector2i = Level.tele_target(here)
		if main._is_open(to.x, to.y):
			return to
	return n


func _cell_cost(c: Vector2i, goal: Vector2i) -> int:
	var lvl: Level = main.current_level
	var cost: int = COST_STEP
	var kind: String = Level.hazard_kind(lvl.trap_cells.get(c, "") as String)
	if kind == Level.HAZARD_LAVA:
		cost += COST_LAVA
	elif kind == Level.HAZARD_SPARK:
		cost += COST_SPARK
	if c in lvl.orb_cells and c != goal:
		cost += COST_ORB
	return cost


# Dijkstra over the floor from where the hero stands. Returns {cell: [cost,
# first_dir]} so any goal can be read off one search.
func _search() -> Dictionary:
	var start: Vector2i = main.player_pos
	var best: Dictionary = {start: [0, -1]}
	var open: Array = [[0, start, -1]]
	while not open.is_empty():
		var at: int = 0
		for i: int in open.size():
			if int(open[i][0]) < int(open[at][0]):
				at = i
		var cur: Array = open[at]
		open.remove_at(at)
		var c: Vector2i = cur[1]
		if int(cur[0]) > int((best[c] as Array)[0]):
			continue
		for d: int in 4:
			var n: Vector2i = _land(c, d)
			if n.x == -99:
				continue
			var nc: int = int(cur[0]) + _cell_cost(n, Vector2i(-99, -99))
			if not best.has(n) or nc < int((best[n] as Array)[0]):
				var first: int = d if c == start else int(cur[2])
				best[n] = [nc, first]
				open.append([nc, n, first])
	return best


func _goal() -> Dictionary:
	var lvl: Level = main.current_level
	var p: PlayerCharacter = main.player_char
	var reach: Dictionary = _search()
	var reachable := func(c: Vector2i) -> bool: return reach.has(c)
	var dist := func(c: Vector2i) -> int: return int((reach[c] as Array)[0]) if reach.has(c) else 99999

	# Twenty minutes of nothing: stop dawdling and take the way down.
	if main.play_time - _progress_t > 1200.0:
		if not _no_prey:
			_event("STALL: nothing has happened for 20 minutes; making for the exit")
		_no_prey = true
		if main._has_key or Level.is_boss_floor(main.floor_num) or lvl.key_taken:
			return {cell = lvl.exit_pos, face = Main.DIR_OFFSET.find(lvl.exit_wall_pos - lvl.exit_pos),
					why = "exit (stalled)"}

	# Hurt and nothing to mend with: the nearest orb first.
	var hurt: bool = p.hp * 100 < p.max_hp * 45
	if hurt and not _can_mend():
		var o: Vector2i = _nearest(lvl.orb_cells, dist)
		if o.x >= 0 and o != main.player_pos:
			return {cell = o, why = "orb (hurt)"}

	# Every orb once a floor: rest, shop, save.
	for o: Vector2i in _sorted(lvl.orb_cells, dist):
		if not _orbs_done.has(o) and reachable.call(o):
			return {cell = o, why = "orb"}

	# Caches in the walls.
	for wall: Variant in lvl.chest_cells.keys():
		if lvl.looted.has(wall):
			continue
		var cell: Vector2i = lvl.chest_cells[wall]
		if reachable.call(cell) and dist.call(cell) < 60:
			return {cell = cell, face = Main.DIR_OFFSET.find((wall as Vector2i) - cell),
					why = "chest"}

	# The key, or the warden holding it.
	if not main._has_key and not Level.is_boss_floor(main.floor_num):
		if is_instance_valid(main._warden):
			# A warden is a third of a dragon: arrive over-levelled and whole.
			if p.lv >= _wanted_level() + 2 and p.hp * 100 >= p.max_hp * 85:
				return {cell = main._warden.cell, why = "warden"}
			var prey: Roamer = _nearest_roamer(dist)
			if prey != null:
				return {cell = prey.cell, why = "hunt before the warden (lv %d)" % p.lv}
			if p.hp * 100 < p.max_hp * 85:
				var o2: Vector2i = _nearest(lvl.orb_cells, dist)
				if o2.x >= 0 and o2 != main.player_pos:
					_orbs_done.erase(o2)
					return {cell = o2, why = "orb before the warden"}
			return {cell = main._warden.cell, why = "warden"}
		if lvl.key_pos.x >= 0 and not lvl.key_taken:
			return {cell = lvl.key_pos, why = "key"}

	# Under the level of what lives here: hunt the floor's roamers first.
	if p.lv < _wanted_level() and not _no_prey and not Level.is_boss_floor(main.floor_num):
		var nearest: Roamer = _nearest_roamer(dist)
		if nearest != null:
			_wander_ticks = 0
			return {cell = nearest.cell, why = "hunt (lv %d < %d)" % [p.lv, _wanted_level()]}
		# Nothing about: walk somewhere far so they come back.
		_wander_ticks += 1
		if _wander_ticks > 120:
			_no_prey = true
			_event("no roamers turning up; done hunting on this floor")
		if _wander.x < 0 or _wander == main.player_pos or not reachable.call(_wander):
			_wander = main._far_open_cell(8)
		if reachable.call(_wander):
			return {cell = _wander, why = "wander for roamers"}

	# The way down (or the dragon).
	return {cell = lvl.exit_pos, face = Main.DIR_OFFSET.find(lvl.exit_wall_pos - lvl.exit_pos),
			why = "exit"}


func _nearest_roamer(dist: Callable) -> Roamer:
	var nearest: Roamer = null
	var nd: int = 99999
	for r: Roamer in main.roamers:
		if not is_instance_valid(r) or r.warden or not r.visible:
			continue
		var dd: int = dist.call(r.cell)
		if dd < nd:
			nd = dd
			nearest = r
	return nearest


# The level a floor's ordinary monsters stand at (Enemy.level_for_floor), less
# one: arriving under it is how the opening floors kill a hero.
func _wanted_level() -> int:
	if Level.is_boss_floor(main.floor_num):
		# The dragon stands at twice the floor; one level more for every time
		# it has already won.
		return main.floor_num * 2 - 1 + int(_boss_losses.get(main.floor_num, 0))
	return maxi(1, roundi(float(main.floor_num) * 1.5) - 1) \
			+ int(_boss_losses.get(main.floor_num, 0))


func _nearest(cells: Array, dist: Callable) -> Vector2i:
	var best: Vector2i = Vector2i(-1, -1)
	var bd: int = 99999
	for c: Vector2i in cells:
		var dd: int = dist.call(c)
		if dd < bd:
			bd = dd
			best = c
	return best


func _sorted(cells: Array, dist: Callable) -> Array:
	var out: Array = cells.duplicate()
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return dist.call(a) < dist.call(b))
	return out


func _walk_tick() -> void:
	if _field_mend():
		await _wait(0.6)
		return
	var goal: Dictionary = _goal()
	var target: Vector2i = goal["cell"]
	var why: String = goal["why"] as String
	if why != _last_why:
		_last_why = why
		_event("  heading for %s" % why)
	if main.player_pos == _last_pos:
		_stuck_ticks += 1
	else:
		_stuck_ticks = 0
		_last_pos = main.player_pos
	if _stuck_ticks > 40:
		_event("stuck at %s going for %s; nudging" % [main.player_pos, goal["why"]])
		_stuck_ticks = 0
		await _turn_to(randi() % 4)
		main._action_forward()
		await _wait(0.3)
		return

	if main.player_pos == target:
		if goal.has("face"):
			await _turn_to(int(goal["face"]))
			main._action_forward()     # opens the chest, turns the key, goes down
			await _wait(0.45)
		elif (goal["why"] as String).begins_with("orb"):
			# It opens on arrival only: step off, and the next tick steps back on.
			for d: int in 4:
				var n: Vector2i = main.player_pos + Main.DIR_OFFSET[d]
				if main._is_open(n.x, n.y) and not n in main.current_level.trap_cells:
					await _turn_to(d)
					main._action_forward()
					await _wait(0.3)
					return
			_orbs_done[target] = true
		return

	var reach: Dictionary = _search()
	if not reach.has(target):
		_event("can't reach %s (%s)" % [target, goal["why"]])
		if goal["why"].begins_with("orb"):
			_orbs_done[target] = true
		await _wait(0.2)
		return
	var first: int = int((reach[target] as Array)[1])
	await _turn_to(first)
	main._action_forward()
	await _wait(0.30)


func _turn_to(d: int) -> void:
	if d < 0:
		return
	var guard: int = 0
	while main.player_facing != d and guard < 4:
		guard += 1
		if (main.player_facing + 1) % 4 == d:
			main._action_turn_right()
		else:
			main._action_turn_left()
		await _wait(0.18)


# Between fights: a heal spell if the MP is there (it comes back as you walk),
# else the smallest potion that does the job. Never walk into a fight half dead.
func _field_mend() -> bool:
	var p: PlayerCharacter = main.player_char
	if p.hp * 100 >= p.max_hp * 60:
		return false
	var missing: int = p.max_hp - p.hp
	var spell: String = ""
	for id: String in p.known_spells:
		var d: Dictionary = Spell.get_data(id)
		if d.get("type", "") != "heal" or p.mp < int(d.get("mp", 0)):
			continue
		if spell == "" or int(d.get("mp", 0)) < int(Spell.get_data(spell).get("mp", 0)):
			spell = id
	if spell != "":
		p.mp -= int(Spell.get_data(spell).get("mp", 0))
		var before: int = p.hp
		p.heal(p.heal_amount_for(spell))
		_event("cast %s on the way: +%d HP" % [Spell.get_data(spell).get("name", spell), p.hp - before])
		return true
	if p.hp * 100 >= p.max_hp * 40:
		return false     # a potion is worth more in a fight
	var best: Dictionary = {}
	for item: Dictionary in p.battle_items():
		var r: int = int(item.get("hp_restore", 0))
		if r <= 0 or item.get("party", false) or int(item.get("mp_restore", 0)) > 0:
			continue
		if best.is_empty() or absi(r - missing) < absi(int(best["hp_restore"]) - missing):
			best = item
	if best.is_empty():
		return false
	items_used[best["name"]] = int(items_used.get(best["name"], 0)) + 1
	_event("drank %s on the way: %s" % [best["name"], p.use_item(best)])
	return true


func _can_mend() -> bool:
	var p: PlayerCharacter = main.player_char
	for item: Dictionary in p.battle_items():
		if int(item.get("hp_restore", 0)) > 0:
			return true
	for id: String in p.equipped_spells:
		var d: Dictionary = Spell.get_data(id)
		if d.get("type", "") == "heal" and p.mp >= int(d.get("mp", 0)):
			return true
	return false


# ── The orb ──────────────────────────────────────────────────────────────────

func _orb_tick() -> void:
	var ui: OrbUI = _find_in(main.orb_layer, "OrbUI") as OrbUI
	if ui == null:
		return
	var here: Vector2i = main.player_pos
	if _orbs_done.has(here) and main.player_char.hp >= main.player_char.max_hp \
			and main.player_char.mp >= main.player_char.max_mp:
		await _wait(0.4)
		ui.closed.emit()
		return
	_orbs_done[here] = true
	await _wait(0.6)
	await _orb_visit(ui)
	if not is_instance_valid(ui):
		return
	await _wait(0.5)
	if main.orb_open:
		ui.closed.emit()


func _show_tab(ui: OrbUI, tab: String) -> void:
	if is_instance_valid(ui):
		ui._switch(tab)
		await _wait(0.5)


func _orb_visit(ui: OrbUI) -> void:
	var p: PlayerCharacter = main.player_char
	# Rest first: the price only grows with what is missing.
	await _show_tab(ui, "rest")
	var hp_cost: int = OrbUI.hp_price(p)
	if hp_cost > 0 and p.gold >= hp_cost:
		p.gold -= hp_cost
		p.hp = p.max_hp
		spent["rest"] += hp_cost
	var mp_cost: int = OrbUI.mp_price(p)
	if mp_cost > 0 and p.gold >= mp_cost and p.mp * 100 < p.max_mp * 80:
		p.gold -= mp_cost
		p.mp = p.max_mp
		spent["rest"] += mp_cost
	ui._refresh()

	await _show_tab(ui, "sell")
	_sell_junk(ui)

	# Under-levelled where there is nothing to hunt (a boss floor, or roamers
	# that never come): the Gauntlet, which pays back twice what it costs.
	if _should_grind() and (Level.is_boss_floor(main.floor_num) or _no_prey):
		await _show_tab(ui, "gauntlet")
		if _gauntlet(ui):
			return

	# The essentials before anything shiny: a few potions and an ether.
	await _show_tab(ui, "buy")
	_restock(ui, true)

	await _show_tab(ui, "scrolls")
	_buy_scrolls(ui)
	_set_loadout()

	await _show_tab(ui, "gear")
	_gear_up(ui)

	await _show_tab(ui, "buy")
	_restock(ui, false)

	_rebind()
	_set_party()

	await _show_tab(ui, "save")
	main._do_save(bot_slot)
	await _wait(0.3)


# ── Selling ──

func _sell_junk(ui: OrbUI) -> void:
	var p: PlayerCharacter = main.player_char
	var sold: Array[String] = []
	for item: Dictionary in p.inventory.duplicate():
		var kind: String = item.get("type", "") as String
		var junk: bool = false
		if kind in ["weapon", "armor"]:
			junk = true    # anything not worn has been outclassed or never fit
		elif kind == "accessory":
			junk = _acc_score(item) <= _worst_worn_acc_score()
		elif kind == "scroll":
			junk = (item.get("teaches", "") as String) in p.known_spells
		if junk:
			var price: int = OrbUI.resale_price(item)
			var n: int = int(item.get("qty", 1))
			p.remove_item(item, n)
			p.gold += price * n
			sold.append(item.get("name", "?") as String)
	if not sold.is_empty():
		_event("sold %s" % ", ".join(sold))
	ui._refresh()


# ── Gear ──

# What lives in this band and the next dragon, as weights per element: what
# they cast at you and how often.
func _threats() -> Dictionary:
	var tier: int = Level.tier_of(main.floor_num)
	var w: Dictionary = {}
	# On a dragon's floor only the dragon matters: dress for it alone.
	if Level.is_boss_floor(main.floor_num) and main.floor_num <= Level.DRAGON_FLOORS:
		var bd: Enemy = Enemy.make_boss(main.floor_num)
		for e: String in bd.attack_elements:
			w[e] = 1.0 / float(bd.attack_elements.size())
		bd.free()
		return w
	for t: Dictionary in Enemy.TEMPLATES:
		if int(t.get("tier", 1)) != tier:
			continue
		for e: String in Enemy._elements_from(t):
			w[e] = float(w.get(e, 0.0)) + 1.0
		w[Affinity.PHYS] = float(w.get(Affinity.PHYS, 0.0)) + 0.6
	var boss_floor: int = ((main.floor_num - 1) / Level.BOSS_EVERY + 1) * Level.BOSS_EVERY
	if boss_floor <= Level.DRAGON_FLOORS:
		var b: Enemy = Enemy.make_boss(boss_floor)
		for e: String in b.attack_elements:
			w[e] = float(w.get(e, 0.0)) + 4.0
		b.free()
	var total: float = 0.0
	for k: String in w:
		total += float(w[k])
	for k: String in w:
		w[k] = float(w[k]) / maxf(1.0, total)
	return w


func _chart_score(item: Dictionary) -> float:
	var w: Dictionary = _threats()
	var s: float = 0.0
	for e: String in Armor.resists_of(item):
		s += float(w.get(e, 0.0)) * 30.0
		if e == "ice":
			s += 4.0     # the hero is born weak to it
	for e: String in Armor.weaknesses_of(item):
		s -= float(w.get(e, 0.0)) * 45.0
	return s


func _weapon_score(item: Dictionary) -> float:
	if item.is_empty():
		return 0.0
	var el: String = item.get("attack_element", "") as String
	var s: float = float(item.get("mag_bonus", 0)) * 1.3 + float(item.get("str_bonus", 0)) * 0.8 \
			+ float(item.get("def_bonus", 0)) * 0.6 + float(item.get("agl_pen", 0)) * 0.9
	if Affinity.is_banishing(el):
		s -= 6.0       # a swing that only banishes is a gamble
	return s


func _armor_score(item: Dictionary) -> float:
	if item.is_empty():
		return 0.0
	return float(item.get("def_bonus", 0)) * 1.7 + float(item.get("agl_pen", 0)) * 1.1 \
			+ _chart_score(item)


func _acc_score(item: Dictionary) -> float:
	if item.is_empty():
		return 0.0
	var s: float = float(item.get("mag_bonus", 0)) * 1.3 + float(item.get("str_bonus", 0)) * 0.6 \
			+ float(item.get("def_bonus", 0)) * 1.0 + float(item.get("agl_bonus", 0)) * 1.1 \
			+ float(item.get("luk_bonus", 0)) * 0.8 + _chart_score(item)
	var wards: String = GearTooltip.wards_text(item)
	if wards != "":
		s += 5.0 + (10.0 if "," in wards or wards.to_lower().contains("every") else 0.0)
	return s


func _worst_worn_acc_score() -> float:
	var p: PlayerCharacter = main.player_char
	if p.equipped_accessories.size() < PlayerCharacter.ACCESSORY_SLOTS:
		return -INF
	var worst: float = INF
	for a: Dictionary in p.equipped_accessories:
		worst = minf(worst, _acc_score(a))
	return worst


func _gear_up(ui: OrbUI) -> void:
	var p: PlayerCharacter = main.player_char
	# Keep enough for the supplies shelf.
	var reserve: int = 60 + main.floor_num * 15
	var shelf: Array[Dictionary] = ui._gear()
	# Best upgrade first, by gain per gold.
	var buys: Array = []
	for g: Dictionary in shelf:
		var price: int = OrbUI.item_price(g)
		var gain: float = 0.0
		match g.get("type", ""):
			"weapon": gain = _weapon_score(g) - _weapon_score(p.equipped_weapon)
			"armor":  gain = _armor_score(g) - _armor_score(p.equipped_armor)
			"accessory":
				if p.is_accessory_equipped(g.get("id", "") as String) or p.owns(g.get("id", "") as String):
					continue
				gain = _acc_score(g) - maxf(_worst_worn_acc_score(), 0.0)
		if gain > 0.5:
			buys.append([gain / float(price), g, price, gain])
	buys.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	for b: Array in buys:
		var g: Dictionary = b[1]
		var price: int = b[2]
		if p.gold - price < reserve:
			continue
		# Re-check against what is worn now: an earlier buy may have beaten it.
		var still: bool = false
		match g.get("type", ""):
			"weapon": still = _weapon_score(g) > _weapon_score(p.equipped_weapon) + 0.5
			"armor":  still = _armor_score(g) > _armor_score(p.equipped_armor) + 0.5
			"accessory": still = _acc_score(g) > _worst_worn_acc_score() + 0.5
		if not still:
			continue
		p.gold -= price
		spent["gear"] += price
		var bought: Dictionary = g.duplicate()
		p.add_item(bought, 1)
		_equip_best()
		_event("bought %s (%d g)" % [g["name"], price])
	_equip_best()
	ui._refresh()


# Puts on the best of everything carried.
func _equip_best() -> void:
	var p: PlayerCharacter = main.player_char
	for item: Dictionary in p.inventory.duplicate():
		match item.get("type", ""):
			"weapon":
				if _weapon_score(item) > _weapon_score(p.equipped_weapon) + 0.01:
					p.equip_weapon(_one_of(item))
			"armor":
				if _armor_score(item) > _armor_score(p.equipped_armor) + 0.01:
					p.equip_armor(_one_of(item))
			"accessory":
				if p.is_accessory_equipped(item.get("id", "") as String):
					continue
				if p.has_free_accessory_slot():
					p.equip_accessory(_one_of(item))
				elif _acc_score(item) > _worst_worn_acc_score() + 0.01:
					var worst: Dictionary = {}
					for a: Dictionary in p.equipped_accessories:
						if worst.is_empty() or _acc_score(a) < _acc_score(worst):
							worst = a
					p.unequip_accessory(worst.get("id", "") as String)
					p.equip_accessory(_one_of(item))


# A stack of two is one dictionary with qty 2; wearing one splits it.
func _one_of(item: Dictionary) -> Dictionary:
	var p: PlayerCharacter = main.player_char
	if int(item.get("qty", 1)) <= 1:
		return item
	item["qty"] = int(item["qty"]) - 1
	var one: Dictionary = item.duplicate()
	one["qty"] = 1
	p.inventory.append(one)
	return one


# ── Spells ──

# The five a run like this wants: the best single-target line of each of the
# three damage elements (weaknesses are the whole game), the best heal, and
# Stoke for the long fights.
func _wanted_spells() -> Array[String]:
	var p: PlayerCharacter = main.player_char
	var out: Array[String] = []
	var heal: String = _best_known(func(d: Dictionary, id: String) -> float:
		if d.get("type", "") != "heal":
			return -1.0
		var amt: float = minf(float(d.get("heal", 0)), float(p.max_hp))
		return amt * (1.6 if Spell.is_multi(id) and not p.active_demons.is_empty() else 1.0) \
				- float(d.get("mp", 0)) * 0.5)
	if heal != "":
		out.append(heal)
	for el: String in ["fire", "ice", "thunder"]:
		var best: String = _best_known(func(d: Dictionary, id: String) -> float:
			if d.get("element", "") != el or d.get("type", "") != "dmg":
				return -1.0
			if Spell.is_multi(id):
				return float(d.get("power", 0)) * 0.7
			return float(d.get("power", 0)))
		if best != "":
			out.append(best)
	for extra: String in ["stoke", "sunder", "analyze"]:
		if out.size() < PlayerCharacter.SPELL_SLOTS and extra in p.known_spells:
			out.append(extra)
	return out


func _best_known(score: Callable) -> String:
	var p: PlayerCharacter = main.player_char
	var best: String = ""
	var bs: float = -0.5
	for id: String in p.known_spells:
		var d: Dictionary = Spell.get_data(id)
		var s: float = score.call(d, id)
		if s > bs:
			bs = s
			best = id
	return best


func _set_loadout() -> void:
	var p: PlayerCharacter = main.player_char
	var want: Array[String] = _wanted_spells()
	for id: String in p.equipped_spells.duplicate():
		if id not in want:
			p.unequip_spell(id)
	for id: String in want:
		if not p.is_equipped(id):
			p.equip_spell(id)


# Scrolls worth reading: a higher rung of an element it fights with, a better
# heal, Stoke and Sunder.
func _buy_scrolls(ui: OrbUI) -> void:
	var p: PlayerCharacter = main.player_char
	var reserve: int = 40 + main.floor_num * 12
	var stock: Array[Dictionary] = Item.scrolls_for_floor(main.floor_num)
	var picks: Array = []
	for s: Dictionary in stock:
		var id: String = s.get("teaches", "") as String
		if id in p.known_spells or p.has_item(s.get("id", "") as String):
			continue
		var d: Dictionary = Spell.get_data(id)
		var value: float = 0.0
		if d.get("type", "") == "dmg" and d.get("element", "") in ["fire", "ice", "thunder"] \
				and not Spell.is_multi(id):
			var have: float = 0.0
			for k: String in p.known_spells:
				var kd: Dictionary = Spell.get_data(k)
				if kd.get("element", "") == d["element"] and kd.get("type", "") == "dmg" \
						and not Spell.is_multi(k):
					have = maxf(have, float(kd.get("power", 0)))
			value = (float(d.get("power", 0)) - have) * 10.0
		elif d.get("type", "") == "heal":
			var best_heal: float = 0.0
			for k: String in p.known_spells:
				var kd: Dictionary = Spell.get_data(k)
				if kd.get("type", "") == "heal":
					best_heal = maxf(best_heal, minf(float(kd.get("heal", 0)), float(p.max_hp)))
			value = (minf(float(d.get("heal", 0)), float(p.max_hp)) - best_heal) * 0.2
			if Spell.is_multi(id):
				value *= 0.6
		elif id in ["stoke", "sunder"]:
			value = 6.0
		if value > 0.5:
			picks.append([value, s])
	picks.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	for pk: Array in picks:
		var s: Dictionary = pk[1]
		var price: int = OrbUI.item_price(s)
		if p.gold - price < reserve:
			continue
		p.gold -= price
		spent["scrolls"] += price
		var id: String = s.get("teaches", "") as String
		p.known_spells.append(id)
		_event("learned %s (%d g)" % [Spell.get_data(id).get("name", id), price])
	ui._refresh()


# ── Supplies ──

func _restock(ui: OrbUI, essentials: bool) -> void:
	var p: PlayerCharacter = main.player_char
	var shelf: Array[Dictionary] = ui._supplies()
	var by_id: Dictionary = {}
	for s: Dictionary in shelf:
		by_id[s["id"]] = s
	var deep: bool = main.floor_num >= Item.DEEP_SUPPLIES_FLOOR
	# id -> how many to carry, in order of need.
	var wants: Array = [
		["super_potion" if deep else ("hi_potion" if main.floor_num >= 4 else "health_potion"), 4],
		["hi_ether" if deep else "ether", 2],
		["revival_feather", 2],
		["panacea", 1],
		["elixir", 1],
		["potion_cauldron", 1],
	]
	if Level.is_boss_floor(main.floor_num):
		wants[0][1] = 8
		wants[1][1] = 6
	if essentials:
		wants = [[wants[0][0], 3], [wants[1][0], 1]]
	# Past the essentials, supplies only get what is left after a cushion.
	var budget_floor: int = 50 + main.floor_num * 20
	for w: Array in wants:
		var id: String = w[0]
		if not by_id.has(id):
			continue
		var item: Dictionary = by_id[id]
		var price: int = OrbUI.item_price(item)
		while p.item_qty(id) < int(w[1]) and p.gold >= price + 30 \
				and (essentials or p.gold - price >= budget_floor):
			p.gold -= price
			spent["supplies"] += price
			p.add_item(item.duplicate(), 1)
	ui._refresh()


# ── Demons ──

# The three that walk in: the strongest, with an eye on not being weak to the
# next dragon's element.
func _set_party() -> void:
	var p: PlayerCharacter = main.player_char
	if p.recruited.is_empty():
		return
	var boss_floor: int = ((main.floor_num - 1) / Level.BOSS_EVERY + 1) * Level.BOSS_EVERY
	var boss_el: Array[String] = []
	if boss_floor <= Level.DRAGON_FLOORS:
		var b: Enemy = Enemy.make_boss(boss_floor)
		boss_el.assign(b.attack_elements)
		b.free()
	var scored: Array = []
	for name: String in p.recruited:
		var e: Enemy = p.bound_demon(name)
		var s: float = float(e.lv) * 3.0 + float(e.max_hp) * 0.05 + float(e.mag + e.str) * 0.5
		for el: String in boss_el:
			match e.affinity_of(el):
				Affinity.WEAK: s -= 12.0
				Affinity.RESIST: s += 4.0
				Affinity.NULL, Affinity.REPEL, Affinity.DRAIN: s += 8.0
		e.free()
		scored.append([s, name])
	scored.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	var want: Array[String] = []
	for i: int in mini(PlayerCharacter.ACTIVE_SLOTS, scored.size()):
		want.append(scored[i][1] as String)
	for n: String in p.active_demons.duplicate():
		if n not in want:
			p.deactivate_demon(n)
	for n: String in want:
		p.activate_demon(n)


# Lost demons are gone for good, but an orb calls back anything that has
# answered before. Fill the walking party back to three when gold allows.
func _rebind() -> void:
	var p: PlayerCharacter = main.player_char
	var guard: int = 0
	while p.recruited.size() < PlayerCharacter.ACTIVE_SLOTS and guard < 3:
		guard += 1
		var best: String = ""
		var best_lv: int = -1
		var best_price: int = 0
		for n: String in p.ever_bound:
			if n in p.recruited:
				continue
			var e: Enemy = Enemy.make_from_name(n, main.floor_num)
			var ok: bool = e.negotiable and e.lv <= p.lv
			var lv: int = e.lv
			var price: int = OrbUI.bind_price(e)
			e.free()
			if ok and lv > best_lv and p.gold - price >= 40 + main.floor_num * 10:
				best = n
				best_lv = lv
				best_price = price
		if best == "":
			return
		p.gold -= best_price
		p.remember_recruit(best, best_lv)
		spent["gear"] += 0
		_event("called %s back at the orb (lv %d, %d g)" % [best, best_lv, best_price])


# ── Grinding ──

func _should_grind() -> bool:
	var p: PlayerCharacter = main.player_char
	return p.lv < _wanted_level() and p.gold > 40


func _gauntlet(ui: OrbUI) -> bool:
	var p: PlayerCharacter = main.player_char
	var pool: Array[String] = ui._gauntlet_pool()
	if pool.is_empty():
		return false
	# Monsters the hero's spells read weak, cheapest first, four of them.
	var lineup: Array[String] = []
	pool.sort_custom(func(a: String, b: String) -> bool:
		return OrbUI.gauntlet_price(a, main.floor_num) < OrbUI.gauntlet_price(b, main.floor_num))
	var total: int = 0
	for i: int in 4:
		var n: String = pool[i % mini(2, pool.size())]
		var price: int = OrbUI.gauntlet_price(n, main.floor_num)
		if p.gold < total + price + 40:
			break
		lineup.append(n)
		total += price
	if lineup.is_empty() or p.hp * 100 < p.max_hp * 90:
		return false
	p.gold -= total
	_event("gauntlet: %s (%d g) to grind toward lv %d" % [", ".join(lineup), total,
			_wanted_level()])
	_orbs_done.erase(main.player_pos)    # come back to this orb after
	ui.gauntlet_requested.emit(lineup)
	return true


# ── Fighting ─────────────────────────────────────────────────────────────────

var _scene_seen: CombatScene = null


func _combat_tick(sc: CombatScene) -> void:
	if sc != _scene_seen:
		_scene_seen = sc
		_fight_began(sc)
	_snapshot_if_phase_over(sc)
	if _boss_fight:
		_mirror_log(sc)
	# Our move: the action bar is up and live.
	if sc._action_bar.visible and _any_enabled(sc._action_bar):
		_fight_turns += 1
		_measure_hits(sc)
		await _wait(0.35)
		if not is_instance_valid(sc) or not sc._action_bar.visible:
			return
		await _act(sc)
		await _wait(0.2)
		return
	# A question in the side panel: a plea, a pay-off, a line of talk.
	if sc._sub_scroll.visible and not sc._action_bar.visible:
		if _button(sc._sub_bar, "Recruit it") != null:
			await _wait(0.6)
			if main.player_char.recruited.size() < PlayerCharacter.ROSTER_SIZE:
				_press(sc._sub_bar, "Recruit it")
				recruits.append(sc.enemy.enemy_name + " (begged)")
			else:
				_press(sc._sub_bar, "Refuse it")
			return
		if _button(sc._sub_bar, "Take it") != null:
			await _wait(0.6)
			_press(sc._sub_bar, "Take it")
			return
		for line: String in ["Flatter", "Pride", "Safety"]:
			if _button(sc._sub_bar, line) != null:
				await _wait(0.6)
				var pick: String = _talk_line(sc.enemy)
				_press(sc._sub_bar, pick)
				return


# At the top of our phase, what the enemy phase just took off each member.
var _last_phase: int = -1
var _defends: int = 0


func _measure_hits(sc: CombatScene) -> void:
	if sc._phases == _last_phase:
		return
	_last_phase = sc._phases
	for m: CharacterSheet in sc.party:
		var id: int = m.get_instance_id()
		if _hp_after_us.has(id):
			var lost: int = int(_hp_after_us[id]) - m.hp
			if lost > int(_phase_hit.get(id, 0)):
				_phase_hit[id] = lost
	_hp_after_us.clear()


# Our icons are spent and theirs are about to be: what everyone has now.
var _snap_phase: int = -1


func _snapshot_if_phase_over(sc: CombatScene) -> void:
	if sc._press == null or sc._press.has_turns() or _snap_phase == sc._phases:
		return
	_snap_phase = sc._phases
	for m: CharacterSheet in sc.party:
		_hp_after_us[m.get_instance_id()] = m.hp


# What the next enemy phase might take off `m`: the worst seen so far, or, before
# anything has landed, a guess from the pack's strength.
func _danger(sc: CombatScene, m: CharacterSheet) -> float:
	var seen: float = float(_phase_hit.get(m.get_instance_id(), 0))
	var guess: float = 0.0
	for f: Enemy in sc._living_foes():
		guess += float(maxi(1, f.icons)) * maxf(float(f.str), float(f.mag) * 1.6) \
				- float(m.def) * 0.5
	guess = maxf(guess * 0.6, float(m.max_hp) * 0.25)
	var boss: bool = sc._living_foes().any(func(f: Enemy) -> bool:
		return f.is_dragon() or f.is_necromancer() or f.is_warden())
	var k: float = 1.5 if boss else 1.1
	return guess if seen == 0.0 else maxf(seen * k, guess * 0.5)


# A boss fight's own battle log, line by line, into the event log: what the
# boss did, and to whom, is the part of the fight worth reading afterwards.
var _log_seen: int = 0


func _mirror_log(sc: CombatScene) -> void:
	var text: String = sc._log_label.get_parsed_text()
	if text.length() < _log_seen:
		_log_seen = 0
	if text.length() == _log_seen:
		return
	for line: String in text.substr(_log_seen).split("\n", false):
		_event("  | " + line.strip_edges())
	_log_seen = text.length()


func _any_enabled(bar: Control) -> bool:
	for n: Node in bar.find_children("*", "Button", true, false):
		var b: Button = n as Button
		if b.is_visible_in_tree() and not b.disabled:
			return true
	return false


func _fight_began(sc: CombatScene) -> void:
	_progress_t = main.play_time
	fights += 1
	_fight_turns = 0
	_fight_start_hp = main.player_char.hp
	_talked.clear()
	_log_seen = 0
	_phase_hit.clear()
	_hp_after_us.clear()
	_boss_fight = false
	var names: Array[String] = []
	for f: Enemy in sc.foes:
		names.append(f.display_name())
		if f.is_dragon() or f.is_necromancer() or f.is_warden():
			_boss_fight = true
			_boss_name = f.enemy_name
	_event("fight %d: %s%s" % [fights, ", ".join(names), "  [BOSS]" if _boss_fight else ""])
	sc.combat_ended.connect(func(result: String) -> void: _fight_over(result), CONNECT_ONE_SHOT)


func _fight_over(result: String) -> void:
	var p: PlayerCharacter = main.player_char
	if is_instance_valid(_scene_seen):
		for f: Enemy in _scene_seen.foes + _scene_seen._departed:
			if is_instance_valid(f):
				for el: String in Affinity.ELEMENTS:
					_aff(f, el)
	match result:
		"win", "talk", "bribe":
			fights_won += 1
		"lose":
			fights_lost += 1
		"flee":
			fled += 1
	_event("  -> %s after %d actions, hero hp %d -> %d / %d" % [result, _fight_turns,
			_fight_start_hp, p.hp, p.max_hp])
	if _boss_fight:
		boss_log.append({boss = _boss_name, floor = main.floor_num, lv = p.lv,
				result = "lost" if result == "lose" else result, turns = _fight_turns})
		if result == "lose":
			_boss_losses[main.floor_num] = int(_boss_losses.get(main.floor_num, 0)) + 1
	_boss_fight = false
	_scene_seen = null


func _talk_line(foe: Enemy) -> String:
	for line: String in ["Pride", "Flatter", "Safety"]:
		if Negotiation.matches(Negotiation.RECRUIT_MATCH, foe.talk_personality, line):
			return line
	return "Flatter"


# What we know of how `foe` takes `element`: its chart once the game has shown
# it, else "?".
func _aff(foe: Enemy, element: String) -> String:
	if element == "":
		return Affinity.NORMAL
	var key: String = foe.lore_name() + "|" + element
	if main.player_char.knows_affinity(foe.lore_name(), element):
		_memory[key] = foe.affinity_of(element)
	if _memory.has(key):
		return _memory[key] as String
	# Not known yet. What a thing throws, it rarely takes: assume the worst of
	# its own elements until it has been shown otherwise.
	if element in foe.attack_elements:
		return "?own"
	return "?"


const AFF_MULT: Dictionary = {"weak": 2.0, "": 1.0, "resist": 0.5, "null": 0.0,
		"repel": 0.0, "drain": 0.0, "?": 0.9, "?own": 0.6}


# The press-turn worth of an outcome, in units of one ordinary action.
func _press_value(a: String) -> float:
	match a:
		"weak": return 0.55
		"null": return -1.0
		"repel", "drain": return -3.0
		"?": return -0.08
		"?own": return -0.45
	return 0.0


# Everything the acting member could do, scored, and the best done.
func _act(sc: CombatScene) -> void:
	var actor: CharacterSheet = sc._actor()
	var hero: bool = sc._actor_is_player()
	var foes: Array[Enemy] = sc._living_foes()
	if foes.is_empty():
		return
	var options: Array[Dictionary] = []
	if hero:
		_hero_options(sc, foes, options)
	else:
		_demon_options(sc, actor as Enemy, foes, options)
	# Bracing is always there, and is what a turn with nothing good is spent on.
	options.append({kind = "defend", score = _typical(sc, actor, foes) * 0.25, label = "Defend"})
	options.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["score"]) > float(b["score"]))
	var pick: Dictionary = options[0]
	# Nothing good to do: try a line we have not seen it take yet, since a
	# brace never wins a fight. And never brace more than a few times running.
	if pick["kind"] == "defend":
		_defends += 1
		var probe: Dictionary = {}
		for o: Dictionary in options:
			if o["kind"] == "action" and o.has("target") and o.has("element_state") \
					and (o["element_state"] as String).begins_with("?"):
				probe = o
				break
		if probe.is_empty() and _defends > 3:
			for o: Dictionary in options:
				if o["kind"] == "action":
					probe = o
					break
		if not probe.is_empty():
			pick = probe
			_defends = 0
	else:
		_defends = 0
	var who: String = "Hero" if hero else (actor as Enemy).enemy_name
	_event("    %s (%d/%d hp, %d mp): %s [%.1f]%s" % [who, actor.hp, actor.max_hp, actor.mp,
			pick["label"], float(pick["score"]),
			("  over " + ", ".join(options.slice(1, 3).map(func(o: Dictionary) -> String:
				return "%s %.1f" % [o["label"], float(o["score"])]))) if options.size() > 1 else ""])
	await _do(sc, pick)


# What an ordinary hit from this actor is worth, the yardstick the press
# bonuses are measured in.
func _typical(sc: CombatScene, actor: CharacterSheet, foes: Array[Enemy]) -> float:
	var power: float = float(actor.mag) * 2.0 if not sc._actor_is_player() \
			else float(main.player_char.effective_mag()) * 2.0
	var def: float = 0.0
	for f: Enemy in foes:
		def += float(f.def)
	def /= maxf(1.0, foes.size())
	return maxf(4.0, power - def * 0.5)


# Damage `base` lands on `foe` through what we know of its chart, plus the
# press-turn swing, plus a kill bonus.
func _hit_score(base: float, element: String, foe: Enemy, typical: float) -> float:
	var a: String = _aff(foe, element)
	var dmg: float = maxf(1.0, base) * float(AFF_MULT.get(a, 1.0))
	var landed: float = minf(dmg, float(foe.hp))
	var s: float = landed + _press_value(a) * typical
	if dmg >= float(foe.hp):
		s += typical * 0.8     # one fewer thing taking turns
	# Bosses are the point of the fight.
	if foe.is_dragon() or foe.is_necromancer() or foe.is_warden():
		s += landed * 0.2
	return s


func _guard(foe: Enemy, element: String) -> float:
	if element == Affinity.PHYS:
		return float(foe.def) * foe.stage_mult(CharacterSheet.STAT_DEF)
	return (float(foe.def) + float(foe.mag)) * 0.25


func _hero_options(sc: CombatScene, foes: Array[Enemy], out: Array[Dictionary]) -> void:
	var p: PlayerCharacter = main.player_char
	var typ: float = _typical(sc, p, foes)
	var boss: bool = foes.any(func(f: Enemy) -> bool: return f.is_dragon() or f.is_necromancer() or f.is_warden())

	# Mending comes first when someone is in trouble.
	_mend_options(sc, typ, out)

	# Attack.
	var atk: float = float(p.effective_str()) * CombatMath.PHYS_POWER * p.stage_mult(CharacterSheet.STAT_ATK)
	var wel: String = p.attack_element()
	for f: Enemy in foes:
		if Affinity.is_banishing(wel):
			continue
		out.append({kind = "action", action = "Attack", target = f,
				score = _hit_score(atk - _guard(f, wel), wel, f, typ) * 0.9,
				label = "Attack %s" % f.display_name()})

	# Spells.
	var silenced: bool = p.has_status(Status.SILENCE)
	for id: String in p.equipped_spells:
		var d: Dictionary = Spell.get_data(id)
		var hp_price: int = Spell.hp_cost(id, p.max_hp)
		if hp_price > 0:
			if p.hp <= hp_price * 2:
				continue
		elif silenced or p.mp < int(d.get("mp", 0)):
			continue
		var kind: String = d.get("type", "dmg") as String
		var el: String = d.get("element", "") as String
		var mp_tax: float = float(d.get("mp", 0)) * 0.15
		match kind:
			"dmg":
				var phys: bool = el == Affinity.PHYS
				var power: float = (float(p.effective_str()) * p.stage_mult(CharacterSheet.STAT_ATK) if phys
						else float(p.effective_mag()) * p.stage_mult(CharacterSheet.STAT_MAG)) \
						* float(d.get("power", Spell.POWER_I))
				if Spell.is_multi(id):
					var total: float = 0.0
					var worst: float = 0.0
					var targets: Array[Enemy] = foes if d.get("shape", "") == Spell.SHAPE_ALL \
							else foes.slice(0, mini(2, foes.size()))
					for f: Enemy in targets:
						var a: String = _aff(f, el)
						total += minf(maxf(1.0, power - _guard(f, el)) * float(AFF_MULT.get(a, 1.0)), float(f.hp))
						worst = minf(worst, _press_value(a) if a != "weak" else 0.0)
					if foes.size() >= 2:
						out.append({kind = "action", action = "Magic:" + id,
								score = total + worst * typ - mp_tax, label = d["name"]})
				else:
					for f: Enemy in foes:
						var s: float = _hit_score(power - _guard(f, el), el, f, typ) - mp_tax
						if d.get("pierce", false) and _aff(f, el) in ["resist", "null", "repel", "drain"]:
							s = _hit_score(power - _guard(f, el), "", f, typ) - mp_tax
						out.append({kind = "action", action = "Magic:" + id, target = f,
								score = s, label = "%s on %s" % [d["name"], f.display_name()],
								element_state = _aff(f, el)})
			"banish":
				for f: Enemy in foes:
					var a: String = _aff(f, el)
					if a in ["null", "repel", "drain"]:
						continue
					var ch: float = CombatMath.banish_chance(f, el, p, float(d.get("boost", 0.0)))
					out.append({kind = "action", action = "Magic:" + id, target = f,
							score = ch * float(f.hp) * 1.2 - mp_tax + _press_value(a) * typ,
							label = "%s on %s" % [d["name"], f.display_name()]})
			"buff":
				var stat: String = d.get("stat", "") as String
				var party: bool = d.get("scope", "party") == "party"
				var stage: int = int(p.stages.get(stat, 0)) if party else int(foes[0].stages.get(stat, 0))
				var room: bool = stage < 2 if party else stage > -2
				if room and (boss or _sum_hp(foes) > typ * 6.0):
					out.append({kind = "action", action = "Magic:" + id,
							score = typ * (1.3 if boss else 0.8) - mp_tax, label = d["name"]})
			"analyze":
				var unknown: bool = false
				for f: Enemy in foes:
					if not f.unreadable and _aff(f, "fire") == "?":
						unknown = true
				if unknown:
					out.append({kind = "action", action = "Magic:" + id, target = foes[0],
							score = typ * 0.6, label = "Analyze"})

	# Throwables against a known weakness.
	for item: Dictionary in p.battle_items():
		var el: String = item.get("element", "") as String
		var dmg: int = int(item.get("dmg", 0))
		if el == "" or dmg <= 0:
			continue
		for f: Enemy in foes:
			if _aff(f, el) == "weak":
				out.append({kind = "item", item = item, target = f,
						score = _hit_score(float(dmg), el, f, typ) * 0.8,
						label = "%s at %s" % [item["name"], f.display_name()]})

	# Calling a demon into an empty place.
	if sc.party.size() < CombatScene.MAX_PARTY:
		var avail: Array[String] = sc._available_summons()
		if not avail.is_empty():
			var best: String = avail[0]
			var best_lv: int = -1
			for n: String in avail:
				var lv: int = int(p.bound_level.get(n, 1))
				if lv > best_lv:
					best_lv = lv
					best = n
			out.append({kind = "summon", name = best, score = typ * 2.2, label = "Summon %s" % best})

	# Talking: one already ours pays us off; a new one can be talked into
	# joining when there is room and it is not above the hero.
	if not boss and not p.has_status(Status.SILENCE):
		for f: Enemy in foes:
			if not f.negotiable or _talked.has(f.get_instance_id()):
				continue
			if f.enemy_name in p.recruited:
				out.append({kind = "talk", target = f, score = typ * 1.4 + float(f.hp) * 0.3,
						label = "Talk to %s (pay-off)" % f.display_name()})
			elif p.can_bind(f.enemy_name) and f.lv <= p.lv \
					and Negotiation.tier_odds(f.tier) >= 38 and _worth_recruiting(f):
				out.append({kind = "talk", target = f,
						score = typ * 1.8 * float(Negotiation.tier_odds(f.tier)) / 63.0,
						label = "Recruit %s" % f.display_name()})


func _sum_hp(foes: Array[Enemy]) -> float:
	var s: float = 0.0
	for f: Enemy in foes:
		s += float(f.hp)
	return s


# A new name is worth a slot if the roster has room to spare, or if it would
# be at least as strong as the weakest one we keep.
func _worth_recruiting(f: Enemy) -> bool:
	var p: PlayerCharacter = main.player_char
	if p.recruited.size() < 4:
		return true
	var weakest: int = 999
	for n: String in p.recruited:
		weakest = mini(weakest, int(p.bound_level.get(n, 1)))
	return f.lv > weakest + 2


func _mend_options(sc: CombatScene, typ: float, out: Array[Dictionary]) -> void:
	var p: PlayerCharacter = main.player_char
	var living: Array[CharacterSheet] = sc._living_party()
	var fallen: Array[CharacterSheet] = sc._fallen_members()
	# The most hurt, the hero counting double: he falls, the run ends.
	var worst: CharacterSheet = null
	var worst_share: float = 1.0
	var hurt_count: int = 0
	for m: CharacterSheet in living:
		var share: float = float(m.hp) / float(maxi(1, m.max_hp))
		if m == p:
			share -= 0.12
		if share < 0.5:
			hurt_count += 1
		if share < worst_share:
			worst_share = share
			worst = m
	var boss_fight: bool = sc._living_foes().any(func(f: Enemy) -> bool:
		return f.is_dragon() or f.is_necromancer() or f.is_warden())
	var urgent: bool = worst != null and worst_share < (0.6 if boss_fight else 0.42)
	# Or anyone the next enemy phase could put down.
	var in_danger: bool = false
	for m: CharacterSheet in living:
		if float(m.hp) <= _danger(sc, m) and (m == p or m.hp * 2 < m.max_hp):
			if not urgent or m == p:
				worst = m
			urgent = true
			in_danger = true
	if urgent:
		var missing: float = float(worst.max_hp - worst.hp)
		var weight: float = 3.0 if worst == p else 1.6
		if in_danger and worst == p:
			weight = 6.0
		# Spells.
		if not p.has_status(Status.SILENCE):
			for id: String in p.equipped_spells:
				var d: Dictionary = Spell.get_data(id)
				if d.get("type", "") != "heal" or p.mp < int(d.get("mp", 0)):
					continue
				var amt: float = float(p.heal_amount_for(id))
				if Spell.is_multi(id):
					var total: float = 0.0
					for m: CharacterSheet in living:
						total += minf(amt, float(m.max_hp - m.hp))
					out.append({kind = "action", action = "Magic:" + id,
							score = total * (1.2 if hurt_count >= 2 else 0.8) * weight / 2.0,
							label = d["name"]})
				else:
					out.append({kind = "heal_spell", action = "Magic:" + id, ally = worst,
							score = minf(amt, missing) * weight - float(d.get("mp", 0)) * 0.1,
							label = "%s on %s" % [d["name"], sc._member_name(worst)]})
		# Potions: the smallest that does the job, so the big ones keep.
		var best_item: Dictionary = {}
		var best_val: float = -1.0
		for item: Dictionary in p.battle_items():
			var hp_r: int = int(item.get("hp_restore", 0))
			if hp_r <= 0 or item.has("revive"):
				continue
			var party_item: bool = item.get("party", false)
			var val: float = 0.0
			if party_item:
				for m: CharacterSheet in living:
					val += minf(float(hp_r), float(m.max_hp - m.hp))
				val *= 0.7 if hurt_count >= 2 else 0.3
			else:
				val = minf(float(hp_r), missing)
				# Waste counts against it.
				val -= maxf(0.0, float(hp_r) - missing) * 0.15
			if int(item.get("mp_restore", 0)) > 0:
				val *= 0.7       # an elixir is for later
			if val > best_val:
				best_val = val
				best_item = item
		if not best_item.is_empty():
			out.append({kind = "item", item = best_item, ally = worst,
					score = best_val * weight * 0.95, label = "%s on %s" % [best_item["name"],
					sc._member_name(worst)]})
	# A fallen demon back on its feet.
	if not fallen.is_empty():
		for item: Dictionary in p.battle_items():
			if item.has("revive"):
				out.append({kind = "item", item = item, ally = fallen[0],
						score = typ * 1.6, label = "%s on %s" % [item["name"], sc._member_name(fallen[0])]})
				break
	# The hero out of MP with spells to cast.
	var cheapest: int = 9999
	for id: String in p.equipped_spells:
		var d: Dictionary = Spell.get_data(id)
		if d.get("type", "") == "dmg" and Spell.hp_cost(id, p.max_hp) == 0:
			cheapest = mini(cheapest, int(d.get("mp", 0)))
	if p.mp < cheapest and cheapest < 9999:
		for item: Dictionary in p.battle_items():
			var mp_r: int = int(item.get("mp_restore", 0))
			if mp_r > 0 and int(item.get("hp_restore", 0)) == 0:
				out.append({kind = "item", item = item, ally = p,
						score = typ * 1.1, label = "%s on Hero" % item["name"]})
				break


func _demon_options(sc: CombatScene, demon: Enemy, foes: Array[Enemy], out: Array[Dictionary]) -> void:
	var p: PlayerCharacter = main.player_char
	var typ: float = _typical(sc, demon, foes)
	var boss: bool = foes.any(func(f: Enemy) -> bool: return f.is_dragon() or f.is_necromancer() or f.is_warden())
	var atk: float = float(demon.str) * demon.stage_mult(CharacterSheet.STAT_ATK)
	for f: Enemy in foes:
		out.append({kind = "action", action = "Attack", target = f,
				score = _hit_score(atk - _guard(f, Affinity.PHYS), Affinity.PHYS, f, typ) * 0.9,
				label = "Attack %s" % f.display_name()})
	var known: Array = p.skills_of(demon.enemy_name)
	var silenced: bool = demon.has_status(Status.SILENCE)
	for i: int in known.size():
		var skill: Dictionary = known[i]
		var hp_price: int = sc._demon_hp_cost(demon, skill)
		var cost: int = sc._demon_skill_cost(demon, skill)
		if hp_price > 0:
			if demon.hp <= hp_price * 2:
				continue
		elif silenced or demon.mp < cost:
			continue
		var kind: String = skill.get("kind", "") as String
		var action: String = "Skill:%d" % i
		match kind:
			"element":
				var el: String = skill.get("element", "") as String
				var rung: int = int(skill.get("rung", 1))
				var phys: bool = el == Affinity.PHYS
				var power: float = (float(demon.str) * demon.stage_mult(CharacterSheet.STAT_ATK) if phys
						else float(demon.mag) * demon.stage_mult(CharacterSheet.STAT_MAG)) * Spell.rung_power(rung)
				if Affinity.is_banishing(el):
					for f: Enemy in foes:
						var a: String = _aff(f, el)
						if a in ["null", "repel", "drain"]:
							continue
						var ch: float = CombatMath.banish_chance(f, el, demon, Spell.rung_boost(rung))
						out.append({kind = "action", action = action, target = f,
								score = ch * float(f.hp) - float(cost) * 0.1 + _press_value(a) * typ,
								label = "%s on %s" % [PlayerCharacter.skill_name(skill), f.display_name()]})
				elif demon.attack_reach != Spell.SHAPE_ONE:
					var total: float = 0.0
					var worst: float = 0.0
					for f: Enemy in foes:
						var a: String = _aff(f, el)
						total += minf(maxf(1.0, power - _guard(f, el)) * float(AFF_MULT.get(a, 1.0)), float(f.hp))
						worst = minf(worst, _press_value(a) if a != "weak" else 0.0)
					total *= 0.8 if demon.attack_reach == Spell.SHAPE_FEW else 1.0
					out.append({kind = "action", action = action,
							score = total + worst * typ - float(cost) * 0.1,
							label = PlayerCharacter.skill_name(skill)})
				else:
					for f: Enemy in foes:
						out.append({kind = "action", action = action, target = f,
								score = _hit_score(power - _guard(f, el), el, f, typ) - float(cost) * 0.1,
								label = "%s on %s" % [PlayerCharacter.skill_name(skill), f.display_name()],
								element_state = _aff(f, el)})
			"support":
				var d: Dictionary = Spell.get_data(skill.get("id", "") as String)
				var stat: String = d.get("stat", "") as String
				if stat == "":
					continue
				var party: bool = d.get("scope", "party") == "party"
				var stage: int = int(p.stages.get(stat, 0)) if party else int(foes[0].stages.get(stat, 0))
				var room: bool = stage < 2 if party else stage > -2
				if room and (boss or _sum_hp(foes) > typ * 6.0):
					out.append({kind = "action", action = action,
							score = typ * (1.2 if boss else 0.7), label = d.get("name", "support")})
			"unique":
				var u: Dictionary = Spell.get_data(skill.get("id", "") as String)
				if u.get("drain", "hp") == "hp" and demon.hp * 2 < demon.max_hp:
					for f: Enemy in foes:
						out.append({kind = "action", action = action, target = f,
								score = float(demon.str) * float(u.get("power", 1.5)) * 1.4,
								label = "HP Leech %s" % f.display_name()})


func _do(sc: CombatScene, pick: Dictionary) -> void:
	if not is_instance_valid(sc):
		return
	if pick.has("target") and is_instance_valid(pick["target"]):
		sc.enemy = pick["target"]
		sc._refresh_hp()
	match pick["kind"]:
		"action":
			sc._commit_action(pick["action"] as String)
		"heal_spell":
			sc._ally_target = pick["ally"]
			sc._commit_action(pick["action"] as String)
		"item":
			var item: Dictionary = pick["item"]
			items_used[item["name"]] = int(items_used.get(item["name"], 0)) + 1
			sc._ally_target = pick.get("ally", null)
			sc._commit_item(item)
		"summon":
			sc._on_summon(pick["name"] as String)
		"talk":
			var f: Enemy = pick["target"]
			_talked[f.get_instance_id()] = true
			if f.enemy_name in main.player_char.recruited:
				sc._prompt_tribute(false)
			else:
				recruits.append(f.enemy_name)
				sc._on_talk("Recruit")
		"defend":
			sc._commit_action("Defend")


# ── The report ───────────────────────────────────────────────────────────────

func _finish() -> void:
	var p: PlayerCharacter = main.player_char if is_instance_valid(main) else null
	var lines: Array[String] = []
	lines.append("# Playtest report")
	lines.append("")
	lines.append("- Result: **%s**" % _result)
	if p:
		lines.append("- Reached floor %d, hero level %d, %d gold" % [main.floor_num, p.lv, p.gold])
		lines.append("- Game time: %d min" % int((main.play_time - _t0) / 60.0))
		lines.append("- Party at the end: %s" % ", ".join(p.recruited))
		lines.append("- Gear: %s, %s, %s" % [p.equipped_weapon.get("name", "-"),
				p.equipped_armor.get("name", "-"),
				", ".join(p.equipped_accessories.map(func(a: Dictionary) -> String: return a.get("name", "?")))])
		lines.append("- Spells: %s" % ", ".join(p.equipped_spells.map(func(id: String) -> String:
				return Spell.get_data(id).get("name", id))))
	lines.append("- Fights: %d (won %d, lost %d, fled %d), deaths %d" % [fights, fights_won,
			fights_lost, fled, deaths])
	lines.append("- Recruit attempts: %s" % (", ".join(recruits) if not recruits.is_empty() else "none"))
	lines.append("- Items used: %s" % (", ".join(items_used.keys().map(func(k: String) -> String:
			return "%s x%d" % [k, items_used[k]])) if not items_used.is_empty() else "none"))
	lines.append("- Gold spent: rest %d, gear %d, scrolls %d, supplies %d" % [spent["rest"],
			spent["gear"], spent["scrolls"], spent["supplies"]])
	lines.append("")
	lines.append("## Floors")
	lines.append("")
	lines.append("| Floor | Arrived at lv | Gold | Game time | Roster |")
	lines.append("|---|---|---|---|---|")
	for r: Dictionary in floor_log:
		lines.append("| %d | %d | %d | %d min | %s |" % [r["floor"], r["lv"], r["gold"],
				int(r["time"]) / 60, r["demons"]])
	lines.append("")
	lines.append("## Bosses")
	lines.append("")
	for b: Dictionary in boss_log:
		lines.append("- Floor %d %s at lv %d: %s in %d actions" % [b["floor"], b["boss"], b["lv"],
				b["result"], b["turns"]])
	var f: FileAccess = FileAccess.open(out_dir.path_join("report.md"),
			FileAccess.READ_WRITE if FileAccess.file_exists(out_dir.path_join("report.md"))
					and stop_floor > 0 else FileAccess.WRITE)
	if f:
		f.seek_end()
		f.store_string("\n".join(lines) + "\n\n")
	_event("done: %s" % _result)
	_restore_saves()
	quit()
