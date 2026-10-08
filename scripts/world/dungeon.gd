# Dungeon
# Turns a Level's maze data into 3D geometry and sets up the world environment.
# Accepts the full Level object so wall/floor/ceiling colours and portal position
# come from the level definition — no hardcoded values here.
class_name Dungeon extends Node3D

const CELL_SIZE: float = 2.0

# Height of wall blocks.
const WALL_HEIGHT: float = 2.0

# Entry point — call once after adding Dungeon to the scene tree.
# Reads all visual settings and the portal position from the Level.
func build(level: Level) -> void:
	_tint = level.wire_color
	# The Necromancer's corridor is the bottom: nothing goes on down from it,
	# so it ends in plain wall where every other corridor has its stairwell.
	# Walking into it still starts the fight (Main._check_portal).
	_dead_end = Level.is_necro_floor(level.floor_num)
	_build_geometry(level)
	_exit_wall = level.exit_wall_pos
	_exit_cell = level.exit_pos
	if level.exit_pos.x >= 0 and level.exit_wall_pos.x >= 0 and not _dead_end:
		_add_exit_marker(level.exit_wall_pos, level.exit_pos)
	_add_trap_markers(level)
	_add_orbs(level)
	_add_chests(level)
	if level.key_pos.x >= 0 and not level.key_taken:
		_add_key(level.key_pos)
	_setup_environment()
	_build_arena()


# Accumulators for the two meshes the maze is drawn with. Members rather than
# locals because GDScript passes Packed arrays by value.
var _wire_v: PackedVector3Array = PackedVector3Array()
var _wire_c: PackedColorArray   = PackedColorArray()
var _fill_v: PackedVector3Array = PackedVector3Array()
var _fill_n: PackedVector3Array = PackedVector3Array()
var _floor_v: PackedVector3Array = PackedVector3Array()
var _ceil_v: PackedVector3Array = PackedVector3Array()

# The outlines stay, but faint: the stone is the wall now, and the lines are
# only there so the grid still counts your steps for you.
const _WALL_LINE_ALPHA:  float = 0.18
const _FLOOR_LINE_ALPHA: float = 0.30
const _CEIL_LINE_ALPHA:  float = 0.12

const _STONE_SHADER: Shader = preload("res://resources/shaders/stone.gdshader")
# The two stone materials, kept so the player's light and the nearby torches
# can be handed to them as the player moves.
var _stone_mats: Array[ShaderMaterial] = []
# The band's colour, for the stone pieces built after the maze itself.
var _tint: Color = Color.WHITE
# The last lighting handed out, so a door built mid-floor starts lit.
var _viewer: Vector3 = Vector3.ZERO
var _near_torches: PackedVector3Array = PackedVector3Array()
var _near_count: int = 0
var _glow: Array = [Vector3.ZERO, Color.BLACK, 4.0]

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
	_fill_n = PackedVector3Array()
	_floor_v = PackedVector3Array()
	_ceil_v = PackedVector3Array()

	for row: int in range(level.maze.size()):
		var row_data: Array = level.maze[row]
		for col: int in range(row_data.size()):
			if row_data[col] == 1:
				var here: Vector2i = Vector2i(col, row)
				# Only faces that touch open floor are ever seen. The face a
				# chest opens through goes too: the alcove brings its own
				# stonework, and the fill behind a whole wall face would write
				# depth over it and bury it.
				var cache_face: Vector2i = Vector2i(-999, -999)
				# Likewise the face the stairwell is cut through.
				if here == level.exit_wall_pos and not _dead_end:
					cache_face = level.exit_pos
				elif level.chest_cells.has(here):
					cache_face = level.chest_cells[here] as Vector2i
				# The Necromancer's hall: the pit is drawn as nothing but the
				# ceiling over it, and the cliff where a walkway (or the tip he
				# stands on) drops into it. Only its outer walls are walls.
				if not level.drawn_walls.is_empty() and not level.drawn_walls.has(here):
					_add_ceiling_only(col, row, level)
					if here == level.exit_wall_pos:
						_add_floor_quad(col, row, false)
						_add_cell_outline(col, row, 0.0, _faint(level.wire_floor_color, _FLOOR_LINE_ALPHA))
						_add_drops(level, here)
					continue
				for n: Vector2i in _NEIGHBOURS:
					if not _is_open(level, col + n.x, row + n.y):
						continue
					if here + n == cache_face:
						continue
					_add_wall_face(col, row, n, _faint(level.wire_color, _WALL_LINE_ALPHA))
			else:
				_add_floor_quad(col, row)
				_add_cell_outline(col, row, 0.0, _faint(level.wire_floor_color, _FLOOR_LINE_ALPHA))
				_add_cell_outline(col, row, WALL_HEIGHT,
						_faint(level.wire_floor_color.darkened(0.35), _CEIL_LINE_ALPHA))
				if not level.pit_cells.is_empty():
					_add_drops(level, Vector2i(col, row))

	_commit_fill(level)
	_commit_flat(level, _floor_v, 1, Vector3.UP)
	_commit_flat(level, _ceil_v, 2, Vector3.DOWN)
	_commit_wire()
	_place_torches(level)


# How far the pit's cliffs fall before the dark takes them.
const PIT_DEPTH: float = 6.0


# The ceiling over a cell with no floor: a pit cell, or the tip he stands on.
func _add_ceiling_only(col: int, row: int, level: Level) -> void:
	var wx: float = col * CELL_SIZE
	var wz: float = row * CELL_SIZE
	var h: float = CELL_SIZE * 0.5
	var up: Vector3 = Vector3(0.0, WALL_HEIGHT, 0.0)
	var c0: Vector3 = Vector3(wx - h, 0.0, wz - h)
	var c1: Vector3 = Vector3(wx + h, 0.0, wz - h)
	var c2: Vector3 = Vector3(wx + h, 0.0, wz + h)
	var c3: Vector3 = Vector3(wx - h, 0.0, wz + h)
	_ceil_v.append_array([c0 + up, c2 + up, c1 + up, c0 + up, c3 + up, c2 + up])
	_add_cell_outline(col, row, WALL_HEIGHT,
			_faint(level.wire_floor_color.darkened(0.35), _CEIL_LINE_ALPHA))


# The cliff under a floor cell's edge wherever the pit lies beside it: stone
# from the floor down PIT_DEPTH, facing out over the pit.
func _add_drops(level: Level, cell: Vector2i) -> void:
	for n: Vector2i in _NEIGHBOURS:
		if not level.pit_cells.has(cell + n):
			continue
		var wx: float = cell.x * CELL_SIZE
		var wz: float = cell.y * CELL_SIZE
		var h: float = CELL_SIZE * 0.5
		var a: Vector3
		var b: Vector3
		if n.x != 0:
			a = Vector3(wx + n.x * h, 0.0, wz + h)
			b = Vector3(wx + n.x * h, 0.0, wz - h)
		else:
			a = Vector3(wx - h, 0.0, wz + n.y * h)
			b = Vector3(wx + h, 0.0, wz + n.y * h)
		if n.x < 0 or n.y > 0:
			var t: Vector3 = a
			a = b
			b = t
		var down: Vector3 = Vector3(0.0, -PIT_DEPTH, 0.0)
		_fill_v.append_array([a, a + down, b + down, a, b + down, b])
		var facing: Vector3 = Vector3(float(n.x), 0.0, float(n.y))
		for i: int in 6:
			_fill_n.append(facing)
		_add_line(a, b, _faint(level.wire_color, _WALL_LINE_ALPHA))


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
	var facing: Vector3 = Vector3(float(dir.x), 0.0, float(dir.y))
	for i: int in 6:
		_fill_n.append(facing)

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


func _faint(c: Color, alpha: float) -> Color:
	return Color(c.r, c.g, c.b, alpha)


# The flagstones under an open cell, and the slab over it.
func _add_floor_quad(col: int, row: int, ceiling: bool = true) -> void:
	var wx: float = col * CELL_SIZE
	var wz: float = row * CELL_SIZE
	var h: float  = CELL_SIZE * 0.5
	var c0: Vector3 = Vector3(wx - h, 0.0, wz - h)
	var c1: Vector3 = Vector3(wx + h, 0.0, wz - h)
	var c2: Vector3 = Vector3(wx + h, 0.0, wz + h)
	var c3: Vector3 = Vector3(wx - h, 0.0, wz + h)
	_floor_v.append_array([c0, c1, c2, c0, c2, c3])
	if not ceiling:
		return
	var up: Vector3 = Vector3(0.0, WALL_HEIGHT, 0.0)
	_ceil_v.append_array([c0 + up, c2 + up, c1 + up, c0 + up, c3 + up, c2 + up])


func _add_line(a: Vector3, b: Vector3, color: Color) -> void:
	_wire_v.append(a)
	_wire_v.append(b)
	_wire_c.append(color)
	_wire_c.append(color)


func _commit_fill(level: Level) -> void:
	if _fill_v.is_empty():
		return
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _fill_v
	arrays[Mesh.ARRAY_NORMAL] = _fill_n
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _stone_material(level, 0)
	add_child(mi)


# A flat stone surface — the floor or the ceiling — as its own mesh.
func _commit_flat(level: Level, verts: PackedVector3Array, surface: int,
		normal: Vector3) -> void:
	if verts.is_empty():
		return
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var normals: PackedVector3Array = PackedVector3Array()
	normals.resize(verts.size())
	normals.fill(normal)
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _stone_material(level, surface)
	add_child(mi)


# ── Torches ───────────────────────────────────────────────────────────────────
#
# Iron brackets on the walls with a flame in each, spread through the maze so
# no two sit closer than a few steps. Their light is worked out in the stone
# shader, not by OmniLights — see stone.gdshader — so there is no ceiling on
# how many a floor can carry beyond taste.
const _TORCH_SPACING: int   = 5      # fewest steps between two torches
const _TORCH_PER_CELLS: int = 22     # one torch for about this many open cells
const _TORCH_HEIGHT: float  = 1.30
const _TORCH_SENT: int      = 12     # nearest torches handed to the shader

# Where each flame's light comes from, a little out from its wall.
var _torch_pts: Array[Vector3] = []


func _place_torches(level: Level) -> void:
	_torch_pts.clear()
	# Seeded from the floor, so rebuilding the dungeon mid-floor (a chest
	# opened, a key taken) hangs every torch back exactly where it was.
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash([level.floor_num, level.maze.size(), level.exit_pos])

	var spots: Array = []
	var open: int = 0
	for row: int in range(level.maze.size()):
		for col: int in range((level.maze[row] as Array).size()):
			if not _is_open(level, col, row):
				continue
			open += 1
			var cell: Vector2i = Vector2i(col, row)
			if cell in level.orb_cells or cell == level.exit_pos:
				continue
			for n: Vector2i in _NEIGHBOURS:
				var wall: Vector2i = cell + n
				if _is_open(level, wall.x, wall.y):
					continue
				if wall == level.exit_wall_pos or level.chest_cells.has(wall):
					continue
				# Nothing to hang a torch on at the edge of the pit.
				if not level.drawn_walls.is_empty() and not level.drawn_walls.has(wall):
					continue
				spots.append([cell, n])
	# Shuffled with the seeded generator, not Array.shuffle, which would not
	# repeat between builds.
	for i: int in range(spots.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Variant = spots[i]
		spots[i] = spots[j]
		spots[j] = tmp

	var want: int = maxi(3, open / _TORCH_PER_CELLS)
	var taken: Array[Vector2i] = []
	for spot: Array in spots:
		if taken.size() >= want:
			break
		var cell: Vector2i = spot[0]
		var clear: bool = true
		for t: Vector2i in taken:
			if absi(t.x - cell.x) + absi(t.y - cell.y) < _TORCH_SPACING:
				clear = false
				break
		if not clear:
			continue
		taken.append(cell)
		_add_torch(cell, spot[1] as Vector2i)


# `toward_wall` points from the open cell at the wall the torch hangs on.
func _add_torch(cell: Vector2i, toward_wall: Vector2i) -> void:
	var into: Vector3 = Vector3(float(toward_wall.x), 0.0, float(toward_wall.y))
	var half: float = CELL_SIZE * 0.5
	var face: Vector3 = Vector3(cell.x * CELL_SIZE, _TORCH_HEIGHT, cell.y * CELL_SIZE) \
			+ into * half
	var root: Node3D = Node3D.new()
	root.position = face
	add_child(root)

	var iron: StandardMaterial3D = StandardMaterial3D.new()
	iron.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	iron.albedo_color = Color(0.10, 0.08, 0.07)
	# Plate on the wall, an arm out of it, a cup at the end.
	_add_box_child(root, -into * 0.02, _flat_box(into, 0.04, 0.26, 0.14), iron)
	_add_box_child(root, -into * 0.12 + Vector3(0.0, 0.02, 0.0),
			_flat_box(into, 0.20, 0.04, 0.04), iron)
	_add_box_child(root, -into * 0.22 + Vector3(0.0, 0.06, 0.0),
			_flat_box(into, 0.10, 0.08, 0.10), iron)

	var flame: Node3D = Node3D.new()
	flame.position = -into * 0.22 + Vector3(0.0, 0.18, 0.0)
	root.add_child(flame)

	var outer_mat: StandardMaterial3D = StandardMaterial3D.new()
	outer_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	outer_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	outer_mat.blend_mode   = BaseMaterial3D.BLEND_MODE_ADD
	outer_mat.albedo_color = Color(1.0, 0.45, 0.12, 0.55)
	var outer: MeshInstance3D = MeshInstance3D.new()
	var outer_mesh: SphereMesh = SphereMesh.new()
	outer_mesh.radius = 0.09
	outer_mesh.height = 0.26
	outer_mesh.radial_segments = 6
	outer_mesh.rings = 3
	outer.mesh = outer_mesh
	outer.material_override = outer_mat
	flame.add_child(outer)

	var core_mat: StandardMaterial3D = StandardMaterial3D.new()
	core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core_mat.albedo_color = Color(1.0, 0.86, 0.45)
	var core: MeshInstance3D = MeshInstance3D.new()
	var core_mesh: SphereMesh = SphereMesh.new()
	core_mesh.radius = 0.045
	core_mesh.height = 0.14
	core_mesh.radial_segments = 6
	core_mesh.rings = 3
	core.mesh = core_mesh
	core.material_override = core_mat
	core.position = Vector3(0.0, -0.02, 0.0)
	flame.add_child(core)

	# A flame breathes: uneven stretches up and back, never in step with the
	# torch next to it.
	var tw: Tween = create_tween().set_loops()
	var beat: float = 0.11 + randf() * 0.05
	tw.tween_property(flame, "scale", Vector3(0.92, 1.14, 0.92), beat)
	tw.tween_property(flame, "scale", Vector3(1.06, 0.90, 1.06), beat * 1.3)
	tw.tween_property(flame, "scale", Vector3(0.97, 1.05, 0.97), beat * 0.8)

	_torch_pts.append(face - into * 0.45 + Vector3(0.0, 0.15, 0.0))


# A box `depth` deep along `out` and `width` across it.
func _flat_box(out: Vector3, depth: float, height: float, width: float) -> Vector3:
	return Vector3(depth, height, width) if absf(out.x) > 0.5 \
			else Vector3(width, height, depth)


# Where the player's light is, and which torches are near enough to matter.
# Called on every step; the flicker itself runs in the shader on its own.
func set_viewer(pos: Vector3) -> void:
	var near: Array[Vector3] = _torch_pts.duplicate()
	near.sort_custom(func(a: Vector3, b: Vector3) -> bool:
		return a.distance_squared_to(pos) < b.distance_squared_to(pos))
	var sent: PackedVector3Array = PackedVector3Array()
	for i: int in mini(_TORCH_SENT, near.size()):
		sent.append(near[i])
	_near_count = sent.size()
	sent.resize(_TORCH_SENT)
	_viewer = pos
	_near_torches = sent
	for mat: ShaderMaterial in _stone_mats:
		_light(mat)


func _light(mat: ShaderMaterial) -> void:
	mat.set_shader_parameter("viewer", _viewer)
	mat.set_shader_parameter("torches", _near_torches)
	mat.set_shader_parameter("torch_count", _near_count)
	mat.set_shader_parameter("glow_pos", _glow[0])
	mat.set_shader_parameter("glow_color", _glow[1])
	mat.set_shader_parameter("glow_range", _glow[2])


# The one coloured light the way out throws onto the stone round it.
func _set_glow(pos: Vector3, color: Color, reach: float) -> void:
	_glow = [pos, color, reach]
	for mat: ShaderMaterial in _stone_mats:
		_light(mat)


# Opaque, so a wall hides what is behind it — the see-through fill this
# replaced had to go opaque for the same reason.
func _stone_material(level: Level, surface: int) -> ShaderMaterial:
	_tint = level.wire_color
	return _stone(surface)


func _stone(surface: int, brightness: float = 1.0) -> ShaderMaterial:
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = _STONE_SHADER
	mat.set_shader_parameter("surface", surface)
	mat.set_shader_parameter("tint", _tint)
	mat.set_shader_parameter("brightness", brightness)
	_stone_mats.append(mat)
	_light(mat)
	return mat


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


# The way down: a stairwell cut into the floor of the wall cell, the flight
# dropping away from the corridor into a dark passage. The first try climbed
# instead, which read as a way up out of a dungeon whose whole point is going
# deeper.
#
# A flight that goes down is hard to show from eye height: the treads sit below
# the lip of the corridor floor, and a line of sight passes over them. So the
# ceiling steps down with the flight, one riser per tread, and it is that
# upside-down staircase above eye level, dropping away into a low dark mouth,
# that says "down" from anywhere along the corridor.
const _STAIR_COUNT: int = 6
# How far the flight drops, as a share of WALL_HEIGHT. 0.75 makes each riser a
# quarter unit, five texels: one course of stone per step.
const _STAIR_RISE: float = 0.75
const _STAIR_GREEN: Color = Color(0.25, 1.0, 0.62)
# Enough to tint the stone round the stairwell, not to dye the corridor.
const _STAIR_GLOW: float = 0.8

var _stair_glow: Vector3 = Vector3.ZERO


func _add_exit_marker(wall_pos: Vector2i, entry_pos: Vector2i) -> void:
	var dir: Vector2i = entry_pos - wall_pos
	var root: Node3D = Node3D.new()
	root.position = Vector3(wall_pos.x * CELL_SIZE, 0.0, wall_pos.y * CELL_SIZE)
	add_child(root)

	# Outward is back toward the corridor; the flight descends the other way.
	var out: Vector3 = Vector3(float(dir.x), 0.0, float(dir.y))
	var across: Vector3 = Vector3(float(dir.y), 0.0, float(-dir.x))
	var half: float = CELL_SIZE * 0.5
	var rise: float = WALL_HEIGHT * _STAIR_RISE
	# The shaft goes a little below the bottom step, so no seam shows under it.
	var pit: float = rise + 0.1

	# Cheeks down both sides, from the ceiling to below the bottom step, in the
	# same stone as the walls, so the stairwell is cut into the rock, not built
	# in it.
	var wall: ShaderMaterial = _stone(0)
	var cheek_h: float = WALL_HEIGHT + pit
	for side: float in [1.0, -1.0]:
		_add_box_child(root,
				across * (half * side) + Vector3(0.0, WALL_HEIGHT - cheek_h * 0.5, 0.0),
				_axis_box(out, across, CELL_SIZE, cheek_h, 0.06), wall)

	# The far end: near-black from below the bottom step up to where the last
	# ceiling block comes down, so the flight runs on into the dark under the
	# rock instead of stopping at a wall.
	var lintel_y: float = WALL_HEIGHT - rise
	var dark: StandardMaterial3D = StandardMaterial3D.new()
	dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dark.albedo_color = Color(0.01, 0.02, 0.02)
	# One thickness inside the cell, with stone at the cell's edge behind it:
	# the stairwell's back can be seen from the corridor on the other side, and
	# on the edge itself the dark showed through there as a black band.
	_add_box_child(root, out * (-half + 0.06) + Vector3(0.0, (lintel_y - pit) * 0.5, 0.0),
			_axis_box(out, across, 0.06, lintel_y + pit, CELL_SIZE), dark)
	_add_box_child(root, out * -half + Vector3(0.0, (lintel_y - pit) * 0.5, 0.0),
			_axis_box(out, across, 0.06, lintel_y + pit, CELL_SIZE), wall)

	# The flight: each step a solid block of stone from the bottom of the shaft
	# up to its tread, each tread one riser lower and one tread further away.
	# From eye height the treads face the camera, so the flight reads as a run
	# of pale ledges stepping down into the dark.
	var step: ShaderMaterial = _stone(4)
	step.set_shader_parameter("course_h", 5.0)
	var roof: ShaderMaterial = _stone(4)
	roof.set_shader_parameter("course_h", 5.0)
	var tread: float = CELL_SIZE / float(_STAIR_COUNT)
	var riser: float = rise / float(_STAIR_COUNT)
	for i: int in range(_STAIR_COUNT):
		var top_y: float = -float(i + 1) * riser
		var at: Vector3 = out * (half - (float(i) + 0.5) * tread) \
				+ Vector3(0.0, (top_y - pit) * 0.5, 0.0)
		_add_box_child(root, at, _axis_box(out, across, tread, top_y + pit, CELL_SIZE), step)
		# The rock over this tread comes down by the same riser, keeping a full
		# WALL_HEIGHT of headroom above every step. Its face toward the corridor
		# is the lit edge of the inverted flight.
		var roof_y: float = WALL_HEIGHT - float(i + 1) * riser
		var over: Vector3 = out * (half - (float(i) + 0.5) * tread) \
				+ Vector3(0.0, (roof_y + WALL_HEIGHT + 0.06) * 0.5, 0.0)
		_add_box_child(root, over,
				_axis_box(out, across, tread, WALL_HEIGHT + 0.06 - roof_y, CELL_SIZE), roof)

	# The light comes up from the foot of the flight and spills over its lip
	# onto the corridor, so what draws the eye is the glow rising out of the
	# floor.
	_stair_glow = root.position + out * (-half + tread) + Vector3(0.0, -rise + 0.5, 0.0)
	_set_glow(_stair_glow, _STAIR_GREEN * _STAIR_GLOW, 3.6)


# The gate standing in the stairwell while the key is still out there. Until
# this existed the only thing saying a floor was sealed was a line of HUD text,
# so a player walking the corridor saw the way out and no reason it would not
# open. The lock is violet, because that is the key's colour everywhere else —
# the floating bit, the minimap mark, the warden popup — and its light is what
# colours the stone round the door.
const _LOCK_VIOLET: Color = Color(0.70, 0.48, 1.0)
# Dead ahead at eye height (Main.EYE_HEIGHT is 1.0), so the lock is the thing
# the player is looking at rather than something to find.
const _LOCK_HEIGHT: float = 1.05
# The doorway in the wall: narrower and lower than the cell, so the stone round
# it is what says "door" rather than the corridor simply stopping.
const _DOOR_W: float = 1.2
const _DOOR_H: float = 1.6

var _door: Node3D = null
var _door_mats: Array[ShaderMaterial] = []
var _exit_wall: Vector2i = Vector2i(-1, -1)
var _dead_end: bool = false
var _exit_cell: Vector2i = Vector2i(-1, -1)


# The door is a node of its own rather than part of the build, because the key
# is found mid-floor: taking it has to open the way without rebuilding the
# maze. Safe to call with the same value twice.
func set_locked(locked: bool) -> void:
	if is_instance_valid(_door):
		_door.free()
	_door = null
	for mat: ShaderMaterial in _door_mats:
		_stone_mats.erase(mat)
	_door_mats.clear()
	if _dead_end:
		return
	if not locked or _exit_wall.x < 0 or _exit_cell.x < 0:
		_set_glow(_stair_glow, _STAIR_GREEN * _STAIR_GLOW, 3.6)
		return
	var before: int = _stone_mats.size()
	_door = _add_locked_door(_exit_wall, _exit_cell)
	_door_mats.assign(_stone_mats.slice(before))


func _add_locked_door(wall_pos: Vector2i, entry_pos: Vector2i) -> Node3D:
	var dir: Vector2i = entry_pos - wall_pos
	var root: Node3D = Node3D.new()
	root.position = Vector3(wall_pos.x * CELL_SIZE, 0.0, wall_pos.y * CELL_SIZE)
	add_child(root)

	var out: Vector3 = Vector3(float(dir.x), 0.0, float(dir.y))
	var across: Vector3 = Vector3(float(dir.y), 0.0, float(-dir.x))
	var half: float = CELL_SIZE * 0.5
	var side_w: float = (CELL_SIZE - _DOOR_W) * 0.5

	# The wall the doorway is cut through: two piers and a lintel of the same
	# stone as every other wall, flush with them, so the door sits in the rock.
	var wall: ShaderMaterial = _stone(0)
	var back: Vector3 = out * (half - 0.10)
	for side: float in [1.0, -1.0]:
		_add_box_child(root,
				back + across * (side * (_DOOR_W * 0.5 + side_w * 0.5))
				+ Vector3(0.0, WALL_HEIGHT * 0.5, 0.0),
				_axis_box(out, across, 0.20, WALL_HEIGHT, side_w), wall)
	_add_box_child(root, back + Vector3(0.0, (_DOOR_H + WALL_HEIGHT) * 0.5, 0.0),
			_axis_box(out, across, 0.20, WALL_HEIGHT - _DOOR_H, _DOOR_W), wall)

	# A dressed frame standing proud of the wall: jambs and a heavier lintel,
	# lighter than the rough stone so the opening has an edge.
	var frame: ShaderMaterial = _stone(0, 1.15)
	var proud: Vector3 = out * (half + 0.04)
	const JAMB: float = 0.12
	for side: float in [1.0, -1.0]:
		_add_box_child(root,
				proud + across * (side * (_DOOR_W + JAMB) * 0.5)
				+ Vector3(0.0, _DOOR_H * 0.5, 0.0),
				_axis_box(out, across, 0.08, _DOOR_H, JAMB), frame)
	_add_box_child(root, proud + Vector3(0.0, _DOOR_H + 0.09, 0.0),
			_axis_box(out, across, 0.10, 0.18, _DOOR_W + JAMB * 2.0 + 0.08), frame)

	# The door: planks and iron straps, drawn by the stone shader so the torches
	# and the lock's own light fall on it like everything else.
	var wood: ShaderMaterial = _stone(3)
	var world_across: Vector3 = root.position + across * (-_DOOR_W * 0.5)
	var origin: float = minf(world_across.x, (root.position + across * (_DOOR_W * 0.5)).x) \
			if absf(across.x) > 0.5 \
			else minf(world_across.z, (root.position + across * (_DOOR_W * 0.5)).z)
	wood.set_shader_parameter("plank_origin", origin)
	var face: Vector3 = out * (half - 0.08)
	_add_box_child(root, face + Vector3(0.0, _DOOR_H * 0.5, 0.0),
			_axis_box(out, across, 0.08, _DOOR_H, _DOOR_W), wood)

	_add_lock(root, out, face + out * 0.04)
	_set_glow(root.position + face + out * 0.6 + Vector3(0.0, _LOCK_HEIGHT, 0.0),
			_LOCK_VIOLET * 0.95, 2.6)
	return root


# The lock plate and the recess the key drops into. The recess is the key's own
# silhouette — a PrismMesh of the same proportions as the floating bit — so the
# thing found on the floor and the thing it opens are legible as a pair, and it
# glows from inside because that is where the key goes.
func _add_lock(root: Node3D, out: Vector3, front: Vector3) -> void:
	var at: Vector3 = front + out * 0.02 + Vector3(0.0, _LOCK_HEIGHT, 0.0)
	var across: Vector3 = Vector3(out.z, 0.0, -out.x)

	var plate_mat: StandardMaterial3D = StandardMaterial3D.new()
	plate_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	plate_mat.albedo_color = Color(0.13, 0.10, 0.17)
	var plate: Vector3 = _axis_box(out, across, 0.04, 0.46, 0.34)
	_add_box_child(root, at, plate, plate_mat)

	var plate_edges: PackedVector3Array = PackedVector3Array()
	_append_box_edges(plate_edges, at, plate)
	_add_line_mesh(root, plate_edges, _LOCK_VIOLET.darkened(0.25))

	# Turned so the triangle faces down the corridor. atan2(x, z) maps +Z to 0
	# and +X to a quarter turn, which is exactly the four cardinal cases.
	var hole: Node3D = Node3D.new()
	hole.position = at + out * 0.02
	hole.rotation = Vector3(0.0, atan2(out.x, out.z), 0.0)
	root.add_child(hole)

	const W: float = 0.18
	const H: float = 0.27
	var sink_mat: StandardMaterial3D = StandardMaterial3D.new()
	sink_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sink_mat.albedo_color = Color(0.38, 0.22, 0.62)
	var sink: MeshInstance3D = MeshInstance3D.new()
	var bit: PrismMesh = PrismMesh.new()
	bit.size = Vector3(W, H, 0.03)
	sink.mesh = bit
	sink.material_override = sink_mat
	hole.add_child(sink)

	var lip: PackedVector3Array = PackedVector3Array()
	var apex: Vector3 = Vector3(0.0, H * 0.5, 0.016)
	var left: Vector3 = Vector3(-W * 0.5, -H * 0.5, 0.016)
	var right: Vector3 = Vector3(W * 0.5, -H * 0.5, 0.016)
	lip.append_array([apex, left, left, right, right, apex])
	_add_line_mesh(hole, lip, _LOCK_VIOLET)


# A save orb: a pale, slowly turning shard hanging at eye height. Cold white so
# it never reads as one of the burning things walking the floor.
# The loose key. Deliberately not an orb: same trick of a lit thing floating in
# a dark corridor, but violet and flat rather than white and round, because the
# one thing it must never be mistaken for at the end of a long corridor is a
# save point.
func _add_key(pos: Vector2i) -> void:
	var root: Node3D = Node3D.new()
	root.position = Vector3(pos.x * CELL_SIZE, 0.95, pos.y * CELL_SIZE)
	root.rotation = Vector3(0.0, PI * 0.25, 0.0)
	add_child(root)

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.86, 0.72, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.66, 0.42, 1.0)
	mat.emission_energy_multiplier = 2.4

	var core: MeshInstance3D = MeshInstance3D.new()
	var bit: PrismMesh = PrismMesh.new()
	bit.size = Vector3(0.30, 0.44, 0.10)
	core.mesh = bit
	core.material_override = mat
	root.add_child(core)

	var halo_mat: StandardMaterial3D = StandardMaterial3D.new()
	halo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo_mat.blend_mode   = BaseMaterial3D.BLEND_MODE_ADD
	halo_mat.cull_mode    = BaseMaterial3D.CULL_FRONT
	halo_mat.albedo_color = Color(0.62, 0.40, 1.0, 0.20)
	var halo: MeshInstance3D = MeshInstance3D.new()
	var halo_mesh: SphereMesh = SphereMesh.new()
	halo_mesh.radius = 0.30
	halo_mesh.height = 0.60
	halo_mesh.radial_segments = 10
	halo_mesh.rings = 5
	halo.mesh = halo_mesh
	halo.material_override = halo_mat
	root.add_child(halo)

	var light: OmniLight3D = OmniLight3D.new()
	light.light_color  = Color(0.70, 0.48, 1.0)
	light.light_energy = 1.6
	light.omni_range   = 4.5
	root.add_child(light)


func _add_orbs(level: Level) -> void:
	for pos: Vector2i in level.orb_cells:
		_add_orb(pos)


# How high the shard hangs. It used to sit at 1.0, which is eye height: dead on
# the horizon, where the far wall's centre is too, so an orb one cell ahead was
# drawn on top of the wall two cells ahead and read as being out there with it.
# Lower, over a glow on its own flagstones, it reads as standing in its cell.
const _ORB_HEIGHT: float = 0.72


func _add_orb(pos: Vector2i) -> void:
	var base: Node3D = Node3D.new()
	base.position = Vector3(pos.x * CELL_SIZE, 0.0, pos.y * CELL_SIZE)
	add_child(base)
	_add_orb_footing(base)

	var root: Node3D = Node3D.new()
	root.position = Vector3(0.0, _ORB_HEIGHT, 0.0)
	base.add_child(root)

	var core_mat: StandardMaterial3D = StandardMaterial3D.new()
	core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core_mat.albedo_color = Color(0.86, 0.96, 1.0)
	core_mat.emission_enabled = true
	core_mat.emission = Color(0.70, 0.92, 1.0)
	core_mat.emission_energy_multiplier = 2.2

	var core: MeshInstance3D = MeshInstance3D.new()
	var shard: SphereMesh = SphereMesh.new()
	shard.radius = 0.16
	shard.height = 0.52
	shard.radial_segments = 6
	shard.rings = 3
	core.mesh = shard
	core.material_override = core_mat
	root.add_child(core)

	var halo_mat: StandardMaterial3D = StandardMaterial3D.new()
	halo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo_mat.blend_mode   = BaseMaterial3D.BLEND_MODE_ADD
	halo_mat.cull_mode    = BaseMaterial3D.CULL_FRONT
	halo_mat.albedo_color = Color(0.55, 0.85, 1.0, 0.22)
	var halo: MeshInstance3D = MeshInstance3D.new()
	var halo_mesh: SphereMesh = SphereMesh.new()
	halo_mesh.radius = 0.34
	halo_mesh.height = 0.68
	halo_mesh.radial_segments = 12
	halo_mesh.rings = 6
	halo.mesh = halo_mesh
	halo.material_override = halo_mat
	root.add_child(halo)

	var light: OmniLight3D = OmniLight3D.new()
	light.light_color  = Color(0.65, 0.88, 1.0)
	light.light_energy = 1.8
	light.omni_range   = 5.0
	root.add_child(light)

	# A slow turn, so it reads as alive from down a corridor.
	var spin: Tween = create_tween().set_loops()
	spin.tween_property(core, "rotation:y", TAU, 6.0).from(0.0)


# What ties the orb to its cell: a pale square of light on the floor under it.
# Perspective does the rest — the square sits on the flagstones you would walk
# over, so the eye can count the cells to it the same way it does on the map.
func _add_orb_footing(base: Node3D) -> void:
	var glow_mat: StandardMaterial3D = StandardMaterial3D.new()
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_mat.blend_mode   = BaseMaterial3D.BLEND_MODE_ADD
	glow_mat.albedo_color = Color(0.55, 0.85, 1.0, 0.16)
	_add_box_child(base, Vector3(0.0, 0.012, 0.0),
			Vector3(CELL_SIZE * 0.80, 0.01, CELL_SIZE * 0.80), glow_mat)


# ── Caches ────────────────────────────────────────────────────────────────────
#
# A cache is a real chest sitting in an alcove cut into the wall it opens
# through. It was a banner for a while — a sprite hung flat on the stone — and
# from anywhere but dead ahead it read as a picture pasted on the wall. The
# alcove is lined with the same stone as every wall (nothing in this maze has
# anything solid behind a face, so an unlined niche would look straight through
# the level), and the chest is built from the planks and iron the locked door
# uses, so it takes the torches and the lamp like the rest of the room.
#
# The alcove: narrower and lower than the cell, and deep enough that the chest
# sits inside the wall line rather than in the corridor.
const _NICHE_W: float = 1.30
const _NICHE_H: float = 1.20
const _NICHE_D: float = 0.85
# The chest itself: body, and the lid that sits on it.
const _CHEST_W: float = 0.90
const _CHEST_D: float = 0.50
const _CHEST_H: float = 0.40
const _LID_H: float   = 0.14
# How far an emptied chest's lid is thrown back, past upright, so it leans on
# the back of the alcove. An open lid is the whole of the looted state.
const _LID_OPEN_DEG: float = 100.0
const _IRON: Color = Color(0.16, 0.15, 0.17)
const _BRASS: Color = Color(0.86, 0.66, 0.24)


func _add_chests(level: Level) -> void:
	for wall: Variant in level.chest_cells.keys():
		var wall_pos: Vector2i = wall as Vector2i
		var face_pos: Vector2i = level.chest_cells[wall] as Vector2i
		_add_chest(wall_pos, face_pos - wall_pos,
				level.looted.has(wall_pos), level.wire_color)


func _add_chest(wall_pos: Vector2i, dir: Vector2i, looted: bool, wire: Color) -> void:
	var root: Node3D = Node3D.new()
	root.position = Vector3(wall_pos.x * CELL_SIZE, 0.0, wall_pos.y * CELL_SIZE)
	add_child(root)

	# Outward is toward the corridor the chest is opened from.
	var out: Vector3 = Vector3(float(dir.x), 0.0, float(dir.y))
	var across: Vector3 = Vector3(float(dir.y), 0.0, float(-dir.x))
	var half: float = CELL_SIZE * 0.5
	_add_niche(root, out, across, half)

	# The chest stands near the mouth of the alcove, leaving room behind it for
	# the lid to swing back without sinking into the stone.
	var centre: Vector3 = out * (half - 0.32)
	_add_chest_body(root, centre, out, across, looted)

	# A full chest has a warm light of its own; an emptied one only enough
	# that you can see it is open, dim and colourless, so it no longer looks
	# worth crossing a floor for.
	var light: OmniLight3D = OmniLight3D.new()
	light.light_color  = wire.lerp(Color(0.75, 0.78, 0.85), 0.5) if looted \
			else Color(1.0, 0.82, 0.40)
	light.light_energy = 0.5 if looted else 1.4
	light.omni_range   = 2.0 if looted else 3.0
	light.position     = out * (half + 0.35) + Vector3(0.0, _NICHE_H * 0.8, 0.0)
	root.add_child(light)


# The wall face the alcove is cut through, and the alcove's lining: two piers
# and a lintel flush with the neighbouring walls, then sides, back, roof and
# floor in the same stone. The stone shader works from world position, so the
# courses run straight on from the walls either side.
func _add_niche(root: Node3D, out: Vector3, across: Vector3, half: float) -> void:
	var wall: ShaderMaterial = _stone(0)
	var face: Vector3 = out * (half - 0.03)
	var pier_w: float = (CELL_SIZE - _NICHE_W) * 0.5
	for side: float in [1.0, -1.0]:
		_add_box_child(root,
				face + across * (side * (_NICHE_W + pier_w) * 0.5)
				+ Vector3(0.0, WALL_HEIGHT * 0.5, 0.0),
				_axis_box(out, across, 0.06, WALL_HEIGHT, pier_w), wall)
	_add_box_child(root, face + Vector3(0.0, (_NICHE_H + WALL_HEIGHT) * 0.5, 0.0),
			_axis_box(out, across, 0.06, WALL_HEIGHT - _NICHE_H, _NICHE_W), wall)

	var inside: Vector3 = out * (half - _NICHE_D * 0.5)
	for side: float in [1.0, -1.0]:
		_add_box_child(root,
				inside + across * (side * _NICHE_W * 0.5)
				+ Vector3(0.0, _NICHE_H * 0.5, 0.0),
				_axis_box(out, across, _NICHE_D, _NICHE_H, 0.06), wall)
	_add_box_child(root, out * (half - _NICHE_D) + Vector3(0.0, _NICHE_H * 0.5, 0.0),
			_axis_box(out, across, 0.06, _NICHE_H, _NICHE_W), wall)
	_add_box_child(root, inside + Vector3(0.0, _NICHE_H, 0.0),
			_axis_box(out, across, _NICHE_D, 0.06, _NICHE_W), _stone(2))
	_add_box_child(root, inside + Vector3(0.0, -0.03, 0.0),
			_axis_box(out, across, _NICHE_D, 0.06, _NICHE_W), _stone(1))


# Planks and iron, the locked door's materials: the body a box of upright
# planks with the door's own strap across it, iron at the corners, and a lid
# hinged along the back with a brass hasp on its front. Emptied, the lid is
# thrown back against the alcove and the dark inside shows.
func _add_chest_body(root: Node3D, centre: Vector3, out: Vector3, across: Vector3,
		looted: bool) -> void:
	var wood: ShaderMaterial = _stone(3)
	var left: Vector3 = root.position + centre + across * (-_CHEST_W * 0.5)
	var right: Vector3 = root.position + centre + across * (_CHEST_W * 0.5)
	wood.set_shader_parameter("plank_origin",
			minf(left.x, right.x) if absf(across.x) > 0.5 else minf(left.z, right.z))
	_add_box_child(root, centre + Vector3(0.0, _CHEST_H * 0.5, 0.0),
			_axis_box(out, across, _CHEST_D, _CHEST_H, _CHEST_W), wood)

	var iron: StandardMaterial3D = StandardMaterial3D.new()
	iron.albedo_color = _IRON
	iron.roughness = 0.6
	iron.metallic = 0.4
	for side: float in [1.0, -1.0]:
		_add_box_child(root,
				centre + across * (side * (_CHEST_W * 0.5 - 0.04))
				+ Vector3(0.0, _CHEST_H * 0.5, 0.0),
				_axis_box(out, across, _CHEST_D + 0.02, _CHEST_H + 0.01, 0.06), iron)

	# The inside, only ever seen with the lid up.
	if looted:
		var hollow: StandardMaterial3D = StandardMaterial3D.new()
		hollow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		hollow.albedo_color = Color(0.03, 0.02, 0.02)
		_add_box_child(root, centre + Vector3(0.0, _CHEST_H + 0.002, 0.0),
				_axis_box(out, across, _CHEST_D - 0.08, 0.004, _CHEST_W - 0.12), hollow)

	# The lid turns about the hinge along the chest's back top edge.
	var hinge: Node3D = Node3D.new()
	hinge.position = centre + out * (-_CHEST_D * 0.5) + Vector3(0.0, _CHEST_H, 0.0)
	if looted:
		# Negative about `across` lifts the front edge up and over toward the back.
		hinge.basis = Basis(across.normalized(), -deg_to_rad(_LID_OPEN_DEG))
	root.add_child(hinge)
	var lid_centre: Vector3 = out * (_CHEST_D * 0.5) + Vector3(0.0, _LID_H * 0.5, 0.0)
	_add_box_child(hinge, lid_centre,
			_axis_box(out, across, _CHEST_D + 0.04, _LID_H, _CHEST_W + 0.04), wood)
	for side: float in [1.0, -1.0]:
		_add_box_child(hinge,
				lid_centre + across * (side * (_CHEST_W * 0.5 - 0.04)),
				_axis_box(out, across, _CHEST_D + 0.06, _LID_H + 0.02, 0.06), iron)

	var brass: StandardMaterial3D = StandardMaterial3D.new()
	brass.albedo_color = _BRASS
	brass.metallic = 0.6
	brass.roughness = 0.35
	brass.emission_enabled = true
	brass.emission = _BRASS * 0.25
	_add_box_child(hinge, out * (_CHEST_D + 0.035) + Vector3(0.0, -0.02, 0.0),
			_axis_box(out, across, 0.03, 0.16, 0.12), brass)


# The twelve edges of an axis-aligned box, appended as line pairs. The maze's
# own outlines are committed once at the end of _build_geometry, long before
# anything is placed in the level, so props that want the same look have to
# carry their own line mesh.
func _append_box_edges(into: PackedVector3Array, centre: Vector3,
		size: Vector3) -> void:
	var h: Vector3 = size * 0.5
	var corner: Array[Vector3] = []
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				corner.append(centre + Vector3(h.x * sx, h.y * sy, h.z * sz))
	# Indices into the xyz-ordered corner list above; each pair differs in
	# exactly one axis, which is what makes it an edge rather than a diagonal.
	const PAIRS: Array[int] = [
		0, 1, 2, 3, 4, 5, 6, 7,
		0, 2, 1, 3, 4, 6, 5, 7,
		0, 4, 1, 5, 2, 6, 3, 7]
	for i: int in range(0, PAIRS.size(), 2):
		into.append(corner[PAIRS[i]])
		into.append(corner[PAIRS[i + 1]])


func _add_line_mesh(parent: Node3D, verts: PackedVector3Array, color: Color) -> void:
	if verts.is_empty():
		return
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	# Above the fill it outlines, the same way the maze's own wire sits above
	# its wall faces — without this the edges z-fight with the box they bound.
	mat.render_priority = 1

	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	parent.add_child(mi)


# Box extents for something aligned to an arbitrary cardinal facing: `depth`
# runs along `out`, `width` along `across`, and height is always Y.
func _axis_box(out: Vector3, across: Vector3, depth: float, height: float,
		width: float) -> Vector3:
	return Vector3(
			absf(out.x) * depth + absf(across.x) * width,
			height,
			absf(out.z) * depth + absf(across.z) * width)


# One tile of hazard shader per hazard cell, lying just on the floor — see
# resources/shaders/hazard.gdshader. Lava and ice fill the cell, a spark plate
# a little less, a teleporter is a disc. No light of their own: they glow in the
# shader, which is what lets a floor carry several without the torches going
# out (the web renderer lights a mesh from eight lights at most).
const _HAZARD_SHADER := preload("res://resources/shaders/hazard.gdshader")
const _PAIR_COLORS: Array[Color] = [Color(0.66, 0.38, 1.0), Color(0.30, 0.85, 0.80)]

# cell -> the plate's material, so the one underfoot can show its own state.
var _spark_mats: Dictionary = {}
# Kept across rebuilds (a looted chest rebuilds the floor mid-pulse).
var _spark_live: int = 0


func _add_trap_markers(level: Level) -> void:
	_spark_mats.clear()
	for pos: Variant in level.trap_cells.keys():
		var gp: Vector2i = pos as Vector2i
		var value: String = level.trap_cells[pos] as String
		var kind: String = Level.hazard_kind(value)
		var mat: ShaderMaterial = ShaderMaterial.new()
		mat.shader = _HAZARD_SHADER
		var size: float = CELL_SIZE
		match kind:
			Level.HAZARD_ICE:
				mat.set_shader_parameter("mode", 1)
				mat.render_priority = 1
			Level.HAZARD_SPARK:
				mat.set_shader_parameter("mode", 2)
				mat.set_shader_parameter("group", Level.spark_group(value))
				mat.set_shader_parameter("live", _spark_live)
				_spark_mats[gp] = mat
				size = CELL_SIZE * 0.9
			Level.HAZARD_TELE:
				mat.set_shader_parameter("mode", 3)
				mat.set_shader_parameter("pair_color",
						_PAIR_COLORS[Level.tele_pair(value) % _PAIR_COLORS.size()])
				size = CELL_SIZE * 0.8
			_:
				mat.set_shader_parameter("mode", 0)
		var mi: MeshInstance3D = MeshInstance3D.new()
		var quad: PlaneMesh = PlaneMesh.new()
		quad.size = Vector2(size, size)
		mi.mesh = quad
		mi.material_override = mat
		mi.position = Vector3(gp.x * CELL_SIZE, 0.012, gp.y * CELL_SIZE)
		add_child(mi)


# Which spark group is live, for every plate on the floor. Called by Main on the
# pulse, so the tiles and the damage never disagree.
#
# Every plate shows `group`, the state it will be in when stepped onto next,
# except the one at `under`: it shows `under_live`, the state that judged the
# player as they landed on it, so what is underfoot always matches whether it
# hurt. Without that exception the plate under you could flip the moment you
# arrived, and you stood on a lit plate unhurt or were hurt by a dark one.
func set_spark_live(group: int, under: Vector2i = Vector2i(-1, -1),
		under_live: int = -1) -> void:
	_spark_live = group
	for cell: Variant in _spark_mats:
		var shown: int = under_live if cell == under and under_live >= 0 else group
		(_spark_mats[cell] as ShaderMaterial).set_shader_parameter("live", shown)


func _add_box_child(parent: Node3D, pos: Vector3, size: Vector3,
		mat: Material) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)


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


# ── The battle room ───────────────────────────────────────────────────────────
#
# A wide room in this floor's stone, out past the edge of the maze where no
# corridor can see it, for a fight to stand in on a wide screen: the maze's
# corridors are one cell across, and a party and a line of monsters spread over
# the whole screen would stand on its walls. Main makes arena_camera current
# for the fight and hands the player's camera back after.

const ARENA_AT: Vector3 = Vector3(-400.0, 0.0, -400.0)
const ARENA_W: float = 16.0      # across, side wall to side wall
# Deep enough, with the camera looking down at the near floor, that the back
# wall's foot sits high on the screen: every figure's feet then land on floor
# tiles. At 12, looking further back, the line was where the back row of each
# side stood, and they stood on the wall.
const ARENA_D: float = 18.0      # from the camera's end to the back wall
const ARENA_H: float = 4.0

var arena_camera: Camera3D


func _build_arena() -> void:
	var root: Node3D = Node3D.new()
	root.position = ARENA_AT
	add_child(root)
	var hw: float = ARENA_W / 2.0
	var back: float = -ARENA_D
	var front: float = 4.0
	# Floor, back wall, and the two side walls running back to it.
	var floor_v: PackedVector3Array = _quad(Vector3(-hw, 0, back), Vector3(hw, 0, back),
			Vector3(hw, 0, front), Vector3(-hw, 0, front))
	var wall_v: PackedVector3Array = PackedVector3Array()
	wall_v.append_array(_quad(Vector3(-hw, 0, back), Vector3(hw, 0, back),
			Vector3(hw, ARENA_H, back), Vector3(-hw, ARENA_H, back)))
	wall_v.append_array(_quad(Vector3(-hw, 0, front), Vector3(-hw, 0, back),
			Vector3(-hw, ARENA_H, back), Vector3(-hw, ARENA_H, front)))
	wall_v.append_array(_quad(Vector3(hw, 0, back), Vector3(hw, 0, front),
			Vector3(hw, ARENA_H, front), Vector3(hw, ARENA_H, back)))
	var cam_at: Vector3 = ARENA_AT + Vector3(0.0, 3.4, 3.6)
	# Its own light: the fighters' torch where the camera is, and a torch
	# each side of the back wall.
	var torches: PackedVector3Array = PackedVector3Array()
	torches.resize(_TORCH_SENT)
	torches[0] = ARENA_AT + Vector3(-hw * 0.55, _TORCH_HEIGHT + 0.6, back + 0.4)
	torches[1] = ARENA_AT + Vector3(hw * 0.55, _TORCH_HEIGHT + 0.6, back + 0.4)
	for part: Array in [[floor_v, 1, Vector3.UP], [wall_v, 0, Vector3.ZERO]]:
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		var verts: PackedVector3Array = part[0] as PackedVector3Array
		arrays[Mesh.ARRAY_VERTEX] = verts
		var normals: PackedVector3Array = PackedVector3Array()
		for i: int in range(0, verts.size(), 3):
			var n: Vector3 = part[2] as Vector3
			if n == Vector3.ZERO:
				n = (verts[i + 1] - verts[i]).cross(verts[i + 2] - verts[i]).normalized()
			normals.append_array([n, n, n])
		arrays[Mesh.ARRAY_NORMAL] = normals
		var mesh: ArrayMesh = ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = mesh
		# Not one of _stone_mats: the maze's lighting follows the player, and
		# this room keeps its own.
		var mat: ShaderMaterial = ShaderMaterial.new()
		mat.shader = _STONE_SHADER
		mat.set_shader_parameter("surface", int(part[1]))
		mat.set_shader_parameter("tint", _tint)
		mat.set_shader_parameter("viewer", cam_at)
		# Reaching as far, against the deeper room, as they did when the back
		# wall stood at 12.
		mat.set_shader_parameter("viewer_range", 16.0)
		mat.set_shader_parameter("torches", torches)
		mat.set_shader_parameter("torch_count", 2)
		mat.set_shader_parameter("torch_range", 9.0)
		mat.set_shader_parameter("ambient", Color(0.22, 0.20, 0.22))
		mi.material_override = mat
		add_child(mi)
		mi.position = ARENA_AT
	root.queue_free()

	arena_camera = Camera3D.new()
	arena_camera.fov = 60.0
	# No depth fog in here: it is there to hide the far maze, and in a room
	# this size it would hide the back wall.
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.02, 0.04)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.12, 0.10, 0.07)
	arena_camera.environment = env
	add_child(arena_camera)
	arena_camera.position = cam_at
	arena_camera.look_at(ARENA_AT + Vector3(0.0, 0.0, -2.0), Vector3.UP)


# Two triangles over four corners, wound the way the corners are given.
func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> PackedVector3Array:
	return PackedVector3Array([a, b, c, a, c, d])

