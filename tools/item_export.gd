extends SceneTree
# Writes every item, weapon, armour piece, accessory and spell to its own CSV
# in data/, one row each, for reworking in a spreadsheet the way
# data/monsters.csv is. From the repo root:
#
#   godot --headless --path . --script tools/item_export.gd
#
# Only fields the game reads are exported. Prices are what an orb charges
# (OrbUI.item_price), so a blank price column never needs explaining.
#
# A scroll has no description of its own: it shows its spell's, led by the
# element and reach (Item.desc_for). Scrolls are therefore columns on the
# spell sheet rather than rows on the item sheet, and editing a spell's desc
# edits its scroll too.

const ITEM_SCRIPT: String = "res://scripts/data/item.gd"

const ITEM_COLUMNS: Array[String] = [
	"id", "name", "kind", "floor", "price",
	"hp_restore", "mp_restore", "cures", "inflicts", "element", "dmg",
	"max_hp_gain", "max_mp_gain", "revive_pct", "desc",
]
const WEAPON_COLUMNS: Array[String] = [
	"id", "name", "tier", "price", "str", "mag", "def", "agl",
	"attack_element", "found_only", "desc",
]
const ARMOR_COLUMNS: Array[String] = [
	"id", "name", "tier", "price", "def", "agl", "resist", "weak", "desc",
]
const ACCESSORY_COLUMNS: Array[String] = [
	"id", "name", "tier", "price", "str", "def", "mag", "agl", "luk",
	"resist", "weak", "desc",
]
const SPELL_COLUMNS: Array[String] = [
	"id", "name", "type", "element", "reach", "rung", "mp", "hp_pct",
	"power", "boost", "heal", "stat", "delta", "scope", "status",
	"scroll", "scroll_floor", "scroll_price", "desc",
]


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://data"))
	var items: Array[Dictionary] = []
	var scrolls: Dictionary = {}   # spell id -> scroll
	for d: Dictionary in _every_item():
		if d.get("type", "") == "scroll":
			scrolls[d["teaches"]] = d
		else:
			items.append(d)
	for d: Dictionary in Item.elemental_scrolls():
		scrolls[d["teaches"]] = d

	_write("items", ITEM_COLUMNS, items.map(func(d: Dictionary) -> Dictionary: return {
		id = d["id"], name = d["name"], kind = _kind(d),
		floor = d.get("floor", 1), price = OrbUI.item_price(d),
		hp_restore = _nz(d.get("hp_restore", 0)), mp_restore = _nz(d.get("mp_restore", 0)),
		cures = d.get("cures_status", ""), inflicts = d.get("inflicts_status", ""),
		element = d.get("element", ""), dmg = _nz(d.get("dmg", 0)),
		max_hp_gain = _nz(d.get("max_hp_gain", 0)), max_mp_gain = _nz(d.get("max_mp_gain", 0)),
		revive_pct = _nz(d.get("revive", 0)), desc = d["desc"]}))

	_write("weapons", WEAPON_COLUMNS, Weapon.all().map(func(d: Dictionary) -> Dictionary: return {
		id = d["id"], name = d["name"], tier = d["floor"], price = OrbUI.item_price(d),
		str = _nz(d.get("str_bonus", 0)), mag = _nz(d.get("mag_bonus", 0)),
		def = _nz(d.get("def_bonus", 0)), agl = _nz(d.get("agl_pen", 0)),
		attack_element = d.get("attack_element", ""),
		found_only = "yes" if bool(d.get("found_only", false)) else "",
		desc = d["desc"]}))

	_write("armor", ARMOR_COLUMNS, Armor.all().map(func(d: Dictionary) -> Dictionary: return {
		id = d["id"], name = d["name"], tier = d["floor"], price = OrbUI.item_price(d),
		def = _nz(d.get("def_bonus", 0)), agl = _nz(d.get("agl_pen", 0)),
		resist = d.get("resist_element", ""), weak = d.get("weakness", ""),
		desc = d["desc"]}))

	_write("accessories", ACCESSORY_COLUMNS, Accessory.all().map(func(d: Dictionary) -> Dictionary: return {
		id = d["id"], name = d["name"], tier = d["floor"], price = OrbUI.item_price(d),
		str = _nz(d.get("str_bonus", 0)), def = _nz(d.get("def_bonus", 0)),
		mag = _nz(d.get("mag_bonus", 0)), agl = _nz(d.get("agl_bonus", 0)),
		luk = _nz(d.get("luk_bonus", 0)),
		resist = d.get("resist_element", ""), weak = d.get("weak_element", ""),
		desc = d["desc"]}))

	var spells: Array = []
	for id: String in Spell.DATA:
		var s: Dictionary = Spell.DATA[id]
		var sc: Dictionary = scrolls.get(id, {})
		var element: String = s.get("element", "") as String
		spells.append({
			id = id, name = s["name"], type = s.get("type", ""), element = element,
			reach = _reach(s.get("shape", Spell.SHAPE_ONE) as String),
			rung = _rung(s) if s.get("type", "") in ["dmg", "banish"] else "",
			mp = _nz(s.get("mp", 0)), hp_pct = _nz(s.get("hp", 0)),
			power = s.get("power", ""), boost = s.get("boost", ""),
			heal = _nz(s.get("heal", 0)), stat = s.get("stat", ""),
			delta = s.get("delta", ""), scope = s.get("scope", ""),
			status = s.get("status", ""),
			scroll = sc.get("name", ""), scroll_floor = sc.get("floor", ""),
			scroll_price = OrbUI.item_price(sc) if not sc.is_empty() else "",
			desc = s.get("desc", "")})
	_write("spells", SPELL_COLUMNS, spells)
	quit()


# Every zero-argument factory on Item that hands back an item. Read off the
# script itself so a new potion shows up here without anyone remembering to.
func _every_item() -> Array[Dictionary]:
	var script: GDScript = load(ITEM_SCRIPT) as GDScript
	var out: Array[Dictionary] = []
	var seen: Dictionary = {}
	for m: Dictionary in script.get_script_method_list():
		if (m["args"] as Array).size() != 0 or not (m["flags"] & METHOD_FLAG_STATIC):
			continue
		var v: Variant = script.call(m["name"])
		if v is Dictionary and (v as Dictionary).has("type") and (v as Dictionary).has("id"):
			if not seen.has(v["id"]):
				seen[v["id"]] = true
				out.append(v)
	return out


static func _kind(d: Dictionary) -> String:
	if d.has("max_hp_gain") or d.has("max_mp_gain"):
		return "stone"
	if d.has("revive"):
		return "revive"
	if d.has("mirror"):
		return "mirror"
	if d.has("element"):
		return "throwable"
	if d.has("inflicts_status"):
		return "ailment"
	if d.has("cures_status"):
		return "cure"
	return "restore"


static func _reach(s: String) -> String:
	match s:
		Spell.SHAPE_FEW: return "few"
		Spell.SHAPE_ALL: return "all"
	return "one"


static func _rung(s: Dictionary) -> String:
	var r: float = Spell.rung_of(s)
	if r >= Spell.POWER_III:
		return "III"
	if r >= Spell.POWER_II:
		return "II"
	return "I"


static func _nz(v: Variant) -> String:
	return "" if (v is int or v is float) and v == 0 else str(v)


func _write(sheet: String, columns: Array[String], rows: Array) -> void:
	var path: String = "res://data/%s.csv" % sheet
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_line(",".join(columns))
	for r: Dictionary in rows:
		var cells: Array[String] = []
		for c: String in columns:
			cells.append(_csv(str(r.get(c, ""))))
		f.store_line(",".join(cells))
	f.close()
	print("wrote %d rows to %s" % [rows.size(), path])


# Quoted only when it has to be, the way Google Sheets writes CSV.
static func _csv(v: String) -> String:
	if v.contains(",") or v.contains("\"") or v.contains("\n"):
		return "\"%s\"" % v.replace("\"", "\"\"")
	return v
