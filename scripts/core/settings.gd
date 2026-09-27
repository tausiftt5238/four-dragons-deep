# Settings
# Player preferences that belong to the device rather than to a run, so they
# live in their own file and no save slot carries them. Read once on first use
# and written back whenever one changes.
class_name Settings

const PATH: String = "user://settings.cfg"

static var _invert_turn: bool = false
static var _invert_move: bool = false
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


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	_invert_turn = bool(cfg.get_value("controls", "invert_turn", false))
	_invert_move = bool(cfg.get_value("controls", "invert_move", false))


static func _save() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("controls", "invert_turn", _invert_turn)
	cfg.set_value("controls", "invert_move", _invert_move)
	cfg.save(PATH)
