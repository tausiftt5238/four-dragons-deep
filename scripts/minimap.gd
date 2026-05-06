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

# Half-width of the view window in cells. The full window is VIEW_HALF*2 square.
const VIEW_HALF: int = 5

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

	var view: int = VIEW_HALF * 2
	var map_w: float = view * CELL_PX + PAD * 2
	var map_h: float = view * CELL_PX + PAD * 2

	draw_rect(Rect2(Vector2.ZERO, Vector2(map_w, map_h)), C_BG)

	# Top-left maze cell of the view window.
	var origin: Vector2i = player_pos - Vector2i(VIEW_HALF, VIEW_HALF)

	for vr: int in range(view):
		for vc: int in range(view):
			var mc: int = origin.x + vc
			var mr: int = origin.y + vr
			# Skip out-of-bounds and unvisited cells.
			if mr < 0 or mr >= maze.size() or mc < 0:
				continue
			var row_data: Array = maze[mr] as Array
			if mc >= row_data.size():
				continue
			if not visited.has(Vector2i(mc, mr)):
				continue
			var rx: float = PAD + vc * CELL_PX
			var ry: float = PAD + vr * CELL_PX
			var c: Color = C_WALL if row_data[mc] == 1 else C_FLOOR
			draw_rect(Rect2(rx, ry, CELL_PX - 1, CELL_PX - 1), c)

	# Portal marker within the view window.
	if exit_pos.x >= 0 and visited.has(exit_pos):
		var vc: int = exit_pos.x - origin.x
		var vr: int = exit_pos.y - origin.y
		if vc >= 0 and vc < view and vr >= 0 and vr < view:
			draw_rect(Rect2(PAD + vc * CELL_PX, PAD + vr * CELL_PX, CELL_PX - 1, CELL_PX - 1), C_PORTAL)

	# Player is always at the centre of the window.
	var cx: float = PAD + VIEW_HALF * CELL_PX + CELL_PX * 0.5
	var cy: float = PAD + VIEW_HALF * CELL_PX + CELL_PX * 0.5
	var center: Vector2 = Vector2(cx, cy)
	var tip: Vector2 = center + FACING_DIR[player_facing] * (CELL_PX * 0.65)
	draw_circle(center, 3.0, C_PLAYER)
	draw_line(center, tip, C_PLAYER, 2.0)

	draw_rect(Rect2(Vector2.ZERO, Vector2(map_w, map_h)), C_BORDER, false, 1.5)
