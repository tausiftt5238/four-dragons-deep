# Minimap
# A 2D HUD overlay that draws a top-down view of the maze.
# Rendered as a Control node inside a CanvasLayer so it always appears
# on top of the 3D scene. Call queue_redraw() whenever the player moves
# or turns to trigger a repaint.
class_name Minimap extends Control

# Maze data and player state are set by main.gd before the first draw.
var maze: Array[Array] = []
var player_pos: Vector2i = Vector2i.ZERO
var player_facing: int = 0

# Shared reference from main.gd. Keys are Vector2i grid positions that have
# been revealed. Only cells present here are drawn; everything else stays dark.
var visited: Dictionary = {}

# Grid position of the portal tile. Drawn with a distinct teal colour so the
# player can spot it on the map once the cell has been explored.
# Set to (-1,-1) when no exit has been assigned yet.
var exit_pos: Vector2i = Vector2i(-1, -1)

# Pixel size of each maze cell on the minimap.
const CELL_PX: int = 10

# Padding (px) between the map edge and the background rectangle border.
const PAD: int = 5

# Colour palette for the minimap elements.
const C_BG: Color     = Color(0.00, 0.00, 0.00, 0.78)  # Semi-transparent dark background
const C_BORDER: Color = Color(0.55, 0.45, 0.28, 1.00)  # Stone-coloured border drawn last so it sits on top
const C_WALL: Color   = Color(0.46, 0.34, 0.22, 1.00)  # Brown walls
const C_FLOOR: Color  = Color(0.13, 0.12, 0.10, 1.00)  # Near-black open floor
const C_PLAYER: Color = Color(1.00, 0.82, 0.20, 1.00)  # Bright yellow player marker
const C_PORTAL: Color = Color(0.00, 0.82, 0.55, 1.00)  # Teal portal — matches the in-world exit glow

# 2D unit vectors for each facing direction, used to draw the direction arrow.
# Order must match the facing constants in main.gd:
# 0=North(-Z)  1=East(+X)  2=South(+Z)  3=West(-X)
# Note: on the minimap +Y is down, so North (world -Z) points up (-Y here).
const FACING_DIR: Array[Vector2] = [
	Vector2( 0.0, -1.0),  # North
	Vector2( 1.0,  0.0),  # East
	Vector2( 0.0,  1.0),  # South
	Vector2(-1.0,  0.0),  # West
]


# Godot calls _draw() automatically when the Control is first shown and
# whenever queue_redraw() is called. All drawing must happen inside here.
func _draw() -> void:
	if maze.is_empty():
		return

	var rows: int = maze.size()
	var cols: int = (maze[0] as Array).size()

	# Total pixel size of the map area including padding on all sides.
	var map_w: float = cols * CELL_PX + PAD * 2
	var map_h: float = rows * CELL_PX + PAD * 2

	# Background panel
	draw_rect(Rect2(Vector2.ZERO, Vector2(map_w, map_h)), C_BG)

	# Draw every revealed cell as a small rectangle. A 1px gap between cells
	# (CELL_PX - 1) creates a subtle grid that makes individual tiles easier to read.
	# Unvisited cells are skipped — they blend into the dark background panel.
	for row in range(rows):
		var row_data: Array = maze[row]
		for col in range(row_data.size()):
			if not visited.has(Vector2i(col, row)):
				continue
			var rx: float = PAD + col * CELL_PX
			var ry: float = PAD + row * CELL_PX
			var c: Color = C_WALL if row_data[col] == 1 else C_FLOOR
			draw_rect(Rect2(rx, ry, CELL_PX - 1, CELL_PX - 1), c)

	# Portal marker — drawn over the floor tile so it's visible as soon as
	# the cell is revealed. Skipped if exit_pos is the sentinel (-1,-1).
	if exit_pos.x >= 0 and visited.has(exit_pos):
		var rx: float = PAD + exit_pos.x * CELL_PX
		var ry: float = PAD + exit_pos.y * CELL_PX
		draw_rect(Rect2(rx, ry, CELL_PX - 1, CELL_PX - 1), C_PORTAL)

	# Player marker: a filled circle at the cell centre with a short line
	# extending in the facing direction so the player can tell which way they face.
	var cx: float = PAD + player_pos.x * CELL_PX + CELL_PX * 0.5
	var cy: float = PAD + player_pos.y * CELL_PX + CELL_PX * 0.5
	var center: Vector2 = Vector2(cx, cy)
	var tip: Vector2 = center + FACING_DIR[player_facing] * (CELL_PX * 0.65)
	draw_circle(center, 3.0, C_PLAYER)
	draw_line(center, tip, C_PLAYER, 2.0)

	# Border drawn after cells so it overlaps any edge bleed from cell rects.
	draw_rect(Rect2(Vector2.ZERO, Vector2(map_w, map_h)), C_BORDER, false, 1.5)
