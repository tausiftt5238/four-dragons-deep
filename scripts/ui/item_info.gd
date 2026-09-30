# ItemInfo
# The one line every list shows under an item or a spell, in place of flavour
# text: what it does, in the fewest symbols that say all of it.
#
#   spell / scroll   [icon] x1 - 8 MP - [Poison]
#   buff / debuff    ATK+ party - 8 MP          (the stat in its StageArrows colour)
#   gear             STR +5  AGL -1   [icon]S  [icon]W   (letters as on the chart)
#   supplies         +30 HP,  Cures [Poison],  [icon] x1 - 20 dmg ...
#
# BBCode for a RichTextLabel, which is what SlotList's detail line is.
class_name ItemInfo

const ICON_SIZE: int = 20
# Larger than the 11 a wrapped description needed: a line this short has the
# room, and the icons have to be big enough to tell apart on a phone.
const FONT_SIZE: int = 16

const ICONS: Dictionary = {
	"phys":    "res://resources/icons/phys.png",
	"fire":    "res://resources/spellFX/fire.png",
	"ice":     "res://resources/spellFX/ice.png",
	"thunder": "res://resources/spellFX/thunder.png",
	"light":   "res://resources/icons/light.png",
	"dark":    "res://resources/icons/dark.png",
}

const SEP: String = "  -  "
const HP_COLOR: String = "#6ee07a"
const MP_COLOR: String = "#7fb0ff"
const MAGIC: Array[String] = ["fire", "ice", "thunder", "light", "dark"]


static func icon(element: String) -> String:
	if not ICONS.has(element):
		return ""
	return "[img=%dx%d]%s[/img]" % [ICON_SIZE, ICON_SIZE, ICONS[element]]


static func _paint(text: String, c: Color) -> String:
	return "[color=#%s]%s[/color]" % [c.to_html(false), text]


static func ailment(status_id: String) -> String:
	var d: Dictionary = Status.get_data(status_id)
	return _paint("[%s]" % d.get("name", status_id), d.get("color", Color.WHITE) as Color)


static func _reach(shape: String) -> String:
	match shape:
		Spell.SHAPE_FEW: return "x2-3"
		Spell.SHAPE_ALL: return "x all"
	return "x1"


static func _stat_tag(stat: String, delta: int) -> String:
	var name: String = stat.to_upper()
	return _paint("%s%s" % [name, "+" if delta > 0 else "-"],
			StageArrows.tint_for(name, Color.WHITE))


static func _sized(text: String) -> String:
	return "[font_size=%d]%s[/font_size]" % [FONT_SIZE, text] if text != "" else ""


# ── Spells ────────────────────────────────────────────────────────────────────

static func spell(spell_id: String) -> String:
	return _sized(_spell(spell_id))


static func _spell(spell_id: String) -> String:
	var d: Dictionary = Spell.get_data(spell_id)
	if d.is_empty():
		return ""
	var reach: String = _reach(d.get("shape", Spell.SHAPE_ONE) as String)
	var cost: String = Spell.cost_text(spell_id)
	var parts: Array[String] = []
	match d.get("type", "dmg") as String:
		"dmg", "banish":
			parts = ["%s %s" % [icon(d.get("element", "") as String), reach], cost]
		"ailment":
			parts = [reach, cost, ailment(d.get("status", "") as String)]
		"heal":
			var who: String = "party" if Spell.is_multi(spell_id) else "ally"
			# The base; the caster's MAG is added on top when it lands.
			parts = [_paint("+%d HP +MAG" % int(d.get("heal", 0)), Color(HP_COLOR)), who, cost]
		"buff":
			var party: bool = d.get("scope", "party") == "party"
			parts = ["%s %s" % [_stat_tag(d.get("stat", "") as String, int(d.get("delta", 1))),
					"party" if party else "foes"], cost]
		"dispel":
			var mine: bool = d.get("scope", "party") == "party"
			parts = ["Clears %s" % ("the party's debuffs" if mine else "foes' buffs"), cost]
		"analyze":
			parts = ["Reveals a foe's chart", cost]
		"leech":
			parts = ["Drains %s x1" % (d.get("drain", "hp") as String).to_upper(), cost]
		_:
			parts = [reach, cost]
	return SEP.join(parts)


# ── Items ─────────────────────────────────────────────────────────────────────

# `deltas` replaces the plain stat list with the shop's green/red comparison
# against what is worn, when the caller has one.
static func item(it: Dictionary, deltas: String = "") -> String:
	match it.get("type", "") as String:
		"scroll":
			var id: String = it.get("teaches", "") as String
			return _sized("Teaches %s%s%s" % [
					Spell.get_data(id).get("name", id), SEP, _spell(id)])
		"weapon", "armor", "accessory":
			return _sized(gear(it, deltas))
	return _sized(supply(it))


static func supply(it: Dictionary) -> String:
	if it.has("mirror"):
		var kind: String = it["mirror"] as String
		var icons: String = icon("phys") if kind == "phys" \
				else "".join(MAGIC.map(func(e: String) -> String: return icon(e)))
		return "Reflects %s%sparty%s1 turn" % [icons, SEP, SEP]
	if it.has("revive"):
		return "Revives an ally at %d%% HP" % int(it["revive"])
	var parts: Array[String] = []
	if int(it.get("max_hp_gain", 0)) > 0:
		parts.append(_paint("Max HP +%d" % int(it["max_hp_gain"]), Color(HP_COLOR)))
	if int(it.get("max_mp_gain", 0)) > 0:
		parts.append(_paint("Max MP +%d" % int(it["max_mp_gain"]), Color(MP_COLOR)))
	if int(it.get("dmg", 0)) > 0:
		parts.append("%s x1" % icon(it.get("element", "") as String))
		parts.append("%d dmg" % int(it["dmg"]))
	if it.get("inflicts_status", "") != "":
		parts.append("x1")
		parts.append(ailment(it["inflicts_status"] as String))
	if int(it.get("hp_restore", 0)) > 0:
		parts.append(_paint("+%d HP" % int(it["hp_restore"]), Color(HP_COLOR)))
	if int(it.get("mp_restore", 0)) > 0:
		parts.append(_paint("+%d MP" % int(it["mp_restore"]), Color(MP_COLOR)))
	var cure: String = it.get("cures_status", "") as String
	if cure == "all":
		parts.append("Cures all ailments")
	elif cure != "":
		parts.append("Cures %s" % ailment(cure))
	return SEP.join(parts)


static func gear(it: Dictionary, deltas: String = "") -> String:
	var parts: Array[String] = []
	if deltas != "":
		parts.append(deltas)
	else:
		var stats: Array[String] = []
		for pair: Array in [["STR", "str_bonus"], ["DEF", "def_bonus"],
				["MAG", "mag_bonus"], ["AGL", "agl_bonus"], ["AGL", "agl_pen"],
				["LUK", "luk_bonus"]]:
			var v: int = int(it.get(pair[1], 0))
			if v == 0:
				continue
			stats.append("%s %s" % [
					_paint(pair[0] as String, StageArrows.tint_for(pair[0] as String,
							Color(0.85, 0.85, 0.85))),
					_paint("%+d" % v, Color(0.9, 0.9, 0.9) if v > 0 else Color(1.0, 0.45, 0.4))])
		if not stats.is_empty():
			parts.append("  ".join(stats))
	var swing: String = it.get("attack_element", "") as String
	if swing != "":
		parts.append("Swings %s" % icon(swing))
	# The chart's own letters, in the chart's own colours: S resists, W weak.
	var chart: Array[String] = []
	var r: String = it.get("resist_element", "") as String
	if r != "":
		chart.append(icon(r) + _paint("S", Affinity.color(Affinity.RESIST)))
	var w: String = it.get("weak_element", it.get("weakness", "")) as String
	if w != "":
		chart.append(icon(w) + _paint("W", Affinity.color(Affinity.WEAK)))
	if not chart.is_empty():
		parts.append(" ".join(chart))
	return SEP.join(parts)
