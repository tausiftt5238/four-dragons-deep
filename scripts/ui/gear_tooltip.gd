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

	if item.get("type", "") != "accessory":
		return "
".join(lines)

	# What it would read as with this trinket on, against what the sheet says
	# now — including the slot it would have to take if both are full.
	for pair: Array in [["STR", "str_bonus", player.effective_str()],
			["DEF", "def_bonus", player.effective_def()],
			["MAG", "mag_bonus", player.effective_mag()],
			["AGL", "agl_bonus", player.effective_agl()],
			["LUK", "luk_bonus", player.effective_luk()]]:
		var delta: int = int(item.get(pair[1] as String, 0))
		if delta != 0:
			lines.append(cmp_line(pair[0] as String, int(pair[2]), int(pair[2]) + delta))

	var r: String = item.get("resist_element", "")
	if r != "":
		lines.append("Resists: %s" % Affinity.element_name(r))
	var w: String = item.get("weak_element", "")
	if w != "":
		lines.append("Opens: %s" % Affinity.element_name(w))

	return "
".join(lines)


static func cmp_line(stat: String, cur: int, nxt: int) -> String:
	var diff: int = nxt - cur
	if diff == 0:
		return "%s  %d" % [stat, nxt]
	return "%s  %d → %d  (%s%d)" % [stat, cur, nxt, ("+" if diff > 0 else ""), diff]


static func bonus_string(item: Dictionary) -> String:
	var parts: Array[String] = []
	if item.get("str_bonus", 0) != 0: parts.append("STR%+d" % item["str_bonus"])
	if item.get("def_bonus", 0) != 0: parts.append("DEF%+d" % item["def_bonus"])
	if item.get("mag_bonus", 0) != 0: parts.append("MAG%+d" % item["mag_bonus"])
	if item.get("agl_bonus", 0) != 0: parts.append("AGL%+d" % item["agl_bonus"])
	if item.get("luk_bonus", 0) != 0: parts.append("LUK%+d" % item["luk_bonus"])
	return "  (%s)" % "  ".join(parts) if not parts.is_empty() else ""
