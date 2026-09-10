# Level
# Base class for all map data scripts. Holds the maze layout, visual colours,
# and the portal positions that main.gd reads during scene transitions.
# Each map script extends this and sets the fields in _ready().
class_name Level extends Node3D

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

# Traps: grid position → trap type ("spike" / "poison_vent" / "binding_rune").
# Erased by main.gd after the player triggers one.
var trap_cells: Dictionary = {}
