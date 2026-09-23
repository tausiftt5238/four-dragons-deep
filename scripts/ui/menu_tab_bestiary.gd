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
	where += "+" if max_fl == -1 else "-%d" % max_fl

	# Everything the bestiary knows, as one wrapped paragraph rather than six
	# stacked lines of wildly different length.
	var parts: Array[String] = []
	# The same chart the fight shows: every line it has been hit with, or all
	# six once analyzed or killed, and "?" for the rest.
	var p: PlayerCharacter = _m.player
	var demon: Enemy = Enemy.make_from_name(enemy_name, 1)
	var chart: AffinityChart = AffinityChart.compact(demon)
	demon.free()
	chart.knows = func(element: String) -> bool:
		return p.knows_affinity(enemy_name, element)
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
			[] as Array[Dictionary], icon, chart)
