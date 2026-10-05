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
# A sheet drawn small in a big frame (the character packs: the Necromancer,
# the Wizard standing in for it) is sized by the figure, not the frame, or it
# stands knee-high at the end of a corridor built for a dragon.
const FIGURE_HEIGHT: float = 1.55
const PADDED_BELOW: float = 0.6   # figure under this share of the frame height

var _frames: int = 1
var _clock: float = 0.0
# How far below the sprite's centre its feet are, in world units: set the
# banner's height to this and it stands on the floor.
var feet_drop: float = HEIGHT * 0.5


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
	var h: int = sheet.get_height()
	var img: Image = sheet.get_image()
	if img != null:
		if img.is_compressed():
			img = img.duplicate() as Image
			img.decompress()
		var used: Rect2i = img.get_region(Rect2i(0, 0, h, h)).get_used_rect()
		if used.size.y > 0 and float(used.size.y) < float(h) * PADDED_BELOW:
			pixel_size = FIGURE_HEIGHT / float(used.size.y)
			feet_drop = (float(used.end.y) - float(h) * 0.5) * pixel_size
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
