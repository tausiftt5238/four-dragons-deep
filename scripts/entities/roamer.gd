# Roamer
# A demon walking the floor rather than waiting inside a dice roll. It holds a
# grid cell, steps when the player steps, and starts a battle when the two land
# on the same square.
#
# Look: a dark core with fire turning around it. It is unshaded and additive so
# it reads against the wireframe maze, and the world's depth fog carries it —
# a roamer more than eight cells off is swallowed by the dark, which is what
# makes the glow at the end of a corridor mean something.
class_name Roamer extends Node3D

const CELL_SIZE:   float = 2.0
const HOVER_Y:     float = 0.95
const STEP_TIME:   float = 0.22

# Manhattan range inside which it stops wandering and comes for you.
const CHASE_RANGE: int = 4

const DIRS: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]

var cell: Vector2i = Vector2i.ZERO

# A warden holds its ground and holds the floor's key. It is drawn cold and
# larger so it never reads as one of the drifting ones.
var warden: bool = false

# The patch of the maze this one keeps to, in grid coordinates. Roamers never
# leave their own territory and never step onto a cell another one holds, so
# they stay spread across the floor instead of collecting into a mob around the
# player. An empty rect means unbounded (the warden, which never moves anyway).
var zone: Rect2i = Rect2i()

# Where it came from, so a wandering roamer does not simply oscillate.
var _prev_cell: Vector2i = Vector2i(-999, -999)
var _bob_phase: float = 0.0
var _move_tween: Tween
var _halo: MeshInstance3D
var _cage: Node3D

# Which band it belongs to, 1-4. Set by main before the roamer enters the tree.
var tier: int = 1

# What a roamer burns as, per band. Chosen AGAINST the wall colour of that band
# (Level.TIER_WIRE: cyan, yellow, orange, pale violet) — a roamer in its band's
# own colour is a roamer you walk into. It gets stranger as it gets deeper,
# which is the other half of the job.
const TIER_HOT: Array[Color] = [
	Color(1.00, 0.55, 0.16),   # I   · ember, against cold cyan walls
	Color(1.00, 0.24, 0.18),   # II  · blood, against a yellow band
	Color(1.00, 0.20, 0.72),   # III · magenta, the one colour orange cannot eat
	Color(0.62, 1.00, 0.30),   # IV  · acid, against the violet draining out
]


func _ready() -> void:
	_bob_phase = randf() * TAU
	_build_visual()
	position = _world_of(cell)


func _process(delta: float) -> void:
	_bob_phase += delta * 2.0
	if _halo != null:
		_halo.rotation.y += delta * 0.9
		var pulse: float = 1.0 + sin(_bob_phase * 1.7) * 0.045
		_halo.scale = Vector3(pulse, pulse, pulse)
	# Turned on two axes, slowly and at different rates, so the cage never
	# settles into a pose that reads as a flat ring.
	if _cage != null:
		_cage.rotation.y += delta * 0.55
		_cage.rotation.x += delta * 0.23


# ── Look ──────────────────────────────────────────────────────────────────────

func hot_color() -> Color:
	if warden:
		return Color(0.62, 0.42, 1.0)
	return TIER_HOT[clampi(tier - 1, 0, TIER_HOT.size() - 1)]


func _build_visual() -> void:
	var scale_up: float = 1.45 if warden else 1.0
	var hot: Color  = hot_color()
	var glow: Color = Color(hot.r, hot.g, hot.b).lightened(0.10)

	# The core reads as an absence, not an object — it is darker than the walls.
	# Four overlapping lumps rather than one sphere: unshaded, a single sphere
	# has no interior to see and its silhouette is a circle, which is why the
	# old roamer read as a flat disc pasted on the corridor.
	var core_mat: StandardMaterial3D = StandardMaterial3D.new()
	core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core_mat.albedo_color = Color(0.05, 0.02, 0.07)
	const LUMPS: Array[Vector4] = [
		Vector4(0.0, 0.0, 0.0, 1.00),
		Vector4(0.14, 0.09, -0.05, 0.72),
		Vector4(-0.12, -0.10, 0.07, 0.66),
		Vector4(0.03, -0.14, -0.11, 0.55),
	]
	for l: Vector4 in LUMPS:
		var lump: MeshInstance3D = MeshInstance3D.new()
		var lm: SphereMesh = SphereMesh.new()
		lm.radius = 0.30 * scale_up * l.w
		lm.height = 0.60 * scale_up * l.w
		lm.radial_segments = 12
		lm.rings = 6
		lump.mesh = lm
		lump.material_override = core_mat
		lump.position = Vector3(l.x, l.y, l.z) * scale_up
		add_child(lump)

	add_child(_build_cage(scale_up, hot))

	# A thin shell of heat sitting just off the core.
	_halo = MeshInstance3D.new()
	var halo_mesh: SphereMesh = SphereMesh.new()
	halo_mesh.radius = 0.355 * scale_up
	halo_mesh.height = 0.71 * scale_up
	halo_mesh.radial_segments = 16
	halo_mesh.rings = 8
	_halo.mesh = halo_mesh
	var halo_mat: StandardMaterial3D = StandardMaterial3D.new()
	halo_mat.shading_mode  = BaseMaterial3D.SHADING_MODE_UNSHADED
	halo_mat.transparency  = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo_mat.blend_mode    = BaseMaterial3D.BLEND_MODE_ADD
	halo_mat.cull_mode     = BaseMaterial3D.CULL_FRONT
	# Sits just off the core so it reads as a hot rim, not a cloud around it.
	halo_mat.albedo_color  = Color(hot.r, hot.g, hot.b, 0.34)
	_halo.material_override = halo_mat
	add_child(_halo)

	add_child(_build_fire(scale_up))

	var light: OmniLight3D = OmniLight3D.new()
	light.light_color  = glow
	light.light_energy = 2.1 if warden else 1.6
	light.omni_range   = 6.0 if warden else 4.5
	add_child(light)


# A wire shell turning around the mass. The whole maze is drawn in lines, so
# the thing walking it is drawn in lines too — and a cage that turns gives the
# core a volume an unshaded sphere can never show on its own.
func _build_cage(scale_up: float, hot: Color) -> Node3D:
	const SEGMENTS: int = 20
	var r: float = 0.46 * scale_up
	var verts: PackedVector3Array = PackedVector3Array()
	for axis: int in range(3):
		for i: int in range(SEGMENTS):
			verts.append(_ring_point(axis, TAU * float(i) / float(SEGMENTS), r))
			verts.append(_ring_point(axis, TAU * float(i + 1) / float(SEGMENTS), r))

	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arr)

	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode   = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(hot.r, hot.g, hot.b, 0.85)
	mi.material_override = mat

	_cage = Node3D.new()
	_cage.add_child(mi)
	return _cage


func _ring_point(axis: int, ang: float, r: float) -> Vector3:
	var c: float = cos(ang) * r
	var s: float = sin(ang) * r
	match axis:
		0: return Vector3(0.0, c, s)
		1: return Vector3(c, 0.0, s)
	return Vector3(c, s, 0.0)


func _build_fire(scale_up: float = 1.0) -> CPUParticles3D:
	var fire: CPUParticles3D = CPUParticles3D.new()
	# Many small embers rather than a few big puffs — large soft quads stacked
	# additively average out into a brown smear instead of reading as flame.
	fire.amount   = 46
	fire.lifetime = 0.7
	fire.local_coords = true

	fire.emission_shape        = CPUParticles3D.EMISSION_SHAPE_SPHERE_SURFACE
	fire.emission_sphere_radius = 0.33 * scale_up
	fire.direction  = Vector3(0.0, 1.0, 0.0)
	fire.spread     = 38.0
	fire.gravity    = Vector3(0.0, 0.85, 0.0)
	fire.initial_velocity_min = 0.35
	fire.initial_velocity_max = 0.95
	fire.scale_amount_min = 0.75
	fire.scale_amount_max = 1.0
	fire.angular_velocity_min = -140.0
	fire.angular_velocity_max = 140.0

	# Each ember shrinks as it climbs, which is what gives the licking motion.
	var shrink: Curve = Curve.new()
	shrink.add_point(Vector2(0.0, 0.55))
	shrink.add_point(Vector2(0.25, 1.0))
	shrink.add_point(Vector2(1.0, 0.05))
	fire.scale_amount_curve = shrink

	var ramp: Gradient = Gradient.new()
	if warden:
		ramp.set_color(0, Color(0.92, 0.86, 1.00, 1.0))
		ramp.set_offset(1, 0.30)
		ramp.set_color(1, Color(0.62, 0.40, 1.00, 0.95))
		ramp.add_point(0.65, Color(0.36, 0.16, 0.72, 0.55))
		ramp.add_point(1.0, Color(0.10, 0.03, 0.24, 0.0))
	else:
		# White at the source whatever the band, then down into the band's own
		# colour and out. An ember that starts already coloured reads as confetti.
		var h: Color = hot_color()
		ramp.set_color(0, Color(1.0, 0.97, 0.90, 1.0))
		ramp.set_offset(1, 0.30)
		ramp.set_color(1, Color(h.r, h.g, h.b, 0.95))
		ramp.add_point(0.65, Color(h.r * 0.80, h.g * 0.42, h.b * 0.42, 0.55))
		ramp.add_point(1.0, Color(h.r * 0.28, h.g * 0.10, h.b * 0.12, 0.0))
	fire.color_ramp = ramp

	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.13, 0.13) * scale_up
	fire.mesh = quad

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode   = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency   = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode     = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = _soft_dot()
	mat.disable_receive_shadows = true
	fire.material_override = mat
	return fire


# A radial falloff, built once per roamer. Without it every ember is a hard
# square and the whole effect reads as confetti.
static func _soft_dot() -> ImageTexture:
	const N: int = 32
	var img: Image = Image.create(N, N, false, Image.FORMAT_RGBAF)
	var c: float = (N - 1) * 0.5
	for y: int in range(N):
		for x: int in range(N):
			var d: float = Vector2(x - c, y - c).length() / c
			var a: float = clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a * a))
	return ImageTexture.create_from_image(img)


# ── Movement ──────────────────────────────────────────────────────────────────

func _world_of(c: Vector2i) -> Vector3:
	return Vector3(c.x * CELL_SIZE, HOVER_Y, c.y * CELL_SIZE)


func in_zone(c: Vector2i) -> bool:
	if zone.size.x <= 0 or zone.size.y <= 0:
		return true
	return zone.has_point(c)


# Picks the next cell. Inside its own territory it closes on the player;
# otherwise it wanders, preferring not to double straight back on itself.
# `occupied` holds every cell another roamer is standing on.
func choose_step(player_cell: Vector2i, is_open: Callable,
		occupied: Dictionary = {}) -> Vector2i:
	if warden:
		return cell
	var options: Array[Vector2i] = []
	for d: Vector2i in DIRS:
		var n: Vector2i = cell + d
		if bool(is_open.call(n.x, n.y)) and in_zone(n) and not occupied.has(n):
			options.append(n)
	if options.is_empty():
		return cell

	# It only gives chase within its own patch; step outside and it lets you go.
	var dist: int = absi(cell.x - player_cell.x) + absi(cell.y - player_cell.y)
	if in_zone(player_cell) and dist <= CHASE_RANGE:
		var best: Vector2i = options[0]
		var best_d: int    = 1 << 30
		for o: Vector2i in options:
			var od: int = absi(o.x - player_cell.x) + absi(o.y - player_cell.y)
			if od < best_d:
				best_d = od
				best = o
		return best

	var onward: Array[Vector2i] = []
	for o: Vector2i in options:
		if o != _prev_cell:
			onward.append(o)
	if onward.is_empty():
		onward = options
	return onward[randi() % onward.size()]


func move_to(next_cell: Vector2i) -> void:
	if next_cell == cell:
		return
	_prev_cell = cell
	cell = next_cell
	if is_instance_valid(_move_tween):
		_move_tween.kill()
	_move_tween = create_tween()
	_move_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_move_tween.tween_property(self, "position", _world_of(cell), STEP_TIME)


# Drops it somewhere else outright — used when the player escapes one, so the
# next step does not simply walk back into the same fight.
func teleport_to(next_cell: Vector2i) -> void:
	if is_instance_valid(_move_tween):
		_move_tween.kill()
	_prev_cell = Vector2i(-999, -999)
	cell = next_cell
	position = _world_of(cell)
