class_name SaveSystem

static func slot_path(slot: int) -> String:
	return "user://save_slot_%d.json" % slot

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

static func pack_chest_items(d: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k: Variant in d.keys():
		out[vec2i_key(k as Vector2i)] = d[k]
	return out

static func unpack_chest_items(d: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k: Variant in d.keys():
		out[key_vec2i(k as String)] = d[k]
	return out
