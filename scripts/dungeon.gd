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


# Entry point — call once after adding Dungeon to the scene tree.
# Reads all visual settings and the portal position from the Level.
func build(level: Level) -> void:
	_build_geometry(level)
	_add_exit_marker(level.exit_pos)
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


# Adds a glowing green floor tile and overhead light at the portal cell so the
# player can spot the exit from a distance. Teal is used on both maps so it
# reads as "portal" regardless of the surrounding wall colour.
func _add_exit_marker(exit_pos: Vector2i) -> void:
	var wx: float = exit_pos.x * CELL_SIZE
	var wz: float = exit_pos.y * CELL_SIZE

	# Emissive floor tile slightly above the normal floor so it isn't z-fighting
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.0, 0.55, 0.38)
	mat.emission_enabled = true
	mat.emission = Color(0.0, 0.55, 0.38)
	mat.emission_energy_multiplier = 2.5
	_add_box(Vector3(wx, 0.02, wz), Vector3(CELL_SIZE * 0.85, 0.05, CELL_SIZE * 0.85), mat)

	# Soft overhead light to cast a teal glow on surrounding walls
	var light: OmniLight3D = OmniLight3D.new()
	light.light_color = Color(0.2, 1.0, 0.6)
	light.light_energy = 1.5
	light.omni_range = 4.0
	light.position = Vector3(wx, WALL_HEIGHT * 0.6, wz)
	add_child(light)


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
