# MenuTabBestiary
# The record of what has been met. Meeting something files its name; only
# Analyze, spent as a turn in battle, fills in what it is made of — so this is
# the list to check before choosing a loadout, not a free encyclopaedia.
class_name MenuTabBestiary extends RefCounted

var _m

func _init(menu) -> void:
	_m = menu


func build() -> void:
	if _m.player.encountered_enemies.is_empty():
		SlotList.new(_m._content).add_note("No enemies recorded yet.")
		return

	var known: Array[String] = []
	for enemy_name: String in _m.player.encountered_enemies:
		for t: Dictionary in Enemy.all_templates():
			if t["name"] == enemy_name:
				known.append(enemy_name)
				break

	_m.add_paged_list(_m._content, "bestiary", known,
			func(list: SlotList, enemy_name: String) -> void: _add_demon(list, enemy_name))


func _add_demon(list: SlotList, enemy_name: String) -> void:
	var tmpl: Dictionary = {}
	for t: Dictionary in Enemy.all_templates():
		if t["name"] == enemy_name:
			tmpl = t
			break
	if tmpl.is_empty():
		return

	var max_fl: int = tmpl.get("max_floor", -1)
	var where: String = "Floors %d" % int(tmpl.get("min_floor", 1))
	where += "+" if max_fl == -1 else "\u2013%d" % max_fl

	# Everything the bestiary knows, as one wrapped paragraph rather than six
	# stacked lines of wildly different length.
	var parts: Array[String] = []
	if _m.player.has_analyzed(enemy_name):
		parts.append(_chart_text(tmpl))
	else:
		parts.append("Affinities unread \u2014 analyze it in battle.")
	var atk: String = tmpl.get("attack_element", "") as String
	if atk != "":
		parts.append("Attacks with %s" % Affinity.element_name(atk))
	var st: String = tmpl.get("status_attack", "") as String
	if st != "":
		parts.append("Inflicts %s" % Status.get_data(st).get("name", st))
	# What it answers to, and what a correct read is worth — but only once it has
	# been scanned. An unscanned demon is a guess, which is the point of Analyze.
	if not bool(tmpl.get("negotiable", false)):
		parts.append("Will not talk")
	elif _m.player.has_analyzed(enemy_name):
		parts.append("%s \u2014 %d%% talked round" % [
				(tmpl.get("personality", "") as String).capitalize(),
				Negotiation.tier_odds(int(tmpl.get("tier", 1)))])
	else:
		parts.append("Talks \u2014 temperament unread")

	var icon: Texture2D = null
	var sprite: String = tmpl.get("sprite", "") as String
	if sprite != "":
		icon = load(sprite) as Texture2D

	var bound: bool = enemy_name in _m.player.recruited
	list.add_entry(enemy_name,
			Color(0.30, 1.0, 0.55) if bound else Color(0.95, 0.82, 0.45),
			"   ".join(parts), where, Color(0.60, 0.60, 0.60),
			[] as Array[Dictionary], icon)


# Every element that is not ordinary, written the way the battle log writes it.
func _chart_text(tmpl: Dictionary) -> String:
	var demon: Enemy = Enemy.make_from_name(tmpl["name"] as String, 1)
	var parts: Array[String] = []
	for element: String in Affinity.ELEMENTS:
		var state: String = demon.affinity_of(element)
		if state != Affinity.NORMAL:
			parts.append("%s %s" % [Affinity.element_name(element), Affinity.label(state)])
	demon.free()
	return "no affinities" if parts.is_empty() else "  ".join(parts)
