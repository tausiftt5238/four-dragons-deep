# DragonBanner
# The dragon of a boss corridor, standing in the stairwell at the far end and
# breathing in its idle loop until you walk up to it. Drawn from the same sheet
# the battle portrait uses (characterSprites/<id>/<id>_Idle.png, square frames
# side by side), as a flat banner facing back down the corridor: the corridor is
# straight, so the player only ever sees it head-on.
class_name DragonBanner extends Sprite3D

const BASE_DIR: String = "res://resources/characterSprites/"
# How tall it stands, in world units — near the ceiling, so it fills the end of
# the corridor the way a dragon should.
const HEIGHT: float = 1.85
const FPS: float = 6.0

var _frames: int = 1
var _clock: float = 0.0


# False when the sprite has no sheet to show, so the caller can skip it.
func setup(sprite_id: String) -> bool:
	var path: String = ""
	for anim: String in ["Idle", "Flying"]:
		var p: String = "%s%s/%s_%s.png" % [BASE_DIR, sprite_id, sprite_id, anim]
		if ResourceLoader.exists(p):
			path = p
			break
	if path == "":
		return false
	var sheet: Texture2D = load(path) as Texture2D
	texture = sheet
	_frames = maxi(1, sheet.get_width() / sheet.get_height())
	hframes = _frames
	frame = 0
	pixel_size = HEIGHT / float(sheet.get_height())
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	shaded = false
	# A little under full brightness, so it sits in the dim corridor rather
	# than glowing off it.
	modulate = Color(0.92, 0.92, 0.92)
	return true


func _process(delta: float) -> void:
	_clock += delta
	frame = int(_clock * FPS) % _frames
