# Main
# Top-level game controller. Owns player state, camera, torch, and minimap.
# Delegates 3D geometry to Dungeon and map data to Level subclasses.
# On startup it loads Map 1; stepping on the portal cell triggers a level swap.
class_name Main extends Node3D

const EYE_HEIGHT: float = 1.0
const _UI_FONT := preload("res://resources/misc/OldSchoolAdventures-42j9.ttf") as FontFile

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

# The camera hangs off a rig at the cell centre. The rig carries the position
# and the yaw; the camera sits a little way back along its own +Z, so turning
# swings the viewpoint around the cell instead of pivoting on the lens. Standing
# dead centre put a faced wall so close that its edges fell outside the frame.
const CAM_PULLBACK: float = 0.40
const CAM_FOV:      float = 90.0
var cam_rig: Node3D
var cam: Camera3D

# ── The two panes ─────────────────────────────────────────────────────────────
#
# Held upright, one tall view is the wrong shape for a grid crawler: the 90°
# field of view is vertical, so a 540x1170 window leaves about 50° across and
# you cannot see a side opening until you are standing in it. The screen splits
# instead — the floor map above, the dungeon below — which gives the 3D a pane
# nearer 4:3 and puts the part you swipe within reach of a thumb.
const MAP_PANE_H: int = 520

var world: SubViewport
var _world_box: SubViewportContainer
var torch: OmniLight3D
var minimap_ctrl: Minimap
var hud_layer: CanvasLayer       # CanvasLayer holding the minimap; hidden during combat

var player_char: PlayerCharacter  # RPG stats — persists across encounters and floors
var in_combat:  bool = false
var menu_open:  bool = false
var save_open:  bool = false
var orb_open:   bool = false
var chest_open: bool = false

var _encounters_enabled:       bool = true

# Demons walking this floor. They step when the player steps; sharing a cell
# with one starts a battle.
var roamers: Array[Roamer] = []
# Every roamer that walked into this battle. They chase, so more than one can
# land on the same cell — taking only the first left the others sitting on top
# of the player, which read as the sphere never disappearing.
var _engaged: Array[Roamer] = []
# Steps taken since the last replacement, so a cleared floor slowly refills.
var _steps_since_spawn: int = 0
const _RESPAWN_STEPS: int = 25

# The floor's warden and whether it has been beaten. The door stays shut until
# it has, so every maze floor has one thing that must be found.
var _warden: Roamer = null
var _has_key: bool  = false
# Set once the boss at the end of the corridor is down.
var _boss_beaten: bool = false
var _pending_congratulations:  bool = false

var _swipe_start:  Vector2 = Vector2.ZERO
var _swipe_active: bool    = false
const _SWIPE_MIN:  float   = 60.0
var _encounter_debug_lbl: Label
var menu_layer:    CanvasLayer
var save_layer:    CanvasLayer
var orb_layer:     CanvasLayer
var chest_layer:   CanvasLayer
var overlay_layer: CanvasLayer  # Layer 25 — level-up and game-over screens

var _orb_btn:         Button  # "Save", shown only while standing on an orb
var _hud_popup:       Label   # brief centred notice in the HUD (traps, poison)
var _hud_popup_tween: Tween

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


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if not in_combat:
			if save_open:
				_close_save_layer()
			elif orb_open:
				_close_orb()
			elif menu_open:
				_close_menu()
			else:
				_open_menu()


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)

	# The world pane has to exist before anything three-dimensional, since
	# everything 3D is parented into it rather than onto Main.
	_setup_world_pane()

	# Camera and torch must exist before the first _sync_player call,
	# so set up the player nodes first.
	_setup_player_nodes()

	# Minimap must exist before _sync_player too (it writes to minimap_ctrl).
	_setup_minimap()

	# Create the player's persistent RPG character.
	player_char = PlayerCharacter.new()
	add_child(player_char)

	# Load Map 1 as the starting level. _sync_player is called inside here.
	_load_level("res://scenes/map.tscn", true)

	if GameBoot.pending_slot > 0:
		var slot: int = GameBoot.pending_slot
		GameBoot.pending_slot = 0
		call_deferred("_do_load", slot)
	else:
		player_pos    = current_level.player_start
		player_facing = current_level.player_start_facing
		_sync_player()
		_snap_cam_yaw()


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
	# Set before it enters the tree: the level builds itself in _ready, and it
	# cannot ask its parent what floor it is any more.
	current_level.floor_num = floor_num
	world.add_child(current_level)

	# Build geometry using the level's colours and maze
	dungeon = Dungeon.new()
	world.add_child(dungeon)
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
	minimap_ctrl.maze      = current_level.maze
	minimap_ctrl.visited   = visited
	minimap_ctrl.exit_pos  = current_level.exit_wall_pos
	minimap_ctrl.orb_cells   = current_level.orb_cells
	minimap_ctrl.chest_cells = current_level.chest_cells
	minimap_ctrl.looted      = current_level.looted
	minimap_ctrl.found_traps = current_level.found_traps
	_sync_minimap_palette()
	_resize_minimap()

	_sync_player()
	_snap_cam_yaw()
	_spawn_roamers()


# ── One-time setup ───────────────────────────────────────────────────────────

# Creates the torch (OmniLight) and first-person camera.
# Called once at startup; both nodes persist across level transitions.
# The lower pane. Everything three-dimensional lives inside it, so the map
# above is not painted over the middle of the view.
func _setup_world_pane() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 0
	add_child(layer)

	_world_box = SubViewportContainer.new()
	_world_box.stretch = true
	_world_box.anchor_left   = 0.0
	_world_box.anchor_right  = 1.0
	_world_box.anchor_top    = 0.0
	_world_box.anchor_bottom = 1.0
	_world_box.offset_top    = MAP_PANE_H
	_world_box.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_world_box)

	world = SubViewport.new()
	world.handle_input_locally = false
	world.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	world.transparent_bg = false
	_world_box.add_child(world)


func _setup_player_nodes() -> void:
	torch = OmniLight3D.new()
	torch.light_color = Color(1.0, 0.72, 0.38)
	torch.light_energy = 3.0
	torch.omni_range   = 9.0
	world.add_child(torch)

	cam_rig = Node3D.new()
	world.add_child(cam_rig)

	cam = Camera3D.new()
	cam.fov      = CAM_FOV
	cam.position = Vector3(0.0, 0.0, CAM_PULLBACK)
	cam_rig.add_child(cam)


# Creates the CanvasLayer and Minimap control, anchored to the top-right corner.
# The minimap size is recalculated whenever a new level is loaded via _resize_minimap().
func _setup_minimap() -> void:
	hud_layer = CanvasLayer.new()
	hud_layer.layer = 10  # Renders above all 3D content
	add_child(hud_layer)
	var layer: CanvasLayer = hud_layer

	minimap_ctrl = Minimap.new()
	minimap_ctrl.visited = visited  # Shared reference — no copy needed
	minimap_ctrl.whole_floor = true
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

	_hud_popup = Label.new()
	_hud_popup.anchor_left   = 0.0
	_hud_popup.anchor_right  = 1.0
	_hud_popup.anchor_top    = 1.0
	_hud_popup.anchor_bottom = 1.0
	_hud_popup.offset_top    = -80.0
	_hud_popup.offset_bottom = -46.0
	_hud_popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_popup.add_theme_color_override("font_color", Color(1.0, 0.88, 0.28))
	_hud_popup.modulate.a = 0.0
	layer.add_child(_hud_popup)

	_encounter_debug_lbl = Label.new()
	_encounter_debug_lbl.anchor_left   = 0.0
	_encounter_debug_lbl.anchor_right  = 0.0
	_encounter_debug_lbl.anchor_top    = 0.0
	_encounter_debug_lbl.anchor_bottom = 0.0
	_encounter_debug_lbl.offset_left   = 10.0
	_encounter_debug_lbl.offset_right  = 260.0
	_encounter_debug_lbl.offset_top    = 10.0
	_encounter_debug_lbl.offset_bottom = 34.0
	_encounter_debug_lbl.add_theme_font_size_override("font_size", 13)
	_update_encounter_debug_label()
	layer.add_child(_encounter_debug_lbl)

	# Bottom right, over the dungeon view. It used to sit in the top-left
	# corner, which the floor map now owns — and the bottom of an upright
	# screen is where a thumb already is.
	var menu_btn: Button = Button.new()
	menu_btn.text          = "Menu"
	menu_btn.anchor_left   = 1.0
	menu_btn.anchor_right  = 1.0
	menu_btn.anchor_top    = 1.0
	menu_btn.anchor_bottom = 1.0
	menu_btn.offset_left   = -122.0
	menu_btn.offset_right  = -14.0
	menu_btn.offset_top    = -74.0
	menu_btn.offset_bottom = -14.0
	menu_btn.pressed.connect(_on_menu_btn_pressed)
	layer.add_child(menu_btn)

	# Directly above Menu, and only while the player is standing on an orb.
	# Stepping onto the tile opens the orb once; without this, leaving that
	# panel meant walking off the tile and back on to reach it again.
	_orb_btn = Button.new()
	_orb_btn.text          = "Save"
	_orb_btn.anchor_left   = 1.0
	_orb_btn.anchor_right  = 1.0
	_orb_btn.anchor_top    = 1.0
	_orb_btn.anchor_bottom = 1.0
	_orb_btn.offset_left   = -122.0
	_orb_btn.offset_right  = -14.0
	_orb_btn.offset_top    = -142.0
	_orb_btn.offset_bottom = -82.0
	_orb_btn.visible       = false
	_orb_btn.pressed.connect(func() -> void:
		if not (in_combat or menu_open or save_open or orb_open or chest_open):
			_open_orb("save"))
	layer.add_child(_orb_btn)

	# Push debug label below the MENU button
	_encounter_debug_lbl.offset_top    = 70.0
	_encounter_debug_lbl.offset_bottom = 94.0


# The map is drawn in the dungeon's own colours: wall faces lifted enough to
# read at 10 px a cell, floor the same void the walls stand in.
func _sync_minimap_palette() -> void:
	# All three come off the level's wire hue, so the map turns red in a boss
	# corridor along with the walls. Floor has to stay clearly above the
	# unexplored black or a walked corridor reads as fog.
	minimap_ctrl.wall_color   = current_level.wire_color.darkened(0.62)
	minimap_ctrl.floor_color  = current_level.wire_color.darkened(0.86)
	minimap_ctrl.border_color = current_level.wire_color


# Updates the minimap Control's anchors and offsets to fit the current maze size.
# Called after every level load because maps can differ in dimensions.
# The map owns the upper pane outright: full width, from under the floor
# label down to where the dungeon view begins.
func _resize_minimap() -> void:
	const TOP: float = 40.0
	minimap_ctrl.anchor_left   = 0.0
	minimap_ctrl.anchor_right  = 1.0
	minimap_ctrl.anchor_top    = 0.0
	minimap_ctrl.anchor_bottom = 0.0
	minimap_ctrl.offset_left   = 0.0
	minimap_ctrl.offset_right  = 0.0
	minimap_ctrl.offset_top    = TOP
	minimap_ctrl.offset_bottom = float(MAP_PANE_H)


# ── Per-frame / movement ─────────────────────────────────────────────────────

# Marks the cell underfoot and the four it touches. Diagonals stay dark — the
# old 3x3 handed over the corners of junctions before you had reached them,
# which drew most of the maze from a corridor.
func _mark_visited() -> void:
	visited[player_pos] = true
	for off: Vector2i in DIR_OFFSET:
		visited[player_pos + off] = true


# Moves camera, torch, and minimap marker to match the current player state.
# Called at startup and after every move or turn.
func _sync_player() -> void:
	var pos: Vector3 = Vector3(
		player_pos.x * Dungeon.CELL_SIZE,
		EYE_HEIGHT,
		player_pos.y * Dungeon.CELL_SIZE
	)
	cam_base_pos     = pos
	cam_rig.position = pos
	torch.position = pos + Vector3(0.0, 0.3, 0.0)
	_mark_visited()
	minimap_ctrl.player_pos    = player_pos
	minimap_ctrl.player_facing = player_facing
	minimap_ctrl.queue_redraw()
	_refresh_orb_btn()


# The orb shortcut follows the player's feet, so every move re-asks.
func _refresh_orb_btn() -> void:
	if not is_instance_valid(_orb_btn):
		return
	_orb_btn.visible = is_instance_valid(current_level) \
			and player_pos in current_level.orb_cells


# Snaps camera rotation to the current facing with no animation. Used on level load.
func _snap_cam_yaw() -> void:
	cam_yaw = FACING_ROT[player_facing]
	cam_rig.rotation = Vector3(0.0, cam_yaw, 0.0)


# Smoothly rotates the camera by delta_yaw radians. Kills any in-progress turn first.
func _tween_turn(delta_yaw: float) -> void:
	cam_yaw += delta_yaw
	if turn_tween:
		turn_tween.kill()
	turn_tween = create_tween()
	turn_tween.tween_property(cam_rig, "rotation:y", cam_yaw, 0.12)


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
	# On a boss floor the far end of the corridor is the boss, not a door. Beat
	# it and the corridor opens onward — except on the last floor of all, where
	# beating it is the end of the run.
	if Level.is_boss_floor(floor_num):
		if not _boss_beaten:
			_start_boss_combat()
			return
		if floor_num >= Level.FLOOR_COUNT:
			return

	if not _has_key:
		_show_hud_popup("The door is sealed. Find the warden.", Color(0.75, 0.55, 1.0))
		_shake_camera()
		return

	if current_level.next_scene == "":
		return
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
		tween.tween_property(cam_rig, "position", cam_base_pos + offset, step)
	tween.tween_property(cam_rig, "position", cam_base_pos, step)


func _action_forward() -> void:
	var nxt: Vector2i = player_pos + DIR_OFFSET[player_facing]
	if _is_open(nxt.x, nxt.y):
		player_pos = nxt
		_post_move()
	elif nxt == current_level.exit_wall_pos and player_pos == current_level.exit_pos:
		_check_portal()
	elif current_level.chest_cells.get(nxt, Vector2i(-1, -1)) == player_pos \
			and not current_level.looted.has(nxt):
		_open_chest(nxt)
	else:
		_shake_camera()


func _action_back() -> void:
	var nxt: Vector2i = player_pos - DIR_OFFSET[player_facing]
	if _is_open(nxt.x, nxt.y):
		player_pos = nxt
		_post_move()
	else:
		_shake_camera()


func _action_turn_left() -> void:
	player_facing = (player_facing + 3) % 4
	_tween_turn(PI / 2.0)
	minimap_ctrl.player_facing = player_facing
	minimap_ctrl.queue_redraw()


func _action_turn_right() -> void:
	player_facing = (player_facing + 1) % 4
	_tween_turn(-PI / 2.0)
	minimap_ctrl.player_facing = player_facing
	minimap_ctrl.queue_redraw()


# Walking is how MP comes back. A flat point a step would be everything at
# level one and nothing at level thirty, so it is a slice of the pool instead:
# fifty steps from empty to full at any level. That is short enough that a bad
# fight never strands you at the far end of a floor, and long enough that three
# fights in a row still leave you deciding whether this one is worth a Pyre.
const MP_PER_STEP: float = 0.02


func _recover_mp_on_step() -> void:
	if player_char.mp >= player_char.max_mp:
		return
	player_char.mp = mini(player_char.max_mp,
			player_char.mp + maxi(1, roundi(float(player_char.max_mp) * MP_PER_STEP)))


func _post_move() -> void:
	_sync_player()
	_recover_mp_on_step()
	_take_key_here()
	_check_step_poison()
	_check_trap()
	if not player_char.is_alive():
		return
	# Walking into a roamer counts before it gets its own step, which is also
	# what stops the two swapping straight through one another.
	if _engage_roamer_here():
		return
	_step_roamers()
	if _engage_roamer_here():
		return
	if player_pos in current_level.orb_cells:
		_open_orb()


func _handle_swipe(delta: Vector2) -> void:
	if in_combat or menu_open or save_open or orb_open or chest_open:
		return
	if delta.length() < _SWIPE_MIN:
		return
	if abs(delta.x) > abs(delta.y):
		if delta.x > 0:
			_action_turn_right()
		else:
			_action_turn_left()
	else:
		if delta.y < 0:
			_action_forward()
		else:
			_action_back()


func _on_menu_btn_pressed() -> void:
	if in_combat or save_open or orb_open or chest_open:
		return
	if menu_open:
		_close_menu()
	else:
		_open_menu()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_swipe_start  = event.position
			_swipe_active = true
		else:
			if _swipe_active:
				_handle_swipe(event.position - _swipe_start)
			_swipe_active = false
		return

	if not (event is InputEventKey and event.pressed):
		return

	if event.keycode == KEY_Q and not in_combat:
		_encounters_enabled = not _encounters_enabled
		_update_encounter_debug_label()
		return

	if event.keycode == KEY_F9 and not in_combat and not save_open and not orb_open \
			and not chest_open:
		if menu_open:
			_close_menu()
		_open_load_menu()
		return

	# ESC: close save picker → close menu → open menu. Blocked during combat.
	if event.keycode == KEY_ESCAPE:
		if not in_combat:
			if save_open:
				_close_save_layer()
			elif menu_open:
				_close_menu()
			else:
				_open_menu()
		return

	if in_combat or menu_open or save_open:
		return

	match event.keycode:
		KEY_UP, KEY_W:
			_action_forward()
		KEY_DOWN, KEY_S:
			_action_back()
		KEY_LEFT, KEY_A:
			_action_turn_left()
		KEY_RIGHT, KEY_D:
			_action_turn_right()


# ── Encounter system ─────────────────────────────────────────────────────────

# Only the abnormal half of the toggle is worth saying out loud. With roamers on
# the HUD stays clean; with them off the floor is silent for a reason, and that
# is exactly when a label earns its place.
func _update_encounter_debug_label() -> void:
	_encounter_debug_lbl.visible = not _encounters_enabled
	_encounter_debug_lbl.text = "[DEBUG] Roamers: OFF"
	_encounter_debug_lbl.add_theme_color_override("font_color", Color(0.90, 0.35, 0.35))


# ── Roaming demons ───────────────────────────────────────────────────────────

# How many demons a floor carries. Boss corridors carry none — the boss is the
# encounter, and a 1-cell-wide corridor gives you nowhere to dodge.
#
# One demon per territory is the rule that keeps them out of each other's way,
# so this can only ever reach as high as there are territories — see ZONE_DIV.
func _roamer_target() -> int:
	if Level.is_boss_floor(floor_num):
		return 0
	return mini(9 + floor_num * 2, 14)


func _spawn_roamers() -> void:
	for r: Roamer in roamers:
		if is_instance_valid(r):
			r.queue_free()
	roamers.clear()
	_engaged.clear()
	_steps_since_spawn = 0
	# One territory each, so they never end up in the same corner of the maze.
	var zones: Array[Rect2i] = _build_zones()
	zones.shuffle()
	var target: int = _roamer_target()
	for z: Rect2i in zones:
		if roamers.size() >= target:
			break
		_spawn_roamer_in(z)
	_spawn_warden()


# Walking onto the loose key takes it. No prompt: there is one thing to do with
# a key and asking whether to do it is a dialog box in front of a door.
func _take_key_here() -> void:
	if current_level == null or _has_key or current_level.key_taken:
		return
	if current_level.key_pos.x < 0 or player_pos != current_level.key_pos:
		return
	current_level.key_taken = true
	_has_key = true
	minimap_ctrl.key_pos = Vector2i(-1, -1)
	minimap_ctrl.queue_redraw()
	_rebuild_dungeon()
	_show_hud_popup("You take the key.", Color(0.75, 0.55, 1.0))


# The thing holding the key, if anything is. A warden stands in the middle of
# its band; the other maze floors leave the key lying and this does nothing.
func _spawn_warden() -> void:
	_warden = null
	_has_key = false
	if current_level == null:
		_has_key = true
		return
	minimap_ctrl.key_pos = Vector2i(-1, -1)
	if current_level.warden_pos.x < 0:
		# A loose key, or a corridor with neither and no locked door.
		if current_level.key_pos.x >= 0 and not current_level.key_taken:
			minimap_ctrl.key_pos = current_level.key_pos
		else:
			_has_key = true
		minimap_ctrl.queue_redraw()
		return
	var w: Roamer = Roamer.new()
	w.warden = true
	w.cell = current_level.warden_pos
	world.add_child(w)
	roamers.append(w)
	_warden = w
	minimap_ctrl.warden_pos = w.cell
	minimap_ctrl.queue_redraw()


# Carves the floor into a grid of territories. Anything smaller than a couple
# of cells is not worth patrolling, so tiny slivers are simply skipped later.
# The maze is cut into ZONE_DIV x ZONE_DIV territories and each one holds at
# most one demon, which is what stops them piling into a corner or wandering
# through each other. It is therefore also the ceiling on how many a floor can
# carry: at 3 that was nine, and a 20x20 maze felt empty. At 4 there are
# sixteen territories of about 5x5, still big enough that a demon patrols
# rather than paces.
const ZONE_DIV: int = 4

func _build_zones() -> Array[Rect2i]:
	var out: Array[Rect2i] = []
	if current_level == null or current_level.maze.is_empty():
		return out
	var rows: int = current_level.maze.size()
	var cols: int = (current_level.maze[0] as Array).size()
	var zw: int = maxi(1, cols / ZONE_DIV)
	var zh: int = maxi(1, rows / ZONE_DIV)
	for zy: int in range(ZONE_DIV):
		for zx: int in range(ZONE_DIV):
			var x0: int = zx * zw
			var y0: int = zy * zh
			var w: int = (cols - x0) if zx == ZONE_DIV - 1 else zw
			var h: int = (rows - y0) if zy == ZONE_DIV - 1 else zh
			if w > 0 and h > 0:
				out.append(Rect2i(x0, y0, w, h))
	return out


# The cells of one territory that are open, clear of the player, and not
# already held by something else.
func _free_cells_in(zone: Rect2i, min_dist: int) -> Array[Vector2i]:
	var taken: Dictionary = _occupied_cells()
	var out: Array[Vector2i] = []
	for row: int in range(zone.position.y, zone.position.y + zone.size.y):
		for col: int in range(zone.position.x, zone.position.x + zone.size.x):
			var c: Vector2i = Vector2i(col, row)
			if not _is_open(c.x, c.y) or taken.has(c):
				continue
			if c == current_level.exit_pos or c == current_level.warden_pos:
				continue
			if c in current_level.orb_cells:
				continue
			if absi(c.x - player_pos.x) + absi(c.y - player_pos.y) < min_dist:
				continue
			out.append(c)
	return out


func _occupied_cells() -> Dictionary:
	var taken: Dictionary = {}
	for r: Roamer in roamers:
		if is_instance_valid(r):
			taken[r.cell] = true
	return taken


# Places one demon inside a territory, and hands it that territory to keep to.
func _spawn_roamer_in(zone: Rect2i) -> void:
	var options: Array[Vector2i] = _free_cells_in(zone, 6)
	if options.is_empty():
		options = _free_cells_in(zone, 3)
	if options.is_empty():
		return
	var r: Roamer = Roamer.new()
	r.cell = options[randi() % options.size()]
	r.zone = zone
	world.add_child(r)
	roamers.append(r)


# Refills a territory that has fallen empty, rather than piling another demon
# into one that is already patrolled.
func _spawn_roamer() -> void:
	var held: Dictionary = {}
	for r: Roamer in roamers:
		if is_instance_valid(r) and not r.warden:
			held[r.zone] = true
	var empty: Array[Rect2i] = []
	for z: Rect2i in _build_zones():
		if not held.has(z):
			empty.append(z)
	if empty.is_empty():
		return
	_spawn_roamer_in(empty[randi() % empty.size()])


# A random open cell at least min_dist away from the player, or (-1,-1) if the
# floor is too cramped to find one.
func _far_open_cell(min_dist: int) -> Vector2i:
	var candidates: Array[Vector2i] = []
	for row: int in range(current_level.maze.size()):
		var row_data: Array = current_level.maze[row]
		for col: int in range(row_data.size()):
			if row_data[col] != 0:
				continue
			var c: Vector2i = Vector2i(col, row)
			if absi(c.x - player_pos.x) + absi(c.y - player_pos.y) < min_dist:
				continue
			if c == current_level.exit_pos:
				continue
			candidates.append(c)
	if candidates.is_empty():
		return Vector2i(-1, -1)
	return candidates[randi() % candidates.size()]


func _step_roamers() -> void:
	if not _encounters_enabled:
		return
	# Everyone sees where everyone else is standing, so two never share a cell.
	for r: Roamer in roamers:
		if is_instance_valid(r):
			var taken: Dictionary = _occupied_cells()
			# An orb is the only place a run can be saved, healed or restocked.
			# A demon parked on one turns that into a fight you cannot decline.
			for orb: Vector2i in current_level.orb_cells:
				taken[orb] = true
			taken.erase(r.cell)
			r.move_to(r.choose_step(player_pos, _is_open, taken))

	_steps_since_spawn += 1
	if _steps_since_spawn >= _RESPAWN_STEPS and roamers.size() < _roamer_target():
		_steps_since_spawn = 0
		_spawn_roamer()


# Starts a battle if a roamer is standing where the player is. Returns true if
# one did, so the caller knows to stop.
func _engage_roamer_here() -> bool:
	if not _encounters_enabled:
		return false
	var here: Array[Roamer] = []
	for r: Roamer in roamers:
		if is_instance_valid(r) and r.cell == player_pos:
			here.append(r)
	if here.is_empty():
		return false

	# Off the floor the instant the battle opens, rather than after it resolves.
	# They are only hidden, not freed — escaping has to put them back.
	_engaged = here
	var warden_here: bool = false
	for e: Roamer in here:
		if e.warden:
			warden_here = true
		roamers.erase(e)
		e.visible = false

	# The warden is a named demon, not a reroll of the floor's random table —
	# it is the locked door, and it fights alone so its two icons read as a
	# wall rather than getting lost in a pack.
	if warden_here:
		var keeper: Array[Enemy] = [Enemy.make_warden(floor_num)]
		_launch_combat(keeper)
		return true

	_launch_combat(Enemy.make_group(floor_num))
	return true


func _start_combat() -> void:
	_launch_combat(Enemy.make_group(floor_num))


func _start_boss_combat() -> void:
	_pending_congratulations = (floor_num >= Level.FLOOR_COUNT)
	# Bosses come alone; their own icon count is what makes them a fight.
	var solo: Array[Enemy] = [Enemy.make_boss(floor_num)]
	_launch_combat(solo)


func _launch_combat(group: Array[Enemy]) -> void:
	in_combat = true
	hud_layer.visible = false
	for foe: Enemy in group:
		add_child(foe)
		if foe.enemy_name not in player_char.encountered_enemies:
			player_char.encountered_enemies.append(foe.enemy_name)
	var combat_layer: CanvasLayer = CanvasLayer.new()
	combat_layer.layer = 20
	add_child(combat_layer)
	var packed: PackedScene = load("res://scenes/combat.tscn") as PackedScene
	var scene: CombatScene = packed.instantiate() as CombatScene
	scene.player = player_char
	# The scene removes negotiated demons from its own list, so hand it a copy
	# and keep the full roster here for the reward tally.
	scene.foes = group.duplicate()
	scene.combat_ended.connect(_on_combat_ended.bind(group, combat_layer))
	combat_layer.add_child(scene)


# Rewards are summed over the whole encounter: anything killed pays experience,
# gold and a drop roll; anything talked down pays experience and gold only.
func _on_combat_ended(result: String, group: Array[Enemy], combat_layer: CanvasLayer) -> void:
	# Read before the scene is freed: anything bound that fell is gone for good,
	# and the player has to be told somewhere they will see it.
	var lost: Array[String] = []
	for child: Node in combat_layer.get_children():
		if child is CombatScene:
			lost = (child as CombatScene).lost_demons.duplicate()

	var exp_reward:  int = 0
	var gold_reward: int = 0
	var item_drop:   Dictionary = {}
	for foe: Enemy in group:
		exp_reward  += foe.exp_reward
		gold_reward += foe.gold_reward
		if not foe.is_alive() and item_drop.is_empty():
			item_drop = foe.roll_drop()
			if item_drop.is_empty() and "scavenger" in player_char.passive_skills \
					and randi() % 2 == 0:
				item_drop = foe.roll_drop()
	for foe: Enemy in group:
		foe.queue_free()
	combat_layer.queue_free()

	# Whatever walked into the fight is already off the floor. Winning or talking
	# your way out keeps it that way; slipping away puts them back, moved on.
	var met: Array[Roamer] = _engaged
	_engaged = []
	var beat_warden: bool = false
	for e: Roamer in met:
		if not is_instance_valid(e):
			continue
		var was_warden: bool = (e == _warden)
		if result == "lose":
			e.visible = true
			roamers.append(e)
		elif result == "flee":
			e.visible = true
			roamers.append(e)
			# The warden is a fixed objective, so escaping never relocates it.
			if not was_warden:
				var spot: Vector2i = _far_open_cell(5)
				if spot.x >= 0:
					e.teleport_to(spot)
		else:
			e.queue_free()
			_steps_since_spawn = 0
			if was_warden:
				beat_warden = true

	if beat_warden:
		_warden  = null
		_has_key = true
		minimap_ctrl.warden_pos = Vector2i(-1, -1)
		minimap_ctrl.queue_redraw()
		_show_hud_popup("The warden falls. You take the key.", Color(0.75, 0.55, 1.0))

	# On a boss floor an encounter with no roamer behind it is the boss.
	if result != "lose" and Level.is_boss_floor(floor_num) and met.is_empty():
		_boss_beaten = true

	if not lost.is_empty() and result != "lose":
		_show_hud_popup("Lost for good:  %s" % ", ".join(lost), Color(1.0, 0.45, 0.45))

	match result:
		"win", "talk":
			player_char.gold += gold_reward
			if result == "win" and not item_drop.is_empty():
				player_char.add_item(item_drop)
			var before: Dictionary = _player_snapshot()
			player_char.gain_exp(exp_reward)
			var after: Dictionary = _player_snapshot()
			var leveled: bool = after["lv"] > before["lv"]
			var climbed: Array[String] = player_char.award_demon_exp(exp_reward)
			var shown_drop: Dictionary = item_drop if result == "win" else {}
			_show_combat_result(exp_reward, gold_reward, shown_drop,
				before if leveled else {}, after if leveled else {},
				_demon_level_lines(climbed))
		"bribe":
			var before: Dictionary = _player_snapshot()
			player_char.gain_exp(exp_reward)
			var after: Dictionary = _player_snapshot()
			var leveled: bool = after["lv"] > before["lv"]
			var climbed_b: Array[String] = player_char.award_demon_exp(exp_reward)
			_show_combat_result(exp_reward, 0, {},
				before if leveled else {}, after if leveled else {},
				_demon_level_lines(climbed_b))
		"lose":
			_pending_congratulations = false
			_show_game_over()
		"flee":
			_pending_congratulations = false
			_resume_from_overlay()



# "Bat Lv 5  STR+4 AGL+2" for each demon that gained a level in that fight.
func _demon_level_lines(climbed: Array[String]) -> Array[String]:
	var out: Array[String] = []
	for demon_name: String in climbed:
		var gains: String = player_char.demon_gain_string(demon_name)
		out.append("%s Lv %d%s" % [demon_name,
				int(player_char.bound_level.get(demon_name, 1)),
				"  " + gains if gains != "" else ""])
	return out


func _show_combat_result(exp: int, gold: int, item: Dictionary,
		lv_before: Dictionary, lv_after: Dictionary,
		demons_leveled: Array[String] = []) -> void:
	var ui: CombatResultUI = CombatResultUI.new()
	ui.exp_gained  = exp
	ui.gold_gained = gold
	ui.item_drop   = item
	ui.demons_leveled = demons_leveled
	ui.dismissed.connect(func():
		ui.queue_free()
		if not lv_before.is_empty():
			_show_level_up(lv_before, lv_after)
		else:
			_resume_from_overlay()
	)
	_get_overlay_layer().add_child(ui)


func _resume_from_overlay() -> void:
	hud_layer.visible = true
	in_combat = false
	if _pending_congratulations:
		_pending_congratulations = false
		_show_congratulations()


func _show_congratulations() -> void:
	in_combat = true
	hud_layer.visible = false
	var ui: CongratulationsUI = CongratulationsUI.new()
	ui.dismissed.connect(func():
		ui.queue_free()
		hud_layer.visible = true
		in_combat = false
	)
	_get_overlay_layer().add_child(ui)


func _player_snapshot() -> Dictionary:
	return {
		lv=player_char.lv, str=player_char.str, def=player_char.def,
		mag=player_char.mag, agl=player_char.agl, luk=player_char.luk,
		max_hp=player_char.max_hp, max_mp=player_char.max_mp,
	}


func _get_overlay_layer() -> CanvasLayer:
	if not is_instance_valid(overlay_layer):
		overlay_layer = CanvasLayer.new()
		overlay_layer.layer = 25
		add_child(overlay_layer)
	return overlay_layer


func _show_level_up(before: Dictionary, after: Dictionary) -> void:
	var ui: LevelUpUI = LevelUpUI.new()
	ui.before  = before
	ui.after   = after
	ui.player  = player_char
	ui.dismissed.connect(func():
		ui.queue_free()
		_resume_from_overlay()
	)
	_get_overlay_layer().add_child(ui)


func _show_game_over() -> void:
	var ui: GameOverUI = GameOverUI.new()
	ui.load_game.connect(func():
		ui.queue_free()
		in_combat = false
		_open_load_menu()
	)
	ui.main_menu.connect(func():
		get_tree().change_scene_to_file("res://scenes/title.tscn")
	)
	_get_overlay_layer().add_child(ui)




func _show_hud_popup(text: String, color: Color = Color(1.0, 0.88, 0.28)) -> void:
	_hud_popup.text = text
	_hud_popup.add_theme_color_override("font_color", color)
	_hud_popup.modulate.a = 1.0
	if is_instance_valid(_hud_popup_tween):
		_hud_popup_tween.kill()
	_hud_popup_tween = create_tween()
	_hud_popup_tween.tween_interval(1.8)
	_hud_popup_tween.tween_property(_hud_popup, "modulate:a", 0.0, 0.6)


func _check_step_poison() -> void:
	if not player_char.has_status(Status.POISON):
		return
	var dmg: int = max(1, int(player_char.max_hp * 0.05))
	player_char.take_damage(dmg)
	_show_hud_popup("Poison  -%d HP" % dmg, Color(0.55, 0.90, 0.30))
	if not player_char.is_alive():
		_show_game_over()


func _check_trap() -> void:
	if not current_level.trap_cells.has(player_pos):
		return
	var trap_type: String = current_level.trap_cells[player_pos] as String
	# Remembered from here on. A trap you have not stepped on is not a thing
	# you know about, so the map stays quiet about it until it has bitten.
	current_level.found_traps[player_pos] = trap_type
	minimap_ctrl.queue_redraw()
	match trap_type:
		"spike":
			var dmg: int = max(1, int(player_char.max_hp * 0.15))
			player_char.take_damage(dmg)
			_show_hud_popup("Spike Trap!  -%d HP" % dmg, Color(0.90, 0.30, 0.30))
			if not player_char.is_alive():
				_show_game_over()
		"poison_vent":
			if not player_char.has_status(Status.POISON):
				player_char.apply_status(Status.POISON)
			_show_hud_popup("Poison Vent!  Poisoned!", Color(0.55, 0.90, 0.30))
		"binding_rune":
			if not player_char.has_status(Status.IMMOBILIZE):
				player_char.apply_status(Status.IMMOBILIZE)
			_show_hud_popup("Binding Rune!  Immobilized!", Color(0.70, 0.50, 1.0))










# ── Menu ─────────────────────────────────────────────────────────────────────

func _open_menu() -> void:
	menu_open = true
	hud_layer.visible = false

	if not is_instance_valid(menu_layer):
		menu_layer = CanvasLayer.new()
		menu_layer.layer = 15  # Above HUD, below combat
		add_child(menu_layer)

	var menu: MenuUI = MenuUI.new()
	menu.player = player_char
	menu.menu_closed.connect(_close_menu)
	menu.load_requested.connect(func():
		_close_menu()
		_open_load_menu()
	)
	menu_layer.add_child(menu)


func _close_menu() -> void:
	if is_instance_valid(menu_layer):
		for child: Node in menu_layer.get_children():
			child.queue_free()
	hud_layer.visible = true
	menu_open = false




# ── Save orbs ────────────────────────────────────────────────────────────────

# ── Caches ────────────────────────────────────────────────────────────────────

func _open_chest(wall: Vector2i) -> void:
	chest_open = true
	hud_layer.visible = false
	if not is_instance_valid(chest_layer):
		chest_layer = CanvasLayer.new()
		chest_layer.layer = 15
		add_child(chest_layer)
	var ui: ChestUI = ChestUI.new()
	ui.closed.connect(func() -> void: _close_chest())
	ui.opened.connect(func() -> void:
		# Nothing about the recess says which it is, so the prompt is the same
		# either way and the answer arrives on the swing of the lid.
		if current_level.mimic_cells.has(wall):
			_spring_mimic(wall)
		else:
			_loot_chest(wall)
			_close_chest())
	chest_layer.add_child(ui)


# It was never a cache. The cell is marked emptied so the recess reads as open
# afterwards whichever way the fight goes, and the mimic is fought where it
# stood — it does not roam and it does not get a second ambush.
func _spring_mimic(wall: Vector2i) -> void:
	current_level.looted[wall] = true
	current_level.mimic_cells.erase(wall)
	_close_chest()
	_rebuild_dungeon()
	# No HUD popup here: _launch_combat hides that layer on the same frame, so
	# the line would never be seen. The encounter line carries the reveal.
	_launch_combat([Enemy.make_mimic(floor_num)] as Array[Enemy])


# What was in it. Gold always, and better odds of something on top of that
# than a demon carries — a cache you had to find should beat a demon you
# tripped over.
func _loot_chest(wall: Vector2i) -> void:
	current_level.looted[wall] = true

	var coin: int = 25 + floor_num * 20 + (randi() % (20 + floor_num * 10))
	player_char.gold += coin
	var found: Array[String] = ["%d gold" % coin]

	if randi() % 100 < 70:
		var table: Array[Dictionary] = Item.drop_table_for_floor(floor_num)
		var item: Dictionary = table[randi() % table.size()].duplicate()
		player_char.add_item(item, 1)
		found.append(item["name"] as String)

	_show_hud_popup("Opened:  %s" % ", ".join(found), Color(1.0, 0.82, 0.40))
	_rebuild_dungeon()


# Rebuild so an emptied recess reads as emptied.
func _rebuild_dungeon() -> void:
	if is_instance_valid(dungeon):
		dungeon.queue_free()
	dungeon = Dungeon.new()
	world.add_child(dungeon)
	dungeon.build(current_level)


func _close_chest() -> void:
	chest_open = false
	hud_layer.visible = true
	if is_instance_valid(chest_layer):
		for child: Node in chest_layer.get_children():
			child.queue_free()


func _open_orb(tab: String = "rest") -> void:
	orb_open = true
	hud_layer.visible = false
	if not is_instance_valid(orb_layer):
		orb_layer = CanvasLayer.new()
		orb_layer.layer = 15
		add_child(orb_layer)
	var ui: OrbUI = OrbUI.new()
	ui.player    = player_char
	ui.floor_num = floor_num
	ui.start_tab = tab
	ui.closed.connect(_close_orb)
	ui.save_requested.connect(func() -> void:
		_close_orb()
		_open_save_menu()
	)
	orb_layer.add_child(ui)


func _close_orb() -> void:
	if is_instance_valid(orb_layer):
		for child: Node in orb_layer.get_children():
			child.queue_free()
	hud_layer.visible = true
	orb_open = false


func _open_save_menu() -> void:
	save_open = true
	hud_layer.visible = false
	if not is_instance_valid(save_layer):
		save_layer = CanvasLayer.new()
		save_layer.layer = 16
		add_child(save_layer)
	var ui: SaveSlotUI = SaveSlotUI.new()
	ui.mode = "save"
	ui.slot_chosen.connect(_do_save)
	ui.cancelled.connect(_close_save_layer)
	save_layer.add_child(ui)


func _open_load_menu() -> void:
	save_open = true
	hud_layer.visible = false
	if not is_instance_valid(save_layer):
		save_layer = CanvasLayer.new()
		save_layer.layer = 16
		add_child(save_layer)
	var ui: SaveSlotUI = SaveSlotUI.new()
	ui.mode = "load"
	ui.slot_chosen.connect(_do_load)
	ui.cancelled.connect(_close_save_layer)
	save_layer.add_child(ui)


func _close_save_layer() -> void:
	if is_instance_valid(save_layer):
		for child: Node in save_layer.get_children():
			child.queue_free()
	hud_layer.visible = true
	save_open = false


func _do_save(slot: int) -> void:
	SaveSystem.write(slot, _gather_save_data())
	_close_save_layer()
	_show_hud_popup("Game saved to Slot %d." % slot)


func _do_load(slot: int) -> void:
	var data: Dictionary = SaveSystem.read(slot)
	if data.is_empty():
		return
	_close_save_layer()
	_restore_save(data)


func _gather_save_data() -> Dictionary:
	var p: PlayerCharacter = player_char
	var visited_serial: Dictionary = {}
	for sp: Variant in visited_by_map.keys():
		visited_serial[sp as String] = SaveSystem.pack_visited(visited_by_map[sp] as Dictionary)

	return {
		timestamp   = Time.get_datetime_string_from_system(),
		floor_num   = floor_num,
		player_pos  = [player_pos.x, player_pos.y],
		player_facing = player_facing,
		player = {
			lv = p.lv, str = p.str, def = p.def, mag = p.mag, agl = p.agl, luk = p.luk,
			exp = p.exp, exp_to_next = p.exp_to_next,
			hp = p.hp, max_hp = p.max_hp, mp = p.mp, max_mp = p.max_mp,
			hp_bonus = p._hp_bonus, mp_bonus = p._mp_bonus,
			gold = p.gold,
			known_spells        = p.known_spells,
			equipped_spells     = p.equipped_spells,
			equipped_items      = p.equipped_items,
			recruited           = p.recruited,
			bound_level         = p.bound_level,
			demon_exp           = p.demon_exp,
			demon_gains         = p.demon_gains,
			active_demons       = p.active_demons,
			encountered_enemies = p.encountered_enemies,
			analyzed            = p.analyzed,
			passive_skills      = p.passive_skills,
			active_statuses     = p.active_statuses,
			inventory       = p.inventory,
			equipped_weapon      = p.equipped_weapon,
			equipped_armor       = p.equipped_armor,
			equipped_accessories = p.equipped_accessories,
		},
		map = {
			scene       = "res://scenes/map.tscn",
			maze        = current_level.maze,
			exit_wall   = [current_level.exit_wall_pos.x,   current_level.exit_wall_pos.y],
			exit_pos    = [current_level.exit_pos.x,        current_level.exit_pos.y],
			trap_cells  = _pack_trap_cells(current_level.trap_cells),
			roamers     = _pack_roamers(),
			orbs        = _pack_orbs(),
			chests      = _pack_chests(),
			mimics      = _pack_cell_set(current_level.mimic_cells),
			looted      = _pack_cell_set(current_level.looted),
			warden      = SaveSystem.vec2i_key(current_level.warden_pos),
			key_pos     = SaveSystem.vec2i_key(current_level.key_pos),
			key_taken   = current_level.key_taken,
			found_traps = _pack_trap_cells(current_level.found_traps),
			has_key     = _has_key,
		},
		visited = visited_serial,
	}


func _restore_save(data: Dictionary) -> void:
	in_combat = false
	menu_open = false
	if is_instance_valid(overlay_layer):
		for c: Node in overlay_layer.get_children():
			c.queue_free()
	if is_instance_valid(menu_layer):
		for c: Node in menu_layer.get_children():
			c.queue_free()

	_apply_player_data(data["player"] as Dictionary)

	floor_num = int(data["floor_num"])
	floor_label.text = "Floor %d" % floor_num

	if is_instance_valid(dungeon):
		dungeon.queue_free()
		dungeon = null
	if is_instance_valid(current_level):
		current_level.queue_free()
		current_level = null

	var map_data: Dictionary = data["map"] as Dictionary
	var scene_path: String   = map_data["scene"] as String
	var packed: PackedScene  = load(scene_path) as PackedScene
	current_level = packed.instantiate() as Level
	# Same reason as the other one: the level builds itself in _ready, and the
	# generated layout is thrown away below anyway — but the shape it builds
	# (maze or boss corridor) has to match the floor being restored.
	current_level.floor_num = floor_num
	world.add_child(current_level)

	# Overwrite the freshly-generated maze with the saved layout.
	var raw_maze: Array = map_data["maze"] as Array
	var saved_maze: Array[Array] = []
	for row: Variant in raw_maze:
		saved_maze.append(row as Array)
	current_level.maze = saved_maze

	var ew: Array  = map_data["exit_wall"]   as Array
	var ep: Array  = map_data["exit_pos"]    as Array
	current_level.exit_wall_pos   = Vector2i(int(ew[0]), int(ew[1]))
	current_level.exit_pos        = Vector2i(int(ep[0]), int(ep[1]))
	current_level.next_scene      = scene_path
	current_level.trap_cells      = _unpack_trap_cells(map_data.get("trap_cells", {}) as Dictionary)
	_pending_roamers              = map_data.get("roamers", []) as Array
	current_level.orb_cells.clear()
	for key: Variant in (map_data.get("orbs", []) as Array):
		current_level.orb_cells.append(SaveSystem.key_vec2i(key as String))
	# Caches were never saved, so a load re-rolled where they were and whether
	# they were empty. Harmless while a chest was only ever a chest; not once
	# one of them can be a mimic, because then a reload is a re-roll of the
	# ambush you just walked into.
	var saved_chests: Dictionary = map_data.get("chests", {}) as Dictionary
	if not saved_chests.is_empty():
		current_level.chest_cells.clear()
		for key: Variant in saved_chests.keys():
			current_level.chest_cells[SaveSystem.key_vec2i(key as String)] = \
					SaveSystem.key_vec2i(saved_chests[key] as String)
		current_level.mimic_cells = _unpack_cell_set(
				map_data.get("mimics", []) as Array)
		current_level.looted = _unpack_cell_set(
				map_data.get("looted", []) as Array)
	current_level.warden_pos      = SaveSystem.key_vec2i(
			map_data.get("warden", "-1,-1") as String)
	current_level.key_pos         = SaveSystem.key_vec2i(
			map_data.get("key_pos", "-1,-1") as String)
	current_level.key_taken       = bool(map_data.get("key_taken", false))
	current_level.found_traps     = _unpack_trap_cells(
			map_data.get("found_traps", {}) as Dictionary)
	_pending_has_key              = bool(map_data.get("has_key", true))

	dungeon = Dungeon.new()
	world.add_child(dungeon)
	dungeon.build(current_level)

	# Restore fog-of-war.
	var raw_visited: Dictionary = data["visited"] as Dictionary
	visited_by_map = {}
	for sp: Variant in raw_visited.keys():
		visited_by_map[sp as String] = SaveSystem.unpack_visited(raw_visited[sp as String] as Array)
	visited = visited_by_map.get(scene_path, {})

	minimap_ctrl.maze      = current_level.maze
	minimap_ctrl.visited   = visited
	minimap_ctrl.exit_pos  = current_level.exit_wall_pos
	_sync_minimap_palette()
	_resize_minimap()

	var pos_arr: Array = data["player_pos"] as Array
	player_pos    = Vector2i(int(pos_arr[0]), int(pos_arr[1]))
	player_facing = int(data["player_facing"])

	_sync_player()
	_snap_cam_yaw()
	# Player position is set above, so the roamers land relative to where the
	# save actually left them.
	_restore_roamers()
	hud_layer.visible = true


func _apply_player_data(pdata: Dictionary) -> void:
	player_char.lv          = int(pdata["lv"])
	player_char.str         = int(pdata["str"])
	player_char.def         = int(pdata["def"])
	player_char.mag         = int(pdata["mag"])
	player_char.agl         = int(pdata["agl"])
	player_char.luk         = int(pdata.get("luk", 3))
	player_char.exp         = int(pdata["exp"])
	player_char.exp_to_next = int(pdata["exp_to_next"])
	player_char.hp          = int(pdata["hp"])
	player_char.max_hp      = int(pdata["max_hp"])
	player_char.mp          = int(pdata["mp"])
	player_char.max_mp      = int(pdata["max_mp"])
	player_char._hp_bonus   = int(pdata.get("hp_bonus", 0))
	player_char._mp_bonus   = int(pdata.get("mp_bonus", 0))
	player_char.gold        = int(pdata["gold"])

	player_char.known_spells.clear()
	player_char.known_spells.assign(pdata["known_spells"] as Array)
	# Saves written before loadouts existed carry no equipped list; fall back to
	# the first few known spells so those saves still have something to cast.
	player_char.equipped_items.clear()
	if pdata.has("equipped_items"):
		player_char.equipped_items.assign(pdata["equipped_items"] as Array)

	player_char.equipped_spells.clear()
	if pdata.has("equipped_spells"):
		player_char.equipped_spells.assign(pdata["equipped_spells"] as Array)
	else:
		for spell_id: String in player_char.known_spells:
			if not player_char.equip_spell(spell_id):
				break

	player_char.recruited.clear()
	player_char.recruited.assign(pdata.get("recruited", []) as Array)
	player_char.bound_level.clear()
	for k: Variant in (pdata.get("bound_level", {}) as Dictionary):
		player_char.bound_level[k] = int((pdata["bound_level"] as Dictionary)[k])
	# A save written before demons remembered their level: assume the shallow
	# end rather than leaving them at zero.
	for demon_name: String in player_char.recruited:
		if not player_char.bound_level.has(demon_name):
			player_char.bound_level[demon_name] = 2

	player_char.demon_exp.clear()
	for k: Variant in (pdata.get("demon_exp", {}) as Dictionary):
		player_char.demon_exp[k] = int((pdata["demon_exp"] as Dictionary)[k])
	player_char.demon_gains.clear()
	for k: Variant in (pdata.get("demon_gains", {}) as Dictionary):
		var raw: Dictionary = (pdata["demon_gains"] as Dictionary)[k] as Dictionary
		var one: Dictionary = {}
		for stat: String in ["str", "def", "mag", "agl"]:
			one[stat] = int(raw.get(stat, 0))
		player_char.demon_gains[k] = one

	player_char.active_demons.clear()
	if pdata.has("active_demons"):
		player_char.active_demons.assign(pdata["active_demons"] as Array)
	else:
		# Saves from before the party screen existed: walk in with the first few.
		for demon_name: String in player_char.recruited:
			if not player_char.activate_demon(demon_name):
				break

	player_char.encountered_enemies.clear()
	player_char.encountered_enemies.assign(pdata.get("encountered_enemies", []) as Array)

	player_char.analyzed.clear()
	player_char.analyzed.assign(pdata.get("analyzed", []) as Array)

	player_char.passive_skills.clear()
	player_char.passive_skills.assign(pdata.get("passive_skills", []) as Array)

	player_char.active_statuses.clear()
	player_char.active_statuses.assign(pdata["active_statuses"] as Array)

	player_char.inventory.clear()
	player_char.inventory.assign(pdata["inventory"] as Array)

	player_char.equipped_weapon = pdata.get("equipped_weapon", {}) as Dictionary
	player_char.equipped_armor  = pdata.get("equipped_armor",  {}) as Dictionary
	var accs: Array = pdata.get("equipped_accessories", []) as Array
	player_char.equipped_accessories.clear()
	for a: Variant in accs:
		player_char.equipped_accessories.append(a as Dictionary)


# Roamer positions are saved so a reload does not shuffle the floor's threats.
var _pending_roamers: Array = []


# Which wall each cache opens through, and which of them are lying.
func _pack_chests() -> Dictionary:
	var out: Dictionary = {}
	for wall: Vector2i in current_level.chest_cells:
		out[SaveSystem.vec2i_key(wall)] = SaveSystem.vec2i_key(
				current_level.chest_cells[wall] as Vector2i)
	return out


func _pack_cell_set(cells: Dictionary) -> Array:
	var out: Array = []
	for c: Vector2i in cells:
		out.append(SaveSystem.vec2i_key(c))
	return out


func _unpack_cell_set(keys: Array) -> Dictionary:
	var out: Dictionary = {}
	for key: Variant in keys:
		out[SaveSystem.key_vec2i(key as String)] = true
	return out


func _pack_orbs() -> Array:
	var out: Array = []
	for c: Vector2i in current_level.orb_cells:
		out.append(SaveSystem.vec2i_key(c))
	return out


func _pack_roamers() -> Array:
	var out: Array = []
	for r: Roamer in roamers:
		if is_instance_valid(r):
			out.append(SaveSystem.vec2i_key(r.cell))
	return out


var _pending_has_key: bool = true


func _restore_roamers() -> void:
	for r: Roamer in roamers:
		if is_instance_valid(r):
			r.queue_free()
	roamers.clear()
	_engaged.clear()
	_warden = null
	_steps_since_spawn = 0
	for key: Variant in _pending_roamers:
		var rm: Roamer = Roamer.new()
		rm.cell = SaveSystem.key_vec2i(key as String)
		world.add_child(rm)
		roamers.append(rm)
	_pending_roamers = []

	_has_key = _pending_has_key
	minimap_ctrl.warden_pos = Vector2i(-1, -1)
	minimap_ctrl.key_pos = Vector2i(-1, -1)
	if not _has_key and current_level.key_pos.x >= 0 and not current_level.key_taken:
		minimap_ctrl.key_pos = current_level.key_pos
	if not _has_key and current_level.warden_pos.x >= 0:
		var w: Roamer = Roamer.new()
		w.warden = true
		w.cell = current_level.warden_pos
		world.add_child(w)
		roamers.append(w)
		_warden = w
		minimap_ctrl.warden_pos = w.cell
	minimap_ctrl.queue_redraw()


func _pack_trap_cells(cells: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for k: Variant in cells.keys():
		var v: Vector2i = k as Vector2i
		result["%d,%d" % [v.x, v.y]] = cells[k]
	return result


func _unpack_trap_cells(data: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for k: Variant in data.keys():
		var parts: Array = (k as String).split(",")
		result[Vector2i(int(parts[0]), int(parts[1]))] = data[k]
	return result


func _on_node_added(node: Node) -> void:
	if node is RichTextLabel:
		(node as RichTextLabel).add_theme_font_override("normal_font", _UI_FONT)
	elif node is Label:
		(node as Label).add_theme_font_override("font", _UI_FONT)
	elif node is Button:
		var btn := node as Button
		btn.add_theme_font_override("font", _UI_FONT)
		btn.add_theme_font_size_override("font_size", 20)
		var cur: Vector2 = btn.custom_minimum_size
		if cur.y > 0:
			btn.custom_minimum_size = Vector2(cur.x, roundf(cur.y * 1.5))
	elif node is Control:
		(node as Control).add_theme_font_override("font", _UI_FONT)
