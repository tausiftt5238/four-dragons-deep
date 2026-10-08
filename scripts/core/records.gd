# Records
# Lifetime numbers for this device, across every run and every new game, in a
# file of their own (not in any save): how long has been played, how far down
# anyone got, what fell along the way. Shown from the Abyss menu (RecordsUI).
#
# Counters are written as they change, except play time, which piles up in
# memory and is written now and then (flush), so a frame never touches disk.
class_name Records

const PATH: String = "user://records.cfg"
const SECTION: String = "records"
const FLUSH_EVERY: float = 30.0

static var _cfg: ConfigFile = null
static var _unsaved_time: float = 0.0
static var _since_flush: float = 0.0


static func _file() -> ConfigFile:
	if _cfg == null:
		_cfg = ConfigFile.new()
		_cfg.load(PATH)
	return _cfg


static func value(key: String) -> float:
	var v: float = float(_file().get_value(SECTION, key, 0))
	if key == "play_time":
		v += _unsaved_time
	return v


static func add(key: String, amount: float = 1.0) -> void:
	_file().set_value(SECTION, key, float(_file().get_value(SECTION, key, 0)) + amount)
	_file().save(PATH)


static func set_max(key: String, v: float) -> void:
	if v > float(_file().get_value(SECTION, key, 0)):
		_file().set_value(SECTION, key, v)
		_file().save(PATH)


# A record where lower is better; 0 means not set yet.
static func set_min(key: String, v: float) -> void:
	var cur: float = float(_file().get_value(SECTION, key, 0))
	if cur <= 0.0 or v < cur:
		_file().set_value(SECTION, key, v)
		_file().save(PATH)


# Called every frame of play; written out every FLUSH_EVERY seconds.
static func tick(delta: float) -> void:
	_unsaved_time += delta
	_since_flush += delta
	if _since_flush >= FLUSH_EVERY:
		flush()


static func flush() -> void:
	_since_flush = 0.0
	if _unsaved_time <= 0.0:
		return
	_file().set_value(SECTION, "play_time",
			float(_file().get_value(SECTION, "play_time", 0)) + _unsaved_time)
	_unsaved_time = 0.0
	_file().save(PATH)


static func clock(seconds: float) -> String:
	var s: int = int(seconds)
	return "%dh %02dm" % [s / 3600, (s / 60) % 60] if s >= 3600 else "%dm %02ds" % [s / 60, s % 60]


# What the screen lists, in order: [label, text].
static func rows() -> Array:
	var best_clear: float = value("fastest_clear")
	return [
		["Total play time", clock(value("play_time"))],
		["Runs started", str(int(value("runs_started")))],
		["Necromancer defeated", str(int(value("runs_won")))],
		["Fastest clear", clock(best_clear) if best_clear > 0.0 else "-"],
		["Deaths", str(int(value("deaths")))],
		["Deepest floor", "Floor %d" % int(value("deepest_floor")) if value("deepest_floor") > 0 else "-"],
		["Deepest Abyss", ("Abyss %d, the end" if Abyss.best_depth() >= Abyss.END_DEPTH else "Abyss %d")
				% Abyss.best_depth() if Abyss.best_depth() > 0 else "-"],
		["Abyss descents", str(int(value("abyss_runs"))) + (
				"  (%d cleared)" % int(value("abyss_cleared")) if value("abyss_cleared") > 0 else "")],
		["Fights won", str(int(value("fights_won")))],
		["Monsters defeated", str(int(value("monsters_defeated")))],
		["Wardens defeated", str(int(value("wardens_defeated")))],
		["Dragons slain", str(int(value("dragons_slain")))],
		["Demons recruited", str(int(value("demons_recruited")))],
		["Gold from fights", str(int(value("gold_earned")))],
	]
