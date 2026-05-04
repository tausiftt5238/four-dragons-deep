# Map 1 — the starting dungeon with warm stone walls.
# Portal at (8,7) leads to Map 2. Player starts at (1,1) facing South.
extends Level


func _ready() -> void:
	maze = [
		[1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
		[1, 0, 0, 0, 1, 0, 0, 0, 0, 1],
		[1, 0, 1, 0, 1, 0, 1, 1, 0, 1],
		[1, 0, 1, 0, 0, 0, 0, 1, 0, 1],
		[1, 0, 1, 1, 1, 1, 0, 1, 0, 1],
		[1, 0, 0, 0, 0, 1, 0, 0, 0, 1],
		[1, 1, 1, 0, 1, 1, 1, 1, 0, 1],
		[1, 0, 0, 0, 0, 0, 0, 0, 0, 1],
		[1, 0, 1, 1, 1, 0, 1, 1, 1, 1],
		[1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
	]

	# Warm stone palette
	wall_color  = Color(0.42, 0.32, 0.22)
	floor_color = Color(0.22, 0.20, 0.16)
	ceil_color  = Color(0.16, 0.16, 0.20)

	player_start        = Vector2i(1, 1)
	player_start_facing = 2  # South

	exit_pos    = Vector2i(8, 7)
	entry_pos   = Vector2i(7, 7)
	entry_facing = 1  # East — facing the portal

	next_scene = "res://scenes/map2.tscn"
