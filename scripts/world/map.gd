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

	wire_color       = Level.tier_wire(floor_num)
	wire_floor_color = Level.tier_wire_floor(floor_num)
	wire_fill_color  = Level.tier_wire_fill(floor_num)

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
	_place_hazards(floor_num)
	# A warden holds the key in the middle of its band; every other maze floor
	# leaves it lying somewhere to be found.
	if Level.is_warden_floor(floor_num):
		_place_warden()
	else:
		_place_key()
	_place_orbs()
	_place_chests()


func _setup_boss_floor() -> void:
	maze = _generate_corridor()

	# A boss corridor burns its band's own colour — the dragon's colour, which
	# every wall of the last five floors has been a dimmer version of.
	wire_color       = Level.boss_wire(floor_num)
	wire_floor_color = Level.boss_wire_floor(floor_num)
	wire_fill_color  = Level.boss_wire_fill(floor_num)

	player_start        = Vector2i(1, 1)
	player_start_facing = 1  # East — face down the corridor
	entry_pos           = Vector2i(1, 1)
	entry_facing        = 1  # East

	# Exit at the far east end
	exit_pos      = Vector2i(17, 1)
	exit_wall_pos = Vector2i(18, 1)

	# An orb one step in, dead ahead of where the player arrives. A boss corridor
	# is a one-way room — walking east is the fight and there is nothing to go
	# back for — so the run has to be savable, healable and shoppable at its mouth
	# or the only way to prepare for a boss is to have guessed five floors ago.
	# It is the last orb of the band; the warden is the floor above.
	orb_cells.clear()
	orb_cells.append(Vector2i(2, 1))

	# No traps. The corridor is one way and the orb at its mouth is the last
	# chance to heal, so HP shaved off between there and the dragon is HP the
	# player has no way to get back.


func _generate_corridor() -> Array[Array]:
	const SIZE: int = 20
	var grid: Array[Array] = []
	for _i: int in range(SIZE):
		var row: Array = []
		row.resize(SIZE)
		row.fill(1)
		grid.append(row)
	# Open cells run x=1..17 and stop there. exit_pos is (17,1) and
	# exit_wall_pos is (18,1), and the boss only fires when the player walks
	# into that wall from that cell — so carving 18 as well let the player step
	# straight past the trigger onto the last tile and find nothing there.
	for x: int in range(1, 18):
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


# The loose key, on a floor with nothing guarding it. Scored the same way the
# warden is — as far from both the entrance and the door as the maze allows —
# because a key you trip over on the way past is not a floor, it is a corridor.
func _place_key() -> void:
	warden_pos = Vector2i(-1, -1)
	key_taken = false
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
	key_pos = best


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


func _place_chests() -> void:
	chest_cells.clear()
	looted.clear()
	var want: int = 2 + (randi() % 2)
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
					or face_cell == warden_pos or face_cell == key_pos \
					or face_cell in orb_cells or trap_cells.has(face_cell):
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


# Each band lays the hazard of the dragon waiting at its bottom. None on a
# warden's floor: the fight for the key is the floor's hurdle, and a timing
# puzzle in front of it would only be noise. Boss corridors never get here.
func _place_hazards(floor_num: int) -> void:
	if Level.is_warden_floor(floor_num):
		return
	var occupied: Dictionary = {
		player_start: true, exit_pos: true, exit_wall_pos: true,
	}
	for orb: Vector2i in orb_cells:
		occupied[orb] = true
	# Nothing right beside the start either: the first step of a floor should
	# never be onto something.
	for off: Vector2i in _DIRS4:
		occupied[player_start + off] = true
	match Level.tier_of(floor_num):
		1: _place_ice(occupied)
		2: _place_sparks(occupied)
		3: _place_lava(occupied)
		_: _place_teleporters(occupied)


const _DIRS4: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]


func _open(p: Vector2i) -> bool:
	return p.y >= 0 and p.y < maze.size() and p.x >= 0 \
			and p.x < (maze[p.y] as Array).size() and (maze[p.y] as Array)[p.x] == 0


# A corridor cell: open, with rock on both sides across `dir`.
func _corridor_cell(p: Vector2i, dir: Vector2i) -> bool:
	var side: Vector2i = Vector2i(dir.y, -dir.x)
	return _open(p) and not _open(p + side) and not _open(p - side)


# Straight runs of `length` corridor cells, with open floor at both ends to
# land on and nothing already claimed in or around them. Ice laid on one can
# only ever carry you from one end to the other, so it can never strand you.
func _corridor_runs(length: int, occupied: Dictionary) -> Array:
	var runs: Array = []
	for y: int in maze.size():
		for x: int in (maze[y] as Array).size():
			for dir: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
				var start: Vector2i = Vector2i(x, y)
				var cells: Array[Vector2i] = []
				var ok: bool = true
				for k: int in length:
					var c: Vector2i = start + dir * k
					if not _corridor_cell(c, dir) or occupied.has(c):
						ok = false
						break
					cells.append(c)
				if not ok:
					continue
				var before: Vector2i = start - dir
				var after: Vector2i = start + dir * length
				if not _open(before) or not _open(after) \
						or occupied.has(before) or occupied.has(after):
					continue
				runs.append(cells)
	runs.shuffle()
	return runs


func _claim_run(cells: Array, occupied: Dictionary) -> void:
	for c: Vector2i in cells:
		occupied[c] = true
		for off: Vector2i in _DIRS4:
			occupied[c + off] = true


# Up to two sheets of ice, each a stretch of corridor two to four long.
func _place_ice(occupied: Dictionary) -> void:
	var placed: int = 0
	for length: int in [4, 3, 3, 2, 2]:
		if placed >= 2:
			return
		var runs: Array = _corridor_runs(length, occupied)
		if runs.is_empty():
			continue
		var cells: Array = runs[0]
		for c: Vector2i in cells:
			trap_cells[c] = Level.HAZARD_ICE
		_claim_run(cells, occupied)
		placed += 1


# Up to three stretches of corridor with a plate on every other tile —
# plate, floor, plate, floor, plate — the plates alternating between the two
# groups. You reach each plate two steps after the last, which is exactly when
# both groups swap, so a strip you start on a dark plate stays dark all the way
# across at a steady walk. And the floor tile between two plates always has
# one dark plate either side of it, so nobody is ever boxed in.
func _place_sparks(occupied: Dictionary) -> void:
	var placed: int = 0
	for length: int in [5, 5, 5, 3, 3, 3]:
		if placed >= 3:
			return
		# Both ends need somewhere to step aside to, or the one way to wait
		# for a lit plate — a step off and back — is not there.
		var runs: Array = _corridor_runs(length, occupied).filter(
				func(run: Array) -> bool:
					var dir: Vector2i = run[1] - run[0]
					return _exits(run[0] - dir) >= 2 \
							and _exits(run[run.size() - 1] + dir) >= 2)
		if runs.is_empty():
			continue
		var cells: Array = runs[0]
		for i: int in range(0, cells.size(), 2):
			trap_cells[cells[i]] = "%s%d" % [Level.HAZARD_SPARK, (i / 2) % 2]
		_claim_run(cells, occupied)
		placed += 1


func _exits(p: Vector2i) -> int:
	var n: int = 0
	for off: Vector2i in _DIRS4:
		if _open(p + off):
			n += 1
	return n


# Three pools of two to four tiles. A pool only goes where the rest of the
# floor still connects without it, so there is always a way round: lava is a
# shortcut you pay for, never a toll on the only road.
func _place_lava(occupied: Dictionary) -> void:
	var lava: Dictionary = {}
	var pools: int = 0
	var attempts: int = 0
	while pools < 3 and attempts < 60:
		attempts += 1
		var seed_cell: Vector2i = _random_reachable_cell(maze, player_start)
		if occupied.has(seed_cell) or lava.has(seed_cell):
			continue
		var pool: Array[Vector2i] = [seed_cell]
		var want: int = randi_range(2, 4)
		var grow: int = 0
		while pool.size() < want and grow < 12:
			grow += 1
			var from: Vector2i = pool[randi() % pool.size()]
			var next: Vector2i = from + _DIRS4[randi() % 4]
			if _open(next) and not occupied.has(next) and not lava.has(next) \
					and not next in pool:
				pool.append(next)
		if pool.size() < 2:
			continue
		var trial: Dictionary = lava.duplicate()
		for c: Vector2i in pool:
			trial[c] = true
		if not _connected_without(trial):
			continue
		lava = trial
		for c: Vector2i in pool:
			trap_cells[c] = Level.HAZARD_LAVA
		_claim_run(pool, occupied)
		pools += 1


# Whether every cell the start reaches today it still reaches with `blocked`
# walled off. Measured against what is reachable now, not every open cell: a
# maze can carry an open pocket the start never reaches, and counting it made
# every pool look like it cut the floor in two.
func _connected_without(blocked: Dictionary) -> bool:
	var before: Dictionary = _reach_from_start({})
	var after: Dictionary = _reach_from_start(blocked)
	for c: Vector2i in before:
		if not blocked.has(c) and not after.has(c):
			return false
	return true


func _reach_from_start(blocked: Dictionary) -> Dictionary:
	var seen: Dictionary = {player_start: true}
	var queue: Array[Vector2i] = [player_start]
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_back()
		for off: Vector2i in _DIRS4:
			var n: Vector2i = cur + off
			if _open(n) and not blocked.has(n) and not seen.has(n):
				seen[n] = true
				queue.append(n)
	return seen


# One or two linked pairs, both ends in dead ends. A teleporter is a tile you
# cannot walk across, so one standing in a corridor would wall off whatever lay
# past it; in a dead end it only ever adds a way through, never takes one away.
# The two ends of a pair are kept well apart, or it is not worth stepping on.
func _place_teleporters(occupied: Dictionary) -> void:
	var ends: Array[Vector2i] = []
	for y: int in maze.size():
		for x: int in (maze[y] as Array).size():
			var p: Vector2i = Vector2i(x, y)
			if not _open(p) or occupied.has(p):
				continue
			var ways: int = 0
			for off: Vector2i in _DIRS4:
				if _open(p + off):
					ways += 1
			if ways == 1:
				ends.append(p)
	ends.shuffle()
	var pair: int = 0
	while pair < 2 and ends.size() >= 2:
		var a: Vector2i = ends.pop_back()
		var best: int = -1
		for i: int in ends.size():
			var d: int = absi(ends[i].x - a.x) + absi(ends[i].y - a.y)
			if d >= 8 and (best < 0 or d > absi(ends[best].x - a.x) + absi(ends[best].y - a.y)):
				best = i
		if best < 0:
			continue
		var b: Vector2i = ends[best]
		ends.remove_at(best)
		trap_cells[a] = "%s:%d,%d:%d" % [Level.HAZARD_TELE, b.x, b.y, pair]
		trap_cells[b] = "%s:%d,%d:%d" % [Level.HAZARD_TELE, a.x, a.y, pair]
		pair += 1


