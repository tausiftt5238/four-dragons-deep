extends SceneTree
# Plays a scripted run for the trailer: walking the maze, a chest, a fight, the
# party, the key and the door, the stairs, and the four dragons, with captions.
# Record it with Godot's Movie Maker, from the repo root, with a real display:
#
#   TRAILER_OUT=/some/dir godot --path . --resolution 540x1170 \
#       --write-movie /some/dir/frame.png --fixed-fps 30 --script tools/trailer.gd
#
# then turn the frames into a video with tools/trailer_encode.sh. Movie Maker
# steps the clock one frame at a time, so timers and tweens here are video
# seconds whatever the machine does. Run it with the real art restored, or the
# trailer shows the silhouettes git stores.

const FONT: FontFile = preload("res://resources/misc/OldSchoolAdventures-42j9.ttf")
const GOLD: Color = Color(0.90, 0.75, 0.30)

var main: Main
var _fade: ColorRect
var _band: ColorRect
var _cap: Label
var _cap_tween: Tween


func _initialize() -> void:
	# Movie Maker waits on nothing but the frames; vsync against a display that
	# is asleep would hold every frame for a second.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	OS.low_processor_usage_mode = false
	seed(20260928)
	GameBoot.pending_slot = 0
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Main
	root.add_child(main)
	_build_overlay()
	_fade.color.a = 1.0
	await _frames(10)
	main._encounters_enabled = false
	_hide_roamers()
	var p: PlayerCharacter = main.player_char
	p.remember_recruit("Slime", 2)
	p.remember_recruit("Skeleton", 2)
	# Enough punch that the fight is two rounds, not ten.
	p.mag += 12
	p.str += 6

	await _title_card()
	await _scene_walk()
	await _scene_chest()
	await _scene_fight()
	await _scene_party()
	await _scene_key_and_door()
	await _scene_dragons()
	await _end_card()
	quit()


# ── Overlay: fades and captions ──────────────────────────────────────────────

func _build_overlay() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 120
	root.add_child(layer)

	_band = ColorRect.new()
	_band.color = Color(0.0, 0.0, 0.0, 0.62)
	_band.anchor_right = 1.0
	_band.offset_top = 420.0
	_band.offset_bottom = 520.0
	_band.modulate.a = 0.0
	layer.add_child(_band)

	_cap = Label.new()
	_cap.add_theme_font_override("font", FONT)
	_cap.add_theme_font_size_override("font_size", 26)
	_cap.add_theme_color_override("font_color", Color(1.0, 0.95, 0.82))
	_cap.add_theme_color_override("font_outline_color", Color.BLACK)
	_cap.add_theme_constant_override("outline_size", 8)
	_cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cap.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_cap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_cap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cap.offset_left = 20.0
	_cap.offset_right = -20.0
	_band.add_child(_cap)

	_fade = ColorRect.new()
	_fade.color = Color(0.0, 0.0, 0.0, 0.0)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)


# Shows a caption for `hold` seconds. Not awaited by callers that want the
# action to carry on underneath it.
func _caption(text: String, hold: float = 2.4, y: float = 420.0) -> void:
	if _cap_tween:
		_cap_tween.kill()
	_cap.text = text
	_band.offset_top = y
	_band.offset_bottom = y + 100.0
	_cap_tween = main.create_tween()
	_cap_tween.tween_property(_band, "modulate:a", 1.0, 0.25)
	_cap_tween.tween_interval(hold)
	_cap_tween.tween_property(_band, "modulate:a", 0.0, 0.35)
	await _cap_tween.finished


func _fade_to(alpha: float, t: float = 0.45) -> void:
	var tw: Tween = main.create_tween()
	tw.tween_property(_fade, "color:a", alpha, t)
	await tw.finished


func _frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _hide_roamers() -> void:
	for r: Roamer in main.roamers:
		if is_instance_valid(r):
			r.visible = false


# A big centred block of text on black, for the first and last cards.
func _card(lines: Array, hold: float) -> void:
	var box: VBoxContainer = VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 26)
	box.modulate.a = 0.0
	_fade.add_child(box)
	for line: Array in lines:
		var l: Label = Label.new()
		l.text = line[0]
		l.add_theme_font_override("font", FONT)
		l.add_theme_font_size_override("font_size", line[1])
		l.add_theme_color_override("font_color", line[2])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(l)
	var tw: Tween = main.create_tween()
	tw.tween_property(box, "modulate:a", 1.0, 0.6)
	tw.tween_interval(hold)
	tw.tween_property(box, "modulate:a", 0.0, 0.5)
	await tw.finished
	box.queue_free()


# ── Moving like a player, but smoothly ───────────────────────────────────────

func _stand(pos: Vector2i, facing: int) -> void:
	main.player_pos = pos
	main.player_facing = facing
	main._sync_player()
	main._snap_cam_yaw()


func _turn_to(d: int) -> void:
	var diff: int = (d - main.player_facing + 4) % 4
	if diff == 0:
		return
	if diff == 3:
		main._action_turn_left()
	else:
		main._action_turn_right()
	main.turn_tween.kill()
	var tw: Tween = main.create_tween()
	tw.tween_property(main.cam_rig, "rotation:y", main.cam_yaw, 0.30) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	main.turn_tween = tw
	await tw.finished
	if diff == 2:
		await _turn_to(d)


# One step forward, glided rather than snapped. Returns false on a bump.
func _forward(t: float = 0.34) -> bool:
	var before: Vector3 = main.cam_rig.position
	main._action_forward()
	var after: Vector3 = main.cam_rig.position
	if after.is_equal_approx(before):
		await _wait(0.35)
		return false
	main.cam_rig.position = before
	var tw: Tween = main.create_tween()
	tw.tween_property(main.cam_rig, "position", after, t) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	return true


func _walk(path: Array[Vector2i]) -> void:
	for cell: Vector2i in path:
		for d: int in 4:
			if main.player_pos + Main.DIR_OFFSET[d] == cell:
				await _turn_to(d)
		await _forward()
		if main.orb_open:
			main._close_orb()


# Breadth-first to `to` (or, with no target, to the farthest cell), around
# traps and orbs. Returns the cells to step through, not counting `from`.
func _path(from: Vector2i, to: Vector2i = Vector2i(-99, -99),
		through_orbs: bool = false) -> Array[Vector2i]:
	var lvl: Level = main.current_level
	var came: Dictionary = {from: from}
	var queue: Array[Vector2i] = [from]
	var last: Vector2i = from
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		last = c
		if c == to:
			break
		for off: Vector2i in Main.DIR_OFFSET:
			var n: Vector2i = c + off
			if came.has(n) or not main._is_open(n.x, n.y) or lvl.trap_cells.has(n):
				continue
			if n in lvl.orb_cells and n != to and not through_orbs:
				continue
			came[n] = c
			queue.append(n)
	var goal: Vector2i = to if came.has(to) else last
	var back: Array[Vector2i] = []
	var c2: Vector2i = goal
	while c2 != from:
		back.push_front(c2)
		c2 = came[c2]
	return back


# How many of a path's first steps run straight on, so the opening shot looks
# down a corridor rather than turning at once.
func _straight(from: Vector2i, path: Array[Vector2i]) -> int:
	if path.size() < 2:
		return -1
	var d: Vector2i = path[0] - from
	var n: int = 0
	var prev: Vector2i = from
	for c: Vector2i in path:
		if c - prev != d:
			break
		n += 1
		prev = c
	return mini(n, 6)


# A cell up to `dist` steps back from `target` along a straight run, and the
# facing that looks at it.
func _approach(target: Vector2i, dist: int) -> Array:
	for want: int in range(dist, 0, -1):
		for d: int in 4:
			var pos: Vector2i = target
			var ok: bool = true
			for i: int in want:
				pos -= Main.DIR_OFFSET[d]
				if not main._is_open(pos.x, pos.y) or main.current_level.trap_cells.has(pos) \
						or pos in main.current_level.orb_cells:
					ok = false
					break
			if ok:
				return [pos, d]
	return []


func _go_to_floor(n: int) -> void:
	main.floor_num = n - 1
	main._descend()
	main.floor_label.text = "Floor %d" % n
	_hide_roamers()
	await _frames(3)


# ── Scenes ───────────────────────────────────────────────────────────────────

func _title_card() -> void:
	await _card([["FOUR\nDRAGONS\nDEEP", 58, GOLD]], 1.8)


func _scene_walk() -> void:
	# The start cell can be boxed in by an orb; begin somewhere with a real
	# stretch of corridor ahead instead.
	var path: Array[Vector2i] = []
	var start: Vector2i = Vector2i.ZERO
	var lvl: Level = main.current_level
	for row: int in lvl.maze.size():
		for col: int in (lvl.maze[row] as Array).size():
			var c: Vector2i = Vector2i(col, row)
			if not main._is_open(c.x, c.y) or c in lvl.orb_cells or lvl.trap_cells.has(c):
				continue
			var p: Array[Vector2i] = _path(c)
			# Not toward the door: that is the reveal for later.
			if lvl.exit_pos in p.slice(0, 13):
				continue
			if p.size() >= 13 and _straight(c, p) > _straight(start, path):
				start = c
				path = p
	path = path.slice(0, 13)
	_stand(start, Main.DIR_OFFSET.find(path[0] - start))
	await _frames(3)
	await _fade_to(0.0, 0.6)
	_caption("Twenty floors down.")
	await _walk(path.slice(0, 6))
	_caption("Stone, torchlight,\nand no way back up.")
	await _walk(path.slice(6))
	await _wait(0.3)
	await _fade_to(1.0)


func _scene_chest() -> void:
	for f: int in [1, 2, 3, 4]:
		if f != main.floor_num:
			await _go_to_floor(f)
		var lvl: Level = main.current_level
		for wall: Variant in lvl.chest_cells.keys():
			if lvl.looted.has(wall):
				continue
			var cell: Vector2i = lvl.chest_cells[wall]
			var face: int = Main.DIR_OFFSET.find((wall as Vector2i) - cell)
			var a: Array = _approach(cell, 2)
			if a.is_empty() or int(a[1]) != face:
				a = [cell, face]
			_stand(a[0] as Vector2i, a[1] as int)
			await _fade_to(0.0)
			_caption("Crack open\nwhat was left behind.")
			await _walk(_path(main.player_pos, cell))
			await _turn_to(face)
			await _wait(0.3)
			main._action_forward()
			await _wait(1.0)
			for ui: Node in main.chest_layer.get_children():
				if ui is ChestUI:
					(ui as ChestUI).opened.emit()
			await _wait(1.8)
			await _fade_to(1.0)
			return


func _scene_fight() -> void:
	await _go_to_floor(1)
	var lvl: Level = main.current_level
	_stand(lvl.player_start, lvl.player_start_facing)
	var run: Array[Vector2i] = _path(main.player_pos).slice(0, 3)
	var roamer: Roamer = main.roamers[0] if not main.roamers.is_empty() else null
	if roamer and run.size() >= 3:
		roamer.teleport_to(run[2])
		roamer.visible = true
	await _fade_to(0.0)
	_caption("Things walk these halls.")
	await _walk(run.slice(0, 2))
	await _wait(0.4)
	if roamer:
		roamer.visible = false
	var group: Array[Enemy] = [Enemy.make_from_name("Skeleton Archer", 2),
			Enemy.make_from_name("Blood Spawn", 2), Enemy.make_from_name("Orc", 2)]
	# A clip, not a whole fight: one round and out. The foes hit softly so no
	# bound monster falls, since the party screen comes next.
	for foe: Enemy in group:
		foe.str = 1
		foe.mag = 1
	main._launch_combat(group)
	await _wait(1.2)
	var scene: CombatScene = _combat_scene()
	var acted: int = 0
	while acted < scene._living_party().size():
		if _find_button(scene, "Skills") == null:
			await _wait(0.1)
			continue
		await _wait(0.35)
		await _press(scene, "Skills")
		if scene._actor_is_player():
			_caption("Hit them where it hurts.", 2.6, 250.0)
			await _press(scene, "Ember")
		else:
			await _press(scene, "Attack")
		# A target list only comes up with more than one foe standing.
		var pick: Enemy = null
		for foe: Enemy in scene._living_foes():
			if pick == null or foe.enemy_name == "Skeleton Archer":
				pick = foe
		if pick:
			await _press(scene, pick.display_name(), 0.3)
		acted += 1
		await _wait(0.3)
	# Their answer, then cut.
	await _wait(2.6)
	await _fade_to(1.0)
	await _end_fight()


func _scene_party() -> void:
	main._open_menu()
	await _frames(3)
	var menu: MenuUI = main.menu_layer.get_child(main.menu_layer.get_child_count() - 1) as MenuUI
	menu._switch_tab("party")
	await _frames(5)
	await _fade_to(0.0, 0.35)
	await _caption("Talk them round.\nFight beside them.", 2.2, 700.0)
	await _fade_to(1.0, 0.35)
	main._close_menu()


func _scene_key_and_door() -> void:
	# A floor with its key lying loose, rather than held by the warden.
	for f: int in [2, 3, 4, 1]:
		await _go_to_floor(f)
		var lvl: Level = main.current_level
		if lvl.key_pos.x < 0 or lvl.key_taken:
			continue
		var a: Array = _approach(lvl.key_pos, 3)
		if a.is_empty():
			continue
		_stand(a[0] as Vector2i, a[1] as int)
		await _frames(5)
		await _fade_to(0.0)
		_caption("Find the key.", 2.0)
		await _walk(_path(main.player_pos, lvl.key_pos))
		main._sync_door()
		await _wait(1.0)
		await _fade_to(1.0)

		var into: Vector2i = lvl.exit_wall_pos - lvl.exit_pos
		var back: Vector2i = lvl.exit_pos
		for i: int in 3:
			var nb: Vector2i = back - into
			if not main._is_open(nb.x, nb.y) or lvl.trap_cells.has(nb) or nb in lvl.orb_cells:
				break
			back = nb
		_stand(back, Main.DIR_OFFSET.find(into))
		await _frames(5)
		await _fade_to(0.0)
		await _walk(_path(main.player_pos, lvl.exit_pos))
		await _turn_to(Main.DIR_OFFSET.find(lvl.exit_wall_pos - lvl.exit_pos))
		_caption("Unlock the way down.", 2.2)
		await _wait(1.6)
		main._action_forward()          # the key turns
		await _wait(1.6)
		# Up the steps and into the dark.
		var dir: Vector3 = Vector3(float(lvl.exit_wall_pos.x - lvl.exit_pos.x), 0.0,
				float(lvl.exit_wall_pos.y - lvl.exit_pos.y))
		var tw: Tween = main.create_tween().set_parallel()
		tw.tween_property(main.cam_rig, "position",
				main.cam_rig.position + dir * 1.9 + Vector3(0.0, 1.0, 0.0), 1.6) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw.tween_property(_fade, "color:a", 1.0, 1.6).set_trans(Tween.TRANS_QUAD) \
				.set_ease(Tween.EASE_IN)
		await tw.finished
		return


func _scene_dragons() -> void:
	await _go_to_floor(5)
	var lvl: Level = main.current_level
	var path: Array[Vector2i] = _path(lvl.player_start, lvl.exit_pos, true)
	var from: Vector2i = lvl.player_start
	for i: int in path.size():
		if path[i] in lvl.orb_cells:
			from = path[i + 1]
			path = path.slice(i + 2)
			break
	_stand(from, Main.DIR_OFFSET.find(path[0] - from))
	await _frames(5)
	await _fade_to(0.0)
	_caption("Every fifth floor,\na dragon.", 2.6)
	await _walk(path.slice(0, 6))
	await _fade_to(1.0, 0.3)
	_stand(lvl.exit_pos, Main.DIR_OFFSET.find(lvl.exit_wall_pos - lvl.exit_pos))
	await _frames(3)
	await _fade_to(0.0, 0.3)
	await _wait(0.4)
	main._action_forward()
	await _wait(0.6)
	_caption("Bring the right element.", 2.2, 250.0)
	await _wait(2.4)
	# The other three, one cut each.
	for f: int in [10, 15, 20]:
		await _fade_to(1.0, 0.2)
		await _end_fight()
		main.floor_num = f
		main._start_boss_combat()
		await _wait(0.4)
		await _fade_to(0.0, 0.2)
		await _wait(1.4)
	await _fade_to(1.0, 0.4)
	await _end_fight()


func _end_card() -> void:
	await _card([["FOUR\nDRAGONS\nDEEP", 58, GOLD],
			["A dungeon crawler\nfor your phone", 22, Color(0.80, 0.82, 0.88)]], 2.6)


# ── Combat plumbing ──────────────────────────────────────────────────────────

func _combat_scene() -> CombatScene:
	for c: Node in main.get_children():
		if c is CanvasLayer:
			for cc: Node in c.get_children():
				if cc is CombatScene and not cc.is_queued_for_deletion():
					return cc as CombatScene
	return null


func _end_fight() -> void:
	var scene: CombatScene = _combat_scene()
	if scene == null:
		return
	for c: Node in main.get_children():
		if c is CanvasLayer and c.get_child_count() > 0 and c.get_child(0) == scene:
			c.queue_free()
	for f: Enemy in scene.foes:
		f.queue_free()
	main.in_combat = false
	main.hud_layer.visible = true
	await _frames(2)


# The first visible, live button whose own text or any label inside it says
# `text` (buttons are upper-cased on screen, so case is ignored).
func _find_button(from: Node, text: String) -> Button:
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


func _press(from: Node, text: String, pause: float = 0.45) -> bool:
	var b: Button = _find_button(from, text)
	if b == null:
		return false
	await _wait(pause)
	b.pressed.emit()
	return true
