extends SceneTree
# Plays a short scripted run and saves the screenshots the title screen's
# tutorial shows, into resources/tutorial/. Rerun it whenever the game's look
# changes, from the repo root, with a real display (the headless renderer draws
# nothing):
#
#   godot --path . --script tools/tutorial_shots.gd
#
# On a machine without one, xvfb-run works:
#
#   xvfb-run -a -s "-screen 0 540x1170x24" godot --path . \
#       --rendering-driver opengl3 --script tools/tutorial_shots.gd
#
# Run it with the real art restored (tools/real_art.sh, restore_sprites.py) or
# the shots show the silhouettes git stores.

const OUT_DIR: String = "res://resources/tutorial/"

var main: Main


func _initialize() -> void:
	seed(20260927)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	GameBoot.pending_slot = 0
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Main
	root.add_child(main)
	await _frames(10)
	main._encounters_enabled = false
	main.player_char.gold = 600
	for r: Roamer in main.roamers:
		r.visible = false

	await _shot_explore()
	await _shot_trap()
	await _shot_key()
	await _shot_orb()
	await _shot_menu()
	await _shot_combat()
	await _shot_dragon()
	quit()


func _frames(n: int) -> void:
	for i: int in n:
		await process_frame


# Real time rather than frames: a software renderer can draw hundreds a second,
# and the camera's tweens (the shake a trap gives) run on the clock.
func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _save(file: String) -> void:
	await _wait(0.4)
	var img: Image = root.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(OUT_DIR + file))
	print("saved ", file)


# Faces the longest straight run of open floor from `from`, so the view looks
# down a corridor rather than into a wall.
func _face_longest(from: Vector2i, avoid_orbs: bool = true) -> void:
	var lvl: Level = main.current_level
	var best: int = -1
	for d: int in 4:
		var n: int = 0
		var c: Vector2i = from + Main.DIR_OFFSET[d]
		# Never onto a trap, and not ending up facing an orb: this is the
		# plain walking shot, and both have their own.
		if (avoid_orbs and c in lvl.orb_cells) or lvl.trap_cells.has(c):
			continue
		while main._is_open(c.x, c.y):
			n += 1
			c += Main.DIR_OFFSET[d]
		if n > best:
			best = n
			main.player_facing = d
	main._sync_player()
	main._snap_cam_yaw()


func _stand(pos: Vector2i, facing: int) -> void:
	main.player_pos = pos
	main.player_facing = facing
	main._sync_player()
	main._snap_cam_yaw()


# A cell `dist` steps back from `target` along `d` with open floor between.
func _approach(target: Vector2i, dist: int) -> Array:
	for d: int in 4:
		var pos: Vector2i = target
		var ok: bool = true
		for i: int in dist:
			pos -= Main.DIR_OFFSET[d]
			if not main._is_open(pos.x, pos.y) or main.current_level.trap_cells.has(pos):
				ok = false
				break
		if ok:
			return [pos, d]
	return []


func _shot_explore() -> void:
	# Walk a stretch first, so the map above has something on it: the shortest
	# path toward the far side of the maze, around traps, twenty steps of it.
	var lvl: Level = main.current_level
	_stand(lvl.player_start, lvl.player_start_facing)
	var path: Array[Vector2i] = _path_away(main.player_pos, 20)
	for cell: Vector2i in path:
		for d: int in 4:
			if main.player_pos + Main.DIR_OFFSET[d] == cell:
				main.player_facing = d
		main._snap_cam_yaw()
		main._action_forward()
		if main.orb_open:
			main._close_orb()
		await _frames(2)
	_face_longest(main.player_pos)
	await _save("explore.png")


# Breadth-first from `from` to the farthest reachable cell, avoiding traps,
# returned as the first `steps` cells of the way there.
func _path_away(from: Vector2i, steps: int) -> Array[Vector2i]:
	var lvl: Level = main.current_level
	var came: Dictionary = {from: from}
	var queue: Array[Vector2i] = [from]
	var last: Vector2i = from
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		last = c
		for off: Vector2i in Main.DIR_OFFSET:
			var n: Vector2i = c + off
			if came.has(n) or not main._is_open(n.x, n.y) or lvl.trap_cells.has(n):
				continue
			came[n] = c
			queue.append(n)
	var back: Array[Vector2i] = []
	var c2: Vector2i = last
	while c2 != from:
		back.push_front(c2)
		c2 = came[c2]
	return back.slice(0, steps)


func _shot_trap() -> void:
	for cell: Variant in main.current_level.trap_cells.keys():
		var a: Array = _approach(cell as Vector2i, 1)
		if a.is_empty():
			continue
		# Something to look at once on it, rather than a wall in the face.
		var beyond: Vector2i = (cell as Vector2i) + Main.DIR_OFFSET[a[1] as int]
		if not main._is_open(beyond.x, beyond.y):
			continue
		_stand(a[0] as Vector2i, a[1] as int)
		await _frames(5)
		main._action_forward()
		await _frames(12)
		await _save("trap.png")
		main.player_char.hp = main.player_char.max_hp
		await _wait(0.6)
		_clear_popup()
		return
	print("no trap to step on")


func _shot_key() -> void:
	# Keep going down until a floor has its key lying loose, then look at it.
	for i: int in 3:
		var lvl: Level = main.current_level
		if lvl.key_pos.x >= 0 and not lvl.key_taken:
			var a: Array = _approach(lvl.key_pos, 1)
			if not a.is_empty():
				_stand(a[0] as Vector2i, a[1] as int)
				await _frames(20)
				await _save("key.png")
				_reset_floor()
				return
		main._descend()
		for r: Roamer in main.roamers:
			r.visible = false
		await _frames(5)
	print("no loose key found")
	_reset_floor()


func _clear_popup() -> void:
	if is_instance_valid(main._hud_popup_tween):
		main._hud_popup_tween.kill()
	main._hud_popup.modulate.a = 0.0


func _reset_floor() -> void:
	main.floor_num = 0
	main._descend()
	main.floor_label.text = "Floor 1"
	for r: Roamer in main.roamers:
		r.visible = false


func _shot_orb() -> void:
	var orb: Vector2i = main.current_level.orb_cells[0]
	_stand(orb, 0)
	main._open_orb("rest")
	await _frames(15)
	await _save("orb.png")
	main._close_orb()


func _shot_menu() -> void:
	var p: PlayerCharacter = main.player_char
	p.remember_recruit("Slime", 2)
	p.remember_recruit("Skeleton", 2)
	main._open_menu()
	await _frames(5)
	var menu: MenuUI = main.menu_layer.get_child(main.menu_layer.get_child_count() - 1) as MenuUI
	menu._switch_tab("party")
	await _frames(10)
	await _save("party.png")
	main._close_menu()


func _combat_scene() -> CombatScene:
	for c: Node in main.get_children():
		if c is CanvasLayer:
			for cc: Node in c.get_children():
				if cc is CombatScene and not cc.is_queued_for_deletion():
					return cc as CombatScene
	return null


func _end_fight(scene: CombatScene) -> void:
	for c: Node in main.get_children():
		if c is CanvasLayer and c.get_child_count() > 0 and c.get_child(0) == scene:
			c.queue_free()
	for f: Enemy in scene.foes:
		f.queue_free()
	main.in_combat = false
	main.hud_layer.visible = true
	await _frames(3)


func _shot_combat() -> void:
	var group: Array[Enemy] = [Enemy.make_from_name("Orc", 2), Enemy.make_from_name("Bat", 2)]
	main._launch_combat(group)
	await _frames(90)
	var scene: CombatScene = _combat_scene()
	await _save("combat.png")
	scene.enemy = scene.foes[0]
	scene._show_talk_submenu()
	await _frames(10)
	await _save("talk.png")
	await _end_fight(scene)


func _shot_dragon() -> void:
	main.floor_num = 5
	main._start_boss_combat()
	await _frames(90)
	await _save("dragon.png")
	await _end_fight(_combat_scene())
