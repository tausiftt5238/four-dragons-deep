# GearTooltip
# Shared static helpers for accessory comparison tooltip text.
# Used by MenuUI to avoid duplicating this logic.
class_name GearTooltip


static func build(item: Dictionary, player: PlayerCharacter) -> String:
	var lines: Array[String] = []

	var desc: String = item.get("desc", "")
	if not desc.is_empty():
		lines.append(desc)
		lines.append("")

	var kind: String = item.get("type", "") as String
	if kind not in ["accessory", "weapon", "armor"]:
		return "
".join(lines)

	# What it would read as with this trinket on, against what the sheet says
	# now — including the slot it would have to take if both are full.
	# Swapping a piece replaces what is in that slot, so the comparison has to
	# take the outgoing piece off before it puts the incoming one on.
	var out: Dictionary = {}
	if kind == "weapon":
		out = player.equipped_weapon
	elif kind == "armor":
		out = player.equipped_armor

	for pair: Array in [["STR", "str_bonus", player.effective_str()],
			["DEF", "def_bonus", player.effective_def()],
			["MAG", "mag_bonus", player.effective_mag()],
			["AGL", "agl_bonus", player.effective_agl()],
			["LUK", "luk_bonus", player.effective_luk()]]:
		var key: String = pair[1] as String
		var delta: int = int(item.get(key, 0)) - int(out.get(key, 0))
		if key == "agl_bonus":
			delta = int(item.get("agl_pen", item.get(key, 0))) - int(out.get("agl_pen", out.get(key, 0)))
		if delta != 0:
			lines.append(cmp_line(pair[0] as String, int(pair[2]), int(pair[2]) + delta))

	var el: String = item.get("attack_element", "") as String
	if el != "":
		lines.append("Swings: %s%s" % [Affinity.element_name(el),
				"  (expels rather than wounds)" if Affinity.is_banishing(el) else ""])

	var r: String = item.get("resist_element", "")
	if r != "":
		lines.append("Resists: %s" % Affinity.element_name(r))
	var w: String = item.get("weak_element", item.get("weakness", ""))
	if w != "":
		lines.append("Opens: %s" % Affinity.element_name(w))

	return "
".join(lines)


static func cmp_line(stat: String, cur: int, nxt: int) -> String:
	var diff: int = nxt - cur
	if diff == 0:
		return "%s  %d" % [stat, nxt]
	return "%s  %d -> %d  (%s%d)" % [stat, cur, nxt, ("+" if diff > 0 else ""), diff]


# Colours used wherever a stat change is shown: a gain, a loss, and a figure
# that is only being stated rather than compared.
const UP:    Color = Color(0.49, 0.88, 0.63)
const DOWN:  Color = Color(1.00, 0.56, 0.56)
const FLAT:  Color = Color(0.60, 0.62, 0.70)

static func stat_color(delta: int) -> Color:
	if delta > 0:
		return UP
	elif delta < 0:
		return DOWN
	return FLAT


# What taking this piece would do, stat by stat and coloured, as BBCode for a
# list row. A weapon or a worn piece is measured against the one already in
# that slot — the number that matters in a shop is the change, not the piece's
# own figure. Trinkets take a free slot, so theirs is stated as it is.
static func delta_markup(item: Dictionary, player: PlayerCharacter) -> String:
	var kind: String = item.get("type", "") as String
	if kind not in ["accessory", "weapon", "armor"]:
		return ""
	var out: Dictionary = {}
	if kind == "weapon":
		out = player.equipped_weapon
	elif kind == "armor":
		out = player.equipped_armor

	var parts: Array[String] = []
	for pair: Array in [["STR", "str_bonus"], ["DEF", "def_bonus"],
			["MAG", "mag_bonus"], ["AGL", "agl_bonus"], ["LUK", "luk_bonus"]]:
		var key: String = pair[1] as String
		var mine: int = int(item.get(key, 0))
		var theirs: int = int(out.get(key, 0))
		if key == "agl_bonus":
			mine = int(item.get("agl_pen", mine))
			theirs = int(out.get("agl_pen", theirs))
		var delta: int = mine - theirs
		if delta == 0:
			continue
		parts.append("[color=#%s]%s%+d[/color]" % [
				stat_color(delta).to_html(false), pair[0], delta])

	var el: String = item.get("attack_element", "") as String
	if el != "":
		parts.append("[color=#c9a6ff]%s[/color]" % Affinity.element_name(el).to_upper())
	var r: String = item.get("resist_element", "") as String
	if r != "":
		parts.append("[color=#86b4ea]res %s[/color]" % Affinity.element_name(r))
	var w: String = item.get("weak_element", item.get("weakness", "")) as String
	if w != "":
		parts.append("[color=#ffcf52]weak %s[/color]" % Affinity.element_name(w))
	return "  ".join(parts)


static func bonus_string(item: Dictionary) -> String:
	var parts: Array[String] = []
	if item.get("str_bonus", 0) != 0: parts.append("STR%+d" % item["str_bonus"])
	if item.get("def_bonus", 0) != 0: parts.append("DEF%+d" % item["def_bonus"])
	if item.get("mag_bonus", 0) != 0: parts.append("MAG%+d" % item["mag_bonus"])
	if item.get("agl_bonus", 0) != 0: parts.append("AGL%+d" % item["agl_bonus"])
	if item.get("agl_pen",   0) != 0: parts.append("AGL%+d" % item["agl_pen"])
	if item.get("luk_bonus", 0) != 0: parts.append("LUK%+d" % item["luk_bonus"])
	var el: String = item.get("attack_element", "") as String
	if el != "": parts.append(Affinity.element_name(el).to_upper())
	return "  " + " ".join(parts) if not parts.is_empty() else ""
