# Map — the dungeon level with warm stone walls.
# Player starts at (1,1) facing South. Maze is procedurally generated on load.
extends Level


func _ready() -> void:
	maze = _generate_maze()

	# Warm stone palette
	wall_color  = Color(0.42, 0.32, 0.22)
	floor_color = Color(0.22, 0.20, 0.16)
	ceil_color  = Color(0.16, 0.16, 0.20)

	wall_texture  = load("res://resources/mapAsset/level_1_wall_1.png")
	floor_texture = load("res://resources/mapAsset/level_1_floor_1.png")

	player_start        = Vector2i(1, 1)
	player_start_facing = 2  # South

	var exit_pair: Dictionary = _random_frontier_wall({player_start: true})
	exit_wall_pos = exit_pair["wall"]
	exit_pos      = exit_pair["floor"]
	next_scene    = "res://scenes/map.tscn"
	_place_chests()
	_place_store()
	_place_rest()


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


# Scatters 4–5 treasure chests at random reachable cells, avoiding the
# player start and portal exit. Each chest holds one random item.
func _place_chests() -> void:
	const COUNT: int = 5
	var occupied: Dictionary = {exit_pos: true}
	var attempts: int = 0
	var placed:   int = 0
	while placed < COUNT and attempts < 60:
		attempts += 1
		var pos: Vector2i = _random_reachable_cell(maze, player_start)
		if occupied.has(pos):
			continue
		occupied[pos] = true
		chest_items[pos] = _random_loot()
		placed += 1


# Flood-fills from player_start and returns a random {wall, floor} pair where
# floor is a reachable open cell not in excluded_floors, and wall is an
# interior wall cell orthogonally adjacent to floor.
# Guaranteed to find a result in any well-formed 20×20 maze.
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


func _place_store() -> void:
	var excluded: Dictionary = {player_start: true, exit_pos: true, exit_wall_pos: true}
	for cp: Variant in chest_items.keys():
		excluded[cp] = true
	var pair: Dictionary = _random_frontier_wall(excluded)
	store_wall_pos  = pair["wall"] as Vector2i
	store_entry_pos = pair["floor"] as Vector2i


func _place_rest() -> void:
	var excluded: Dictionary = {
		player_start: true, exit_pos: true, exit_wall_pos: true,
		store_wall_pos: true, store_entry_pos: true,
	}
	for cp: Variant in chest_items.keys():
		excluded[cp] = true
	var pair: Dictionary = _random_frontier_wall(excluded)
	rest_wall_pos  = pair["wall"] as Vector2i
	rest_entry_pos = pair["floor"] as Vector2i


func _random_loot() -> Dictionary:
	var roll: int = randi() % 100
	if   roll < 16: return Item.health_potion()
	elif roll < 28: return Item.hi_potion()
	elif roll < 38: return Item.ether()
	elif roll < 44: return Item.antidote()
	elif roll < 49: return Item.stimulant()
	elif roll < 53: return Item.echo_gem()
	elif roll < 56: return Item.elixir_motion()
	elif roll < 63: return Item.scroll_venom()
	elif roll < 69: return Item.scroll_shock()
	elif roll < 74: return Item.scroll_mute()
	elif roll < 78: return Item.scroll_bind()
	elif roll < 84: return Weapon.iron_sword()
	elif roll < 89: return Weapon.battle_axe()
	elif roll < 93: return Weapon.magic_rod()
	elif roll < 97: return Armor.leather_vest()
	elif roll < 99: return Armor.chain_mail()
	else:           return Armor.plate_armor()
