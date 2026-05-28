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

# Optional pixel-art textures. When set, dungeon.gd uses these instead of plain colour.
var wall_texture: Texture2D  = null
var floor_texture: Texture2D = null

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

# Treasure chests: grid position → item Dictionary.
# Entries are erased by main.gd when the player picks them up.
var chest_items: Dictionary = {}

# Store entrance: the wall cell the player walks into, and the open floor cell
# in front of it where the glowing marker is placed.
var store_wall_pos:  Vector2i = Vector2i(-1, -1)
var store_entry_pos: Vector2i = Vector2i(-1, -1)

# Inn entrance: same layout as the store.
var rest_wall_pos:  Vector2i = Vector2i(-1, -1)
var rest_entry_pos: Vector2i = Vector2i(-1, -1)

# Traps: grid position → trap type ("spike" / "poison_vent" / "binding_rune").
# Erased by main.gd after the player triggers one.
var trap_cells: Dictionary = {}
