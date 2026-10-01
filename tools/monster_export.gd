extends SceneTree
# Writes every monster in Enemy's tables to data/monsters.csv, one row each, for
# reworking in a spreadsheet. From the repo root:
#
#   godot --headless --path . --script tools/monster_export.gd
#
# Only the fields the game actually reads are exported. A template's lv, exp,
# gold, min_floor, max_floor and talk_difficulty are left out on purpose:
# nothing uses them. Level comes from the floor plus `rank`, exp and gold come
# from the level, the talk odds from the tier, and the floors from the tier.
#
# The six affinity columns are the chart as the game resolves it, one word per
# element: weak, resist, null, reflect, drain, or blank for normal.

const OUT: String = "res://data/monsters.csv"

const COLUMNS: Array[String] = [
	"group", "name", "where", "tier", "rank", "icons",
	"str", "def", "mag", "agl",
	"phys", "fire", "ice", "thunder", "light", "dark",
	"attacks", "reach", "caster",
	"ailment", "ailment_chance", "support",
	"talks", "personality", "wants",
	"sprite", "notes",
]


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://data"))
	var f: FileAccess = FileAccess.open(OUT, FileAccess.WRITE)
	f.store_line(",".join(COLUMNS))
	var n: int = 0
	for t: Dictionary in Enemy.TEMPLATES:
		f.store_line(_row("monster", t, int(t.get("tier", 1))))
		n += 1
	for i: int in Enemy.WARDEN_TEMPLATES.size():
		f.store_line(_row("warden", Enemy.WARDEN_TEMPLATES[i], i + 1))
		n += 1
	for i: int in Enemy.BOSS_TEMPLATES.size():
		f.store_line(_row("dragon", Enemy.BOSS_TEMPLATES[i], i + 1))
		n += 1
	f.close()
	print("wrote %d monsters to %s" % [n, OUT])
	quit()


func _row(group: String, t: Dictionary, tier: int) -> String:
	var chart: Dictionary = Enemy._affinities_from(t)
	var cells: Dictionary = {
		group = group,
		name = t["name"],
		where = Enemy.where_found(t),
		tier = str(tier) if tier > 0 else "",
		rank = str(int(t.get("rank", 0))) if group == "monster" else "",
		icons = str(int(t.get("icons", 1))),
		str = str(int(t["str"])), def = str(int(t["def"])),
		mag = str(int(t["mag"])), agl = str(int(t["agl"])),
		attacks = " ".join(Enemy._elements_from(t)),
		reach = _reach(t.get("reach", Spell.SHAPE_ONE) as String),
		caster = "yes" if bool(t.get("caster", false)) else "",
		ailment = t.get("status_attack", "") as String,
		ailment_chance = str(int(t.get("ail", 12))),
		support = t.get("support", "") as String,
		talks = "yes" if bool(t.get("negotiable", true)) else "no",
		personality = t.get("personality", "") as String,
		wants = t.get("wants", "") as String,
		sprite = t.get("sprite_id", t.get("sprite", "")) as String,
		notes = t.get("design_note", t.get("art_note", "")) as String,
	}
	for e: String in Affinity.ELEMENTS:
		cells[e] = _state(chart.get(e, "") as String)
	var out: Array[String] = []
	for c: String in COLUMNS:
		out.append(_csv(str(cells.get(c, ""))))
	return ",".join(out)


# The sheet says "reflect" where the code says "repel": it is the word the
# battle chart's R stands for.
static func _state(s: String) -> String:
	return "reflect" if s == Affinity.REPEL else s


static func _reach(s: String) -> String:
	match s:
		Spell.SHAPE_FEW: return "few"
		Spell.SHAPE_ALL: return "all"
	return "one"


# Quoted only when it has to be, the way Google Sheets writes CSV.
static func _csv(v: String) -> String:
	if v.contains(",") or v.contains("\"") or v.contains("\n"):
		return "\"%s\"" % v.replace("\"", "\"\"")
	return v
