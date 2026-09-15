# Map — the dungeon level with warm stone walls.
# Player starts at (1,1) facing South. Maze is procedurally generated on load.
extends Level


func _ready() -> void:
	next_scene = "res://scenes/map.tscn"

	# Every fifth floor is a boss corridor; everything else is a maze.
	if Level.is_boss_floor(floor_num):
		_setup_boss_floor()
	else:
		_setup_normal_floor(floor_num)


func _setup_normal_floor(floor_num: int = 0) -> void:
	maze = _generate_maze()

	wire_color       = Color(0.55, 0.88, 1.00)
	wire_floor_color = Color(0.32, 0.55, 0.70)
	wire_fill_color  = Color(0.075, 0.085, 0.115)

	player_start        = Vector2i(1, 1)
	player_start_facing = 2  # South

	# On the first floor the cells beside the spawn are reserved for the opening
	# orb, so the exit is not allowed to take the one open neighbour a tight
	# corner leaves — which is exactly how a handful of runs used to start with
	# no orb in sight.
	var reserved: Dictionary = {player_start: true}
	if floor_num <= 1:
		for off: Vector2i in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
			reserved[player_start + off] = true
	var exit_pair: Dictionary = _random_frontier_wall(reserved)
	exit_wall_pos = exit_pair["wall"]
	exit_pos      = exit_pair["floor"]
	# The very first floor opens with an orb already in view. Orbs are the only
	# save point, the only shop and the only way to heal, and a player who has
	# not met one yet does not know any of that — so the first one is claimed
	# before anything else can take the cell, and everything placed afterwards
	# routes around it.
	orb_cells.clear()
	if floor_num <= 1:
		_place_orb_in_front_of_start()
	_place_traps()
	_place_warden()
	_place_orbs()
	_place_chests()


func _setup_boss_floor() -> void:
	maze = _generate_corridor()

	# Boss corridors burn red.
	wire_color       = Color(1.00, 0.34, 0.30)
	wire_floor_color = Color(0.62, 0.18, 0.18)
	wire_fill_color  = Color(0.115, 0.052, 0.052)

	player_start        = Vector2i(1, 1)
	player_start_facing = 1  # East — face down the corridor
	entry_pos           = Vector2i(1, 1)
	entry_facing        = 1  # East

	# Exit at the far east end
	exit_pos      = Vector2i(17, 1)
	exit_wall_pos = Vector2i(18, 1)

	# 2 traps along the corridor, clear of both ends
	var trap_occupied: Dictionary = {Vector2i(1, 1): true, Vector2i(17, 1): true}
	var trap_candidates: Array[Vector2i] = []
	for x: int in range(3, 17):
		if not trap_occupied.has(Vector2i(x, 1)):
			trap_candidates.append(Vector2i(x, 1))
	trap_candidates.shuffle()
	var trap_types: Array[String] = ["spike", "poison_vent", "binding_rune"]
	for i: int in range(min(2, trap_candidates.size())):
		trap_cells[trap_candidates[i]] = trap_types[randi() % trap_types.size()]


func _generate_corridor() -> Array[Array]:
	const SIZE: int = 20
	var grid: Array[Array] = []
	for _i: int in range(SIZE):
		var row: Array = []
		row.resize(SIZE)
		row.fill(1)
		grid.append(row)
	for x: int in range(1, 19):
		(grid[1] as Array)[x] = 0
	return grid


# Generates a 20x20 maze with loops and variable-size rooms.
# Rooms sit at odd coordinates (1,3,...,17) — 9 per side.
func _generate_maze() -> Array[Array]:
	const SIZE: int  = 20
	const ROOMS: int = 9  # odd positions 1,3,5,7,9,11,13,15,17

	var grid: Array[Array] = []
	for _i: int in range(SIZE):
		var row: Array = []
		row.resize(SIZE)
		row.fill(1)
		grid.append(row)

	var visited: Array = []
	for _i: int in range(ROOMS):
		var row: Array = []
		row.resize(ROOMS)
		row.fill(false)
		visited.append(row)

	(grid[1] as Array)[1] = 0
	(visited[0] as Array)[0] = true

	var stack: Array = [Vector2i(0, 0)]
	var dirs: Array  = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]

	# Perfect maze via recursive backtracker
	while stack.size() > 0:
		var cur: Vector2i = stack[stack.size() - 1] as Vector2i
		var neighbors: Array = []
		for d: Variant in dirs:
			var dv: Vector2i = d as Vector2i
			var nr: int = cur.y + dv.y
			var nc: int = cur.x + dv.x
			if nr >= 0 and nr < ROOMS and nc >= 0 and nc < ROOMS:
				if not (visited[nr] as Array)[nc]:
					neighbors.append(Vector2i(nc, nr))

		if neighbors.size() > 0:
			var nxt: Vector2i = neighbors[randi() % neighbors.size()] as Vector2i
			(grid[cur.y + nxt.y + 1] as Array)[cur.x + nxt.x + 1] = 0
			(grid[2 * nxt.y + 1] as Array)[2 * nxt.x + 1] = 0
			(visited[nxt.y] as Array)[nxt.x] = true
			stack.append(nxt)
		else:
			stack.pop_back()

	# Loops: randomly remove ~15% of remaining internal walls between adjacent rooms
	for r: int in range(ROOMS):
		for c: int in range(ROOMS):
			if c + 1 < ROOMS:
				var wc: int = 2 * c + 2
				var wr: int = 2 * r + 1
				if (grid[wr] as Array)[wc] == 1 and randf() < 0.15:
					(grid[wr] as Array)[wc] = 0
			if r + 1 < ROOMS:
				var wc: int = 2 * c + 1
				var wr: int = 2 * r + 2
				if (grid[wr] as Array)[wc] == 1 and randf() < 0.15:
					(grid[wr] as Array)[wc] = 0

	# Bigger rooms: open corner walls between adjacent rooms with ~25% chance,
	# merging four neighbouring cells into one larger open space
	for r: int in range(ROOMS - 1):
		for c: int in range(ROOMS - 1):
			var cr: int = 2 * r + 2
			var cc: int = 2 * c + 2
			if randf() < 0.25:
				(grid[cr] as Array)[cc] = 0

	return grid


# Flood-fill from start; returns a random reachable open cell (excluding start).
func _random_reachable_cell(grid: Array[Array], start: Vector2i) -> Vector2i:
	var rows: int = grid.size()
	var cols: int = (grid[0] as Array).size()
	var dirs: Array = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]

	var visited: Dictionary = {start: true}
	var queue: Array = [start]
	var reachable: Array = []

	while queue.size() > 0:
		var cur: Vector2i = queue.pop_front() as Vector2i
		if cur != start:
			reachable.append(cur)
		for dir: Variant in dirs:
			var dv: Vector2i = dir as Vector2i
			var nc: int = cur.x + dv.x
			var nr: int = cur.y + dv.y
			var nxt: Vector2i = Vector2i(nc, nr)
			if nr >= 0 and nr < rows and nc >= 0 and nc < cols:
				if (grid[nr] as Array)[nc] == 0 and not visited.has(nxt):
					visited[nxt] = true
					queue.append(nxt)

	return reachable[randi() % reachable.size()] as Vector2i



func _random_frontier_wall(excluded_floors: Dictionary) -> Dictionary:
	const DIRS: Array[Vector2i] = [Vector2i(0,-1), Vector2i(1,0), Vector2i(0,1), Vector2i(-1,0)]
	var rows: int = maze.size()
	var cols: int = (maze[0] as Array).size()

	var reachable: Dictionary = {}
	var queue: Array = [player_start]
	reachable[player_start] = true
	while queue.size() > 0:
		var cur: Vector2i = queue.pop_front() as Vector2i
		for d: Vector2i in DIRS:
			var nxt: Vector2i = cur + d
			if nxt.x >= 0 and nxt.x < cols and nxt.y >= 0 and nxt.y < rows:
				if (maze[nxt.y] as Array)[nxt.x] == 0 and not reachable.has(nxt):
					reachable[nxt] = true
					queue.append(nxt)

	var seen_walls: Dictionary = {}
	var candidates: Array = []
	for fp: Variant in reachable.keys():
		if excluded_floors.has(fp):
			continue
		for d: Vector2i in DIRS:
			var wp: Vector2i = (fp as Vector2i) + d
			if seen_walls.has(wp):
				continue
			if wp.x <= 0 or wp.x >= cols - 1 or wp.y <= 0 or wp.y >= rows - 1:
				continue
			if (maze[wp.y] as Array)[wp.x] == 1:
				seen_walls[wp] = true
				candidates.append({wall=wp, floor=fp})

	return candidates[randi() % candidates.size()]




# Drops the warden on a reachable cell well away from both the entrance and the
# door it is guarding, so finding it is the floor's actual task.
func _place_warden() -> void:
	var best: Vector2i = Vector2i(-1, -1)
	var best_score: int = -1
	for _attempt: int in range(80):
		var pos: Vector2i = _random_reachable_cell(maze, player_start)
		if pos == player_start or pos == exit_pos or trap_cells.has(pos):
			continue
		if pos in orb_cells:
			continue
		var from_start: int = absi(pos.x - player_start.x) + absi(pos.y - player_start.y)
		var from_exit: int  = absi(pos.x - exit_pos.x) + absi(pos.y - exit_pos.y)
		var score: int = mini(from_start, from_exit)
		if score > best_score:
			best_score = score
			best = pos
	warden_pos = best


# Two or three orbs, spread out and clear of everything else that matters.
# They are the run's only save points, so a floor without one would be cruel.
# Adds to whatever is already down rather than clearing, so a starting orb
# claimed earlier survives and still counts toward the floor's total.
func _place_orbs() -> void:
	var want: int = 2 + (randi() % 2)
	var attempts: int = 0
	while orb_cells.size() < want and attempts < 120:
		attempts += 1
		var pos: Vector2i = _random_reachable_cell(maze, player_start)
		if pos == player_start or pos == exit_pos or pos == warden_pos:
			continue
		if trap_cells.has(pos) or pos in orb_cells:
			continue
		# Keep them apart so one corner of the maze does not hold all of them.
		var too_close: bool = false
		for other: Vector2i in orb_cells:
			if absi(pos.x - other.x) + absi(pos.y - other.y) < 8:
				too_close = true
		if too_close:
			continue
		orb_cells.append(pos)


# Puts one orb on a cell adjacent to the spawn and turns the player to face it,
# so the first thing on screen at the start of a run is the thing that explains
# the run. Falls back to leaving it out entirely if the spawn is somehow boxed
# in, rather than dropping an orb inside a wall.
func _place_orb_in_front_of_start() -> void:
	const DIRS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0),
			Vector2i(0, 1), Vector2i(-1, 0)]
	for facing: int in DIRS.size():
		var cell: Vector2i = player_start + DIRS[facing]
		if not _cell_is_open(cell):
			continue
		if cell == exit_pos or cell == exit_wall_pos:
			continue
		orb_cells.append(cell)
		player_start_facing = facing
		return


func _cell_is_open(cell: Vector2i) -> bool:
	if cell.y < 0 or cell.y >= maze.size():
		return false
	var row: Array = maze[cell.y]
	if cell.x < 0 or cell.x >= row.size():
		return false
	return int(row[cell.x]) == 0


# Two or three caches per floor, each cut into a wall that exactly one open
# cell touches. Requiring a single neighbour is what puts them in the side of
# a corridor rather than in the middle of a junction, where a recess would be
# visible from three directions and lose all of its quality of being found.
# Two or three caches on a shallow floor. From the depth a mimic lives at there
# are more of them and a share are mimics, so the extras are not a gift: the
# floor has more to open and opening is no longer free.
const MIMIC_EXTRA_CHESTS: int = 3
const MIMIC_SHARE: float = 0.4


func _place_chests() -> void:
	chest_cells.clear()
	looted.clear()
	mimic_cells.clear()
	var deep: bool = floor_num >= Enemy.MIMIC_FROM_FLOOR
	var want: int = 2 + (randi() % 2) + (MIMIC_EXTRA_CHESTS if deep else 0)
	var rows: int = maze.size()
	var cols: int = (maze[0] as Array).size()

	var candidates: Array[Array] = []
	for row: int in rows:
		for col: int in cols:
			var wall: Vector2i = Vector2i(col, row)
			if _cell_is_open(wall):
				continue
			if wall == exit_wall_pos:
				continue
			var touching: Array[Vector2i] = []
			for off: Vector2i in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
				var face: Vector2i = wall + off
				if _cell_is_open(face):
					touching.append(face)
			if touching.size() != 1:
				continue
			var face_cell: Vector2i = touching[0]
			if face_cell == player_start or face_cell == exit_pos \
					or face_cell == warden_pos or face_cell in orb_cells \
					or trap_cells.has(face_cell):
				continue
			candidates.append([wall, face_cell])

	candidates.shuffle()
	for entry: Array in candidates:
		if chest_cells.size() >= want:
			break
		var wall2: Vector2i = entry[0] as Vector2i
		var face2: Vector2i = entry[1] as Vector2i
		# Spread them out, the same way the orbs are spread.
		var too_close: bool = false
		for other: Variant in chest_cells.keys():
			var o: Vector2i = other as Vector2i
			if absi(o.x - wall2.x) + absi(o.y - wall2.y) < 7:
				too_close = true
		if too_close:
			continue
		chest_cells[wall2] = face2

	if not deep:
		return
	# At least one, so a floor that can hold a mimic always holds one — and
	# never all of them, so opening a cache is a risk rather than a refusal.
	var keys: Array = chest_cells.keys()
	keys.shuffle()
	var mimics: int = clampi(roundi(float(keys.size()) * MIMIC_SHARE),
			1, maxi(1, keys.size() - 1))
	for i: int in mimics:
		mimic_cells[keys[i]] = true


func _place_traps() -> void:
	const COUNT: int = 3
	var occupied: Dictionary = {
		player_start: true, exit_pos: true, exit_wall_pos: true,
	}
	for orb: Vector2i in orb_cells:
		occupied[orb] = true
	var types: Array[String] = ["spike", "poison_vent", "binding_rune"]
	var placed: int = 0
	var attempts: int = 0
	while placed < COUNT and attempts < 60:
		attempts += 1
		var pos: Vector2i = _random_reachable_cell(maze, player_start)
		if occupied.has(pos):
			continue
		occupied[pos] = true
		trap_cells[pos] = types[randi() % types.size()]
		placed += 1


