# MainHazards
# What each band's floor does to you, split out of Main: the ice that slides
# you, the charged plates, lava and traps, the teleporters, and the boss's
# banner at the end of its corridor. It works on the Main it belongs to.
class_name MainHazards extends RefCounted

var main: Main


func _init(host: Main) -> void:
	main = host


# ── Floor hazards ─────────────────────────────────────────────────────────────
#
# One kind per band, after its dragon — see Level.trap_cells. Lava and a live
# spark tile cost the same slice of max HP the old spike trap did, halved by
# armour that resists the element and ignored by any that nulls it. Ice slides
# you on; a teleporter moves you to its partner.

const HAZARD_DAMAGE: float = 0.15

const _HAZARD_NOTES: Dictionary = {
	"ice":   "Ice! You slide until you reach solid floor.",
	"spark": "Charged plates change every two steps. Lit ones hurt: step back and forth to wait.",
	"lava":  "Lava! Fire-resistant armour halves the burn.",
	"tele":  "A teleporter. It carries you to its twin, and back.",
}

# Charged plates count the player's moves on this floor, not time: two groups,
# always opposite, each lit for two steps and dark for two. Two, not one — at
# one step per change every move flips both the tile you reach and its state,
# so walking stays in lock-step and waiting does nothing. At two, stepping back
# and forth once flips the plate ahead, which is the whole of the puzzle.
# Turning is not a step, and standing still never hurts.
var _spark_steps: int = 0


# Which group is lit at a given step count.
static func _spark_live_at(steps: int) -> int:
	return (steps / 2) % 2


# What the plates show: the group that would be lit if you stepped onto it now.
# Damage lands on arrival, so the plates show the arrival, and "do not step on
# a lit plate" is the whole rule the player has to learn. The plate you are
# standing on is the exception: it keeps the state it judged you by (see
# Dungeon.set_spark_live), so lit underfoot means it shocked you.
func _shown_spark_group() -> int:
	return _spark_live_at(_spark_steps + 1)


# The dragon of a boss corridor, waiting in the stairwell at its far end until
# it is beaten. Hung on the dungeon so every rebuild clears it with the rest.
func _sync_boss_banner() -> void:
	if not is_instance_valid(main.dungeon) or not Level.is_boss_floor(main.floor_num):
		return
	var old: Node = main.dungeon.get_node_or_null("DragonBanner")
	if old != null:
		old.queue_free()
	if main._boss_beaten:
		return
	var sprite_id: String = ""
	if Level.is_necro_floor(main.floor_num):
		sprite_id = Enemy.necro_sprite()
	elif Abyss.boss_floor(main.floor_num):
		sprite_id = Enemy.ABYSS_BOSS_TEMPLATES[Abyss.boss_for_depth(Abyss.depth_of(main.floor_num))] \
				.get("sprite_id", "") as String
	else:
		var idx: int = clampi(main.floor_num / maxi(1, Level.BOSS_EVERY) - 1,
				0, Enemy.BOSS_TEMPLATES.size() - 1)
		sprite_id = Enemy.BOSS_TEMPLATES[idx].get("sprite_id", "") as String
	var banner: DragonBanner = DragonBanner.new()
	if not banner.setup(sprite_id):
		banner.free()
		return
	if sprite_id == Enemy.NECRO_STAND_IN:
		banner.modulate = Enemy.NECRO_STAND_IN_TINT
	banner.name = "DragonBanner"
	# Just inside the stairwell the fight starts from, turned to face back
	# down the corridor toward the player.
	var wall: Vector2i = main.current_level.exit_wall_pos
	var from: Vector2i = main.current_level.exit_pos
	var toward: Vector3 = Vector3(float(from.x - wall.x), 0.0, float(from.y - wall.y))
	var inset: float = 0.35
	# In a hall over the pit the boss stands in the middle of the pier's tip,
	# its own cell, looking out over the pit at where the player comes in.
	if Level.is_hall_floor(main.floor_num):
		inset = 0.0
		var arrive: Vector2i = main.current_level.player_start
		toward = Vector3(float(arrive.x - wall.x), 0.0, float(arrive.y - wall.y)).normalized()
	banner.position = Vector3(wall.x * Dungeon.CELL_SIZE, banner.feet_drop,
			wall.y * Dungeon.CELL_SIZE) + toward * (Dungeon.CELL_SIZE * inset)
	banner.rotation = Vector3(0.0, atan2(toward.x, toward.z), 0.0)
	main.dungeon.add_child(banner)


func _show_sparks() -> void:
	if is_instance_valid(main.dungeon):
		main.dungeon.set_spark_live(_shown_spark_group(), main.player_pos, _spark_live_at(_spark_steps))


func _hazard_here() -> String:
	return main.current_level.trap_cells.get(main.player_pos, "") as String


func _note_hazard(kind: String) -> bool:
	if kind in main.player_char.hazards_seen:
		return false
	main.player_char.hazards_seen.append(kind)
	main._screens._show_hud_popup(_HAZARD_NOTES.get(kind, "") as String, Color(0.85, 0.90, 1.0))
	return true


func _remember_hazard(at: Vector2i) -> void:
	main.current_level.found_traps[at] = main.current_level.trap_cells[at]
	main.minimap_ctrl.queue_redraw()


# Carries the player on across ice in the direction they moved, until solid
# floor, a wall, or a demon in the way. The whole slide is one move: the
# roamers take one step for it and nothing else can happen partway.
func _slide(dir: Vector2i) -> void:
	if _hazard_here() != Level.HAZARD_ICE:
		return
	_note_hazard(Level.HAZARD_ICE)
	var guard: int = 0
	while _hazard_here() == Level.HAZARD_ICE and guard < 32:
		guard += 1
		_remember_hazard(main.player_pos)
		var nxt: Vector2i = main.player_pos + dir
		if not main._is_open(nxt.x, nxt.y) or _roamer_at(nxt):
			break
		main.player_pos = nxt
		# Seen on the way past, so the map has no hole down the middle.
		main._mark_visited()


func _roamer_at(cell: Vector2i) -> bool:
	for r: Roamer in main.roamers:
		if is_instance_valid(r) and r.cell == cell:
			return true
	return false


func _check_trap() -> void:
	var here: String = _hazard_here()
	if here == "":
		return
	var kind: String = Level.hazard_kind(here)
	if kind == Level.HAZARD_ICE:
		return    # handled as the move was made
	_remember_hazard(main.player_pos)
	var first: bool = _note_hazard(kind)
	match kind:
		Level.HAZARD_TELE:
			_teleport(here)
		Level.HAZARD_SPARK:
			if Level.spark_group(here) == _spark_live_at(_spark_steps):
				_hazard_hurt("thunder", "Shocked!", Color(0.55, 0.85, 1.0), first)
		_:
			_hazard_hurt("fire", "Lava!", Color(1.0, 0.45, 0.20), first)


func _hazard_hurt(element: String, what: String, color: Color, quiet: bool) -> void:
	var dmg: int = maxi(1, int(main.player_char.max_hp * HAZARD_DAMAGE))
	match main.player_char.affinity_of(element):
		Affinity.RESIST:
			dmg = maxi(1, dmg / 2)
		Affinity.NULL, Affinity.REPEL, Affinity.DRAIN:
			dmg = 0
	Sfx.play("trap")
	var poppets: int = main.player_char.item_qty(Item.POPPET_ID)
	if dmg > 0:
		main.player_char.take_damage(dmg)
		main._shake_camera()
	# A poppet that broke is always told, even over the tile's first note.
	if main.player_char.item_qty(Item.POPPET_ID) < poppets:
		main._screens._show_hud_popup("%s  A Straw Poppet breaks in your place." % what, color)
		return
	# The first time, the note explaining the tile is on screen instead.
	if not quiet:
		main._screens._show_hud_popup("%s  -%d HP" % [what, dmg] if dmg > 0 else "%s  No effect." % what,
				color)
	if not main.player_char.is_alive():
		main._screens._show_game_over()


# Arrives on the partner without setting it off: a teleporter only fires when
# you walk onto it, so stepping off and back on is how to go back.
func _teleport(here: String) -> void:
	var to: Vector2i = Level.tele_target(here)
	if not main._is_open(to.x, to.y):
		return
	main.player_pos = to
	_remember_hazard(to)
	main._sync_player()


