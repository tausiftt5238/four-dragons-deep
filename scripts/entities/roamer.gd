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

# Where it came from, so a wandering roamer does not simply oscillate.
var _prev_cell: Vector2i = Vector2i(-999, -999)
var _bob_phase: float = 0.0
var _move_tween: Tween
var _halo: MeshInstance3D


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


# ── Look ──────────────────────────────────────────────────────────────────────

func _build_visual() -> void:
	# The core reads as an absence, not an object — it is darker than the walls.
	var core: MeshInstance3D = MeshInstance3D.new()
	var core_mesh: SphereMesh = SphereMesh.new()
	core_mesh.radius = 0.30
	core_mesh.height = 0.60
	core_mesh.radial_segments = 16
	core_mesh.rings = 8
	core.mesh = core_mesh
	var core_mat: StandardMaterial3D = StandardMaterial3D.new()
	core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core_mat.albedo_color = Color(0.05, 0.02, 0.07)
	core.material_override = core_mat
	add_child(core)

	# A thin shell of heat sitting just off the core.
	_halo = MeshInstance3D.new()
	var halo_mesh: SphereMesh = SphereMesh.new()
	halo_mesh.radius = 0.355
	halo_mesh.height = 0.71
	halo_mesh.radial_segments = 16
	halo_mesh.rings = 8
	_halo.mesh = halo_mesh
	var halo_mat: StandardMaterial3D = StandardMaterial3D.new()
	halo_mat.shading_mode  = BaseMaterial3D.SHADING_MODE_UNSHADED
	halo_mat.transparency  = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo_mat.blend_mode    = BaseMaterial3D.BLEND_MODE_ADD
	halo_mat.cull_mode     = BaseMaterial3D.CULL_FRONT
	# Sits just off the core so it reads as a hot rim, not a cloud around it.
	halo_mat.albedo_color  = Color(1.0, 0.55, 0.16, 0.34)
	_halo.material_override = halo_mat
	add_child(_halo)

	add_child(_build_fire())

	var light: OmniLight3D = OmniLight3D.new()
	light.light_color  = Color(1.0, 0.55, 0.20)
	light.light_energy = 1.6
	light.omni_range   = 4.5
	add_child(light)


func _build_fire() -> CPUParticles3D:
	var fire: CPUParticles3D = CPUParticles3D.new()
	# Many small embers rather than a few big puffs — large soft quads stacked
	# additively average out into a brown smear instead of reading as flame.
	fire.amount   = 46
	fire.lifetime = 0.7
	fire.local_coords = true

	fire.emission_shape        = CPUParticles3D.EMISSION_SHAPE_SPHERE_SURFACE
	fire.emission_sphere_radius = 0.33
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
	ramp.set_color(0, Color(1.00, 0.97, 0.80, 1.0))
	ramp.set_offset(1, 0.30)
	ramp.set_color(1, Color(1.00, 0.58, 0.10, 0.95))
	ramp.add_point(0.65, Color(0.92, 0.24, 0.03, 0.55))
	ramp.add_point(1.0, Color(0.30, 0.04, 0.01, 0.0))
	fire.color_ramp = ramp

	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.13, 0.13)
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


# Picks the next cell. Close to the player it closes the distance; otherwise it
# wanders, preferring not to double straight back on itself.
func choose_step(player_cell: Vector2i, is_open: Callable) -> Vector2i:
	var options: Array[Vector2i] = []
	for d: Vector2i in DIRS:
		var n: Vector2i = cell + d
		if bool(is_open.call(n.x, n.y)):
			options.append(n)
	if options.is_empty():
		return cell

	var dist: int = absi(cell.x - player_cell.x) + absi(cell.y - player_cell.y)
	if dist <= CHASE_RANGE:
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
