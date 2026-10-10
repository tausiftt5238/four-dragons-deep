extends "res://tools/trailer.gd"
# The PC (Steam) trailer: the wide build, at its 960x540 canvas, which
# tools/trailer_encode.sh scales to 1920x1080. It plays walking a floor,
# opening a chest, a won fight with the party hopping, talking a dragon into
# joining, stepping on each of the four kinds of trap, the gacha at an orb, and
# a dragon, with captions. tools/trailer.gd is the phone one, whose helpers this
# borrows. Record it from the repo root, with a real display:
#
#   tools/run.sh steam --resolution 960x540 --write-movie DIR/frame.png \
#       --fixed-fps 30 --script tools/trailer_steam.gd
#   SIZE=1920x1080 tools/trailer_encode.sh DIR OUT.mp4 resources/music/overture.ogg
#
# Run it with the real art and the music in place. It puts this machine's
# autosave and records back when it is done.

const W: float = 960.0
const CAP_Y: float = 40.0

var _records_backup: Variant = null


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	OS.low_processor_usage_mode = false
	seed(20261009)
	var auto: String = SaveSystem.slot_path(SaveSystem.AUTO_SLOT)
	_auto_backup = FileAccess.get_file_as_string(auto) if FileAccess.file_exists(auto) else ""
	_records_backup = FileAccess.get_file_as_string(Records.PATH) if FileAccess.file_exists(Records.PATH) else null
	Settings.audio_bus(Settings.MUSIC_BUS)
	Settings.audio_bus(Settings.SFX_BUS)
	Settings.set_music_volume(0, false)
	Settings.set_sfx_volume(100, false)
	GameBoot.pending_slot = 0
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Main
	root.add_child(main)
	_build_overlay()
	_fit_overlay()
	_fade.color.a = 1.0
	await _frames(10)
	main._encounters_enabled = false
	_hide_roamers()
	_dress()
	# The game's own notes (a trap's first time, a key) would sit under the
	# captions at the top of the view; the captions say it instead.
	main._hud_popup.visible = false

	await _card([["FOUR DRAGONS DEEP", 46, GOLD]], 1.6)
	await _scene_walk_wide()
	await _scene_chest()
	await _scene_fight_won()
	await _scene_talk()
	await _scene_traps()
	await _scene_gacha()
	await _scene_dragon()
	await _card([["FOUR DRAGONS DEEP", 46, GOLD],
			["A first-person dungeon crawler with press-turn fights", 18, Color(0.80, 0.82, 0.88)],
			["Coming to Steam  ·  Play the demo on itch.io", 18, Color(0.60, 0.85, 1.0)]], 3.2)
	_restore_autosave()
	Records.flush()
	if _records_backup == null:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Records.PATH))
	else:
		FileAccess.open(Records.PATH, FileAccess.WRITE).store_string(_records_backup as String)
	quit()


# The phone overlay's caption band, moved to the top of the wide screen and
# sized to it.
func _fit_overlay() -> void:
	_cap.add_theme_font_size_override("font_size", 20)
	_band.offset_top = CAP_Y
	_band.offset_bottom = CAP_Y + 62.0


func _caption(text: String, hold: float = 2.4, y: float = CAP_Y) -> void:
	if _cap_tween:
		_cap_tween.kill()
	_cap.text = text
	_band.offset_top = y
	_band.offset_bottom = y + 62.0
	_cap_tween = main.create_tween()
	_cap_tween.tween_property(_band, "modulate:a", 1.0, 0.25)
	_cap_tween.tween_interval(hold)
	_cap_tween.tween_property(_band, "modulate:a", 0.0, 0.35)
	await _cap_tween.finished


# A party in the middle of a run: a few demons, some levels, spells, gold.
func _dress() -> void:
	var p: PlayerCharacter = main.player_char
	p.gold = 5000
	for i: int in 12:
		p._level_up()
	p.known_spells.assign(["analyze", "ember", "rime", "arc", "cure"])
	p.equipped_spells.assign(["analyze", "ember", "rime", "arc", "cure"])
	p.remember_recruit("Baby Brass Dragon", 10)
	p.remember_recruit("Werebear", 10)
	p.mag += 30
	p.str += 10
	p.hp = p.max_hp
	p.mp = p.max_mp
	# Walking through traps: the trailer shows them, it does not die of them.
	p.max_hp += 400
	p.hp = p.max_hp


func _scene_walk_wide() -> void:
	var lvl: Level = main.current_level
	var start: Vector2i = Vector2i.ZERO
	var path: Array[Vector2i] = []
	for row: int in lvl.maze.size():
		for col: int in (lvl.maze[row] as Array).size():
			var c: Vector2i = Vector2i(col, row)
			if not main._is_open(c.x, c.y) or c in lvl.orb_cells or lvl.trap_cells.has(c):
				continue
			var p: Array[Vector2i] = _path(c)
			if p.size() >= 10 and _straight(c, p) > _straight(start, path):
				start = c
				path = p
	path = path.slice(0, 10)
	_stand(start, Main.DIR_OFFSET.find(path[0] - start))
	await _frames(3)
	await _fade_to(0.0, 0.6)
	_caption("Twenty floors down, into the dark.")
	await _walk(path)
	await _wait(0.2)
	await _fade_to(1.0)


func _scene_fight_won() -> void:
	await _go_to_floor(7)
	var group: Array[Enemy] = [Enemy.make_from_name("Young Red Dragon", 7),
			Enemy.make_from_name("Young Silver Dragon", 7), Enemy.make_from_name("Hellhound", 7)]
	# A clip, not a whole fight: everything falls to one hit, and hits back
	# softly while it stands.
	for foe: Enemy in group:
		foe.str = 1
		foe.mag = 1
		foe.max_hp = 1
		foe.hp = 1
	main._launch_combat(group)
	await _wait(0.3)
	await _fade_to(0.0, 0.35)
	_caption("Press-turn fights: hit a weakness, keep your turn.", 2.8)
	await _wait(0.8)
	var scene: CombatScene = _combat_scene()
	var tries: int = 0
	while scene != null and not scene.finished and tries < 24:
		tries += 1
		if _find_button(scene, "Skills") == null:
			await _wait(0.15)
			continue
		await _press(scene, "Skills", 0.3)
		var spell: String = "Ember"
		for foe: Enemy in scene._living_foes():
			if foe.enemy_name == "Young Silver Dragon":
				spell = "Ember"
			elif foe.enemy_name == "Young Red Dragon":
				spell = "Rime"
		if scene._actor_is_player():
			await _press(scene, spell, 0.35)
		else:
			await _press(scene, "Attack", 0.35)
		var pick: Enemy = null
		for foe: Enemy in scene._living_foes():
			pick = foe
			break
		if pick:
			await _press(scene, pick.display_name(), 0.3)
		await _wait(0.6)
	# The win: the party hops under the results.
	while scene != null and not scene.finished:
		await _wait(0.1)
	await _wait(0.4)
	_caption("Win, and the party celebrates.", 2.0)
	await _wait(2.4)
	await _fade_to(1.0)
	await _leave_results()


# Clicks through the results and any level-ups, back to the corridor.
func _leave_results() -> void:
	for i: int in 30:
		if not main.in_combat:
			break
		var hit: bool = false
		for t: String in ["Continue", "Confirm", "Skip"]:
			if _find_button(main, t) != null:
				await _press(main, t, 0.05)
				hit = true
				break
		if not hit:
			await _wait(0.15)
	await _end_fight()
	await _frames(3)


func _scene_talk() -> void:
	var foe: Enemy = Enemy.make_from_name("Baby Green Dragon", 7)
	main._launch_combat([foe])
	await _wait(0.3)
	await _fade_to(0.0, 0.35)
	_caption("Talk them round, and they fight for you.", 3.6)
	await _wait(0.8)
	var scene: CombatScene = _combat_scene()
	while _find_button(scene, "Talk") == null:
		await _wait(0.1)
	await _press(scene, "Talk", 0.4)
	# Asked who to talk to, even with one there.
	await _press(scene, scene.enemy.display_name(), 0.4)
	await _press(scene, "Recruit", 0.7)
	# The talk is rolled; for the trailer it goes the hero's way.
	var talk: Variant = scene._negotiation._active
	if talk != null:
		talk._talk_trust = Negotiation.needed(scene.enemy)
	var want: Array = Negotiation.RECRUIT_MATCH.get(scene.enemy.talk_personality, ["Flatter"])
	await _press(scene, want[0] as String, 0.8)
	await _wait(3.0)
	await _fade_to(1.0)
	# Joining ends the fight with its results, like a win; through them.
	await _leave_results()


# Floor 21 lays all four kinds: stand beside one of each and step on, and let
# the game do the rest (the slide, the shock, the burn, the jump).
func _scene_traps() -> void:
	await _go_to_floor(21)
	var lvl: Level = main.current_level
	var lines: Dictionary = {
		Level.HAZARD_ICE: "Ice carries you along.",
		Level.HAZARD_SPARK: "Spark plates bite when they are lit.",
		Level.HAZARD_LAVA: "Lava burns.",
		Level.HAZARD_TELE: "Teleporters send you somewhere else.",
	}
	var first: bool = true
	for kind: String in [Level.HAZARD_ICE, Level.HAZARD_SPARK, Level.HAZARD_LAVA, Level.HAZARD_TELE]:
		var spot: Array = _beside(kind)
		if spot.is_empty():
			print("trailer: no ", kind, " to step on")
			continue
		_stand(spot[0] as Vector2i, spot[1] as int)
		await _frames(3)
		await _fade_to(0.0, 0.3)
		_caption(("Every floor of the deep has its traps.  " if first else "") + (lines[kind] as String), 2.6)
		first = false
		await _wait(0.6)
		main._action_forward()
		await _wait(2.0)
		await _fade_to(1.0, 0.3)


# An open cell beside a trap of `kind`, the way to face it, and the trap; one
# that is not itself a trap or an orb, so the step is onto the trap and nothing
# else happens first.
func _beside(kind: String) -> Array:
	var lvl: Level = main.current_level
	for cell: Variant in lvl.trap_cells.keys():
		var value: String = str(lvl.trap_cells[cell])
		if Level.hazard_kind(value) != kind:
			continue
		# A spark plate bites only when lit on arrival ("spark0"/"spark1" is
		# its group; the lit one goes by steps taken): one that will be.
		if kind == Level.HAZARD_SPARK \
				and int(value.substr(Level.HAZARD_SPARK.length())) != Main._spark_live_at(main._spark_steps + 1):
			continue
		for d: int in 4:
			var from: Vector2i = (cell as Vector2i) - Main.DIR_OFFSET[d]
			if main._is_open(from.x, from.y) and not lvl.trap_cells.has(from) \
					and not from in lvl.orb_cells:
				return [from, d, cell]
	return []


func _scene_gacha() -> void:
	main._open_orb("gacha")
	await _wait(0.8)
	await _fade_to(0.0, 0.35)
	_caption("Rest, shop and gamble at the orbs.", 3.0)
	await _wait(0.6)
	var spin: Button = null
	for b: Node in main.orb_layer.find_children("*", "Button", true, false):
		if (b as Button).text.begins_with("Spin"):
			spin = b as Button
	if spin:
		spin.pressed.emit()
	await _wait(3.4)
	await _fade_to(1.0)
	main._close_orb()
	await _frames(5)


func _scene_dragon() -> void:
	await _go_to_floor(15)
	main.floor_num = 15
	main._start_boss_combat()
	await _wait(0.4)
	await _fade_to(0.0, 0.3)
	_caption("Every fifth floor, a dragon.", 2.6)
	await _wait(3.0)
	await _fade_to(1.0, 0.4)
	await _end_fight()


# The phone trailer's press, but a button freed while it waits (a menu that
# rebuilt itself) is skipped rather than pressed.
func _press(from: Node, text: String, pause: float = 0.45) -> bool:
	var b: Button = _find_button(from, text)
	if b == null:
		return false
	await _wait(pause)
	if not is_instance_valid(b) or not b.is_inside_tree():
		return false
	b.pressed.emit()
	return true
