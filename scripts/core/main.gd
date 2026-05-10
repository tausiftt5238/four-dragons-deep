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
var hud_layer: CanvasLayer       # CanvasLayer holding the minimap; hidden during combat

var player_char: PlayerCharacter  # RPG stats — persists across encounters and floors
var in_combat:  bool = false
var menu_open:  bool = false
var store_open: bool = false
var save_open:  bool = false

var _encounters_enabled: bool = true
var _encounter_debug_lbl: Label
var menu_layer:    CanvasLayer
var store_layer:   CanvasLayer
var save_layer:    CanvasLayer
var overlay_layer: CanvasLayer  # Layer 25 — level-up and game-over screens

var _chest_popup:       Label   # brief "Found X!" label in the HUD
var _chest_popup_tween: Tween

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

	# Create the player's persistent RPG character.
	player_char = PlayerCharacter.new()
	add_child(player_char)

	# Load Map 1 as the starting level. _sync_player is called inside here.
	_load_level("res://scenes/map.tscn", true)


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
	minimap_ctrl.exit_pos  = current_level.exit_wall_pos
	minimap_ctrl.store_pos = current_level.store_wall_pos
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
	hud_layer = CanvasLayer.new()
	hud_layer.layer = 10  # Renders above all 3D content
	add_child(hud_layer)
	var layer: CanvasLayer = hud_layer

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

	_chest_popup = Label.new()
	_chest_popup.anchor_left   = 0.0
	_chest_popup.anchor_right  = 1.0
	_chest_popup.anchor_top    = 1.0
	_chest_popup.anchor_bottom = 1.0
	_chest_popup.offset_top    = -80.0
	_chest_popup.offset_bottom = -46.0
	_chest_popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_chest_popup.add_theme_color_override("font_color", Color(1.0, 0.88, 0.28))
	_chest_popup.modulate.a = 0.0
	layer.add_child(_chest_popup)

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
		tween.tween_property(cam, "position", cam_base_pos + offset, step)
	tween.tween_property(cam, "position", cam_base_pos, step)


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	if event.keycode == KEY_Q and not in_combat:
		_encounters_enabled = not _encounters_enabled
		_update_encounter_debug_label()
		return

	if event.keycode == KEY_F5 and not in_combat and not store_open and not save_open:
		if menu_open:
			_close_menu()
		_open_save_menu()
		return

	if event.keycode == KEY_F9 and not in_combat and not store_open and not save_open:
		if menu_open:
			_close_menu()
		_open_load_menu()
		return

	# ESC: close save picker → close store → close menu → open menu. Blocked during combat.
	if event.keycode == KEY_ESCAPE:
		if not in_combat:
			if save_open:
				_close_save_layer()
			elif store_open:
				_close_store()
			elif menu_open:
				_close_menu()
			else:
				_open_menu()
		return
	if in_combat or menu_open or store_open or save_open:
		return
	var moved: bool = false
	match event.keycode:
		KEY_UP:
			var nxt: Vector2i = player_pos + DIR_OFFSET[player_facing]
			if _is_open(nxt.x, nxt.y):
				player_pos = nxt
				moved = true
			elif nxt == current_level.exit_wall_pos and player_pos == current_level.exit_pos:
				_check_portal()
			elif nxt == current_level.store_wall_pos and player_pos == current_level.store_entry_pos:
				_open_store()
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
		_check_step_poison()
		if player_char.is_alive() and not _check_chest():
			_check_encounter()


# ── Encounter system ─────────────────────────────────────────────────────────

func _update_encounter_debug_label() -> void:
	if _encounters_enabled:
		_encounter_debug_lbl.text = "[DEBUG] Encounters: ON"
		_encounter_debug_lbl.add_theme_color_override("font_color", Color(0.45, 0.90, 0.45))
	else:
		_encounter_debug_lbl.text = "[DEBUG] Encounters: OFF"
		_encounter_debug_lbl.add_theme_color_override("font_color", Color(0.90, 0.35, 0.35))


func _check_encounter() -> void:
	if _encounters_enabled and randi() % 5 == 0:
		_start_combat()


func _start_combat() -> void:
	in_combat = true
	hud_layer.visible = false

	var foe: Enemy = Enemy.make_random(floor_num)
	add_child(foe)

	var combat_layer: CanvasLayer = CanvasLayer.new()
	combat_layer.layer = 20  # Above the HUD
	add_child(combat_layer)

	var packed: PackedScene = load("res://scenes/combat.tscn") as PackedScene
	var scene: CombatScene = packed.instantiate() as CombatScene
	scene.player = player_char
	scene.enemy  = foe
	scene.combat_ended.connect(_on_combat_ended.bind(foe, combat_layer))
	combat_layer.add_child(scene)


func _on_combat_ended(result: String, foe: Enemy, combat_layer: CanvasLayer) -> void:
	var exp_reward:  int        = foe.exp_reward
	var gold_reward: int        = foe.gold_reward
	var item_drop:   Dictionary = foe.roll_drop()
	foe.queue_free()
	combat_layer.queue_free()

	match result:
		"win":
			player_char.gold += gold_reward
			if not item_drop.is_empty():
				player_char.add_item(item_drop)
			var before: Dictionary = _player_snapshot()
			player_char.gain_exp(exp_reward)
			var after: Dictionary = _player_snapshot()
			var leveled: bool = after["lv"] > before["lv"]
			_show_combat_result(exp_reward, gold_reward, item_drop,
				before if leveled else {}, after if leveled else {})
		"lose":
			_show_game_over()
		"flee":
			_resume_from_overlay()


func _show_combat_result(exp: int, gold: int, item: Dictionary,
		lv_before: Dictionary, lv_after: Dictionary) -> void:
	var ui: CombatResultUI = CombatResultUI.new()
	ui.exp_gained  = exp
	ui.gold_gained = gold
	ui.item_drop   = item
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


func _player_snapshot() -> Dictionary:
	return {
		lv=player_char.lv, str=player_char.str, def=player_char.def,
		mag=player_char.mag, agl=player_char.agl,
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
	ui.try_again.connect(func():
		ui.queue_free()
		player_char.active_statuses.clear()
		player_char.heal(player_char.max_hp)
		player_char.restore_mp(player_char.max_mp)
		player_pos    = current_level.player_start
		player_facing = current_level.player_start_facing
		_sync_player()
		_snap_cam_yaw()
		_resume_from_overlay()
	)
	ui.load_game.connect(func():
		ui.queue_free()
		in_combat = false
		_open_load_menu()
	)
	_get_overlay_layer().add_child(ui)


# ── Chest system ──────────────────────────────────────────────────────────────

func _check_chest() -> bool:
	if not current_level.chest_items.has(player_pos):
		return false
	var item: Dictionary = (current_level.chest_items[player_pos] as Dictionary).duplicate()
	current_level.chest_items.erase(player_pos)
	dungeon.remove_chest(player_pos)
	player_char.add_item(item)
	_show_hud_popup("Found:  " + item["name"] + "!")
	return true


func _show_hud_popup(text: String, color: Color = Color(1.0, 0.88, 0.28)) -> void:
	_chest_popup.text = text
	_chest_popup.add_theme_color_override("font_color", color)
	_chest_popup.modulate.a = 1.0
	if is_instance_valid(_chest_popup_tween):
		_chest_popup_tween.kill()
	_chest_popup_tween = create_tween()
	_chest_popup_tween.tween_interval(1.8)
	_chest_popup_tween.tween_property(_chest_popup, "modulate:a", 0.0, 0.6)


func _check_step_poison() -> void:
	if not player_char.has_status(Status.POISON):
		return
	var dmg: int = max(1, int(player_char.max_hp * 0.05))
	player_char.take_damage(dmg)
	_show_hud_popup("Poison  -%d HP" % dmg, Color(0.55, 0.90, 0.30))
	if not player_char.is_alive():
		_show_game_over()


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
	menu.save_requested.connect(func():
		_close_menu()
		_open_save_menu()
	)
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


func _open_store() -> void:
	store_open = true
	hud_layer.visible = false

	if not is_instance_valid(store_layer):
		store_layer = CanvasLayer.new()
		store_layer.layer = 15
		add_child(store_layer)

	var packed: PackedScene = load("res://scenes/store.tscn") as PackedScene
	var store: StoreUI = packed.instantiate() as StoreUI
	store.player = player_char
	store.store_closed.connect(_close_store)
	store_layer.add_child(store)


func _close_store() -> void:
	if is_instance_valid(store_layer):
		for child: Node in store_layer.get_children():
			child.queue_free()
	hud_layer.visible = true
	store_open = false


# ── Save / Load ───────────────────────────────────────────────────────────────

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
			lv = p.lv, str = p.str, def = p.def, mag = p.mag, agl = p.agl,
			exp = p.exp, exp_to_next = p.exp_to_next,
			hp = p.hp, max_hp = p.max_hp, mp = p.mp, max_mp = p.max_mp,
			gold = p.gold,
			known_spells    = p.known_spells,
			active_statuses = p.active_statuses,
			inventory       = p.inventory,
			equipped_weapon = p.equipped_weapon,
			equipped_armor  = p.equipped_armor,
		},
		map = {
			scene       = "res://scenes/map.tscn",
			maze        = current_level.maze,
			exit_wall   = [current_level.exit_wall_pos.x,   current_level.exit_wall_pos.y],
			exit_pos    = [current_level.exit_pos.x,        current_level.exit_pos.y],
			store_wall  = [current_level.store_wall_pos.x,  current_level.store_wall_pos.y],
			store_entry = [current_level.store_entry_pos.x, current_level.store_entry_pos.y],
			chest_items = SaveSystem.pack_chest_items(current_level.chest_items),
		},
		visited = visited_serial,
	}


func _restore_save(data: Dictionary) -> void:
	in_combat  = false
	menu_open  = false
	store_open = false
	if is_instance_valid(overlay_layer):
		for c: Node in overlay_layer.get_children():
			c.queue_free()
	if is_instance_valid(menu_layer):
		for c: Node in menu_layer.get_children():
			c.queue_free()
	if is_instance_valid(store_layer):
		for c: Node in store_layer.get_children():
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
	add_child(current_level)

	# Overwrite the freshly-generated maze with the saved layout.
	var raw_maze: Array = map_data["maze"] as Array
	var saved_maze: Array[Array] = []
	for row: Variant in raw_maze:
		saved_maze.append(row as Array)
	current_level.maze = saved_maze

	var ew: Array  = map_data["exit_wall"]   as Array
	var ep: Array  = map_data["exit_pos"]    as Array
	var sw: Array  = map_data["store_wall"]  as Array
	var se: Array  = map_data["store_entry"] as Array
	current_level.exit_wall_pos   = Vector2i(int(ew[0]), int(ew[1]))
	current_level.exit_pos        = Vector2i(int(ep[0]), int(ep[1]))
	current_level.store_wall_pos  = Vector2i(int(sw[0]), int(sw[1]))
	current_level.store_entry_pos = Vector2i(int(se[0]), int(se[1]))
	current_level.next_scene      = scene_path
	current_level.chest_items     = SaveSystem.unpack_chest_items(map_data["chest_items"] as Dictionary)

	dungeon = Dungeon.new()
	add_child(dungeon)
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
	minimap_ctrl.store_pos = current_level.store_wall_pos
	_resize_minimap()

	var pos_arr: Array = data["player_pos"] as Array
	player_pos    = Vector2i(int(pos_arr[0]), int(pos_arr[1]))
	player_facing = int(data["player_facing"])

	_sync_player()
	_snap_cam_yaw()
	hud_layer.visible = true


func _apply_player_data(pdata: Dictionary) -> void:
	player_char.lv          = int(pdata["lv"])
	player_char.str         = int(pdata["str"])
	player_char.def         = int(pdata["def"])
	player_char.mag         = int(pdata["mag"])
	player_char.agl         = int(pdata["agl"])
	player_char.exp         = int(pdata["exp"])
	player_char.exp_to_next = int(pdata["exp_to_next"])
	player_char.hp          = int(pdata["hp"])
	player_char.max_hp      = int(pdata["max_hp"])
	player_char.mp          = int(pdata["mp"])
	player_char.max_mp      = int(pdata["max_mp"])
	player_char.gold        = int(pdata["gold"])

	player_char.known_spells.clear()
	player_char.known_spells.assign(pdata["known_spells"] as Array)

	player_char.active_statuses.clear()
	player_char.active_statuses.assign(pdata["active_statuses"] as Array)

	player_char.inventory.clear()
	player_char.inventory.assign(pdata["inventory"] as Array)

	player_char.equipped_weapon = pdata.get("equipped_weapon", {}) as Dictionary
	player_char.equipped_armor  = pdata.get("equipped_armor",  {}) as Dictionary
