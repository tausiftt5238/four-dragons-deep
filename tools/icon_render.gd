# Renders the corridor behind the app icon, in the game's own stone.
#
# A straight run of cells built the way Dungeon builds the maze: the stone
# shader on the walls, floor and ceiling, the band's faint wire lines along
# every edge, the player's carried light at the camera and a torch on each
# wall a few cells in. Seen from where the player stands, with the game's
# field of view, so it is the view the game opens on.
#
# Writes .godot/icon_corridor.png (432×432); tools/make_icons.py puts the eyes
# on it and cuts every size. Run from the repo root:
#
#   godot --path . --rendering-driver opengl3 --script tools/icon_render.gd
#
# It needs a display (xvfb-run works); --headless renders nothing.
extends SceneTree

const SIZE: int = 432
const CELLS: int = 3   # short, so the far end is a wide dark doorway
const BAND: int = 1     # which band's colour the stone and lines take

const STONE: Shader = preload("res://resources/shaders/stone.gdshader")


func _initialize() -> void:
	var vp: SubViewport = SubViewport.new()
	vp.size = Vector2i(SIZE, SIZE)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.own_world_3d = true
	root.add_child(vp)

	var env: WorldEnvironment = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color.BLACK
	vp.add_child(env)

	var cs: float = Dungeon.CELL_SIZE
	var wh: float = Dungeon.WALL_HEIGHT
	var tint: Color = Level.TIER_WIRE[BAND - 1]
	var eye: Vector3 = Vector3(0.0, Main.EYE_HEIGHT, Main.CAM_PULLBACK)

	# Torches a few cells down, one each side, staggered, as the game spaces them.
	var torches: PackedVector3Array = PackedVector3Array([
		Vector3(-cs * 0.5 + 0.15, 1.30, -cs * 1.0),
		Vector3(cs * 0.5 - 0.15, 1.30, -cs * 2.0),
	])
	torches.resize(12)

	var mats: Array[ShaderMaterial] = []
	for surface: int in 3:
		var m: ShaderMaterial = ShaderMaterial.new()
		m.shader = STONE
		m.set_shader_parameter("surface", surface)
		m.set_shader_parameter("tint", tint)
		m.set_shader_parameter("viewer", eye)
		m.set_shader_parameter("torches", torches)
		m.set_shader_parameter("torch_count", 2)
		mats.append(m)

	# Cells run from the player's own (z = 0) away down -z.
	var half: float = cs * 0.5
	var z0: float = half
	var z1: float = -cs * CELLS + half
	var length: float = z0 - z1
	var mid_z: float = (z0 + z1) * 0.5
	_quad(vp, Vector3(-half, wh * 0.5, mid_z), Vector3(0, 0, 0), Vector2(length, wh), mats[0], Vector3(0, PI * 0.5, 0))
	_quad(vp, Vector3(half, wh * 0.5, mid_z), Vector3(0, 0, 0), Vector2(length, wh), mats[0], Vector3(0, -PI * 0.5, 0))
	_quad(vp, Vector3(0, 0, mid_z), Vector3(0, 0, 0), Vector2(cs, length), mats[1], Vector3(-PI * 0.5, 0, 0))
	_quad(vp, Vector3(0, wh, mid_z), Vector3(0, 0, 0), Vector2(cs, length), mats[2], Vector3(PI * 0.5, 0, 0))

	# The wire: every cell's outline on the floor and ceiling and the edges of
	# each wall face, in the band colour at the game's faintness.
	var im: ImmediateMesh = ImmediateMesh.new()
	var line_mat: StandardMaterial3D = StandardMaterial3D.new()
	line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_mat.vertex_color_use_as_albedo = true
	line_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	line_mat.render_priority = 1
	im.surface_begin(Mesh.PRIMITIVE_LINES, line_mat)
	for i: int in CELLS:
		var za: float = -cs * i + half
		var zb: float = za - cs
		for y: float in [0.0, wh]:
			var a: float = 0.30 if y == 0.0 else 0.12
			var c: Color = Color(tint.r, tint.g, tint.b, a)
			_line(im, Vector3(-half, y, za), Vector3(half, y, za), c)
			for x: float in [-half, half]:
				_line(im, Vector3(x, y, za), Vector3(x, y, zb), c)
		var wc: Color = Color(tint.r, tint.g, tint.b, 0.18)
		for x: float in [-half, half]:
			_line(im, Vector3(x, 0.0, za), Vector3(x, wh, za), wc)
	im.surface_end()
	var wire: MeshInstance3D = MeshInstance3D.new()
	wire.mesh = im
	vp.add_child(wire)

	var cam: Camera3D = Camera3D.new()
	cam.fov = Main.CAM_FOV
	cam.position = eye
	vp.add_child(cam)
	cam.current = true

	for i: int in 4:
		await process_frame
	var img: Image = vp.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("res://.godot/icon_corridor.png"))
	print("wrote .godot/icon_corridor.png")
	quit()


func _quad(parent: Node, pos: Vector3, _unused: Vector3, size: Vector2,
		mat: Material, rot: Vector3) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var q: QuadMesh = QuadMesh.new()
	q.size = size
	mi.mesh = q
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)


func _line(im: ImmediateMesh, a: Vector3, b: Vector3, c: Color) -> void:
	im.surface_set_color(c)
	im.surface_add_vertex(a)
	im.surface_set_color(c)
	im.surface_add_vertex(b)
