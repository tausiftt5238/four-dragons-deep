# Main
# Top-level game controller. Owns player state, camera, torch, and minimap.
# Delegates 3D geometry to Dungeon and map data to Level subclasses.
# On startup it loads Map 1; stepping on the portal cell triggers a level swap.
extends Node3D

const EYE_HEIGHT: float = 1.0

# Grid offsets for each facing direction (col delta, row delta).
# Index: 0=North(-Z)  1=East(+X)  2=South(+Z)  3=West(-X)
const DIR_OFFSET: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]

# Camera Y-axis rotation (radians) per facing index.
# Default camera looks towards -Z, so North (index 0) needs no rotation.
const FACING_ROT: Array[float] = [0.0, -PI / 2.0, PI, PI / 2.0]

var player_pos: Vector2i = Vector2i.ZERO
var player_facing: int   = 0

var cam_yaw: float  = 0.0  # continuous Y rotation — never wrapped, avoids shortest-path issues
var turn_tween: Tween

var floor_num: int = 1
var floor_label: Label

var cam: Camera3D
var torch: OmniLight3D
var minimap_ctrl: Minimap

# Canonical camera position — stored so _shake_camera always snaps back to the
# correct grid position even when called during a shake-in-progress.
var cam_base_pos: Vector3

# Per-map fog-of-war store. Keys are scene paths; values are the visited
# Dictionaries for that map. Persists across portal transitions so returning
# to a map restores its previous exploration state.
var visited_by_map: Dictionary = {}

# Reference to the active map's visited Dictionary. Reassigned on every level
# load and shared with minimap_ctrl so no copy is needed — queue_redraw() is
# enough to reflect any change.
var visited: Dictionary = {}

# Active level node and dungeon geometry node.
# Both are freed and rebuilt on every portal transition.
var current_level: Level
var dungeon: Dungeon


func _ready() -> void:
	# Camera and torch must exist before the first _sync_player call,
	# so set up the player nodes first.
	_setup_player_nodes()

	# Minimap must exist before _sync_player too (it writes to minimap_ctrl).
	_setup_minimap()

	# Load Map 1 as the starting level. _sync_player is called inside here.
	_load_level("res://scenes/map1.tscn", true)


# ── Level loading ────────────────────────────────────────────────────────────

# Loads a level scene, builds its dungeon, and places the player.
# first_load = true  → use level.player_start (beginning of the game)
# first_load = false → use level.entry_pos    (arriving through a portal)
func _load_level(scene_path: String, first_load: bool) -> void:
	# Free the previous dungeon and level if they exist
	if dungeon:
		dungeon.queue_free()
	if current_level:
		current_level.queue_free()

	# Instantiate the new level — _ready() on the level script runs inside
	# add_child(), so maze/colour data is available immediately after.
	var packed: PackedScene = load(scene_path) as PackedScene
	current_level = packed.instantiate() as Level
	add_child(current_level)

	# Build geometry using the level's colours and maze
	dungeon = Dungeon.new()
	add_child(dungeon)
	dungeon.build(current_level)

	# Place the player at the appropriate spawn point
	if first_load:
		player_pos    = current_level.player_start
		player_facing = current_level.player_start_facing
	else:
		player_pos    = current_level.entry_pos
		player_facing = current_level.entry_facing

	# Retrieve or create the visited dict for this map.
	# Using the scene path as key means each map remembers its own exploration
	# independently — returning through the portal restores the previous state.
	if not visited_by_map.has(scene_path):
		visited_by_map[scene_path] = {}
	visited = visited_by_map[scene_path]

	# Update minimap to the new map's data and its own visited reference.
	# The reference must be reassigned here because visited was just repointed.
	minimap_ctrl.maze     = current_level.maze
	minimap_ctrl.visited  = visited
	minimap_ctrl.exit_pos = current_level.exit_pos
	_resize_minimap()

	_sync_player()
	_snap_cam_yaw()


# ── One-time setup ───────────────────────────────────────────────────────────

# Creates the torch (OmniLight) and first-person camera.
# Called once at startup; both nodes persist across level transitions.
func _setup_player_nodes() -> void:
	torch = OmniLight3D.new()
	torch.light_color = Color(1.0, 0.72, 0.38)
	torch.light_energy = 3.0
	torch.omni_range   = 9.0
	add_child(torch)

	cam = Camera3D.new()
	add_child(cam)


# Creates the CanvasLayer and Minimap control, anchored to the top-right corner.
# The minimap size is recalculated whenever a new level is loaded via _resize_minimap().
func _setup_minimap() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 10  # Renders above all 3D content
	add_child(layer)

	minimap_ctrl = Minimap.new()
	minimap_ctrl.visited = visited  # Shared reference — no copy needed
	layer.add_child(minimap_ctrl)

	floor_label = Label.new()
	floor_label.text = "Floor 1"
	floor_label.anchor_left   = 0.0
	floor_label.anchor_right  = 1.0
	floor_label.anchor_top    = 0.0
	floor_label.anchor_bottom = 0.0
	floor_label.offset_top    = 10.0
	floor_label.offset_bottom = 40.0
	floor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.add_child(floor_label)


# Updates the minimap Control's anchors and offsets to fit the current maze size.
# Called after every level load because maps can differ in dimensions.
func _resize_minimap() -> void:
	var view: int = Minimap.VIEW_HALF * 2
	var map_w: float = Minimap.CELL_PX * view + Minimap.PAD * 2
	var map_h: float = Minimap.CELL_PX * view + Minimap.PAD * 2
	var margin: float = 10.0

	# Both horizontal anchors = 1 pins the right edge to the viewport right edge;
	# offsets pull the control left and down by the map size + margin.
	minimap_ctrl.anchor_left   = 1.0
	minimap_ctrl.anchor_right  = 1.0
	minimap_ctrl.anchor_top    = 0.0
	minimap_ctrl.anchor_bottom = 0.0
	minimap_ctrl.offset_left   = -(map_w + margin)
	minimap_ctrl.offset_right  = -margin
	minimap_ctrl.offset_top    = margin
	minimap_ctrl.offset_bottom = margin + map_h


# ── Per-frame / movement ─────────────────────────────────────────────────────

# Marks the 3×3 area around the player as visited.
# The extra ring reveals adjacent walls so the player always has context.
func _mark_visited() -> void:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			visited[player_pos + Vector2i(dx, dy)] = true


# Moves camera, torch, and minimap marker to match the current player state.
# Called at startup and after every move or turn.
func _sync_player() -> void:
	var pos: Vector3 = Vector3(
		player_pos.x * Dungeon.CELL_SIZE,
		EYE_HEIGHT,
		player_pos.y * Dungeon.CELL_SIZE
	)
	cam_base_pos   = pos
	cam.position   = pos
	torch.position = pos + Vector3(0.0, 0.3, 0.0)
	_mark_visited()
	minimap_ctrl.player_pos    = player_pos
	minimap_ctrl.player_facing = player_facing
	minimap_ctrl.queue_redraw()


# Snaps camera rotation to the current facing with no animation. Used on level load.
func _snap_cam_yaw() -> void:
	cam_yaw = FACING_ROT[player_facing]
	cam.rotation = Vector3(0.0, cam_yaw, 0.0)


# Smoothly rotates the camera by delta_yaw radians. Kills any in-progress turn first.
func _tween_turn(delta_yaw: float) -> void:
	cam_yaw += delta_yaw
	if turn_tween:
		turn_tween.kill()
	turn_tween = create_tween()
	turn_tween.tween_property(cam, "rotation:y", cam_yaw, 0.12)


# Returns true if (col, row) is within bounds and not a wall.
func _is_open(col: int, row: int) -> bool:
	if row < 0 or row >= current_level.maze.size() or col < 0:
		return false
	var row_data: Array = current_level.maze[row]
	if col >= row_data.size():
		return false
	return row_data[col] == 0


# Checks whether the player is standing on the portal tile and, if so,
# transitions to the next level. Called after every successful move.
func _check_portal() -> void:
	if current_level.next_scene != "" and player_pos == current_level.exit_pos:
		floor_num += 1
		floor_label.text = "Floor %d" % floor_num
		visited_by_map.erase(current_level.next_scene)
		_load_level(current_level.next_scene, true)


# Jolts the camera with quick random offsets then snaps back to base.
# Uses cam_base_pos so rapid wall-bumps always return to the correct position.
func _shake_camera() -> void:
	var tween: Tween = create_tween()
	var intensity: float = 0.07
	var step: float = 0.04
	for i in range(5):
		var offset: Vector3 = Vector3(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity),
			0.0
		)
		tween.tween_property(cam, "position", cam_base_pos + offset, step)
	tween.tween_property(cam, "position", cam_base_pos, step)


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	var moved: bool = false
	match event.keycode:
		KEY_UP:
			var nxt: Vector2i = player_pos + DIR_OFFSET[player_facing]
			if _is_open(nxt.x, nxt.y):
				player_pos = nxt
				moved = true
			else:
				_shake_camera()
		KEY_DOWN:
			var nxt: Vector2i = player_pos - DIR_OFFSET[player_facing]
			if _is_open(nxt.x, nxt.y):
				player_pos = nxt
				moved = true
			else:
				_shake_camera()
		KEY_LEFT:
			player_facing = (player_facing + 3) % 4
			_tween_turn(PI / 2.0)
			minimap_ctrl.player_facing = player_facing
			minimap_ctrl.queue_redraw()
		KEY_RIGHT:
			player_facing = (player_facing + 1) % 4
			_tween_turn(-PI / 2.0)
			minimap_ctrl.player_facing = player_facing
			minimap_ctrl.queue_redraw()
	if moved:
		_sync_player()
		_check_portal()
