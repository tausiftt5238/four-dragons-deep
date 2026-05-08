# Map — the dungeon level with warm stone walls.
# Player starts at (1,1) facing South. Maze is procedurally generated on load.
extends Level


func _ready() -> void:
	maze = _generate_maze()

	# Warm stone palette
	wall_color  = Color(0.42, 0.32, 0.22)
	floor_color = Color(0.22, 0.20, 0.16)
	ceil_color  = Color(0.16, 0.16, 0.20)

	player_start        = Vector2i(1, 1)
	player_start_facing = 2  # South

	exit_pos   = _random_reachable_cell(maze, player_start)
	next_scene = "res://scenes/map.tscn"
	_place_chests()


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


func _random_loot() -> Dictionary:
	var roll: int = randi() % 100
	if   roll < 22: return Item.health_potion()
	elif roll < 38: return Item.hi_potion()
	elif roll < 52: return Item.ether()
	elif roll < 62: return Weapon.iron_sword()
	elif roll < 70: return Weapon.battle_axe()
	elif roll < 78: return Weapon.magic_rod()
	elif roll < 87: return Armor.leather_vest()
	elif roll < 94: return Armor.chain_mail()
	else:           return Armor.plate_armor()
