# Dungeon
# Turns a Level's maze data into 3D geometry and sets up the world environment.
# Accepts the full Level object so wall/floor/ceiling colours and portal position
# come from the level definition — no hardcoded values here.
class_name Dungeon extends Node3D

# World-space size of one grid cell. Referenced by main.gd via Dungeon.CELL_SIZE
# so the value lives in exactly one place.
const CELL_SIZE: float = 2.0

# Height of wall blocks.
const WALL_HEIGHT: float = 2.0

# Chest root nodes keyed by grid position so they can be removed on pickup.
var _chest_nodes: Dictionary = {}


# Entry point — call once after adding Dungeon to the scene tree.
# Reads all visual settings and the portal position from the Level.
func build(level: Level) -> void:
	_build_geometry(level)
	if level.exit_pos.x >= 0 and level.exit_wall_pos.x >= 0:
		_add_exit_marker(level.exit_wall_pos, level.exit_pos)
	_add_chests(level)
	if level.store_entry_pos.x >= 0:
		_add_store_marker(level.store_wall_pos, level.store_entry_pos)
	_setup_environment()


# Iterates every cell in the maze and spawns the appropriate mesh.
# Walls get a full-height box; open cells get a thin floor slab and ceiling slab.
# All boxes of the same type share one material instance to keep draw calls low.
func _build_geometry(level: Level) -> void:
	var wall_mat: StandardMaterial3D = StandardMaterial3D.new()
	wall_mat.albedo_color = level.wall_color
	wall_mat.roughness = 1.0

	var floor_mat: StandardMaterial3D = StandardMaterial3D.new()
	floor_mat.albedo_color = level.floor_color
	floor_mat.roughness = 1.0

	var ceil_mat: StandardMaterial3D = StandardMaterial3D.new()
	ceil_mat.albedo_color = level.ceil_color
	ceil_mat.roughness = 1.0

	for row in range(level.maze.size()):
		var row_data: Array = level.maze[row]
		for col in range(row_data.size()):
			# Row maps to Z axis, column maps to X axis.
			var wx: float = col * CELL_SIZE
			var wz: float = row * CELL_SIZE
			if row_data[col] == 1:
				_add_box(Vector3(wx, WALL_HEIGHT * 0.5, wz),
						Vector3(CELL_SIZE, WALL_HEIGHT, CELL_SIZE), wall_mat)
			else:
				# Floor slab sits just below y=0 so there is no visible gap
				_add_box(Vector3(wx, -0.05, wz),
						Vector3(CELL_SIZE, 0.1, CELL_SIZE), floor_mat)
				# Ceiling slab sits just above WALL_HEIGHT for the same reason
				_add_box(Vector3(wx, WALL_HEIGHT + 0.05, wz),
						Vector3(CELL_SIZE, 0.1, CELL_SIZE), ceil_mat)


# Glowing teal panel on the wall face adjacent to the portal floor tile.
# dir = entry_pos - wall_pos identifies the accessible face.
func _add_exit_marker(wall_pos: Vector2i, entry_pos: Vector2i) -> void:
	var dir: Vector2i = entry_pos - wall_pos
	var wx: float = wall_pos.x * CELL_SIZE
	var wz: float = wall_pos.y * CELL_SIZE

	var px: float = wx + dir.x * (CELL_SIZE * 0.5 + 0.05)
	var pz: float = wz + dir.y * (CELL_SIZE * 0.5 + 0.05)
	var py: float = WALL_HEIGHT * 0.5

	var panel_size: Vector3
	if dir.x != 0:
		panel_size = Vector3(0.08, WALL_HEIGHT * 0.75, CELL_SIZE * 0.80)
	else:
		panel_size = Vector3(CELL_SIZE * 0.80, WALL_HEIGHT * 0.75, 0.08)

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.0, 0.55, 0.38)
	mat.emission_enabled = true
	mat.emission = Color(0.0, 0.55, 0.38)
	mat.emission_energy_multiplier = 2.5
	_add_box(Vector3(px, py, pz), panel_size, mat)

	var light: OmniLight3D = OmniLight3D.new()
	light.light_color  = Color(0.2, 1.0, 0.6)
	light.light_energy = 1.5
	light.omni_range   = 4.0
	light.position     = Vector3(px, py, pz)
	add_child(light)
	_add_wall_label("NEXT FLOOR", Vector3(px, WALL_HEIGHT * 0.95, pz), dir, Color(0.20, 1.0, 0.70))


# Spawns a visible chest model at each position in level.chest_items.
func _add_chests(level: Level) -> void:
	for pos: Variant in level.chest_items.keys():
		_add_chest_marker(pos as Vector2i)


# Builds a small treasure chest (body + lid + gold trim + amber light) for one cell.
func _add_chest_marker(pos: Vector2i) -> void:
	var wx: float = pos.x * CELL_SIZE
	var wz: float = pos.y * CELL_SIZE

	var root: Node3D = Node3D.new()
	root.position = Vector3(wx, 0.0, wz)
	add_child(root)
	_chest_nodes[pos] = root

	var body_mat: StandardMaterial3D = StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.45, 0.28, 0.12)
	body_mat.roughness    = 0.85
	_add_box_child(root, Vector3(0, 0.22, 0), Vector3(0.70, 0.44, 0.50), body_mat)

	var lid_mat: StandardMaterial3D = StandardMaterial3D.new()
	lid_mat.albedo_color = Color(0.58, 0.40, 0.18)
	lid_mat.roughness    = 0.75
	_add_box_child(root, Vector3(0, 0.50, 0), Vector3(0.72, 0.14, 0.52), lid_mat)

	# Emissive gold trim along the seam between body and lid
	var trim_mat: StandardMaterial3D = StandardMaterial3D.new()
	trim_mat.albedo_color            = Color(0.90, 0.72, 0.15)
	trim_mat.emission_enabled        = true
	trim_mat.emission                = Color(0.90, 0.72, 0.15)
	trim_mat.emission_energy_multiplier = 1.8
	_add_box_child(root, Vector3(0, 0.455, 0), Vector3(0.73, 0.04, 0.53), trim_mat)

	# Soft amber glow overhead so the chest is visible from a distance
	var light: OmniLight3D = OmniLight3D.new()
	light.light_color  = Color(1.0, 0.80, 0.30)
	light.light_energy = 1.4
	light.omni_range   = 3.5
	light.position     = Vector3(0, WALL_HEIGHT * 0.55, 0)
	root.add_child(light)


# Glowing purple panel on the wall face that the player walks toward.
# dir = entry_pos - wall_pos tells us which face of the wall is accessible.
func _add_store_marker(wall_pos: Vector2i, entry_pos: Vector2i) -> void:
	var dir: Vector2i = entry_pos - wall_pos
	var wx: float = wall_pos.x * CELL_SIZE
	var wz: float = wall_pos.y * CELL_SIZE

	# Place the panel at the wall face, protruding 0.05 units into the corridor.
	var px: float = wx + dir.x * (CELL_SIZE * 0.5 + 0.05)
	var pz: float = wz + dir.y * (CELL_SIZE * 0.5 + 0.05)
	var py: float = WALL_HEIGHT * 0.5

	# Panel is thin along the approach axis and wide along the perpendicular.
	var panel_size: Vector3
	if dir.x != 0:
		panel_size = Vector3(0.08, WALL_HEIGHT * 0.75, CELL_SIZE * 0.80)
	else:
		panel_size = Vector3(CELL_SIZE * 0.80, WALL_HEIGHT * 0.75, 0.08)

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.40, 0.10, 0.80)
	mat.emission_enabled = true
	mat.emission = Color(0.40, 0.10, 0.80)
	mat.emission_energy_multiplier = 2.5
	_add_box(Vector3(px, py, pz), panel_size, mat)

	var light: OmniLight3D = OmniLight3D.new()
	light.light_color  = Color(0.65, 0.35, 1.0)
	light.light_energy = 1.5
	light.omni_range   = 4.0
	light.position     = Vector3(px, py, pz)
	add_child(light)
	_add_wall_label("SHOP", Vector3(px, WALL_HEIGHT * 0.95, pz), dir, Color(0.75, 0.40, 1.0))


# Flat label above a wall marker, facing the same direction as the panel.
# dir = entry_pos - wall_pos; used to derive the Y rotation so the text is
# readable from the approach side.
func _add_wall_label(text: String, pos: Vector3, dir: Vector2i, color: Color) -> void:
	var lbl: Label3D = Label3D.new()
	lbl.text             = text
	lbl.font_size        = 28
	lbl.pixel_size       = 0.008
	lbl.modulate         = color
	lbl.outline_size     = 6
	lbl.outline_modulate = Color(0.0, 0.0, 0.0, 1.0)
	lbl.position         = pos
	# Label3D default normal is -Z; rotate so it faces the entry side (toward player).
	lbl.rotation.y       = atan2(-float(dir.x), -float(dir.y))
	lbl.scale.x          = -1.0
	add_child(lbl)


# Removes the 3D chest visual when the player picks it up.
func remove_chest(pos: Vector2i) -> void:
	if _chest_nodes.has(pos):
		(_chest_nodes[pos] as Node3D).queue_free()
		_chest_nodes.erase(pos)


# Adds a box mesh as a child of the given parent node (not self).
func _add_box_child(parent: Node3D, pos: Vector3, size: Vector3,
		mat: StandardMaterial3D) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)


# Creates a single MeshInstance3D box and adds it as a child of this node.
func _add_box(pos: Vector3, size: Vector3, mat: StandardMaterial3D) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	add_child(mi)


# Sets up the WorldEnvironment with a dark background and warm ambient light.
# Called fresh on every level load since the old environment is freed with
# the previous Dungeon node.
func _setup_environment() -> void:
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.02, 0.04)
	# Colour-based ambient keeps unlit surfaces dark and moody
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.12, 0.10, 0.07)
	env.ambient_light_energy = 1.0
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	add_child(we)
