# Level
# Base class for all map data scripts. Holds the maze layout, visual colours,
# and the portal positions that main.gd reads during scene transitions.
# Each map script extends this and sets the fields in _ready().
class_name Level extends Node3D

# The whole run: two mazes, then a corridor with the boss at the end of it.
# Twenty floors, a boss closing every fifth. A boss floor is a straight
# corridor rather than a maze, so the last thing before the stairs is a fight
# you cannot walk around.
const FLOOR_COUNT: int = 20
const BOSS_EVERY:  int = 5


# Boss floors are the multiples of five; the run ends after the last one.
static func is_boss_floor(floor_num: int) -> bool:
	return floor_num % BOSS_EVERY == 0


# A warden stands in the middle of its band and nowhere else — floors 3, 8, 13
# and 18, one for each of the four of them. Every other maze floor leaves its
# key lying somewhere instead, so finding the way down is sometimes a fight and
# sometimes a search rather than the same errand sixteen times.
const WARDEN_OFFSET: int = 3


static func is_warden_floor(floor_num: int) -> bool:
	return not is_boss_floor(floor_num) and floor_num % BOSS_EVERY == WARDEN_OFFSET

# 2D maze layout: 1 = wall, 0 = open floor.
var maze: Array[Array] = []

# Wall / floor / ceiling colours — set per-map so each area looks distinct.
var wall_color: Color  = Color(0.42, 0.32, 0.22)
var floor_color: Color = Color(0.22, 0.20, 0.16)
var ceil_color: Color  = Color(0.16, 0.16, 0.20)

# Wireframe palette. The dungeon is drawn as edges, so these are the line
# colour and the translucent fill behind it — see Dungeon._build_geometry.
var wire_color: Color      = Color(0.55, 0.88, 1.00)
var wire_floor_color: Color = Color(0.35, 0.60, 0.75)
# Walls are opaque, and the fill has to sit clearly above the background or a
# wall face and the empty void render as the same black — which is exactly what
# makes "am I facing a wall?" unanswerable.
var wire_fill_color: Color = Color(0.075, 0.085, 0.115)
var wire_fill_alpha: float = 1.0

# Which floor this is. Set by Main on the instance BEFORE it enters the tree,
# because the level's own _ready runs inside add_child and needs it. It used to
# be read off get_parent(), which stopped working the moment the world moved
# into its own SubViewport — the parent became the viewport, the lookup
# returned nothing, and every floor quietly built as floor zero.
var floor_num: int = 1

# Where the player spawns when this map is first loaded (start of the game).
var player_start: Vector2i        = Vector2i(1, 1)
var player_start_facing: int      = 2  # South

# Where the player appears when arriving through the portal FROM the other map.
# Placed one step before the portal so the player can see it and choose to
# re-enter or explore instead.
var entry_pos: Vector2i    = Vector2i(7, 7)
var entry_facing: int      = 1  # East — facing the portal at (8,7)

# The portal tile. Stepping onto this cell triggers a scene transition.
var exit_pos:      Vector2i = Vector2i(-1, -1)
# Wall cell adjacent to exit_pos — the glowing panel is rendered here.
var exit_wall_pos: Vector2i = Vector2i(-1, -1)

# Path to the scene file loaded when the player steps through the portal.
var next_scene: String     = ""

# The warden: one stationary demon that holds this floor's key. The door on
# does not open until it is beaten. (-1,-1) on the boss floor, which has none.
var warden_pos: Vector2i = Vector2i(-1, -1)

# The key lying loose on a floor that has no warden, and whether it has been
# picked up. (-1,-1) on a floor whose key is carried by something instead.
var key_pos: Vector2i = Vector2i(-1, -1)
var key_taken: bool = false

# Traps the player has actually set off. The map draws these and nothing else:
# a trap you have not stepped on is not a thing you know about.
var found_traps: Dictionary = {}

# Save orbs. Standing on one opens the orb: the only place a run can be saved,
# and the only place gold buys anything.
var orb_cells: Array[Vector2i] = []

# Caches cut into the walls. The key is the WALL cell the cache sits inside;
# the value is the floor cell you have to be standing on to reach it, so
# walking into that wall from that side opens it instead of bumping. A cache
# that has been emptied stays in the dictionary and moves into `looted`, so
# the recess is still drawn and still reads as somewhere you have been.
var chest_cells: Dictionary = {}
var looted: Dictionary = {}

# The subset of chest_cells that are not chests. Keyed the same way, so a cache
# is looked up once and its nature answered by a second lookup — nothing about
# the recess itself gives it away, which is the whole point of the thing.
var mimic_cells: Dictionary = {}

# Traps: grid position → trap type ("spike" / "poison_vent" / "binding_rune").
# Erased by main.gd after the player triggers one.
var trap_cells: Dictionary = {}
