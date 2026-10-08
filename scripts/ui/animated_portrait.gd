class_name AnimatedPortrait extends TextureRect

# Frames are square and as tall as the sheet. The character packs draw 100px
# frames with the figure small in the middle, which is what zoom crops into; the
# dragons are 16px frames drawn edge to edge, so zoom leaves them whole.
const FRAME_SIZE: int = 100
const BASE_DIR: String = "res://resources/characterSprites/"

var _atlas: AtlasTexture
var _anims: Dictionary = {}
var _current_anim: String = ""
var _frame: int = 0
var _timer: float = 0.0
var _fps: float = 8.0
var _looping: bool = true
var _playing: bool = false
var _loaded: bool = false
var _zoom: float = 1.0
# A cast stops partway through its sheet and holds there (play_cast).
var _stop_at: int = -1
var _hold: float = 0.0
var _sprite_id: String = ""
# How much of the box the figure is drawn in, its feet kept on the box's floor
# (Enemy.figure_scale). Done with the atlas's margin, so the box itself never
# changes size and nothing laid out around it moves.
var shrink: float = 1.0:
	set(v):
		shrink = clampf(v, 0.1, 1.0)
		if _loaded:
			_update_frame()

signal anim_done(anim_name: String)


func _init() -> void:
	_atlas = AtlasTexture.new()
	texture = _atlas
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED


func load_sprite_id(sprite_id: String) -> void:
	if sprite_id == "":
		return
	_anims.clear()
	_sprite_id = sprite_id
	var dir: String = BASE_DIR + sprite_id + "/"
	var tries: Array[String] = ["Idle", "Walk", "Attack01", "Attack02", "Attack03",
			"Attack", "Hurt", "Death", "Block", "Flying", "Beam", "Summon", "Spike"]
	for anim_name: String in tries:
		var path: String = "%s%s_%s.png" % [dir, sprite_id, anim_name]
		if ResourceLoader.exists(path):
			var sheet: Texture2D = load(path) as Texture2D
			_anims[anim_name.to_lower()] = {
				sheet = sheet, frames = sheet.get_width() / sheet.get_height()}
	_loaded = not _anims.is_empty()
	if _loaded:
		_play_default()


# A magic effect drawn on its own sheet (the Necromancer's summoning circle):
# laid over a portrait at the same zoom so it lands where the figure stands,
# played through once, then gone.
static func one_shot(sheet_path: String, zoom: float) -> AnimatedPortrait:
	var fx: AnimatedPortrait = AnimatedPortrait.new()
	var sheet: Texture2D = load(sheet_path) as Texture2D
	fx._anims["fx"] = {sheet = sheet, frames = sheet.get_width() / sheet.get_height()}
	fx._loaded = true
	fx._zoom = maxf(zoom, 1.0)
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fx.anim_done.connect(func(_n: String) -> void: fx.queue_free())
	fx.play_once("fx")
	return fx


func load_static(tex: Texture2D) -> void:
	if tex == null:
		return
	_atlas.atlas = tex
	_atlas.region = Rect2(Vector2.ZERO, tex.get_size())
	_atlas.margin = Rect2()
	_loaded = false
	_playing = false


func _play_default() -> void:
	if _anims.has("idle"):
		play("idle")
	elif _anims.has("flying"):
		play("flying")


func play(anim_name: String, loop: bool = true) -> void:
	var key: String = _resolve(anim_name)
	if key == "":
		return
	if key == _current_anim and _playing:
		return
	_current_anim = key
	_atlas.atlas = (_anims[key] as Dictionary)["sheet"] as Texture2D
	_frame = 0
	_looping = loop
	_playing = true
	_timer = 0.0
	_stop_at = -1
	_fps = DEFAULT_FPS
	_update_frame()


func play_once(anim_name: String) -> void:
	play(anim_name, false)


# ── Casting ──────────────────────────────────────────────────────────────────
#
# The Knight's special attack is how a spell looks in his hands: he raises the
# blade and it flashes along its length (frame six of Attack03), and he holds
# there rather than running on into the swing of flame the sheet ends with.
# The flash is drawn in four shades the rest of him never uses, so those four
# are swapped for the element's own, dark to light, and the plume stays red.
const CAST_SHEET: String = "attack03"
const CAST_FRAME: int = 5        # frame six
const CAST_HOLD: float = 0.6
# Quicker than the sheets' own 8 a second: the turn moves on half a second
# after a spell lands, and at 8 he was pulled back to standing before the
# blade ever flashed. At 16 the flash is up in a third of a second.
const CAST_FPS: float = 16.0
const DEFAULT_FPS: float = 8.0
const FLASH_SHADES: Array[Color] = [Color8(125, 24, 24), Color8(159, 50, 50),
		Color8(190, 81, 47), Color8(221, 144, 74)]
const CAST_RAMPS: Dictionary = {
	"fire":    [Color8(125, 24, 24), Color8(159, 50, 50), Color8(190, 81, 47), Color8(221, 144, 74)],
	"ice":     [Color8(28, 60, 130), Color8(50, 104, 182), Color8(92, 162, 226), Color8(172, 222, 250)],
	"thunder": [Color8(122, 96, 18), Color8(182, 150, 30), Color8(232, 206, 60), Color8(255, 246, 160)],
	"light":   [Color8(150, 128, 78), Color8(202, 186, 122), Color8(240, 230, 182), Color8(255, 255, 240)],
	"dark":    [Color8(60, 20, 92), Color8(96, 42, 142), Color8(142, 72, 192), Color8(196, 142, 236)],
	"phys":    [Color8(92, 100, 112), Color8(140, 150, 162), Color8(190, 200, 212), Color8(240, 245, 250)],
	"heal":    [Color8(26, 96, 46), Color8(48, 140, 70), Color8(92, 196, 110), Color8(176, 240, 180)],
	"other":   [Color8(24, 92, 104), Color8(44, 134, 148), Color8(90, 190, 200), Color8(170, 236, 240)],
}
static var _cast_sheets: Dictionary = {}    # "sprite|kind" -> Texture2D


# Plays the cast in `kind`'s colours (an element, "heal" or "other"); falls back
# to the plain special attack for a figure without one.
func play_cast(kind: String) -> void:
	if not _anims.has(CAST_SHEET):
		play_once("attack")
		return
	play_once(CAST_SHEET)
	_atlas.atlas = _cast_sheet(kind)
	_stop_at = mini(CAST_FRAME, int((_anims[CAST_SHEET] as Dictionary)["frames"]) - 1)
	_hold = CAST_HOLD
	_fps = CAST_FPS
	_update_frame()


func _cast_sheet(kind: String) -> Texture2D:
	var base: Texture2D = (_anims[CAST_SHEET] as Dictionary)["sheet"] as Texture2D
	if not CAST_RAMPS.has(kind):
		kind = "other"
	if kind == "fire":
		return base     # the sheet is already drawn in fire
	var key: String = "%s|%s" % [_sprite_id, kind]
	if _cast_sheets.has(key):
		return _cast_sheets[key] as Texture2D
	# A copy: get_image() can hand back the sheet's own image, and recolouring
	# that in place would turn every later cast, fire included, the same.
	var img: Image = base.get_image().duplicate() as Image
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var ramp: Array = CAST_RAMPS[kind]
	var lookup: Dictionary = {}
	for i: int in FLASH_SHADES.size():
		lookup[FLASH_SHADES[i].to_rgba32()] = ramp[i]
	for y: int in img.get_height():
		for x: int in img.get_width():
			var c: Color = img.get_pixel(x, y)
			if c.a <= 0.0:
				continue
			var opaque: Color = Color(c.r, c.g, c.b, 1.0)
			var swap: Variant = lookup.get(opaque.to_rgba32())
			if swap != null:
				var to: Color = swap as Color
				img.set_pixel(x, y, Color(to.r, to.g, to.b, c.a))
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_cast_sheets[key] = tex
	return tex


func _resolve(anim_name: String) -> String:
	if _anims.has(anim_name):
		return anim_name
	match anim_name:
		"idle":
			if _anims.has("flying"):
				return "flying"
		"attack":
			if _anims.has("attack01"):
				return "attack01"
		"walk":
			if _anims.has("idle"):
				return "idle"
			if _anims.has("flying"):
				return "flying"
	return ""


func _process(delta: float) -> void:
	if not _playing or not _loaded:
		return
	_timer += delta
	var step: float = 1.0 / _fps
	if _timer < step:
		return
	_timer -= step
	if _stop_at >= 0 and _frame >= _stop_at:
		# Holding the cast: wait it out, then back to standing.
		_hold -= step
		if _hold > 0.0:
			return
		_stop_at = -1
		_playing = false
		anim_done.emit(_current_anim)
		_play_default()
		return
	_frame += 1
	var max_frames: int = int((_anims[_current_anim] as Dictionary)["frames"])
	if _frame >= max_frames:
		if _looping:
			_frame = 0
		else:
			_frame = max_frames - 1
			_playing = false
			anim_done.emit(_current_anim)
			if _current_anim != "death":
				_play_default()
			return
	_update_frame()


func set_zoom(z: float) -> void:
	_zoom = maxf(z, 1.0)
	if _loaded:
		_update_frame()


func _update_frame() -> void:
	var size: int = _atlas.atlas.get_height()
	_atlas.region = _frame_region(size, _frame, _zoom)
	var r: float = _atlas.region.size.x
	var pad: float = r / shrink - r
	_atlas.margin = Rect2(pad / 2.0, pad, pad, pad)


# Whether the figure is drawn edge to edge in its frame (the dragons' 16px
# sheets) rather than small in the middle of a 100px one, which zoom crops into.
# An edge-to-edge figure's feet are on the bottom of its box, not partway up.
func fills_frame() -> bool:
	return _loaded and _atlas.atlas != null and _atlas.atlas.get_height() < FRAME_SIZE


static func _frame_region(size: int, frame: int, zoom: float) -> Rect2:
	var z: float = maxf(zoom, 1.0) if size >= FRAME_SIZE else 1.0
	var cropped: float = float(size) / z
	var offset: float = (float(size) - cropped) / 2.0
	return Rect2(frame * size + offset, offset, cropped, cropped)


static func first_frame_texture(sprite_id: String, zoom: float = 1.0) -> Texture2D:
	if sprite_id == "":
		return null
	var dir: String = BASE_DIR + sprite_id + "/"
	for anim: String in ["Idle", "Flying"]:
		var path: String = "%s%s_%s.png" % [dir, sprite_id, anim]
		if ResourceLoader.exists(path):
			var a: AtlasTexture = AtlasTexture.new()
			a.atlas = load(path) as Texture2D
			a.region = _frame_region(a.atlas.get_height(), 0, zoom)
			return a
	return null
