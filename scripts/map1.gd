# Map 1 — the starting dungeon with warm stone walls.
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


# Iterative recursive-backtracker on a 50x50 grid.
# Rooms occupy odd coordinates (1,3,...,47) — 24 per side.
# Every room is reachable; no loops; border stays solid wall.
func _generate_maze() -> Array[Array]:
	const SIZE: int  = 50
	const ROOMS: int = 24

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

	return grid
