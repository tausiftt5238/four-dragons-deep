# Main
# Top-level game controller. Owns player state, camera, torch, and minimap.
# Delegates 3D geometry to Dungeon and map data to Level subclasses.
# On startup it loads Map 1; stepping on the portal cell triggers a level swap.
#
# Four parts of it live in files of their own beside this one, each holding a
# reference back to Main: MainSaves (saving and loading), MainScreens (the
# screens laid over the dungeon), MainHazards (each band's floor) and
# MainRoamers (the monsters walking it). docs/architecture.md has the map.
class_name Main extends Node3D

const EYE_HEIGHT: float = 1.0
const _UI_FONT: Font = preload("res://resources/misc/ui_font.tres")

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

# The rest of the run, in files of their own that work on this Main:
var _saves: MainSaves = MainSaves.new(self)        # saving and loading
var _screens: MainScreens = MainScreens.new(self)  # results, level-ups, endings
var _hazards: MainHazards = MainHazards.new(self)  # what each band's floor does
var _roaming: MainRoamers = MainRoamers.new(self)  # the monsters walking the floor


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
# The demo ends once its last boss is down (Build.demo, DEMO_LAST_FLOOR).
var _pending_demo_end: bool = false
# The Abyss's last boss is down (Abyss.END_DEPTH).
var _pending_abyss_end: bool = false
const DEMO_LAST_FLOOR: int = Level.BOSS_EVERY

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
		_saves._autosave()
		Records.flush()
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if not in_combat:
			if save_open:
				_saves._close_save_layer()
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
	get_tree().node_added.connect(_saves._on_node_added)
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
	# A new run's hero is who the intro named (a save or the Abyss brings
	# its own name with it, over this).
	if GameBoot.pending_name != "":
		player_char.hero_name = GameBoot.pending_name
	GameBoot.pending_name = ""

	# An Abyss descent: the hero who beat the game, whole again, at Abyss 1.
	var abyss_intent: String = GameBoot.pending_abyss
	GameBoot.pending_abyss = ""
	Abyss.active = abyss_intent != ""
	if abyss_intent == "new":
		Abyss.run_seed = randi() | 1
		player_char.load_save(Abyss.cleared_hero())
		player_char.hp = player_char.max_hp
		player_char.mp = player_char.max_mp
		player_char.active_statuses.clear()
		floor_num = Abyss.floor_for_depth(1)

	# Load the starting level. _sync_player is called inside here.
	_load_level("res://scenes/map.tscn", true)
	_show_floor_title()

	if abyss_intent == "continue":
		_saves._do_load.call_deferred(SaveSystem.ABYSS_SLOT, false)
	elif abyss_intent == "new":
		Records.add("abyss_runs")
		Abyss.note_depth(1)
		_saves._autosave.call_deferred()
	elif GameBoot.pending_slot <= 0:
		Records.add("runs_started")
	if abyss_intent == "" and GameBoot.pending_slot > 0:
		var slot: int = GameBoot.pending_slot
		GameBoot.pending_slot = 0
		_saves._do_load.call_deferred(slot, false)
	else:
		player_pos    = current_level.player_start
		player_facing = current_level.player_start_facing
		_sync_player()
		_snap_cam_yaw()


# ── Level loading ─────────────────────────────────────────────────────────────

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

	_hazards._spark_steps = 0
	# Build geometry using the level's colours and maze
	dungeon = Dungeon.new()
	world.add_child(dungeon)
	dungeon.build(current_level)
	_hazards._show_sparks()
	_hazards._sync_boss_banner()

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

	_saves._point_minimap_at_level()
	_sync_minimap_palette()
	_resize_minimap()

	_sync_player()
	_snap_cam_yaw()
	_roaming._spawn_roamers()
	# After MainRoamers._spawn_roamers, which is what decides whether this floor holds the
	# key at all and so whether the way on is shut.
	_door_open = _has_key
	_roaming._sync_door()
	Music.play(Music.dungeon_track(floor_num))


# ── One-time setup ────────────────────────────────────────────────────────────

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


# ── Per-frame / movement ──────────────────────────────────────────────────────

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
		if Level.is_necro_floor(floor_num):
			_screens._show_congratulations()
			return
		if Abyss.is_end_floor(floor_num):
			_screens._show_abyss_end()
			return

	if not _has_key:
		_screens._show_hud_popup("The door is locked. Find the key.", Color(0.75, 0.55, 1.0))
		_shake_camera()
		return

	# The first push with the key turns it; the next one goes through.
	if not _door_open:
		_door_open = true
		_roaming._sync_door()
		_screens._show_hud_popup("You turn the key. The door opens.", Color(0.75, 0.55, 1.0))
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
	# The demo goes no deeper than its last boss: a save from there that walks
	# on to the stairs gets the demo's ending again, not the next band.
	if Build.demo() and floor_num >= DEMO_LAST_FLOOR:
		_screens._show_demo_end()
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
	_saves._autosave()


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
		_hazards._slide(DIR_OFFSET[player_facing])
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
		_hazards._slide(-DIR_OFFSET[player_facing])
		Sfx.play("step")
		_post_move()
	else:
		_shake_camera()


# A step to the side without turning (the PC build's strafe): `side` is -1
# for left, 1 for right.
func _action_strafe(side: int) -> void:
	var dir: Vector2i = DIR_OFFSET[(player_facing + 4 + side) % 4]
	var nxt: Vector2i = player_pos + dir
	if _is_open(nxt.x, nxt.y):
		player_pos = nxt
		_hazards._slide(dir)
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
	_hazards._spark_steps += 1
	_sync_player()
	_recover_mp_on_step()
	_roaming._take_key_here()
	_hazards._check_trap()
	_hazards._show_sparks()
	if not player_char.is_alive():
		return
	# Walking into a roamer counts before it gets its own step, which is also
	# what stops the two swapping straight through one another.
	if _roaming._engage_roamer_here():
		return
	_roaming._step_roamers()
	if _roaming._engage_roamer_here():
		return
	if player_pos in current_level.orb_cells:
		_open_orb()


# Whether the hero may take a step or turn: not while a fight (and the screens
# after it), the menu, the orb, a chest or the save slots are up, nor while
# the floor changes behind black. Every way of moving asks this.
func _can_walk() -> bool:
	return not (in_combat or menu_open or save_open or orb_open or chest_open or _fading)


func _handle_swipe(delta: Vector2) -> void:
	if not _can_walk():
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


# ── The wide-screen HUD's questions and buttons ───────────────────────────────

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
	if dir == Vector2i.ZERO or not _can_walk():
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
	var key: int = (event as InputEventKey).keycode if is_key else KEY_NONE

	# Q and N are cheats for testing; a release build has neither.
	# Q is also the PC build's strafe left; strafing wins.
	if OS.is_debug_build() and key == KEY_Q and not in_combat \
			and not (Build.steam() and event.is_action("strafe_left")):
		_encounters_enabled = not _encounters_enabled
		_update_encounter_debug_label()
		return

	# N drops a floor where you stand. Debug, alongside Q and F9, and it goes
	# through _descend so a skipped floor arrives in exactly the state a walked
	# one does — key, boss flag, fog and minimap all reset the same way.
	if OS.is_debug_build() and key == KEY_N and not in_combat and not save_open and not orb_open \
			and not chest_open and not menu_open:
		if floor_num >= Level.FLOOR_COUNT:
			_screens._show_hud_popup("[DEBUG] Floor %d is the last one." % floor_num,
					Color(0.55, 0.85, 1.0))
		else:
			_descend()
			_screens._show_hud_popup("[DEBUG] Skipped to floor %d" % (floor_num + 1),
					Color(0.55, 0.85, 1.0))
		return

	if key == KEY_F9 and not in_combat and not save_open and not orb_open \
			and not chest_open:
		if menu_open:
			_close_menu()
		_saves._open_load_menu()
		return

	# × (Escape is always one): close the save picker, then the menu; with
	# nothing open, open the menu. The menu's and the orb's own windows take
	# it first, a step at a time (SidePanel). Blocked during combat.
	if event.is_action_pressed("no"):
		if not in_combat:
			if save_open:
				_saves._close_save_layer()
			elif menu_open:
				_close_menu()
			elif not (orb_open or chest_open):
				_open_menu()
		return

	if not _can_walk():
		return

	# ○: whatever is in front of you, or the orb underfoot.
	if _explore_hud != null and event.is_action_pressed("yes"):
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
	elif Build.steam() and event.is_action_pressed("strafe_left", true):
		_action_strafe(-1)
	elif Build.steam() and event.is_action_pressed("strafe_right", true):
		_action_strafe(1)


# ── Encounter system ──────────────────────────────────────────────────────────

# Only the abnormal half of the toggle is worth saying out loud. With roamers on
# the HUD stays clean; with them off the floor is silent for a reason, and that
# is exactly when a label earns its place.
func _update_encounter_debug_label() -> void:
	_encounter_debug_lbl.visible = not _encounters_enabled
	_encounter_debug_lbl.text = "[DEBUG] Roamers: OFF"
	_encounter_debug_lbl.add_theme_color_override("font_color", Color(0.90, 0.35, 0.35))


# ── Starting a fight ──────────────────────────────────────────────────────────

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
	_pending_congratulations = Level.is_necro_floor(floor_num)
	_pending_demo_end = Build.demo() and floor_num == DEMO_LAST_FLOOR
	_pending_abyss_end = Abyss.is_end_floor(floor_num)
	# Bosses come alone; their own icon count is what makes them a fight. The
	# Necromancer comes alone too, and does not stay that way.
	var solo: Array[Enemy] = []
	if Level.is_necro_floor(floor_num):
		solo.append(Enemy.make_necromancer(floor_num))
	elif Abyss.boss_floor(floor_num):
		solo.append(Enemy.make_abyss_boss(floor_num, Abyss.boss_for_depth(Abyss.depth_of(floor_num))))
	else:
		solo.append(Enemy.make_boss(floor_num))
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
	scene.floor_num = floor_num
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


# ── After a fight ─────────────────────────────────────────────────────────────

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
	# A win keeps the field up under the results, the party hopping on it, and
	# the foes it still draws; both go once the results are done with
	# (MainScreens._clear_victory). Anything else ends the fight on the spot.
	if result == "win":
		_screens._victory_layer = combat_layer
		_screens._victory_foes = group
	else:
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
				var spot: Vector2i = _roaming._far_open_cell(5)
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
		_roaming._sync_door()
		Sfx.play("key")
		_screens._show_hud_popup("The warden falls. You take the key.", Color(0.75, 0.55, 1.0))

	# On a boss floor an encounter with no roamer behind it is the boss. Only a
	# win counts: a flee used to pass as "not a loss", so slipping away from the
	# Ice Dragon marked it beaten and the corridor let you walk on past it.
	if result not in ["lose", "flee"] and Level.is_boss_floor(floor_num) and met.is_empty() \
			and not _in_gauntlet:
		_boss_beaten = true
		_hazards._sync_boss_banner()
	_in_gauntlet = false

	if not lost.is_empty() and result != "lose":
		_screens._show_hud_popup("Lost for good:  %s" % ", ".join(lost), Color(1.0, 0.45, 0.45))

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
		"win", "talk", "bribe":
			# Every way out but running pays the experience. A bribe pays no
			# gold (you were the one paying), and only a kill drops anything.
			var paid: int = 0 if result == "bribe" else gold_reward
			var drop: Dictionary = item_drop if result == "win" else {}
			if result != "bribe":
				Records.add("fights_won")
				Records.add("gold_earned", paid)
			player_char.gold += paid
			if not drop.is_empty():
				player_char.add_item(drop)
			var before: Dictionary = _screens._player_snapshot()
			player_char.gain_exp(exp_reward)
			var after: Dictionary = _screens._player_snapshot()
			var leveled: bool = after["lv"] > before["lv"]
			var demons_before: Dictionary = _demon_snapshots()
			var grew: Dictionary = player_char.award_demon_exp(exp_reward)
			_screens._show_combat_result(exp_reward, paid, drop,
				before if leveled else {}, after if leveled else {},
				_demon_level_ups(grew, demons_before))
		"lose":
			_pending_congratulations = false
			_pending_demo_end = false
			_pending_abyss_end = false
			_screens._show_game_over()
		"flee":
			_pending_congratulations = false
			_pending_demo_end = false
			_pending_abyss_end = false
			_screens._resume_from_overlay()


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


# ── Menu ──────────────────────────────────────────────────────────────────────

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
		_saves._open_load_menu()
	)
	menu.title_requested.connect(func():
		get_tree().change_scene_to_file("res://scenes/title.tscn")
	)
	menu.respec_requested.connect(func(item: Dictionary) -> void:
		_screens._show_respec(item, menu)
	)
	menu.quit_requested.connect(func():
		_saves._autosave()
		Records.flush()
		get_tree().quit()
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


# ── The side panel: the menu and the orb on a wide screen ─────────────────────
#
# They come in from the left over the map's place and push the map ahead of
# them to the right edge, the view fading under the two; closing runs it back.
# On a phone they are the whole screen, as they always were.

const SIDE_SLIDE: float = 0.32
var _side_tween: Tween
var _side_leaving: Control


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
	# A panel still on its way out when the next slide starts (the menu opened
	# just as the orb closed) would lose the tween that frees it.
	if is_instance_valid(_side_leaving):
		_side_leaving.queue_free()
	_side_leaving = holder if free_after else null
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

# ── Chests ────────────────────────────────────────────────────────────────────

func _open_chest(wall: Vector2i) -> void:
	chest_open = true
	hud_layer.visible = false
	if not is_instance_valid(chest_layer):
		chest_layer = CanvasLayer.new()
		chest_layer.layer = 15
		add_child(chest_layer)
		Layout.focus_arrivals(chest_layer)
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

	var stone: Dictionary = Item.roll_keepsake(Item.STONE_FROM_CHEST, Item.SEED_FROM_CHEST,
			Item.LETHE_FROM_CHEST)
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
	_hazards._show_sparks()
	_hazards._sync_boss_banner()
	dungeon.set_viewer(cam_base_pos)
	_roaming._sync_door()


func _close_chest() -> void:
	chest_open = false
	hud_layer.visible = true
	if is_instance_valid(chest_layer):
		for child: Node in chest_layer.get_children():
			child.queue_free()


# ── The orb: rest, shop, gacha ────────────────────────────────────────────────

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
		_saves._open_save_menu()
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
	var before: Dictionary = _screens._player_snapshot()
	player_char.gain_exp(amount)
	var after: Dictionary = _screens._player_snapshot()
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
		_screens._show_level_up(before, after, ups)
	else:
		_screens._show_demon_level_ups(ups)


# Debug only (the playtester's grind): the hero climbs `levels` and every
# demon on the roster catches up to him, through the same screens a fight's
# exp shows. Does nothing in a release build.
func debug_level_party(levels: int) -> void:
	if not OS.is_debug_build() or levels <= 0 or in_combat:
		return
	var hero_exp: int = player_char.exp_to_next - player_char.exp
	for i: int in range(1, levels):
		hero_exp += CharacterSheet.hero_exp_to_next(player_char.lv + i)
	var before: Dictionary = _screens._player_snapshot()
	player_char.gain_exp(hero_exp)
	var after: Dictionary = _screens._player_snapshot()
	# Twice the whole climb from level 1, so the bench's half share gets
	# there too; a demon stops at the hero's level whatever it is paid.
	var demon_exp: int = 0
	for lv: int in range(1, player_char.lv):
		demon_exp += PlayerCharacter.demon_exp_to_next(lv)
	var demons_before: Dictionary = _demon_snapshots()
	var grew: Dictionary = player_char.award_demon_exp(demon_exp * 2)
	var ups: Array[Dictionary] = _demon_level_ups(grew, demons_before)
	in_combat = true
	hud_layer.visible = false
	_screens._show_level_up(before, after, ups)


func _close_orb() -> void:
	if is_instance_valid(orb_layer):
		# Closing only to come straight back (the slot machine's level-up
		# screens) does not play the slide out.
		_side_close(orb_layer, _reopen_orb_tab != "")
	hud_layer.visible = true
	orb_open = false
	if _reopen_orb_tab == "":
		Music.play(Music.dungeon_track(floor_num))

