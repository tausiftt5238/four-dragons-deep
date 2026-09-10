# GearTooltip
# Shared static helpers for gear comparison tooltip text.
# Used by MenuUI to avoid duplicating this logic.
class_name GearTooltip


static func build(item: Dictionary, player: PlayerCharacter) -> String:
	var lines: Array[String] = []

	var desc: String = item.get("desc", "")
	if not desc.is_empty():
		lines.append(desc)
		lines.append("")

	match item["type"]:
		"weapon":
			var new_str: int = player.str + item.get("str_bonus", 0)
			var new_mag: int = player.mag + item.get("mag_bonus", 0)
			var new_agl: int = player.agl + player.equipped_armor.get("agl_pen", 0) + item.get("agl_pen", 0)
			lines.append(cmp_line("STR", player.effective_str(), new_str))
			if new_mag != player.effective_mag() or item.get("mag_bonus", 0) != 0:
				lines.append(cmp_line("MAG", player.effective_mag(), new_mag))
			if new_agl != player.effective_agl() or item.get("agl_pen", 0) != 0:
				lines.append(cmp_line("AGL", player.effective_agl(), new_agl))
		"armor":
			var new_def: int = player.def + item.get("def_bonus", 0)
			var new_agl: int = player.agl + player.equipped_weapon.get("agl_pen", 0) + item.get("agl_pen", 0)
			lines.append(cmp_line("DEF", player.effective_def(), new_def))
			if new_agl != player.effective_agl() or item.get("agl_pen", 0) != 0:
				lines.append(cmp_line("AGL", player.effective_agl(), new_agl))
			var w: String = item.get("weakness", "")
			if w != "":
				lines.append("Weakness: %s" % w.capitalize())
			var r: String = item.get("reflect_element", "")
			if r != "":
				lines.append("Reflects: %s" % r.capitalize())
			var a: String = item.get("absorb_element", "")
			if a != "":
				lines.append("Absorbs: %s" % a.capitalize())

	return "\n".join(lines)


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
	if item.get("agl_pen",   0) != 0: parts.append("AGL%+d" % item["agl_pen"])
	return "  (%s)" % "  ".join(parts) if not parts.is_empty() else ""
