class_name AnimatedPortrait extends TextureRect

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
	var dir: String = BASE_DIR + sprite_id + "/"
	var tries: Array[String] = ["Idle", "Walk", "Attack01", "Attack02", "Attack03",
			"Attack", "Hurt", "Death", "Block", "Flying", "Beam", "Summon", "Spike"]
	for anim_name: String in tries:
		var path: String = "%s%s_%s.png" % [dir, sprite_id, anim_name]
		if ResourceLoader.exists(path):
			var sheet: Texture2D = load(path) as Texture2D
			_anims[anim_name.to_lower()] = {
				sheet = sheet, frames = sheet.get_width() / FRAME_SIZE}
	_loaded = not _anims.is_empty()
	if _loaded:
		_play_default()


func load_static(tex: Texture2D) -> void:
	if tex == null:
		return
	_atlas.atlas = tex
	_atlas.region = Rect2(Vector2.ZERO, tex.get_size())
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
	_update_frame()


func play_once(anim_name: String) -> void:
	play(anim_name, false)


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
	var cropped: float = float(FRAME_SIZE) / _zoom
	var offset: float = (float(FRAME_SIZE) - cropped) / 2.0
	_atlas.region = Rect2(
		_frame * FRAME_SIZE + offset, offset, cropped, cropped)


static func first_frame_texture(sprite_id: String, zoom: float = 1.0) -> Texture2D:
	if sprite_id == "":
		return null
	var dir: String = BASE_DIR + sprite_id + "/"
	for anim: String in ["Idle", "Flying"]:
		var path: String = "%s%s_%s.png" % [dir, sprite_id, anim]
		if ResourceLoader.exists(path):
			var a: AtlasTexture = AtlasTexture.new()
			a.atlas = load(path) as Texture2D
			var z: float = maxf(zoom, 1.0)
			var cropped: float = float(FRAME_SIZE) / z
			var off: float = (float(FRAME_SIZE) - cropped) / 2.0
			a.region = Rect2(off, off, cropped, cropped)
			return a
	return null
