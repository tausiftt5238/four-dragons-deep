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
var play_time: float = 0.0  # seconds this run has been played, saved with it
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
const MAP_PANE_H: int = Layout.MAP_PANE_H

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
# Set while ScreenFade has the screen dark for a floor change; input waits.
var _fading: bool = false

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
# Holding the key is not the same as having used it: the door stays shut until
# the player walks into it with the key. Floors with no locked door start open.
var _door_open: bool = false
# Top right of the dungeon view while the key is carried and not yet used.
var _key_icon: KeyIcon
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

var _explore_hud: ExploreHUD  # the wide-screen exploring HUD; null on a phone
var _hud_tick: float = 0.0
var _stick_held: Vector2i = Vector2i.ZERO
var _orb_btn:         Button  # "Orb", shown only while standing on an orb
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
	# Android may kill a backgrounded app without another word, and a desktop
	# window can be closed at any moment: either way, write the run down first.
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST \
			or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_autosave()
		Records.flush()
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


func _process(delta: float) -> void:
	play_time += delta
	Records.tick(delta)
	# A few times a second is plenty for numbers that change on a step.
	_sync_view_width()
	if _explore_hud != null and hud_layer.visible:
		_hud_tick -= delta
		if _hud_tick <= 0.0:
			_hud_tick = 0.15
			_explore_hud.refresh()


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	Controls.ensure()
	Sfx.init()

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

	# An Abyss descent: the hero who beat the game, whole again, at Abyss 1.
	var abyss_intent: String = GameBoot.pending_abyss
	GameBoot.pending_abyss = ""
	Abyss.active = abyss_intent != ""
	if abyss_intent == "new":
		_apply_player_data(Abyss.cleared_hero())
		player_char.hp = player_char.max_hp
		player_char.mp = player_char.max_mp
		player_char.active_statuses.clear()
		floor_num = Abyss.floor_for_depth(1)

	# Load the starting level. _sync_player is called inside here.
	_load_level("res://scenes/map.tscn", true)
	_show_floor_title()

	if abyss_intent == "continue":
		call_deferred("_do_load", SaveSystem.ABYSS_SLOT, false)
	elif abyss_intent == "new":
		Records.add("abyss_runs")
		Abyss.note_depth(1)
		call_deferred("_autosave")
	elif GameBoot.pending_slot <= 0:
		Records.add("runs_started")
	if abyss_intent == "" and GameBoot.pending_slot > 0:
		var slot: int = GameBoot.pending_slot
		GameBoot.pending_slot = 0
		call_deferred("_do_load", slot, false)
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

	_spark_steps = 0
	# Build geometry using the level's colours and maze
	dungeon = Dungeon.new()
	world.add_child(dungeon)
	dungeon.build(current_level)
	_show_sparks()
	_sync_boss_banner()

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

	_point_minimap_at_level()
	_sync_minimap_palette()
	_resize_minimap()

	_sync_player()
	_snap_cam_yaw()
	_spawn_roamers()
	# After _spawn_roamers, which is what decides whether this floor holds the
	# key at all and so whether the way on is shut.
	_door_open = _has_key
	_sync_door()
	Music.play(Music.dungeon_track(floor_num))


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
	# Landscape: the map column down the left, the dungeon on the right.
	if Build.steam():
		_world_box.offset_left = Layout.MAP_PANE_W
	else:
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


# The HUD over the dungeon: the map, the notice band and the debug line on
# both builds, then the build's own pieces (_setup_phone_hud or ExploreHUD).
# The map's size is set per level by _resize_minimap.
func _setup_minimap() -> void:
	hud_layer = CanvasLayer.new()
	hud_layer.layer = 10  # Renders above all 3D content
	add_child(hud_layer)
	var layer: CanvasLayer = hud_layer

	minimap_ctrl = Minimap.new()
	minimap_ctrl.visited = visited  # Shared reference — no copy needed
	minimap_ctrl.whole_floor = true
	layer.add_child(minimap_ctrl)

	# A notice (a trap, the key, the door) on a dark band. On a phone it sits
	# at the top of the 3D view, just under the map: at the bottom it sat on
	# the floor, where a hazard's glow made it unreadable. On a wide screen it
	# is a window under the top strip.
	_hud_popup = Label.new()
	_hud_popup.anchor_right  = 1.0
	_hud_popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_popup.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_hud_popup.autowrap_mode        = TextServer.AUTOWRAP_WORD_SMART
	_hud_popup.add_theme_color_override("font_color", Color(1.0, 0.88, 0.28))
	_hud_popup.modulate.a = 0.0
	if Build.steam():
		_hud_popup.offset_left = Layout.MAP_PANE_W + 60.0
		_hud_popup.offset_right = -60.0
		_hud_popup.offset_top = ExploreHUD.STRIP_H + 8.0
		_hud_popup.offset_bottom = ExploreHUD.STRIP_H + 44.0
		_hud_popup.add_theme_stylebox_override("normal", ExploreHUD.window_box(0.92))
	else:
		_hud_popup.offset_left   = 12.0
		_hud_popup.offset_right  = -12.0
		_hud_popup.offset_top    = MAP_PANE_H + 12.0
		_hud_popup.offset_bottom = MAP_PANE_H + 52.0
		var band: StyleBoxFlat = StyleBoxFlat.new()
		band.bg_color = Color(0.02, 0.02, 0.04, 0.88)
		band.set_corner_radius_all(4)
		band.content_margin_left  = 8.0
		band.content_margin_right = 8.0
		_hud_popup.add_theme_stylebox_override("normal", band)
	layer.add_child(_hud_popup)

	# Under the popup band.
	_encounter_debug_lbl = Label.new()
	_encounter_debug_lbl.offset_left   = 10.0
	_encounter_debug_lbl.offset_right  = 260.0
	_encounter_debug_lbl.offset_top    = 90.0
	_encounter_debug_lbl.offset_bottom = 114.0
	_encounter_debug_lbl.add_theme_font_size_override("font_size", 13)
	_update_encounter_debug_label()
	layer.add_child(_encounter_debug_lbl)

	if Build.steam():
		# The strip, the party and the map in windows, the fight's own.
		_explore_hud = ExploreHUD.new(self, float(Layout.MAP_PANE_W))
		layer.add_child(_explore_hud)
		layer.move_child(_explore_hud, 0)
		_explore_hud.hold_map(minimap_ctrl)
		_explore_hud.menu_pressed.connect(_on_menu_btn_pressed)
		_explore_hud.act_pressed.connect(_act)
	else:
		_setup_phone_hud(layer)


# The phone's pieces: the floor's name over the map, Menu and Orb buttons
# where a thumb is, and the key while it is carried.
func _setup_phone_hud(layer: CanvasLayer) -> void:
	floor_label = Label.new()
	floor_label.text = "Floor 1"
	floor_label.anchor_right  = 1.0
	floor_label.offset_top    = 10.0
	floor_label.offset_bottom = 40.0
	floor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.add_child(floor_label)

	# Bottom right, over the dungeon view: the bottom of an upright screen is
	# where a thumb already is.
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
	# panel meant walking off the tile and back on to reach it again. "Orb",
	# not "Save": the panel rests, shops, binds and sells, and saving is one
	# row inside it.
	_orb_btn = Button.new()
	_orb_btn.text          = "Orb"
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

	# Right edge of the dungeon view, just under the map, while the key is
	# carried. A popup says it once; this keeps saying it.
	_key_icon = KeyIcon.new()
	_key_icon.anchor_left   = 1.0
	_key_icon.anchor_right  = 1.0
	_key_icon.offset_left   = -62.0
	_key_icon.offset_right  = -14.0
	_key_icon.offset_top    = MAP_PANE_H + 12.0
	_key_icon.offset_bottom = MAP_PANE_H + 60.0
	_key_icon.visible       = false
	layer.add_child(_key_icon)


# The floor's name, where this build shows it (the HUD reads it itself on a
# wide screen).
func _show_floor_title() -> void:
	if floor_label != null:
		floor_label.text = Abyss.floor_title(floor_num)


# The map is drawn in the dungeon's own colours: wall faces lifted enough to
# read at 10 px a cell, floor the same void the walls stand in.
func _sync_minimap_palette() -> void:
	# All three come off the level's wire hue, so the map turns red in a boss
	# corridor along with the walls. Floor has to stay clearly above the
	# unexplored black or a walked corridor reads as fog.
	minimap_ctrl.wall_color   = current_level.wire_color.darkened(0.62)
	minimap_ctrl.floor_color  = current_level.wire_color.darkened(0.86)
	minimap_ctrl.border_color = current_level.wire_color


# The phone's map owns the band across the top, under the floor's name, down
# to where the dungeon view begins. On a wide screen the HUD holds it.
func _resize_minimap() -> void:
	if _explore_hud != null:
		return
	minimap_ctrl.anchor_right  = 1.0
	minimap_ctrl.offset_top    = 40.0
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
	if is_instance_valid(dungeon):
		dungeon.set_viewer(pos)
	_mark_visited()
	minimap_ctrl.player_pos    = player_pos
	minimap_ctrl.player_facing = player_facing
	minimap_ctrl.queue_redraw()
	_refresh_hud()


# Every move re-asks: the wide HUD (the prompt, the facing) and the phone's Orb
# shortcut both follow the player's feet.
func _refresh_hud() -> void:
	if _explore_hud != null:
		_explore_hud.refresh()
	elif is_instance_valid(_orb_btn):
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
	# it and the corridor opens onward, the last dragon's included: under it
	# is the Abyss. Past the Necromancer there is nowhere further to go.
	if Level.is_boss_floor(floor_num):
		if not _boss_beaten:
			_start_boss_combat()
			return
		if floor_num >= Level.FLOOR_COUNT:
			_show_congratulations()
			return

	if not _has_key:
		_show_hud_popup("The door is locked. Find the key.", Color(0.75, 0.55, 1.0))
		_shake_camera()
		return

	# The first push with the key turns it; the next one goes through.
	if not _door_open:
		_door_open = true
		_sync_door()
		_show_hud_popup("You turn the key. The door opens.", Color(0.75, 0.55, 1.0))
		return

	if current_level.next_scene == "":
		return
	_descend()


# Going down one floor. The stairs and the debug skip both come through here so
# the two cannot drift, which is the whole reason it is a function: a floor
# arrived at by one path and not the other is a floor carrying stale state.
func _descend() -> void:
	if current_level == null or current_level.next_scene == "" or _fading:
		return
	# Down through the dark, the new floor's number on it, and the floor is
	# built while nothing can be seen.
	_fading = true
	Sfx.play("descend")
	var fade: ScreenFade = ScreenFade.cover(get_tree(), Abyss.floor_title(floor_num + 1))
	await fade.covered
	floor_num += 1
	_show_floor_title()
	if Abyss.active:
		Abyss.note_depth(Abyss.depth_of(floor_num))
	else:
		Records.set_max("deepest_floor", floor_num)
	# Cleared per floor. It used to be raised when a dragon fell and never put
	# back down, so beating the Ice Dragon on floor five left every later boss
	# corridor already counted as beaten — floors ten, fifteen and twenty were
	# walked straight through, and only the first dragon in a run ever fought.
	_boss_beaten = false
	visited_by_map.erase(current_level.next_scene)
	_load_level(current_level.next_scene, true)
	await get_tree().process_frame
	_fading = false
	fade.reveal()
	_autosave()


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
		_slide(DIR_OFFSET[player_facing])
		Sfx.play("step")
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
		_slide(-DIR_OFFSET[player_facing])
		Sfx.play("step")
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


# Walking brings MP back, but only with a Wellspring Charm worn: otherwise it
# comes from orbs and ethers. A flat point a step would be everything at
# level one and nothing at level thirty, so it is a slice of the pool instead:
# fifty steps from empty to full at any level.
const MP_PER_STEP: float = 0.02


func _recover_mp_on_step() -> void:
	if player_char.mp >= player_char.max_mp or not player_char.recovers_mp_walking():
		return
	player_char.mp = mini(player_char.max_mp,
			player_char.mp + maxi(1, roundi(float(player_char.max_mp) * MP_PER_STEP)))


func _post_move() -> void:
	_spark_steps += 1
	_sync_player()
	_recover_mp_on_step()
	_take_key_here()
	_check_trap()
	_show_sparks()
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
	# Either axis can be flipped in Options. Keys are left alone: W means
	# forward whichever way a thumb likes to drag.
	if Settings.invert_turn():
		delta.x = -delta.x
	if Settings.invert_move():
		delta.y = -delta.y
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


# ── The wide-screen HUD's questions and buttons ──────────────────────────────

func has_floor_key() -> bool:
	return _has_key


# What Act would do here, said for the prompt over the party; "" when there is
# nothing in front of you to use.
func facing_prompt() -> String:
	if current_level == null or in_combat:
		return ""
	if player_pos in current_level.orb_cells:
		return "Use the orb"
	var ahead: Vector2i = player_pos + DIR_OFFSET[player_facing]
	if ahead == current_level.exit_wall_pos and player_pos == current_level.exit_pos:
		if Level.is_boss_floor(floor_num) and not _boss_beaten:
			return "Go on"
		if not _has_key:
			return "The door is locked"
		return "Go through" if _door_open else "Open the door"
	if current_level.chest_cells.get(ahead, Vector2i(-1, -1)) == player_pos \
			and not current_level.looted.has(ahead):
		return "Open the chest"
	return ""


# Act: the orb underfoot, or whatever is in front (a chest, the door) — which
# is what walking into it already does.
func _act() -> void:
	if in_combat or menu_open or save_open or orb_open or chest_open or _fading:
		return
	if current_level != null and player_pos in current_level.orb_cells:
		_open_orb("save")
		return
	if facing_prompt() != "":
		_action_forward()


# A pad's left stick walks and turns, one step per push. Every button, the
# d-pad included, goes through the same actions as the keyboard (Controls),
# so Options can rebind either.
const STICK_DEAD: float = 0.6


func _stick_input(m: InputEventJoypadMotion) -> void:
	if m.axis != JOY_AXIS_LEFT_X and m.axis != JOY_AXIS_LEFT_Y:
		return
	if _explore_hud != null:
		_explore_hud.set_pad(true)
	# The stick has to come back to the middle before it counts again, so
	# holding it does not run you down a corridor.
	var held: Vector2i = _stick_held
	var v: int = 0
	if m.axis_value > STICK_DEAD:
		v = 1
	elif m.axis_value < -STICK_DEAD:
		v = -1
	var dir: Vector2i = Vector2i.ZERO
	if m.axis == JOY_AXIS_LEFT_X:
		_stick_held.x = v
		if v != 0 and held.x == 0:
			dir = Vector2i(v, 0)
	else:
		_stick_held.y = v
		if v != 0 and held.y == 0:
			dir = Vector2i(0, v)
	if dir == Vector2i.ZERO or in_combat or menu_open or save_open or orb_open or chest_open:
		return
	if dir.y < 0:
		_action_forward()
	elif dir.y > 0:
		_action_back()
	elif dir.x < 0:
		_action_turn_left()
	else:
		_action_turn_right()


func _input(event: InputEvent) -> void:
	# The screen is black and the floor is changing under it.
	if _fading:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_swipe_start  = event.position
			_swipe_active = true
		else:
			if _swipe_active:
				_handle_swipe(event.position - _swipe_start)
			_swipe_active = false
		return

	if event is InputEventJoypadMotion:
		_stick_input(event as InputEventJoypadMotion)
		return

	var is_key: bool = event is InputEventKey and event.pressed
	var is_pad: bool = event is InputEventJoypadButton and event.pressed
	if not (is_key or is_pad):
		return
	if _explore_hud != null:
		_explore_hud.set_pad(is_pad)
	var key: int = (event as InputEventKey).keycode if is_key else KEY_NONE

	# Q and N are cheats for testing; a release build has neither.
	if OS.is_debug_build() and key == KEY_Q and not in_combat:
		_encounters_enabled = not _encounters_enabled
		_update_encounter_debug_label()
		return

	# N drops a floor where you stand. Debug, alongside Q and F9, and it goes
	# through _descend so a skipped floor arrives in exactly the state a walked
	# one does — key, boss flag, fog and minimap all reset the same way.
	if OS.is_debug_build() and key == KEY_N and not in_combat and not save_open and not orb_open \
			and not chest_open and not menu_open:
		if floor_num >= Level.FLOOR_COUNT:
			_show_hud_popup("[DEBUG] Floor %d is the last one." % floor_num,
					Color(0.55, 0.85, 1.0))
		else:
			_descend()
			_show_hud_popup("[DEBUG] Skipped to floor %d" % (floor_num + 1),
					Color(0.55, 0.85, 1.0))
		return

	if key == KEY_F9 and not in_combat and not save_open and not orb_open \
			and not chest_open:
		if menu_open:
			_close_menu()
		_open_load_menu()
		return

	# × (Escape is always one): close the save picker, then the menu; with
	# nothing open, open the menu. The menu's and the orb's own windows take
	# it first, a step at a time (SidePanel). Blocked during combat.
	if event.is_action_pressed("no"):
		if not in_combat:
			if save_open:
				_close_save_layer()
			elif menu_open:
				_close_menu()
			elif not (orb_open or chest_open):
				_open_menu()
		return

	if in_combat or menu_open or save_open:
		return

	# ○: whatever is in front of you, or the orb underfoot.
	if _explore_hud != null and not orb_open and not chest_open \
			and event.is_action_pressed("yes"):
		_act()
		return

	if event.is_action_pressed("up", true):
		_action_forward()
	elif event.is_action_pressed("down", true):
		_action_back()
	elif event.is_action_pressed("left", true):
		_action_turn_left()
	elif event.is_action_pressed("right", true):
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


# The door and the HUD key follow the same two flags, so they are set together.
func _sync_door() -> void:
	if is_instance_valid(dungeon):
		dungeon.set_locked(not _door_open)
	if _key_icon != null:
		_key_icon.visible = _has_key and not _door_open


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
	Sfx.play("key")
	_show_hud_popup("You take the key. Find the door.", Color(0.75, 0.55, 1.0))


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
	r.tier = Enemy.roamer_tier(floor_num)
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
		_launch_combat(keeper, true)
		return true

	_launch_combat(Enemy.make_group(floor_num))
	return true


# A practice fight bought at an orb. Built at this floor's level, and marked so
# a boss floor does not read the win as the dragon falling. It is the place to
# make money: each monster beaten pays GAUNTLET_PAYOUT times what it cost to
# put in the lineup (OrbUI.gauntlet_price), plus its experience, but no item
# drop. Losing it is losing a fight, with everything that means.
var _in_gauntlet: bool = false
const GAUNTLET_PAYOUT: int = 2


func _start_gauntlet(names: Array[String]) -> void:
	var group: Array[Enemy] = []
	for n: String in names:
		var e: Enemy = Enemy.make_from_name(n, floor_num)
		e.gold_reward = OrbUI.gauntlet_price(n, floor_num) * GAUNTLET_PAYOUT
		group.append(e)
	_in_gauntlet = true
	_launch_combat(group)


func _start_boss_combat() -> void:
	_pending_congratulations = (floor_num >= Level.FLOOR_COUNT)
	# Bosses come alone; their own icon count is what makes them a fight. The
	# Necromancer comes alone too, and does not stay that way.
	var solo: Array[Enemy] = [Enemy.make_necromancer(floor_num)
			if floor_num >= Level.FLOOR_COUNT else Enemy.make_boss(floor_num)]
	_launch_combat(solo)


func _launch_combat(group: Array[Enemy], warden: bool = false) -> void:
	in_combat = true
	Music.play(Music.battle_track(group, floor_num, warden))
	hud_layer.visible = false
	for foe: Enemy in group:
		add_child(foe)
		# The bestiary reads its entries off the monster tables, which the
		# Necromancer is not in: it is the end of the run, not a page.
		if foe.enemy_name not in player_char.encountered_enemies \
				and Enemy.is_known(foe.enemy_name):
			player_char.encountered_enemies.append(foe.enemy_name)
	var combat_layer: CanvasLayer = CanvasLayer.new()
	combat_layer.layer = 20
	add_child(combat_layer)
	# The fight's layout is the build's: upright on a phone, Final Fantasy
	# fashion on a wide screen. The rules are the same in both (CombatScene).
	var scene: CombatScene = CombatSceneSteam.new() if Build.steam() else CombatScenePortable.new()
	scene.name = "CombatScene"
	scene.player = player_char
	# The scene removes negotiated demons from its own list, so hand it a copy
	# and keep the full roster here for the reward tally.
	scene.foes = group.duplicate()
	# Only an ordinary fight can open with an ambush: not the warden, a boss,
	# or a Gauntlet lineup the player paid to face.
	scene.can_ambush = not warden and not _in_gauntlet and not player_char.never_ambushed() \
			and not group.any(
			func(f: Enemy) -> bool: return f.is_dragon() or f.is_necromancer() or f.is_warden())
	# Wide screen: the fight stands on this floor's own stone, in its battle
	# room (Dungeon._build_arena), seen across the full width; the scene only
	# shades it (see _sync_view_width).
	scene.see_through = _explore_hud != null
	_sync_view_width()
	scene.combat_ended.connect(_on_combat_ended.bind(group, combat_layer))
	combat_layer.add_child(scene)


# The dungeon view takes the whole width while a fight is drawn over it, and
# gives the map its column back after.
func _sync_view_width() -> void:
	if _explore_hud == null:
		return
	var left: float = 0.0 if in_combat else float(Layout.MAP_PANE_W)
	if _world_box.offset_left != left:
		_world_box.offset_left = left
		# The fight stands in the floor's battle room, not in the corridor.
		if is_instance_valid(dungeon) and dungeon.arena_camera != null:
			if in_combat:
				dungeon.arena_camera.make_current()
			else:
				cam.make_current()


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
		# Killing a thing teaches you what it was made of — wardens and bosses
		# too. Analyze is the only thing they refuse.
		if not foe.is_alive():
			player_char.record_analysis(foe.lore_name() if foe.abyss_element != "" else foe.enemy_name)
			if result != "lose" and not foe.summoned:
				Records.add("monsters_defeated")
				if foe.is_dragon():
					Records.add("dragons_slain")
				elif foe.is_warden():
					Records.add("wardens_defeated")
		if not foe.is_alive() and item_drop.is_empty() and not _in_gauntlet:
			item_drop = foe.roll_drop()
			if item_drop.is_empty() and "scavenger" in player_char.passive_skills \
					and randi() % 2 == 0:
				item_drop = foe.roll_drop()
	for foe: Enemy in group:
		foe.queue_free()
	combat_layer.queue_free()
	Music.play(Music.dungeon_track(floor_num))

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
		_sync_door()
		Sfx.play("key")
		_show_hud_popup("The warden falls. You take the key.", Color(0.75, 0.55, 1.0))

	# On a boss floor an encounter with no roamer behind it is the boss. Only a
	# win counts: a flee used to pass as "not a loss", so slipping away from the
	# Ice Dragon marked it beaten and the corridor let you walk on past it.
	if result not in ["lose", "flee"] and Level.is_boss_floor(floor_num) and met.is_empty() \
			and not _in_gauntlet:
		_boss_beaten = true
		_sync_boss_banner()
	_in_gauntlet = false

	if not lost.is_empty() and result != "lose":
		_show_hud_popup("Lost for good:  %s" % ", ".join(lost), Color(1.0, 0.45, 0.45))

	# A fight the demons finish after the hero fell is still a win, but he
	# walks out of it on his feet: at 0 HP the corridor stops treating him as
	# alive, and nothing on the floor would move or open for him again.
	if result != "lose":
		player_char.hp = maxi(1, player_char.hp)

	# An ailment wears off after three turns and never outlasts the fight, so
	# nothing follows the player into the corridor. Bound demons are rebuilt
	# per fight and need no clearing.
	player_char.active_statuses.clear()

	match result:
		"win", "talk":
			Records.add("fights_won")
			Records.add("gold_earned", gold_reward)
			player_char.gold += gold_reward
			if result == "win" and not item_drop.is_empty():
				player_char.add_item(item_drop)
			var before: Dictionary = _player_snapshot()
			player_char.gain_exp(exp_reward)
			var after: Dictionary = _player_snapshot()
			var leveled: bool = after["lv"] > before["lv"]
			var demons_before: Dictionary = _demon_snapshots()
			var grew: Dictionary = player_char.award_demon_exp(exp_reward)
			var shown_drop: Dictionary = item_drop if result == "win" else {}
			_show_combat_result(exp_reward, gold_reward, shown_drop,
				before if leveled else {}, after if leveled else {},
				_demon_level_ups(grew, demons_before))
		"bribe":
			var before: Dictionary = _player_snapshot()
			player_char.gain_exp(exp_reward)
			var after: Dictionary = _player_snapshot()
			var leveled: bool = after["lv"] > before["lv"]
			var demons_before_b: Dictionary = _demon_snapshots()
			var grew_b: Dictionary = player_char.award_demon_exp(exp_reward)
			_show_combat_result(exp_reward, 0, {},
				before if leveled else {}, after if leveled else {},
				_demon_level_ups(grew_b, demons_before_b))
		"lose":
			_pending_congratulations = false
			_show_game_over()
		"flee":
			_pending_congratulations = false
			_resume_from_overlay()



# Stats of one bound demon as it would walk into a fight right now.
func _demon_snapshot(demon_name: String) -> Dictionary:
	var e: Enemy = player_char.bound_demon(demon_name)
	var snap: Dictionary = {lv = e.lv, max_hp = e.max_hp, max_mp = e.max_mp,
			str = e.str, def = e.def, mag = e.mag, agl = e.agl}
	e.free()
	return snap


# Taken before demon exp is paid, so each level-up popup can show before -> after.
# The whole roster, since the bench earns a share and can level too.
func _demon_snapshots() -> Dictionary:
	var out: Dictionary = {}
	for demon_name: String in player_char.recruited:
		out[demon_name] = _demon_snapshot(demon_name)
	return out


# One entry per demon that grew in that fight: {name, before, after, learned}.
func _demon_level_ups(grew: Dictionary, before: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var learned: Dictionary = grew.get("learned", {}) as Dictionary
	var offers: Dictionary = grew.get("offers", {}) as Dictionary
	for demon_name: String in (grew.get("climbed", []) as Array):
		out.append({name = demon_name,
				before = before.get(demon_name, {}),
				after = _demon_snapshot(demon_name),
				learned = learned.get(demon_name, []),
				offers = offers.get(demon_name, [])})
	return out


func _show_combat_result(exp: int, gold: int, item: Dictionary,
		lv_before: Dictionary, lv_after: Dictionary,
		demon_ups: Array[Dictionary] = []) -> void:
	var ui: CombatResultUI = CombatResultUI.new()
	ui.exp_gained  = exp
	ui.gold_gained = gold
	ui.item_drop   = item
	ui.dismissed.connect(func():
		ui.queue_free()
		if not lv_before.is_empty():
			_show_level_up(lv_before, lv_after, demon_ups)
		else:
			_show_demon_level_ups(demon_ups)
	)
	_get_overlay_layer().add_child(ui)


# Each demon that grew gets its own popup, one after another, and the corridor
# comes back after the last of them.
func _show_demon_level_ups(queue: Array[Dictionary]) -> void:
	if queue.is_empty():
		_resume_from_overlay()
		return
	var entry: Dictionary = queue[0]
	var rest: Array[Dictionary] = queue.slice(1)
	var ui: DemonLevelUpUI = DemonLevelUpUI.new()
	ui.demon_name = entry["name"] as String
	ui.before     = entry["before"] as Dictionary
	ui.after      = entry["after"] as Dictionary
	ui.learned    = entry["learned"] as Array
	ui.offers     = entry.get("offers", []) as Array
	ui.player     = player_char
	ui.dismissed.connect(func():
		ui.queue_free()
		_show_demon_level_ups(rest)
	)
	_get_overlay_layer().add_child(ui)


func _resume_from_overlay() -> void:
	hud_layer.visible = true
	in_combat = false
	# A fight and everything after it is over; this is a good place to be.
	call_deferred("_autosave")
	if _reopen_orb_tab != "":
		var tab: String = _reopen_orb_tab
		_reopen_orb_tab = ""
		_open_orb(tab)
		return
	if _pending_congratulations:
		_pending_congratulations = false
		_show_congratulations()


# The Necromancer is down: through black into the climb home and the credits,
# and from there back to the title. The run is over.
func _show_congratulations() -> void:
	in_combat = true
	_fading = true
	# The Abyss opens. The first hero to clear it is the one who goes down into
	# it; after that the player is asked, once the credits are done, whether
	# this one should take the old one's place.
	var cleared: Dictionary = _gather_save_data()["player"] as Dictionary
	var ask: bool = Abyss.has_hero()
	var abyss: bool = Abyss.in_build()
	if abyss:
		Abyss.unlock(cleared, not ask)
	Records.add("runs_won")
	Records.set_min("fastest_clear", play_time)
	var fade: ScreenFade = ScreenFade.cover(get_tree(), "", 0.8)
	await fade.covered
	hud_layer.visible = false
	var ui: EndingUI = EndingUI.new()
	# Whoever is still walking with the hero walks home with him.
	for demon_name: String in player_char.active_demons:
		var d: Enemy = player_char.bound_demon(demon_name)
		if d.sprite_id != "":
			ui.team.append(d.sprite_id)
		d.free()
	ui.finished.connect(func() -> void:
		if not abyss:
			pass
		elif ask:
			await _ask_replace_abyss_hero(cleared)
		else:
			await _tell_abyss_unlocked()
		var out: ScreenFade = ScreenFade.cover(get_tree())
		await out.covered
		get_tree().change_scene_to_file("res://scenes/title.tscn")
		out.reveal()
	)
	_get_overlay_layer().add_child(ui)
	fade.reveal(0.8)


# After a second (or later) clear: keep the Abyss hero there is, or put this
# one in its place. Both are shown by level, so the choice is an informed one.
signal _abyss_hero_chosen


# The first clear: say so, or nobody would know the mode is there.
func _tell_abyss_unlocked() -> void:
	var panel: Control = Control.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var veil: ColorRect = ColorRect.new()
	veil.color = Color(0.03, 0.02, 0.06, 1.0)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(veil)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(center)
	var col: VBoxContainer = VBoxContainer.new()
	col.custom_minimum_size = Vector2(440, 0)
	col.add_theme_constant_override("separation", 18)
	center.add_child(col)
	for row: Array in [["CONGRATULATIONS!", 26, Color(0.90, 0.75, 0.30)],
			["You have unlocked\nABYSS MODE", 28, Color(0.78, 0.60, 1.0)],
			["An endless descent for the hero who beat the Necromancer. Find it on the title screen, below Load Game.",
				18, Color(0.85, 0.83, 0.92)]]:
		var l: Label = Label.new()
		l.text = row[0] as String
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_font_override("font", _UI_FONT)
		l.add_theme_font_size_override("font_size", int(row[1]))
		l.add_theme_color_override("font_color", row[2] as Color)
		col.add_child(l)
	var b: Button = Button.new()
	b.text = "CONTINUE"
	b.custom_minimum_size = Vector2(0, 50)
	b.add_theme_font_override("font", _UI_FONT)
	b.pressed.connect(func() -> void: _abyss_hero_chosen.emit())
	col.add_child(b)
	Sfx.play("recruit")
	_get_overlay_layer().add_child(panel)
	await _abyss_hero_chosen
	panel.queue_free()


func _ask_replace_abyss_hero(cleared: Dictionary) -> void:
	var old_lv: int = int(Abyss.cleared_hero().get("lv", 1))
	var new_lv: int = int(cleared.get("lv", 1))
	var panel: Control = Control.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var veil: ColorRect = ColorRect.new()
	veil.color = Color(0.03, 0.02, 0.06, 1.0)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(veil)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(center)
	var col: VBoxContainer = VBoxContainer.new()
	col.custom_minimum_size = Vector2(440, 0)
	col.add_theme_constant_override("separation", 16)
	center.add_child(col)
	var head: Label = Label.new()
	head.text = "THE ABYSS"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_font_override("font", _UI_FONT)
	head.add_theme_font_size_override("font_size", 36)
	head.add_theme_color_override("font_color", Color(0.78, 0.60, 1.0))
	col.add_child(head)
	var q: Label = Label.new()
	q.text = "Which hero goes down into the Abyss?\n\nThe one waiting there now is level %d.\nThe one who just won is level %d." % [old_lv, new_lv]
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	q.add_theme_font_override("font", _UI_FONT)
	q.add_theme_font_size_override("font_size", 18)
	col.add_child(q)
	for pair: Array in [["KEEP THE ONE THERE (LV %d)" % old_lv, false],
			["SEND THIS HERO (LV %d)" % new_lv, true]]:
		var b: Button = Button.new()
		b.text = pair[0] as String
		b.custom_minimum_size = Vector2(0, 50)
		b.add_theme_font_override("font", _UI_FONT)
		var replace: bool = pair[1]
		b.pressed.connect(func() -> void:
			if replace:
				Abyss.unlock(cleared, true)
			_abyss_hero_chosen.emit())
		col.add_child(b)
	_get_overlay_layer().add_child(panel)
	await _abyss_hero_chosen
	panel.queue_free()


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


func _show_level_up(before: Dictionary, after: Dictionary,
		demon_ups: Array[Dictionary] = []) -> void:
	var ui: LevelUpUI = LevelUpUI.new()
	ui.before  = before
	ui.after   = after
	ui.player  = player_char
	ui.dismissed.connect(func():
		ui.queue_free()
		_show_demon_level_ups(demon_ups)
	)
	_get_overlay_layer().add_child(ui)


func _show_game_over() -> void:
	Sfx.play("game_over")
	Records.add("deaths")
	# The Abyss has one life: the run is over, and so is its save. The captain
	# hauls the hero back up first, and the depth reached comes after.
	if Abyss.active:
		Abyss.wipe_run()
		var rescue: IntroUI = IntroUI.new()
		rescue.rescue = true
		rescue.lines = IntroUI.RESCUE_LINES
		rescue.closing_text = "Abyss %d. Back in the light." % Abyss.depth_of(floor_num)
		_get_overlay_layer().add_child(rescue)
		await rescue.finished
		rescue.queue_free()
	var ui: GameOverUI = GameOverUI.new()
	ui.abyss_depth = Abyss.depth_of(floor_num) if Abyss.active else 0
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


# ── Floor hazards ─────────────────────────────────────────────────────────────
#
# One kind per band, after its dragon — see Level.trap_cells. Lava and a live
# spark tile cost the same slice of max HP the old spike trap did, halved by
# armour that resists the element and ignored by any that nulls it. Ice slides
# you on; a teleporter moves you to its partner.

const HAZARD_DAMAGE: float = 0.15

const _HAZARD_NOTES: Dictionary = {
	"ice":   "Ice! You slide until you reach solid floor.",
	"spark": "Charged plates change every two steps. Lit ones hurt: step back and forth to wait.",
	"lava":  "Lava! Fire-resistant armour halves the burn.",
	"tele":  "A teleporter. It carries you to its twin, and back.",
}

# Charged plates count the player's moves on this floor, not time: two groups,
# always opposite, each lit for two steps and dark for two. Two, not one — at
# one step per change every move flips both the tile you reach and its state,
# so walking stays in lock-step and waiting does nothing. At two, stepping back
# and forth once flips the plate ahead, which is the whole of the puzzle.
# Turning is not a step, and standing still never hurts.
var _spark_steps: int = 0


# Which group is lit at a given step count.
static func _spark_live_at(steps: int) -> int:
	return (steps / 2) % 2


# What the plates show: the group that would be lit if you stepped onto it now.
# Damage lands on arrival, so the plates show the arrival, and "do not step on
# a lit plate" is the whole rule the player has to learn. The plate you are
# standing on is the exception: it keeps the state it judged you by (see
# Dungeon.set_spark_live), so lit underfoot means it shocked you.
func _shown_spark_group() -> int:
	return _spark_live_at(_spark_steps + 1)


# The dragon of a boss corridor, waiting in the stairwell at its far end until
# it is beaten. Hung on the dungeon so every rebuild clears it with the rest.
func _sync_boss_banner() -> void:
	if not is_instance_valid(dungeon) or not Level.is_boss_floor(floor_num):
		return
	var old: Node = dungeon.get_node_or_null("DragonBanner")
	if old != null:
		old.queue_free()
	if _boss_beaten:
		return
	var sprite_id: String = ""
	if floor_num >= Level.FLOOR_COUNT:
		sprite_id = Enemy.necro_sprite()
	else:
		var idx: int = clampi(floor_num / maxi(1, Level.BOSS_EVERY) - 1,
				0, Enemy.BOSS_TEMPLATES.size() - 1)
		sprite_id = Enemy.BOSS_TEMPLATES[idx].get("sprite_id", "") as String
	var banner: DragonBanner = DragonBanner.new()
	if not banner.setup(sprite_id):
		banner.free()
		return
	if sprite_id == Enemy.NECRO_STAND_IN:
		banner.modulate = Enemy.NECRO_STAND_IN_TINT
	banner.name = "DragonBanner"
	# Just inside the stairwell the fight starts from, turned to face back
	# down the corridor toward the player.
	var wall: Vector2i = current_level.exit_wall_pos
	var from: Vector2i = current_level.exit_pos
	var toward: Vector3 = Vector3(float(from.x - wall.x), 0.0, float(from.y - wall.y))
	# The Necromancer's corridor ends in wall, not a stairwell: he stands just
	# in front of it rather than in it.
	var inset: float = 0.62 if floor_num >= Level.FLOOR_COUNT else 0.35
	banner.position = Vector3(wall.x * Dungeon.CELL_SIZE, banner.feet_drop,
			wall.y * Dungeon.CELL_SIZE) + toward * (Dungeon.CELL_SIZE * inset)
	banner.rotation = Vector3(0.0, atan2(toward.x, toward.z), 0.0)
	dungeon.add_child(banner)


func _show_sparks() -> void:
	if is_instance_valid(dungeon):
		dungeon.set_spark_live(_shown_spark_group(), player_pos, _spark_live_at(_spark_steps))


func _hazard_here() -> String:
	return current_level.trap_cells.get(player_pos, "") as String


func _note_hazard(kind: String) -> bool:
	if kind in player_char.hazards_seen:
		return false
	player_char.hazards_seen.append(kind)
	_show_hud_popup(_HAZARD_NOTES.get(kind, "") as String, Color(0.85, 0.90, 1.0))
	return true


func _remember_hazard(at: Vector2i) -> void:
	current_level.found_traps[at] = current_level.trap_cells[at]
	minimap_ctrl.queue_redraw()


# Carries the player on across ice in the direction they moved, until solid
# floor, a wall, or a demon in the way. The whole slide is one move: the
# roamers take one step for it and nothing else can happen partway.
func _slide(dir: Vector2i) -> void:
	if _hazard_here() != Level.HAZARD_ICE:
		return
	_note_hazard(Level.HAZARD_ICE)
	var guard: int = 0
	while _hazard_here() == Level.HAZARD_ICE and guard < 32:
		guard += 1
		_remember_hazard(player_pos)
		var nxt: Vector2i = player_pos + dir
		if not _is_open(nxt.x, nxt.y) or _roamer_at(nxt):
			break
		player_pos = nxt
		# Seen on the way past, so the map has no hole down the middle.
		_mark_visited()


func _roamer_at(cell: Vector2i) -> bool:
	for r: Roamer in roamers:
		if is_instance_valid(r) and r.cell == cell:
			return true
	return false


func _check_trap() -> void:
	var here: String = _hazard_here()
	if here == "":
		return
	var kind: String = Level.hazard_kind(here)
	if kind == Level.HAZARD_ICE:
		return    # handled as the move was made
	_remember_hazard(player_pos)
	var first: bool = _note_hazard(kind)
	match kind:
		Level.HAZARD_TELE:
			_teleport(here)
		Level.HAZARD_SPARK:
			if Level.spark_group(here) == _spark_live_at(_spark_steps):
				_hazard_hurt("thunder", "Shocked!", Color(0.55, 0.85, 1.0), first)
		_:
			_hazard_hurt("fire", "Lava!", Color(1.0, 0.45, 0.20), first)


func _hazard_hurt(element: String, what: String, color: Color, quiet: bool) -> void:
	var dmg: int = maxi(1, int(player_char.max_hp * HAZARD_DAMAGE))
	match player_char.affinity_of(element):
		Affinity.RESIST:
			dmg = maxi(1, dmg / 2)
		Affinity.NULL, Affinity.REPEL, Affinity.DRAIN:
			dmg = 0
	Sfx.play("trap")
	if dmg > 0:
		player_char.take_damage(dmg)
		_shake_camera()
	# The first time, the note explaining the tile is on screen instead.
	if not quiet:
		_show_hud_popup("%s  -%d HP" % [what, dmg] if dmg > 0 else "%s  No effect." % what,
				color)
	if not player_char.is_alive():
		_show_game_over()


# Arrives on the partner without setting it off: a teleporter only fires when
# you walk onto it, so stepping off and back on is how to go back.
func _teleport(here: String) -> void:
	var to: Vector2i = Level.tele_target(here)
	if not _is_open(to.x, to.y):
		return
	player_pos = to
	_remember_hazard(to)
	_sync_player()












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
	menu.title_requested.connect(func():
		get_tree().change_scene_to_file("res://scenes/title.tscn")
	)
	_side_parent(menu_layer).add_child(menu)


func _close_menu() -> void:
	if is_instance_valid(menu_layer):
		_side_close(menu_layer)
	# Options may have rebound a key while the menu was up.
	if _explore_hud != null:
		_explore_hud.repaint_keys()
	hud_layer.visible = true
	menu_open = false





# ── The side panel: the menu and the orb on a wide screen ────────────────────
#
# They come in from the left over the map's place and push the map ahead of
# them to the right edge, the view fading under the two; closing runs it back.
# On a phone they are the whole screen, as they always were.

const SIDE_SLIDE: float = 0.32
var _side_tween: Tween


func _side_width() -> float:
	return get_viewport().get_visible_rect().size.x - float(Layout.MAP_PANE_W)


# What a panel is added to: the layer itself on a phone, or a holder that
# slides in on a wide screen.
func _side_parent(layer: CanvasLayer) -> Node:
	if _explore_hud == null:
		return layer
	# The map stays up, pushed aside rather than hidden with the rest.
	hud_layer.visible = true
	# A panel still sliding out goes now, so two never share the slide.
	for old: Node in layer.get_children():
		old.queue_free()
	var w: float = _side_width()
	var holder: Control = Control.new()
	holder.anchor_bottom = 1.0
	holder.offset_right = w
	holder.position.x = -w
	layer.add_child(holder)
	_slide_side(holder, 0.0, 1.0, false)
	return holder


func _side_close(layer: CanvasLayer, instant: bool = false) -> void:
	for child: Node in layer.get_children():
		if _explore_hud == null or instant or not (child is Control):
			child.queue_free()
			continue
		# Out of reach the moment it starts to go, so a key pressed during
		# the slide cannot land on it.
		child.process_mode = Node.PROCESS_MODE_DISABLED
		_slide_side(child as Control, 1.0, 0.0, true)
	if instant and _explore_hud != null:
		_explore_hud.push_map(0.0, _side_width())


func _slide_side(holder: Control, from: float, to: float, free_after: bool) -> void:
	if is_instance_valid(_side_tween):
		_side_tween.kill()
	var w: float = _side_width()
	var step: Callable = func(t: float) -> void:
		if is_instance_valid(holder):
			holder.position.x = -w * (1.0 - t)
		_explore_hud.push_map(t, w)
	step.call(from)
	_side_tween = create_tween()
	_side_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT if to > from else Tween.EASE_IN_OUT)
	_side_tween.tween_method(step, from, to, SIDE_SLIDE)
	if free_after:
		_side_tween.tween_callback(holder.queue_free)

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
		var found: Dictionary = _loot_chest(wall)
		Sfx.play("loot")
		ui.show_found(int(found["gold"]), found["items"] as Array))
	chest_layer.add_child(ui)


# What was in it. Gold always, and better odds of something on top of that
# than a demon carries — a cache you had to find should beat a demon you
# tripped over.
# Returns {gold, items} for the chest panel to show.
func _loot_chest(wall: Vector2i) -> Dictionary:
	current_level.looted[wall] = true

	var coin: int = 25 + floor_num * 20 + (randi() % (20 + floor_num * 10))
	player_char.gold += coin
	var items: Array = []

	var stone: Dictionary = Item.roll_keepsake(Item.STONE_FROM_CHEST, Item.SEED_FROM_CHEST)
	if not stone.is_empty():
		player_char.add_item(stone, 1)
		items.append(stone)
	elif randi() % 100 < 70:
		var item: Dictionary = Item.pick_drop(floor_num).duplicate()
		if not item.is_empty():
			player_char.add_item(item, 1)
			items.append(item)

	_rebuild_dungeon()
	return {gold = coin, items = items}


# Rebuild so an emptied recess reads as emptied.
func _rebuild_dungeon() -> void:
	if is_instance_valid(dungeon):
		dungeon.queue_free()
	dungeon = Dungeon.new()
	world.add_child(dungeon)
	dungeon.build(current_level)
	_show_sparks()
	_sync_boss_banner()
	dungeon.set_viewer(cam_base_pos)
	_sync_door()


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
	ui.gauntlet_requested.connect(func(names: Array[String]) -> void:
		_close_orb()
		_start_gauntlet(names)
	)
	ui.gacha_exp_won.connect(_gacha_exp.bind(ui))
	_side_parent(orb_layer).add_child(ui)


# Experience off the orb's slot machine, paid the way a fight pays it: the hero
# and the roster both. A level-up closes the orb for the same screens a fight
# shows, and the orb comes back on the slot machine after the last of them.
var _reopen_orb_tab: String = ""

func _gacha_exp(amount: int, orb: OrbUI) -> void:
	var before: Dictionary = _player_snapshot()
	player_char.gain_exp(amount)
	var after: Dictionary = _player_snapshot()
	var demons_before: Dictionary = _demon_snapshots()
	var grew: Dictionary = player_char.award_demon_exp(amount)
	var ups: Array[Dictionary] = _demon_level_ups(grew, demons_before)
	var leveled: bool = after["lv"] > before["lv"]
	if not leveled and ups.is_empty():
		return
	# The orb is about to close: no spin may start in the meantime.
	orb.lock_gacha()
	# After the reels have settled and the result is up, not in the middle.
	await get_tree().create_timer(0.8).timeout
	# Set before closing, so the slot machine's music plays on under the
	# level-up screens rather than dipping into the floor's for a moment.
	_reopen_orb_tab = "gacha"
	_close_orb()
	in_combat = true
	hud_layer.visible = false
	if leveled:
		_show_level_up(before, after, ups)
	else:
		_show_demon_level_ups(ups)


func _close_orb() -> void:
	if is_instance_valid(orb_layer):
		# Closing only to come straight back (the slot machine's level-up
		# screens) does not play the slide out.
		_side_close(orb_layer, _reopen_orb_tab != "")
	hud_layer.visible = true
	orb_open = false
	if _reopen_orb_tab == "":
		Music.play(Music.dungeon_track(floor_num))


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


# Writes the autosave slot, but only from a moment a save can come back to:
# walking the floor. Mid-fight, mid-fade, in the Gauntlet or dead, it keeps the
# last one it wrote instead.
func _autosave() -> void:
	if player_char == null or current_level == null:
		return
	if in_combat or _fading or _in_gauntlet or chest_open or not player_char.is_alive():
		return
	SaveSystem.write(SaveSystem.ABYSS_SLOT if Abyss.active else SaveSystem.AUTO_SLOT,
			_gather_save_data())


func _do_save(slot: int) -> void:
	SaveSystem.write(slot, _gather_save_data())
	_close_save_layer()
	_show_hud_popup("Game saved to Slot %d." % slot)


func _do_load(slot: int, through_black: bool = true) -> void:
	var data: Dictionary = SaveSystem.read(slot)
	if data.is_empty():
		return
	# From the title the loading screen is already covering this; in the game
	# the floor would swap in plain view, so it goes through black.
	var fade: ScreenFade = null
	if through_black:
		_fading = true
		fade = ScreenFade.cover(get_tree())
		await fade.covered
	_close_save_layer()
	_restore_save(data)
	if fade != null:
		await get_tree().process_frame
		_fading = false
		fade.reveal()


func _gather_save_data() -> Dictionary:
	var p: PlayerCharacter = player_char
	var visited_serial: Dictionary = {}
	for sp: Variant in visited_by_map.keys():
		visited_serial[sp as String] = SaveSystem.pack_visited(visited_by_map[sp] as Dictionary)

	return {
		timestamp   = Time.get_datetime_string_from_system(),
		abyss       = Abyss.active,
		floor_num   = floor_num,
		play_time   = play_time,
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
			recruited           = p.recruited,
			ever_bound          = p.ever_bound,
			bound_level         = p.bound_level,
			demon_exp           = p.demon_exp,
			demon_gains         = p.demon_gains,
			demon_bonus         = p.demon_bonus,
			demon_skills        = p.demon_skills,
			demon_levels_gained = p.demon_levels_gained,
			demon_element       = p.demon_element,
			active_demons       = p.active_demons,
			encountered_enemies = p.encountered_enemies,
			analyzed            = p.analyzed,
			hazards_seen        = p.hazards_seen,
			learned_affinities  = p.learned_affinities,
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
			looted      = _pack_cell_set(current_level.looted),
			warden      = SaveSystem.vec2i_key(current_level.warden_pos),
			key_pos     = SaveSystem.vec2i_key(current_level.key_pos),
			key_taken   = current_level.key_taken,
			found_traps = _pack_trap_cells(current_level.found_traps),
			has_key     = _has_key,
			door_open   = _door_open,
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
	play_time = float(data.get("play_time", 0.0))
	Abyss.active = bool(data.get("abyss", false))
	_show_floor_title()
	Music.play(Music.dungeon_track(floor_num))

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
	# Caches are saved, so a load does not re-roll where they were and whether
	# they were empty. An older save's "mimics" list is simply ignored.
	var saved_chests: Dictionary = map_data.get("chests", {}) as Dictionary
	if not saved_chests.is_empty():
		current_level.chest_cells.clear()
		for key: Variant in saved_chests.keys():
			current_level.chest_cells[SaveSystem.key_vec2i(key as String)] = \
					SaveSystem.key_vec2i(saved_chests[key] as String)
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
	# Saves from before the door needed turning: holding the key meant open.
	_pending_door_open            = bool(map_data.get("door_open", _pending_has_key))

	_spark_steps = 0
	dungeon = Dungeon.new()
	world.add_child(dungeon)
	dungeon.build(current_level)
	_show_sparks()
	_sync_boss_banner()

	# Restore fog-of-war.
	var raw_visited: Dictionary = data["visited"] as Dictionary
	visited_by_map = {}
	for sp: Variant in raw_visited.keys():
		visited_by_map[sp as String] = SaveSystem.unpack_visited(raw_visited[sp as String] as Array)
	visited = visited_by_map.get(scene_path, {})

	_point_minimap_at_level()
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
	# Analyze used to be a button welded into the battle menu rather than a
	# spell, so a save written then does not know it. Without this the skill
	# simply vanishes from an older run.
	if "analyze" not in player_char.known_spells:
		player_char.known_spells.insert(0, "analyze")
	# Saves written before loadouts existed carry no equipped list; fall back to
	# the first few known spells so those saves still have something to cast.
	# equipped_items, the old belt, is ignored: every consumable reaches a
	# fight now.

	player_char.equipped_spells.clear()
	if pdata.has("equipped_spells"):
		player_char.equipped_spells.assign(pdata["equipped_spells"] as Array)
	else:
		for spell_id: String in player_char.known_spells:
			if not player_char.equip_spell(spell_id):
				break

	player_char.recruited.clear()
	player_char.recruited.assign(pdata.get("recruited", []) as Array)
	player_char.ever_bound.clear()
	# A save written before this existed knows only who is bound right now, so
	# that is what it gets back — better than an empty orb on an old run.
	player_char.ever_bound.assign(
			pdata.get("ever_bound", pdata.get("recruited", [])) as Array)
	player_char.bound_level.clear()
	for k: Variant in (pdata.get("bound_level", {}) as Dictionary):
		player_char.bound_level[k] = int((pdata["bound_level"] as Dictionary)[k])
	# A save written before demons remembered their level: assume the shallow
	# end rather than leaving them at zero.
	for demon_name: String in player_char.recruited:
		if not player_char.bound_level.has(demon_name):
			player_char.bound_level[demon_name] = 2
		# A save written before demons carried a skill list: give it the one it
		# would have been bound with, so an old run is not mute in the menu.
		player_char.seed_demon_skills(demon_name)

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
	player_char.demon_bonus.clear()
	for k: Variant in (pdata.get("demon_bonus", {}) as Dictionary):
		var rawb: Dictionary = (pdata["demon_bonus"] as Dictionary)[k] as Dictionary
		player_char.demon_bonus[k] = {hp = int(rawb.get("hp", 0)), mp = int(rawb.get("mp", 0))}

	player_char.demon_element.clear()
	for k: Variant in (pdata.get("demon_element", {}) as Dictionary):
		player_char.demon_element[k] = (pdata["demon_element"] as Dictionary)[k] as String
	player_char.demon_levels_gained.clear()
	for k: Variant in (pdata.get("demon_levels_gained", {}) as Dictionary):
		player_char.demon_levels_gained[k] = int(
				(pdata["demon_levels_gained"] as Dictionary)[k])
	player_char.demon_skills.clear()
	for k: Variant in (pdata.get("demon_skills", {}) as Dictionary):
		var raw: Array = (pdata["demon_skills"] as Dictionary)[k] as Array
		var list: Array = []
		for entry: Variant in raw:
			var e: Dictionary = entry as Dictionary
			if e.get("kind", "") in ["support", "unique"]:
				list.append({kind = e["kind"] as String, id = e.get("id", "") as String})
			else:
				list.append({kind = "element",
						element = e.get("element", "") as String,
						rung = int(e.get("rung", 1)),
						shape = e.get("shape", Spell.SHAPE_ONE) as String})
		player_char.demon_skills[k] = list
	player_char.top_up_unique_skills()

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
	player_char.hazards_seen.assign(pdata.get("hazards_seen", []) as Array)
	player_char.learned_affinities = (pdata.get("learned_affinities", {}) as Dictionary).duplicate(true)
	# A monster that has since been taken out of the game (the Mimic) drops out
	# of the bestiary rather than showing up as a random stand-in.
	player_char.encountered_enemies.assign(player_char.encountered_enemies.filter(Enemy.is_known))
	player_char.analyzed.assign(player_char.analyzed.filter(Enemy.is_known))
	for gone: Variant in player_char.learned_affinities.keys():
		if not Enemy.is_known(gone as String):
			player_char.learned_affinities.erase(gone)

	# Passive skills are off while they are reworked, so a save that picked some
	# comes back without them rather than keeping powers a new run cannot get.
	player_char.passive_skills.clear()

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


# Every one of these is a reference INTO the level, and both the walk-in and the
# load-a-save path build a brand new Level — so all of them have to be repointed
# or the map is still describing the floor before this one.
#
# It lives in one function because it did not: _restore_save repointed three of
# the seven, so a loaded run came back with no orb, no chest and no sprung trap
# on the map while the level itself knew exactly where all of them were.
func _point_minimap_at_level() -> void:
	minimap_ctrl.maze        = current_level.maze
	minimap_ctrl.visited     = visited
	minimap_ctrl.exit_pos    = current_level.exit_wall_pos
	minimap_ctrl.orb_cells   = current_level.orb_cells
	minimap_ctrl.chest_cells = current_level.chest_cells
	minimap_ctrl.looted      = current_level.looted
	minimap_ctrl.found_traps = current_level.found_traps


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
var _pending_door_open: bool = true


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
		rm.tier = Enemy.roamer_tier(floor_num)
		world.add_child(rm)
		roamers.append(rm)
	_pending_roamers = []

	_has_key = _pending_has_key
	_door_open = _pending_door_open
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
	# A loaded run arrives here with the geometry already built, so the door is
	# hung once _has_key is known rather than during the build.
	_sync_door()


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
		# Thumb-sized on a phone; on a wide screen, under a mouse or a pad, the
		# size the fight's windows use.
		if Build.steam():
			btn.add_theme_font_size_override("font_size", SidePanel.TEXT)
		else:
			btn.add_theme_font_size_override("font_size", 20)
			var cur: Vector2 = btn.custom_minimum_size
			if cur.y > 0:
				btn.custom_minimum_size = Vector2(cur.x, roundf(cur.y * 1.5))
	elif node is Control:
		(node as Control).add_theme_font_override("font", _UI_FONT)
