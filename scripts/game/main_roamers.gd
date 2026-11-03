# MainRoamers
# The monsters walking a floor, split out of Main: how many and where (one
# to a territory), the warden with the floor's key and the door it opens,
# moving them a step when the player steps, and starting the fight when one
# is reached. It works on the Main it belongs to.
class_name MainRoamers extends RefCounted

var main: Main


func _init(host: Main) -> void:
	main = host


# ── Roaming demons ────────────────────────────────────────────────────────────

# How many demons a floor carries. Boss corridors carry none — the boss is the
# encounter, and a 1-cell-wide corridor gives you nowhere to dodge.
#
# One demon per territory is the rule that keeps them out of each other's way,
# so this can only ever reach as high as there are territories — see ZONE_DIV.
func _roamer_target() -> int:
	if Level.is_boss_floor(main.floor_num):
		return 0
	return mini(9 + main.floor_num * 2, 14)


func _spawn_roamers() -> void:
	for r: Roamer in main.roamers:
		if is_instance_valid(r):
			r.queue_free()
	main.roamers.clear()
	main._engaged.clear()
	main._steps_since_spawn = 0
	# One territory each, so they never end up in the same corner of the maze.
	var zones: Array[Rect2i] = _build_zones()
	zones.shuffle()
	var target: int = _roamer_target()
	for z: Rect2i in zones:
		if main.roamers.size() >= target:
			break
		_spawn_roamer_in(z)
	_spawn_warden()


# The door and the HUD key follow the same two flags, so they are set together.
func _sync_door() -> void:
	if is_instance_valid(main.dungeon):
		main.dungeon.set_locked(not main._door_open)
	if main._key_icon != null:
		main._key_icon.visible = main._has_key and not main._door_open


# Walking onto the loose key takes it. No prompt: there is one thing to do with
# a key and asking whether to do it is a dialog box in front of a door.
func _take_key_here() -> void:
	if main.current_level == null or main._has_key or main.current_level.key_taken:
		return
	if main.current_level.key_pos.x < 0 or main.player_pos != main.current_level.key_pos:
		return
	main.current_level.key_taken = true
	main._has_key = true
	main.minimap_ctrl.key_pos = Vector2i(-1, -1)
	main.minimap_ctrl.queue_redraw()
	main._rebuild_dungeon()
	Sfx.play("key")
	main._screens._show_hud_popup("You take the key. Find the door.", Color(0.75, 0.55, 1.0))


# The thing holding the key, if anything is. A warden stands in the middle of
# its band; the other maze floors leave the key lying and this does nothing.
func _spawn_warden() -> void:
	main._warden = null
	main._has_key = false
	if main.current_level == null:
		main._has_key = true
		return
	main.minimap_ctrl.key_pos = Vector2i(-1, -1)
	if main.current_level.warden_pos.x < 0:
		# A loose key, or a corridor with neither and no locked door.
		if main.current_level.key_pos.x >= 0 and not main.current_level.key_taken:
			main.minimap_ctrl.key_pos = main.current_level.key_pos
		else:
			main._has_key = true
		main.minimap_ctrl.queue_redraw()
		return
	var w: Roamer = Roamer.new()
	w.warden = true
	w.cell = main.current_level.warden_pos
	main.world.add_child(w)
	main.roamers.append(w)
	main._warden = w
	main.minimap_ctrl.warden_pos = w.cell
	main.minimap_ctrl.queue_redraw()


# Carves the floor into a grid of territories. Anything smaller than a couple
# of cells is not worth patrolling, so tiny slivers are simply skipped later.
# The maze is cut into ZONE_DIV x ZONE_DIV territories and each one holds at
# most one demon, which is what stops them piling into a corner or wandering
# through each other. It is therefore also the ceiling on how many a floor can
# carry: at 3 that was nine, and a 20x20 maze felt empty. At 4 there are
# sixteen territories of about 5x5, still big enough that a demon patrols
# rather than paces.
const ZONE_DIV: int = 4

func _build_zones() -> Array[Rect2i]:
	var out: Array[Rect2i] = []
	if main.current_level == null or main.current_level.maze.is_empty():
		return out
	var rows: int = main.current_level.maze.size()
	var cols: int = (main.current_level.maze[0] as Array).size()
	var zw: int = maxi(1, cols / ZONE_DIV)
	var zh: int = maxi(1, rows / ZONE_DIV)
	for zy: int in range(ZONE_DIV):
		for zx: int in range(ZONE_DIV):
			var x0: int = zx * zw
			var y0: int = zy * zh
			var w: int = (cols - x0) if zx == ZONE_DIV - 1 else zw
			var h: int = (rows - y0) if zy == ZONE_DIV - 1 else zh
			if w > 0 and h > 0:
				out.append(Rect2i(x0, y0, w, h))
	return out


# The cells of one territory that are open, clear of the player, and not
# already held by something else.
func _free_cells_in(zone: Rect2i, min_dist: int) -> Array[Vector2i]:
	var taken: Dictionary = _occupied_cells()
	var out: Array[Vector2i] = []
	for row: int in range(zone.position.y, zone.position.y + zone.size.y):
		for col: int in range(zone.position.x, zone.position.x + zone.size.x):
			var c: Vector2i = Vector2i(col, row)
			if not main._is_open(c.x, c.y) or taken.has(c):
				continue
			if c == main.current_level.exit_pos or c == main.current_level.warden_pos:
				continue
			if c in main.current_level.orb_cells:
				continue
			if absi(c.x - main.player_pos.x) + absi(c.y - main.player_pos.y) < min_dist:
				continue
			out.append(c)
	return out


func _occupied_cells() -> Dictionary:
	var taken: Dictionary = {}
	for r: Roamer in main.roamers:
		if is_instance_valid(r):
			taken[r.cell] = true
	return taken


# Places one demon inside a territory, and hands it that territory to keep to.
func _spawn_roamer_in(zone: Rect2i) -> void:
	var options: Array[Vector2i] = _free_cells_in(zone, 6)
	if options.is_empty():
		options = _free_cells_in(zone, 3)
	if options.is_empty():
		return
	var r: Roamer = Roamer.new()
	r.cell = options[randi() % options.size()]
	r.zone = zone
	r.tier = Enemy.roamer_tier(main.floor_num)
	main.world.add_child(r)
	main.roamers.append(r)


# Refills a territory that has fallen empty, rather than piling another demon
# into one that is already patrolled.
func _spawn_roamer() -> void:
	var held: Dictionary = {}
	for r: Roamer in main.roamers:
		if is_instance_valid(r) and not r.warden:
			held[r.zone] = true
	var empty: Array[Rect2i] = []
	for z: Rect2i in _build_zones():
		if not held.has(z):
			empty.append(z)
	if empty.is_empty():
		return
	_spawn_roamer_in(empty[randi() % empty.size()])


# A random open cell at least min_dist away from the player, or (-1,-1) if the
# floor is too cramped to find one.
func _far_open_cell(min_dist: int) -> Vector2i:
	var candidates: Array[Vector2i] = []
	for row: int in range(main.current_level.maze.size()):
		var row_data: Array = main.current_level.maze[row]
		for col: int in range(row_data.size()):
			if row_data[col] != 0:
				continue
			var c: Vector2i = Vector2i(col, row)
			if absi(c.x - main.player_pos.x) + absi(c.y - main.player_pos.y) < min_dist:
				continue
			if c == main.current_level.exit_pos:
				continue
			candidates.append(c)
	if candidates.is_empty():
		return Vector2i(-1, -1)
	return candidates[randi() % candidates.size()]


func _step_roamers() -> void:
	if not main._encounters_enabled:
		return
	# Everyone sees where everyone else is standing, so two never share a cell.
	for r: Roamer in main.roamers:
		if is_instance_valid(r):
			var taken: Dictionary = _occupied_cells()
			# An orb is the only place a run can be saved, healed or restocked.
			# A demon parked on one turns that into a fight you cannot decline.
			for orb: Vector2i in main.current_level.orb_cells:
				taken[orb] = true
			taken.erase(r.cell)
			r.move_to(r.choose_step(main.player_pos, main._is_open, taken))

	main._steps_since_spawn += 1
	if main._steps_since_spawn >= Main._RESPAWN_STEPS and main.roamers.size() < _roamer_target():
		main._steps_since_spawn = 0
		_spawn_roamer()


# Starts a battle if a roamer is standing where the player is. Returns true if
# one did, so the caller knows to stop.
func _engage_roamer_here() -> bool:
	if not main._encounters_enabled:
		return false
	var here: Array[Roamer] = []
	for r: Roamer in main.roamers:
		if is_instance_valid(r) and r.cell == main.player_pos:
			here.append(r)
	if here.is_empty():
		return false

	# Off the floor the instant the battle opens, rather than after it resolves.
	# They are only hidden, not freed — escaping has to put them back.
	main._engaged = here
	var warden_here: bool = false
	for e: Roamer in here:
		if e.warden:
			warden_here = true
		main.roamers.erase(e)
		e.visible = false

	# The warden is a named demon, not a reroll of the floor's random table —
	# it is the locked door, and it fights alone so its two icons read as a
	# wall rather than getting lost in a pack.
	if warden_here:
		var keeper: Array[Enemy] = [Enemy.make_warden(main.floor_num)]
		main._launch_combat(keeper, true)
		return true

	main._launch_combat(Enemy.make_group(main.floor_num))
	return true


