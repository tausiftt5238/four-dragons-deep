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
	_build_geometry(level)
	_exit_wall = level.exit_wall_pos
	_exit_cell = level.exit_pos
	if level.exit_pos.x >= 0 and level.exit_wall_pos.x >= 0:
		_add_exit_marker(level.exit_wall_pos, level.exit_pos)
	_add_trap_markers(level)
	_add_orbs(level)
	_add_chests(level)
	if level.key_pos.x >= 0 and not level.key_taken:
		_add_key(level.key_pos)
	_setup_environment()


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
				# Only faces that touch open floor are ever seen. A chest used
				# to delete the face it opened through as well, because it was a
				# recess cut into the block and the fill behind a wall writes
				# depth, which buried it. It hangs on the wall now, so the wall
				# stays whole and the banner sits just in front of it.
				var cache_face: Vector2i = Vector2i(-999, -999)
				# The stairwell is still hollowed rather than decorated, so the
				# face the stairs climb through has to go or they are buried
				# behind it.
				if here == level.exit_wall_pos:
					cache_face = level.exit_pos
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

	_commit_fill(level)
	_commit_flat(level, _floor_v, 1, Vector3.UP)
	_commit_flat(level, _ceil_v, 2, Vector3.DOWN)
	_commit_wire()
	_place_torches(level)


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
func _add_floor_quad(col: int, row: int) -> void:
	var wx: float = col * CELL_SIZE
	var wz: float = row * CELL_SIZE
	var h: float  = CELL_SIZE * 0.5
	var c0: Vector3 = Vector3(wx - h, 0.0, wz - h)
	var c1: Vector3 = Vector3(wx + h, 0.0, wz - h)
	var c2: Vector3 = Vector3(wx + h, 0.0, wz + h)
	var c3: Vector3 = Vector3(wx - h, 0.0, wz + h)
	_floor_v.append_array([c0, c1, c2, c0, c2, c3])
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
	_add_box_child(root, out * -half + Vector3(0.0, (lintel_y - pit) * 0.5, 0.0),
			_axis_box(out, across, 0.06, lintel_y + pit, CELL_SIZE), dark)

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
# A cache hangs on a wall like a banner. It used to be cut INTO the block, which
# meant it had to bring its own recess — no wall in this maze has anything solid
# behind it, so an unlined niche looked straight through the level — and that
# lining was three quads and a floor standing in for masonry that was never
# there. A banner needs none of it: the wall face stays whole and the sprite
# sits just in front of it.
# How far the banner stands off the wall it hangs on. Enough to clear the wall
# face without reading as a box pulled out of it — the point of the change is
# that a chest is a picture on the stonework, not a thing with sides.
const _CHEST_STANDOFF: float = 0.03

# Two frames side by side in one 96x48 image: closed on the left, lid tipped
# back on the right. Which half is showing is the whole of the looted state —
# an emptied cache is the same chest standing open, not a dimmer box.
const _CHEST_TEX: Texture2D = preload("res://resources/mapAsset/TreasureChest.png")
const _CHEST_SHADER := preload("res://resources/shaders/chest_banner.gdshader")
const _CHEST_FRAMES: float = 2.0

# The drawn chest is only the middle 28 of its frame's 48 pixels and sits 8 up
# from the bottom edge, so the quad has to be a good deal bigger than the chest
# looks. These two are set together: the size makes the drawn chest read at the
# scale the block it replaced did, and the lift puts its feet near the floor
# rather than halfway up the wall. Changing either alone floats it or sinks it.
const _CHEST_SIZE: float = 1.32
const _CHEST_LIFT: float = 0.52

# How hard the chest is worked into the wall it hangs on — see the shader's own
# notes. These are the four to move if it starts looking pasted on again, and
# zeroing all four gives back the plain lit sprite.
const _CHEST_BEVEL: float   = 1.2
const _CHEST_TINT: float    = 0.45
# Small on purpose. Specular on a flat quad is one flat highlight; this is only
# here to keep the bands from being as matte as the wall around them.
const _CHEST_SHEEN: float   = 0.20
const _CHEST_CONTACT: float = 0.7
const _CHEST_GLOW: float    = 1.15
# How far in front of the chest its light hangs. Not optional now the sprite is
# lit rather than unshaded: a light sitting exactly on the quad reaches every
# point of it from a direction lying in the quad's own plane, so N·L is about
# zero and the chest takes almost no diffuse from the one lamp that is there for
# it. Standing the lamp off towards the corridor is what lights the face.
const _CHEST_LIGHT_STANDOFF: float = 0.22


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

	# Outward is the direction the chest faces; the wall behind it is whole.
	var out: Vector3 = Vector3(float(dir.x), 0.0, float(dir.y))

	# The cache itself, hung on the face of the wall like a banner rather than
	# set into a hole cut through it. A mimic is drawn with exactly this call —
	# nothing here may ever branch on whether the cache is real, or the disguise
	# is over before it starts.
	var centre: Vector3 = out * (CELL_SIZE * 0.5 + _CHEST_STANDOFF) \
			+ Vector3(0.0, _CHEST_LIFT, 0.0)
	_add_chest_sprite(root, centre, out, looted, wire)

	# Both states carry a light now, because the chest is lit geometry rather
	# than an unshaded decal: ambient down here is 0.12, so an emptied cache with
	# nothing on it would be a black smear in a lined hole instead of somewhere
	# you can see you have already been. The spent one is dim and colourless —
	# what it must not do is still look worth crossing a floor for.
	var light: OmniLight3D = OmniLight3D.new()
	light.light_color  = wire.lerp(Color(0.75, 0.78, 0.85), 0.5) if looted \
			else Color(1.0, 0.82, 0.40)
	light.light_energy = 0.5 if looted else 1.6
	light.omni_range   = 2.0 if looted else 3.4
	light.position     = centre + out * _CHEST_LIGHT_STANDOFF
	root.add_child(light)


# The chest, as a flat quad hung on the wall and turned to face the one cell it
# can be opened from. A quad rather than a billboard: a cache hangs on a wall
# and opens one way, so a sprite that swivelled to follow the player would peel
# off the stonework at any angle but head-on.
func _add_chest_sprite(parent: Node3D, pos: Vector3, out: Vector3, looted: bool,
		wire: Color) -> void:
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = _CHEST_SHADER
	mat.set_shader_parameter("tex", _CHEST_TEX)
	mat.set_shader_parameter("frames", _CHEST_FRAMES)
	mat.set_shader_parameter("frame", 1.0 if looted else 0.0)
	# What stops it sitting in front of the room rather than in it. The tint is
	# the band's own wire colour, so the chest is recoloured by depth along with
	# every wall around it; the rest gives a flat quad a surface.
	mat.set_shader_parameter("bevel", _CHEST_BEVEL)
	mat.set_shader_parameter("tint", wire)
	mat.set_shader_parameter("tint_amount", _CHEST_TINT)
	mat.set_shader_parameter("sheen", _CHEST_SHEEN)
	mat.set_shader_parameter("contact", _CHEST_CONTACT)
	# Only a full one is lit from the inside.
	mat.set_shader_parameter("glow", 0.0 if looted else _CHEST_GLOW)

	var mi: MeshInstance3D = MeshInstance3D.new()
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(_CHEST_SIZE, _CHEST_SIZE)
	mi.mesh = quad
	mi.material_override = mat
	mi.position = pos
	# A QuadMesh faces +Z; turn it to face the way the niche opens.
	mi.rotation = Vector3(0.0, atan2(out.x, out.z), 0.0)
	parent.add_child(mi)


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


# Colored floor overlay for each trap cell so the player can see them. Traps
# all bite the same way now, so they all read red.
func _add_trap_markers(level: Level) -> void:
	for pos: Variant in level.trap_cells.keys():
		var gp: Vector2i      = pos as Vector2i
		var wx: float = gp.x * CELL_SIZE
		var wz: float = gp.y * CELL_SIZE

		var col:       Color = Color(0.72, 0.08, 0.08)
		var light_col: Color = Color(1.0,  0.25, 0.25)

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



func _add_box_child(parent: Node3D, pos: Vector3, size: Vector3,
		mat: Material) -> void:
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
