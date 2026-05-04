# Map 2 — a deeper dungeon with cold blue walls.
# Portal at (8,7) leads back to Map 1. Player arrives at (7,7) facing East.
#
# Verified path from (1,1) to exit (8,7):
#   (1,1)→S→(1,3)→E→(3,3)→N→(3,1)→E→(6,1)→S→(6,3)→W→(5,3)
#   →S→(5,5)→E→(8,5)→S→(8,7)
extends Level


func _ready() -> void:
	maze = [
		[1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
		[1, 0, 1, 0, 0, 0, 0, 1, 0, 1],
		[1, 0, 1, 0, 1, 1, 0, 1, 0, 1],
		[1, 0, 0, 0, 1, 0, 0, 0, 0, 1],
		[1, 1, 1, 1, 1, 0, 1, 1, 1, 1],
		[1, 0, 0, 0, 0, 0, 0, 0, 0, 1],
		[1, 0, 1, 1, 0, 1, 1, 1, 0, 1],
		[1, 0, 0, 1, 0, 0, 0, 0, 0, 1],
		[1, 1, 0, 1, 1, 1, 0, 1, 1, 1],
		[1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
	]

	# Cold blue palette — distinct from Map 1's warm stone
	wall_color  = Color(0.18, 0.25, 0.55)
	floor_color = Color(0.08, 0.10, 0.18)
	ceil_color  = Color(0.06, 0.08, 0.16)

	player_start        = Vector2i(1, 1)
	player_start_facing = 2  # South

	exit_pos     = Vector2i(8, 7)
	entry_pos    = Vector2i(7, 7)
	entry_facing = 1  # East — facing the portal

	next_scene = "res://scenes/map1.tscn"
