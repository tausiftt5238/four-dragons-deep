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
var exit_pos:  Vector2i = Vector2i(-1, -1)
# The warden's cell while it still holds the key; (-1,-1) once it is beaten.
var warden_pos: Vector2i = Vector2i(-1, -1)

# Every save orb on this floor. Drawn only once the cell has been walked, like
# the portal: an orb you have not found yet is the thing you are looking for,
# but an orb you HAVE found is somewhere you need to be able to get back to,
# and remembering that is the map's job rather than the player's.
var orb_cells: Array[Vector2i] = []

# Draw the entire floor scaled to fit, rather than a window around the player.
# The upper pane has room for a 20x20 maze at eighteen pixels a cell, so the
# whole floor is visible at once instead of a ten-by-ten keyhole.
var whole_floor: bool = false

# Pixel size of each maze cell on the minimap.
const CELL_PX: int = 10

# Half-width of the view window in cells. The full window is VIEW_HALF*2 square.
const VIEW_HALF: int = 5

# Padding (px) between the map edge and the background rectangle border.
const PAD: int = 5

# Colour palette for the minimap elements.
const C_BG: Color     = Color(0.00, 0.00, 0.00, 0.78)  # Semi-transparent dark background
# Wall, floor and border are handed over by main.gd from the level's own wire
# palette, so the map is drawn in the same colours as the dungeon it describes
# — including the red of a boss corridor.
var wall_color:   Color = Color(0.20, 0.30, 0.36, 1.00)
var floor_color:  Color = Color(0.04, 0.04, 0.06, 1.00)
var border_color: Color = Color(0.55, 0.88, 1.00, 1.00)
const C_PLAYER: Color = Color(1.00, 0.82, 0.20, 1.00)  # Bright yellow player marker
const C_PORTAL: Color = Color(0.00, 0.82, 0.55, 1.00)  # Teal portal — matches the in-world exit glow
const C_WARDEN: Color = Color(0.66, 0.42, 1.00, 1.00)  # Violet warden — matches its cold fire
const C_ORB: Color    = Color(0.80, 0.96, 1.00, 1.00)  # Cold white orb — matches the shard in the world

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

	var cell: float = float(CELL_PX)
	var origin: Vector2i = player_pos - Vector2i(VIEW_HALF, VIEW_HALF)
	var view_c: int = VIEW_HALF * 2
	var view_r: int = VIEW_HALF * 2
	var map_w: float = view_c * cell + PAD * 2
	var map_h: float = view_r * cell + PAD * 2
	var ox: float = PAD
	var oy: float = PAD

	if whole_floor:
		# Fit the floor to the pane and centre it, square cells either way.
		map_w = size.x
		map_h = size.y
		cell = minf((map_w - PAD * 2) / float(cols), (map_h - PAD * 2) / float(rows))
		origin = Vector2i.ZERO
		view_c = cols
		view_r = rows
		ox = (map_w - cell * float(cols)) * 0.5
		oy = (map_h - cell * float(rows)) * 0.5

	draw_rect(Rect2(Vector2.ZERO, Vector2(map_w, map_h)), C_BG)

	for vr: int in range(view_r):
		for vc: int in range(view_c):
			var mc: int = origin.x + vc
			var mr: int = origin.y + vr
			if mr < 0 or mr >= rows or mc < 0:
				continue
			var row_data: Array = maze[mr] as Array
			if mc >= row_data.size():
				continue
			if not visited.has(Vector2i(mc, mr)):
				continue
			var c: Color = wall_color if row_data[mc] == 1 else floor_color
			draw_rect(Rect2(ox + vc * cell, oy + vr * cell,
					cell - maxf(1.0, cell * 0.08), cell - maxf(1.0, cell * 0.08)), c)

	# Portal, once the cell has been walked.
	if exit_pos.x >= 0 and visited.has(exit_pos):
		var pc: int = exit_pos.x - origin.x
		var pr: int = exit_pos.y - origin.y
		if pc >= 0 and pc < view_c and pr >= 0 and pr < view_r:
			draw_rect(Rect2(ox + pc * cell, oy + pr * cell,
					cell - 1.0, cell - 1.0), C_PORTAL)

	# The warden, while it still holds the key. Shown without needing the cell
	# visited — the floor's task is finding it, not stumbling on it.
	if warden_pos.x >= 0:
		var wc: int = warden_pos.x - origin.x
		var wr: int = warden_pos.y - origin.y
		if wc >= 0 and wc < view_c and wr >= 0 and wr < view_r:
			draw_rect(Rect2(ox + wc * cell, oy + wr * cell,
					cell - 1.0, cell - 1.0), C_WARDEN)

	# Orbs, drawn as discs rather than squares so they cannot be mistaken for
	# the portal or the warden at a glance.
	for orb: Vector2i in orb_cells:
		if not visited.has(orb):
			continue
		var oc: int = orb.x - origin.x
		var orow: int = orb.y - origin.y
		if oc < 0 or oc >= view_c or orow < 0 or orow >= view_r:
			continue
		draw_circle(Vector2(ox + (oc + 0.5) * cell, oy + (orow + 0.5) * cell),
				cell * 0.34, C_ORB)

	# The player: centred in a window, in its own cell on a whole floor.
	var pcx: float = ox + (float(player_pos.x - origin.x) + 0.5) * cell
	var pcy: float = oy + (float(player_pos.y - origin.y) + 0.5) * cell
	if not whole_floor:
		pcx = PAD + VIEW_HALF * cell + cell * 0.5
		pcy = PAD + VIEW_HALF * cell + cell * 0.5
	var center: Vector2 = Vector2(pcx, pcy)
	var tip: Vector2 = center + FACING_DIR[player_facing] * (cell * 0.65)
	draw_circle(center, maxf(2.0, cell * 0.3), C_PLAYER)
	draw_line(center, tip, C_PLAYER, maxf(1.5, cell * 0.18))

	draw_rect(Rect2(Vector2.ZERO, Vector2(map_w, map_h)), border_color, false, 1.5)
