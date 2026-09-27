# LoadingScreen
# Stands between the title and the game. Pressing New Game or Load Game used to
# change scene straight away, and the frame froze on the title while the game
# scene loaded and built its first floor — the press had landed, but nothing
# said so. This goes up on the same frame as the press, has the Knight walking
# on the spot while the scene loads, and stays up until the game's first frame
# has drawn underneath it.
#
# It hangs off the tree root rather than the current scene, which is what lets
# it outlive the scene change it is covering.
class_name LoadingScreen extends CanvasLayer

const _FONT := preload("res://resources/misc/OldSchoolAdventures-42j9.ttf") as FontFile

const _SPRITE_SIZE: float = 260.0

var _walker: AnimatedPortrait
var _dots: Label
var _dots_timer: float = 0.0


# Covers the screen, swaps to `scene_path`, and takes itself down once the new
# scene has drawn. Call it instead of change_scene_to_file.
static func change_scene(tree: SceneTree, scene_path: String) -> void:
	var screen: LoadingScreen = LoadingScreen.new()
	tree.root.add_child(screen)
	screen._run(scene_path)


func _ready() -> void:
	layer = 100
	_build()


func _build() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.04, 0.03, 0.07, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Swallows taps, so nothing on the title underneath can be pressed twice.
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	_walker = AnimatedPortrait.new()
	# On the spot rather than across the screen: a load can be over in under a
	# second, and he has to be in view for all of it.
	_walker.anchor_left   = 0.5
	_walker.anchor_right  = 0.5
	_walker.anchor_top    = 0.5
	_walker.anchor_bottom = 0.5
	_walker.offset_left   = -_SPRITE_SIZE * 0.5
	_walker.offset_right  = _SPRITE_SIZE * 0.5
	_walker.offset_top    = -_SPRITE_SIZE * 0.5
	_walker.offset_bottom = _SPRITE_SIZE * 0.5
	_walker.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	_walker.load_sprite_id(PlayerCharacter.SPRITE_KNIGHT)
	_walker.play("walk")
	# The figure fills about a third of its 100px frame; crop in on it.
	_walker.set_zoom(2.5)
	add_child(_walker)

	_dots = Label.new()
	_dots.text = "Descending"
	_dots.anchor_left   = 0.0
	_dots.anchor_right  = 1.0
	_dots.anchor_top    = 0.5
	_dots.anchor_bottom = 0.5
	_dots.offset_top    = _SPRITE_SIZE * 0.5 + 8.0
	_dots.offset_bottom = _SPRITE_SIZE * 0.5 + 48.0
	_dots.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dots.add_theme_font_override("font", _FONT)
	_dots.add_theme_font_size_override("font_size", 22)
	_dots.add_theme_color_override("font_color", Color(0.90, 0.75, 0.30))
	add_child(_dots)


func _process(delta: float) -> void:
	_dots_timer += delta
	var n: int = int(_dots_timer * 2.5) % 4
	_dots.text = "Descending" + ".".repeat(n)


func _run(scene_path: String) -> void:
	# One drawn frame first, so the screen is what the press answers with.
	await get_tree().process_frame
	await get_tree().process_frame

	var packed: PackedScene = null
	if ResourceLoader.load_threaded_request(scene_path) == OK:
		while ResourceLoader.load_threaded_get_status(scene_path) \
				== ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			await get_tree().process_frame
		packed = ResourceLoader.load_threaded_get(scene_path) as PackedScene
	if packed == null:
		packed = load(scene_path) as PackedScene
	get_tree().change_scene_to_packed(packed)

	# The new scene builds its first floor in _ready, on the frame after the
	# swap. Wait for that and for one frame of it to draw before lifting.
	await get_tree().scene_changed
	await get_tree().process_frame
	await get_tree().process_frame

	var fade: Tween = create_tween()
	for child: Node in get_children():
		if child is CanvasItem:
			fade.parallel().tween_property(child, "modulate:a", 0.0, 0.25)
	await fade.finished
	queue_free()
