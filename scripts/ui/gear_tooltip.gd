# GearTooltip
# Shared static helpers for accessory comparison tooltip text.
# Used by MenuUI to avoid duplicating this logic.
class_name GearTooltip


static func build(item: Dictionary, player: PlayerCharacter) -> String:
	var lines: Array[String] = []

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

	var r: PackedStringArray = PackedStringArray()
	for e: String in Armor.resists_of(item):
		r.append(Affinity.element_name(e))
	if not r.is_empty():
		lines.append("Resists: %s" % ", ".join(r))
	var w: PackedStringArray = PackedStringArray()
	for e: String in Armor.weaknesses_of(item):
		w.append(Affinity.element_name(e))
	if not w.is_empty():
		lines.append("Opens: %s" % ", ".join(w))
	var wards: String = wards_text(item)
	if wards != "":
		lines.append("Wards: %s" % wards)
	if item.get("first_strike", false):
		lines.append("Never ambushed: every fight opens on your turn")
	if item.get("walk_mp", false):
		lines.append("Walking brings MP back (full in fifty steps)")
	if item.get("round_mp", false):
		lines.append("In a fight, you and your demons get 10% MP back each round")

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

	# Elements are ItemInfo's: it draws them as icons after these.
	return "  ".join(parts)


# The ailments a ward trinket keeps off, named; "" for anything else.
static func wards_text(item: Dictionary) -> String:
	var w: Array = item.get("wards", []) as Array
	if w.is_empty():
		return ""
	if "all" in w:
		return "every ailment"
	var names: Array[String] = []
	for id: Variant in w:
		names.append((Status.get_data(id as String).get("noun", id) as String).capitalize())
	return ", ".join(names)
