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
# The way on is a flight of steps cut into the wall, not a lit panel stuck to
# it. The wall cell is hollowed out entirely (its face is dropped in
# _build_geometry) and lined, because nothing in this maze has solid ground
# behind it — without cheeks, a back and a ceiling you would be looking straight
# through the level.
const _STAIR_COUNT: int = 6
# How far up the flight climbs before the opening above it goes dark. Short of
# WALL_HEIGHT on purpose: steps that ran all the way to the ceiling would read
# as a ramp into a blocked shaft rather than a way out.
const _STAIR_RISE: float = 0.78


func _add_exit_marker(wall_pos: Vector2i, entry_pos: Vector2i) -> void:
	var dir: Vector2i = entry_pos - wall_pos
	var root: Node3D = Node3D.new()
	root.position = Vector3(wall_pos.x * CELL_SIZE, 0.0, wall_pos.y * CELL_SIZE)
	add_child(root)

	# Outward is the way the stairwell opens; the flight climbs the other way.
	var out: Vector3 = Vector3(float(dir.x), 0.0, float(dir.y))
	var across: Vector3 = Vector3(float(dir.y), 0.0, float(-dir.x))
	var half: float = CELL_SIZE * 0.5

	# Dark, like the fill behind a wall face. At 0.40 these read as a flat green
	# wall the stairs are stuck to, which is louder than anything else down here
	# and buries the step edges that do the actual work.
	var line_mat: StandardMaterial3D = StandardMaterial3D.new()
	line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_mat.albedo_color = Color(0.01, 0.14, 0.10)

	# Cheeks down both sides, and a ceiling over the whole shaft.
	for side: float in [1.0, -1.0]:
		_add_box_child(root,
				across * (half * side) + Vector3(0.0, WALL_HEIGHT * 0.5, 0.0),
				_axis_box(out, across, CELL_SIZE, WALL_HEIGHT, 0.06), line_mat)
	_add_box_child(root, Vector3(0.0, WALL_HEIGHT, 0.0),
			_axis_box(out, across, CELL_SIZE, 0.06, CELL_SIZE), line_mat)

	# The back of the shaft, above the top step: near-black rather than lined, so
	# the flight reads as climbing into darkness instead of stopping at a wall.
	var dark: StandardMaterial3D = StandardMaterial3D.new()
	dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dark.albedo_color = Color(0.02, 0.05, 0.04)
	var rise: float = WALL_HEIGHT * _STAIR_RISE
	_add_box_child(root, out * -half + Vector3(0.0, rise + (WALL_HEIGHT - rise) * 0.5, 0.0),
			_axis_box(out, across, 0.06, WALL_HEIGHT - rise, CELL_SIZE), dark)

	# The flight itself: each step a solid block from the floor up to its own
	# tread, drawn the way everything else down here is drawn — a dark fill with
	# its edges picked out in line.
	#
	# Solid faces do not work for this. The camera stands at exactly eye height,
	# so every tread is edge-on and invisible, and six risers of the same flat
	# colour merge into ONE slab: the first build of this rendered as a green
	# door at the end of the corridor, not as a staircase. It is the line along
	# the nose of each tread that says "steps", and the whole dungeon is lines
	# anyway — solid geometry was the thing that looked out of place.
	var fill_mat: StandardMaterial3D = StandardMaterial3D.new()
	fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fill_mat.albedo_color = Color(0.02, 0.10, 0.07)

	var tread: float = CELL_SIZE / float(_STAIR_COUNT)
	var riser: float = rise / float(_STAIR_COUNT)
	var edges: PackedVector3Array = PackedVector3Array()
	for i: int in range(_STAIR_COUNT):
		var top_y: float = float(i + 1) * riser
		var at: Vector3 = out * (half - (float(i) + 0.5) * tread) \
				+ Vector3(0.0, top_y * 0.5, 0.0)
		var size: Vector3 = _axis_box(out, across, tread, top_y, CELL_SIZE)
		_add_box_child(root, at, size, fill_mat)
		_append_box_edges(edges, at, size)
	_add_line_mesh(root, edges, Color(0.20, 1.0, 0.70))

	# One light at the head of the flight, so what draws the eye down the
	# corridor is the glow coming off the top of the stairs.
	var light: OmniLight3D = OmniLight3D.new()
	light.light_color  = Color(0.2, 1.0, 0.6)
	light.light_energy = 1.8
	light.omni_range   = 4.5
	light.position     = out * (-half + tread) + Vector3(0.0, rise + 0.30, 0.0)
	root.add_child(light)

	# No sign. A flight of steps climbing out of the corridor already says what
	# it is, and the label was left over from when this was a panel that did not.


# The gate standing in the stairwell while the key is still out there. Until
# this existed the only thing saying a floor was sealed was a line of HUD text,
# so a player walking the corridor saw the way out and no reason it would not
# open. Violet throughout, because that is the key's colour everywhere else —
# the floating bit, the minimap mark, the warden popup.
const _LOCK_VIOLET: Color = Color(0.70, 0.48, 1.0)
# Dead ahead at eye height (Main.EYE_HEIGHT is 1.0), so the lock is the thing
# the player is looking at rather than something to find.
const _LOCK_HEIGHT: float = 1.05

var _door: Node3D = null
var _exit_wall: Vector2i = Vector2i(-1, -1)
var _exit_cell: Vector2i = Vector2i(-1, -1)


# The door is a node of its own rather than part of the build, because the key
# is found mid-floor: taking it has to open the way without rebuilding the
# maze. Safe to call with the same value twice.
func set_locked(locked: bool) -> void:
	if is_instance_valid(_door):
		_door.free()
	_door = null
	if not locked or _exit_wall.x < 0 or _exit_cell.x < 0:
		return
	_door = _add_locked_door(_exit_wall, _exit_cell)


func _add_locked_door(wall_pos: Vector2i, entry_pos: Vector2i) -> Node3D:
	var dir: Vector2i = entry_pos - wall_pos
	var root: Node3D = Node3D.new()
	root.position = Vector3(wall_pos.x * CELL_SIZE, 0.0, wall_pos.y * CELL_SIZE)
	add_child(root)

	var out: Vector3 = Vector3(float(dir.x), 0.0, float(dir.y))
	var across: Vector3 = Vector3(float(dir.y), 0.0, float(-dir.x))
	var half: float = CELL_SIZE * 0.5
	# Set just inside the mouth so the flight sits behind the door rather than
	# the top steps poking through its face.
	var face: Vector3 = out * (half - 0.08)
	var mid: Vector3 = face + Vector3(0.0, WALL_HEIGHT * 0.5, 0.0)

	var slab: StandardMaterial3D = StandardMaterial3D.new()
	slab.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	slab.albedo_color = Color(0.05, 0.03, 0.09)
	var panel: Vector3 = _axis_box(out, across, 0.12, WALL_HEIGHT, CELL_SIZE)
	_add_box_child(root, mid, panel, slab)

	# Banded across, because an unbroken rectangle at the end of a corridor
	# reads as the corridor simply stopping. The bands are what make it a door.
	var edges: PackedVector3Array = PackedVector3Array()
	_append_box_edges(edges, mid, panel)
	for i: int in range(1, 4):
		_append_box_edges(edges,
				face + Vector3(0.0, WALL_HEIGHT * 0.25 * float(i), 0.0),
				_axis_box(out, across, 0.14, 0.045, CELL_SIZE * 0.88))
	_add_line_mesh(root, edges, _LOCK_VIOLET)

	_add_lock(root, out, across, face)
	return root


# The lock plate and the recess the key drops into. The recess is the key's own
# silhouette — a PrismMesh of the same proportions as the floating bit — so the
# thing found on the floor and the thing it opens are legible as a pair.
func _add_lock(root: Node3D, out: Vector3, across: Vector3, face: Vector3) -> void:
	var at: Vector3 = face + out * 0.06 + Vector3(0.0, _LOCK_HEIGHT, 0.0)

	var plate_mat: StandardMaterial3D = StandardMaterial3D.new()
	plate_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	plate_mat.albedo_color = Color(0.20, 0.10, 0.34)
	var plate: Vector3 = _axis_box(out, across, 0.08, 0.60, 0.46)
	_add_box_child(root, at, plate, plate_mat)

	var plate_edges: PackedVector3Array = PackedVector3Array()
	_append_box_edges(plate_edges, at, plate)
	_add_line_mesh(root, plate_edges, _LOCK_VIOLET)

	# Turned so the triangle faces down the corridor. atan2(x, z) maps +Z to 0
	# and +X to a quarter turn, which is exactly the four cardinal cases.
	var hole: Node3D = Node3D.new()
	hole.position = at + out * 0.045
	hole.rotation = Vector3(0.0, atan2(out.x, out.z), 0.0)
	root.add_child(hole)

	# Near-black against the lit plate: unshaded, so what makes it read as a
	# hollow is the contrast, not a light that would have to reach in.
	const W: float = 0.26
	const H: float = 0.38
	var sink_mat: StandardMaterial3D = StandardMaterial3D.new()
	sink_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sink_mat.albedo_color = Color(0.02, 0.01, 0.04)
	var sink: MeshInstance3D = MeshInstance3D.new()
	var bit: PrismMesh = PrismMesh.new()
	bit.size = Vector3(W, H, 0.07)
	sink.mesh = bit
	sink.material_override = sink_mat
	hole.add_child(sink)

	var lip: PackedVector3Array = PackedVector3Array()
	var apex: Vector3 = Vector3(0.0, H * 0.5, 0.035)
	var left: Vector3 = Vector3(-W * 0.5, -H * 0.5, 0.035)
	var right: Vector3 = Vector3(W * 0.5, -H * 0.5, 0.035)
	lip.append_array([apex, left, left, right, right, apex])
	_add_line_mesh(hole, lip, _LOCK_VIOLET)

	var glow: OmniLight3D = OmniLight3D.new()
	glow.light_color  = _LOCK_VIOLET
	glow.light_energy = 1.5
	glow.omni_range   = 3.6
	glow.position     = at + out * 0.5
	root.add_child(glow)




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


func _add_orb(pos: Vector2i) -> void:
	var root: Node3D = Node3D.new()
	root.position = Vector3(pos.x * CELL_SIZE, 1.0, pos.y * CELL_SIZE)
	add_child(root)

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
