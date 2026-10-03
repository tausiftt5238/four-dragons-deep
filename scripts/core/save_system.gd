class_name SaveSystem

# The game writes this one itself, when the app goes to the background and
# whenever play settles (a floor reached, a fight over), so a phone that kills
# the app loses at most the fight that was going on. It can be loaded like any
# other slot but never chosen to save into.
const AUTO_SLOT: int = 4

static func slot_path(slot: int) -> String:
	return "user://save_slot_%d.json" % slot

# Whether there is anything to load: a hand save or the autosave.
static func any_save() -> bool:
	for i: int in range(1, AUTO_SLOT + 1):
		if not slot_info(i).is_empty():
			return true
	return false

static func slot_info(slot: int) -> Dictionary:
	var path: String = slot_path(slot)
	if not FileAccess.file_exists(path):
		return {}
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not f:
		return {}
	var text: String = f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		return {}
	var d: Dictionary = parsed as Dictionary
	return {
		floor = d.get("floor_num", 1),
		lv    = (d.get("player", {}) as Dictionary).get("lv", 1),
		timestamp = d.get("timestamp", ""),
		play_time = float(d.get("play_time", 0.0)),
	}

static func write(slot: int, data: Dictionary) -> void:
	var path: String = slot_path(slot)
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if not f:
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()

static func read(slot: int) -> Dictionary:
	var path: String = slot_path(slot)
	if not FileAccess.file_exists(path):
		return {}
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not f:
		return {}
	var text: String = f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed as Dictionary
	return {}

static func vec2i_key(v: Vector2i) -> String:
	return "%d,%d" % [v.x, v.y]

static func key_vec2i(s: String) -> Vector2i:
	var parts: PackedStringArray = s.split(",")
	return Vector2i(int(parts[0]), int(parts[1]))

static func pack_visited(d: Dictionary) -> Array:
	var out: Array = []
	for k: Variant in d.keys():
		out.append(vec2i_key(k as Vector2i))
	return out

static func unpack_visited(a: Array) -> Dictionary:
	var out: Dictionary = {}
	for s: Variant in a:
		out[key_vec2i(s as String)] = true
	return out


