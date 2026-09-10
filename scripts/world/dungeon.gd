# Dungeon
# Turns a Level's maze data into 3D geometry and sets up the world environment.
# Accepts the full Level object so wall/floor/ceiling colours and portal position
# come from the level definition — no hardcoded values here.
class_name Dungeon extends Node3D

const CELL_SIZE: float = 2.0
const _FONT := preload("res://resources/misc/OldSchoolAdventures-42j9.ttf") as FontFile

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
	_add_trap_markers(level)
	_setup_environment()


# Accumulators for the two meshes the maze is drawn with. Members rather than
# locals because GDScript passes Packed arrays by value.
var _wire_v: PackedVector3Array = PackedVector3Array()
var _wire_c: PackedColorArray   = PackedColorArray()
var _fill_v: PackedVector3Array = PackedVector3Array()

# Cardinal neighbours as (column, row) offsets.
const _NEIGHBOURS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

# Lines are nudged this far out of the surface they trace so they do not
# z-fight with the translucent fill sitting in the same plane.
const _LINE_OFFSET: float = 0.006


# Draws the maze the way the old grid crawlers did: every wall is an outline,
# and the fill behind it is translucent so the shape of the level reads through
# itself. Two meshes total, so the whole floor is two draw calls.
func _build_geometry(level: Level) -> void:
	_wire_v = PackedVector3Array()
	_wire_c = PackedColorArray()
	_fill_v = PackedVector3Array()

	for row: int in range(level.maze.size()):
		var row_data: Array = level.maze[row]
		for col: int in range(row_data.size()):
			if row_data[col] == 1:
				# Only faces that touch open floor are ever seen.
				for n: Vector2i in _NEIGHBOURS:
					if _is_open(level, col + n.x, row + n.y):
						_add_wall_face(col, row, n, level.wire_color)
			else:
				_add_cell_outline(col, row, 0.0, level.wire_floor_color)
				_add_cell_outline(col, row, WALL_HEIGHT, level.wire_floor_color.darkened(0.35))

	_commit_fill(level)
	_commit_wire()


func _is_open(level: Level, col: int, row: int) -> bool:
	if row < 0 or row >= level.maze.size():
		return false
	var row_data: Array = level.maze[row]
	if col < 0 or col >= row_data.size():
		return false
	return row_data[col] == 0


# One wall face: its four edges as lines, plus two triangles of fill behind.
func _add_wall_face(col: int, row: int, dir: Vector2i, color: Color) -> void:
	var wx: float = col * CELL_SIZE
	var wz: float = row * CELL_SIZE
	var h: float  = CELL_SIZE * 0.5

	var a: Vector3
	var b: Vector3
	if dir.x != 0:
		var fx: float = wx + dir.x * h
		a = Vector3(fx, 0.0, wz - h)
		b = Vector3(fx, 0.0, wz + h)
	else:
		var fz: float = wz + dir.y * h
		a = Vector3(wx - h, 0.0, fz)
		b = Vector3(wx + h, 0.0, fz)

	var up: Vector3 = Vector3(0.0, WALL_HEIGHT, 0.0)
	_fill_v.append_array([a, b, b + up, a, b + up, a + up])

	var push: Vector3 = Vector3(dir.x, 0.0, dir.y) * _LINE_OFFSET
	var p0: Vector3 = a + push
	var p1: Vector3 = b + push
	_add_line(p0, p1, color)
	_add_line(p0 + up, p1 + up, color)
	_add_line(p0, p0 + up, color)
	_add_line(p1, p1 + up, color)


# The square an open cell traces on the floor or the ceiling — the grid that
# tells you how far you have walked.
func _add_cell_outline(col: int, row: int, y: float, color: Color) -> void:
	var wx: float = col * CELL_SIZE
	var wz: float = row * CELL_SIZE
	var h: float  = CELL_SIZE * 0.5
	var lift: float = _LINE_OFFSET if y < WALL_HEIGHT * 0.5 else -_LINE_OFFSET
	var c0: Vector3 = Vector3(wx - h, y + lift, wz - h)
	var c1: Vector3 = Vector3(wx + h, y + lift, wz - h)
	var c2: Vector3 = Vector3(wx + h, y + lift, wz + h)
	var c3: Vector3 = Vector3(wx - h, y + lift, wz + h)
	_add_line(c0, c1, color)
	_add_line(c1, c2, color)
	_add_line(c2, c3, color)
	_add_line(c3, c0, color)


func _add_line(a: Vector3, b: Vector3, color: Color) -> void:
	_wire_v.append(a)
	_wire_v.append(b)
	_wire_c.append(color)
	_wire_c.append(color)


func _commit_fill(level: Level) -> void:
	if _fill_v.is_empty() or level.wire_fill_alpha <= 0.0:
		return
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _fill_v
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode    = BaseMaterial3D.CULL_DISABLED
	if level.wire_fill_alpha >= 0.999:
		# Opaque fill writes depth, so a wall actually hides what is behind it.
		# An alpha-blended material never does, which is why a half-lit fill
		# and no fill at all look identical.
		mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
		mat.albedo_color = level.wire_fill_color
	else:
		mat.transparency    = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
		mat.albedo_color    = Color(level.wire_fill_color.r, level.wire_fill_color.g,
				level.wire_fill_color.b, level.wire_fill_alpha)

	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	add_child(mi)


func _commit_wire() -> void:
	if _wire_v.is_empty():
		return
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _wire_v
	arrays[Mesh.ARRAY_COLOR]  = _wire_c
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode    = BaseMaterial3D.CULL_DISABLED
	mat.render_priority = 1

	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	add_child(mi)


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



# Flat label above a wall marker, facing the same direction as the panel.
# dir = entry_pos - wall_pos; used to derive the Y rotation so the text is
# readable from the approach side.
func _add_wall_label(text: String, pos: Vector3, dir: Vector2i, color: Color) -> void:
	var lbl: Label3D = Label3D.new()
	lbl.text             = text
	lbl.font             = _FONT
	lbl.uppercase        = true
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



# Colored floor overlay for each trap cell so the player can see them.
# spike = red, poison_vent = green, binding_rune = purple.
func _add_trap_markers(level: Level) -> void:
	for pos: Variant in level.trap_cells.keys():
		var trap_type: String = level.trap_cells[pos] as String
		var gp: Vector2i      = pos as Vector2i
		var wx: float = gp.x * CELL_SIZE
		var wz: float = gp.y * CELL_SIZE

		var col: Color
		var light_col: Color
		match trap_type:
			"spike":
				col       = Color(0.72, 0.08, 0.08)
				light_col = Color(1.0,  0.25, 0.25)
			"poison_vent":
				col       = Color(0.12, 0.62, 0.15)
				light_col = Color(0.35, 1.0,  0.40)
			"binding_rune":
				col       = Color(0.42, 0.08, 0.78)
				light_col = Color(0.65, 0.35, 1.0)
			_:
				col       = Color(0.50, 0.50, 0.50)
				light_col = Color(0.80, 0.80, 0.80)

		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color            = col
		mat.emission_enabled        = true
		mat.emission                = col
		mat.emission_energy_multiplier = 1.6
		# Thin slab sitting just on top of the floor surface
		_add_box(Vector3(wx, 0.01, wz), Vector3(CELL_SIZE * 0.85, 0.02, CELL_SIZE * 0.85), mat)

		var light: OmniLight3D = OmniLight3D.new()
		light.light_color  = light_col
		light.light_energy = 0.8
		light.omni_range   = 2.5
		light.position     = Vector3(wx, 0.4, wz)
		add_child(light)


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
	# Depth fog is what stops a see-through maze reading as a wall of noise:
	# the far side of the level dissolves into the background colour.
	env.fog_enabled     = true
	env.fog_mode        = Environment.FOG_MODE_DEPTH
	env.fog_light_color = env.background_color
	env.fog_light_energy = 0.0
	env.fog_depth_begin = 3.0
	env.fog_depth_end   = 17.0
	env.fog_depth_curve = 1.4
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	add_child(we)
