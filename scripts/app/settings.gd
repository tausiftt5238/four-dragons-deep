# Settings
# Player preferences that belong to the device rather than to a run, so they
# live in their own file and no save slot carries them. Read once on first use
# and written back whenever one changes.
class_name Settings

const PATH: String = "user://settings.cfg"

static var _invert_turn: bool = false
static var _invert_move: bool = false
# Percent, 0 to 100. Each drives its own audio bus, made here on first use.
static var _music_volume: int = 80
static var _sfx_volume: int = 80
# The PC build: fullscreen, or a window that fits the screen (apply_window).
static var _fullscreen: bool = true
static var _loaded: bool = false


# Swipe left to turn right, and right to turn left: the view is dragged rather
# than pointed.
static func invert_turn() -> bool:
	_ensure_loaded()
	return _invert_turn


# Swipe down to step forward and up to step back: the floor is pulled toward
# you rather than pushed away.
static func invert_move() -> bool:
	_ensure_loaded()
	return _invert_move


static func set_invert_turn(on: bool) -> void:
	_ensure_loaded()
	_invert_turn = on
	_save()


static func set_invert_move(on: bool) -> void:
	_ensure_loaded()
	_invert_move = on
	_save()


static func music_volume() -> int:
	_ensure_loaded()
	return _music_volume


static func sfx_volume() -> int:
	_ensure_loaded()
	return _sfx_volume


# Applied at once; `keep` writes it down. A slider applies as it is dragged
# and keeps when it is let go, rather than writing the file every step.
static func set_music_volume(pct: int, keep: bool = true) -> void:
	_ensure_loaded()
	_music_volume = clampi(pct, 0, 100)
	apply_volume(MUSIC_BUS, _music_volume)
	if keep:
		_save()


static func set_sfx_volume(pct: int, keep: bool = true) -> void:
	_ensure_loaded()
	_sfx_volume = clampi(pct, 0, 100)
	apply_volume(SFX_BUS, _sfx_volume)
	if keep:
		_save()


static func fullscreen() -> bool:
	_ensure_loaded()
	return _fullscreen


static func set_fullscreen(on: bool) -> void:
	_ensure_loaded()
	_fullscreen = on
	apply_window()
	_save()


# Fullscreen, or the largest 16:9 window that fits nine tenths of the screen
# the game is on, in the middle of it.
static func apply_window() -> void:
	_ensure_loaded()
	if _fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var screen: int = DisplayServer.window_get_current_screen()
	var room: Rect2i = DisplayServer.screen_get_usable_rect(screen)
	var w: int = mini(1920, int(room.size.x * 0.9))
	var h: int = mini(int(w * 9.0 / 16.0), int(room.size.y * 0.9))
	w = int(h * 16.0 / 9.0)
	DisplayServer.window_set_size(Vector2i(w, h))
	DisplayServer.window_set_position(room.position + (room.size - Vector2i(w, h)) / 2)


const MUSIC_BUS: String = "Music"
const SFX_BUS: String = "SFX"


# The bus a player should be on, made and set to the saved volume if it is not
# there yet.
static func audio_bus(bus: String) -> String:
	_ensure_loaded()
	if AudioServer.get_bus_index(bus) < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
		apply_volume(bus, _music_volume if bus == MUSIC_BUS else _sfx_volume)
	return bus


static func apply_volume(bus: String, pct: int) -> void:
	var idx: int = AudioServer.get_bus_index(bus)
	if idx < 0:
		return
	AudioServer.set_bus_mute(idx, pct <= 0)
	AudioServer.set_bus_volume_db(idx, linear_to_db(float(pct) / 100.0) if pct > 0 else -80.0)


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	_invert_turn = bool(cfg.get_value("controls", "invert_turn", false))
	_invert_move = bool(cfg.get_value("controls", "invert_move", false))
	_music_volume = int(cfg.get_value("audio", "music", 80))
	_sfx_volume = int(cfg.get_value("audio", "sfx", 80))
	_fullscreen = bool(cfg.get_value("display", "fullscreen", true))


static func _save() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	# Loaded first: the same file keeps the button mapping (Controls).
	cfg.load(PATH)
	cfg.set_value("controls", "invert_turn", _invert_turn)
	cfg.set_value("controls", "invert_move", _invert_move)
	cfg.set_value("audio", "music", _music_volume)
	cfg.set_value("audio", "sfx", _sfx_volume)
	cfg.set_value("display", "fullscreen", _fullscreen)
	cfg.save(PATH)
