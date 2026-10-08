# Abyss
# The endless mode, unlocked by beating the Necromancer. The hero who did it
# goes on down: floor after floor with no bottom and no bosses at the ends of
# bands, every monster from every band coming up together in an element of its
# own, the dragons and wardens wandering among them now and then, and new gear
# on the shelves every five floors. The run is the score.
#
# There is one life. Orbs still rest and sell but no longer save; the run is
# kept only in its own autosave (SaveSystem.ABYSS_SLOT), written where the main
# game writes its autosave, and a death wipes it.
#
# Depth: Abyss 1 is main-game floor 26 (Level.FLOOR_COUNT + 1), so everything
# that reads floor_num (monster levels, rewards, the Abyss's hazards and walls)
# simply carries on from where the run left off.
class_name Abyss

const STATE_PATH: String = "user://abyss.cfg"
const HERO_PATH: String = "user://abyss_hero.json"

# Set while an Abyss run is being played (Main sets it from GameBoot or a save).
static var active: bool = false


# ── Depth ────────────────────────────────────────────────────────────────────

static func depth_of(floor_num: int) -> int:
	return floor_num - Level.FLOOR_COUNT


static func floor_for_depth(depth: int) -> int:
	return Level.FLOOR_COUNT + depth


# What the HUD and the fades call a floor.
static func floor_title(floor_num: int) -> String:
	if active and floor_num > Level.FLOOR_COUNT:
		return "Abyss %d" % depth_of(floor_num)
	return "Floor %d" % floor_num


# ── Unlock, the cleared hero, the record ─────────────────────────────────────

static func _cfg() -> ConfigFile:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.load(STATE_PATH)
	return cfg


static func unlocked() -> bool:
	return bool(_cfg().get_value("abyss", "unlocked", false))


static func best_depth() -> int:
	return int(_cfg().get_value("abyss", "best_depth", 0))


static func note_depth(depth: int) -> void:
	var cfg: ConfigFile = _cfg()
	if depth > int(cfg.get_value("abyss", "best_depth", 0)):
		cfg.set_value("abyss", "best_depth", depth)
		cfg.save(STATE_PATH)


# Beating the Necromancer opens the mode. `keep_hero`: the hero who did it
# becomes the one every new descent starts with (the first clear always; a
# later one only if the player says so, Main._show_congratulations).
static func unlock(player_data: Dictionary, keep_hero: bool = true) -> void:
	var cfg: ConfigFile = _cfg()
	cfg.set_value("abyss", "unlocked", true)
	cfg.save(STATE_PATH)
	if not keep_hero:
		return
	var f: FileAccess = FileAccess.open(HERO_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(player_data, "\t"))


static func has_hero() -> bool:
	return not cleared_hero().is_empty()


# The hero a new descent starts with: the one who cleared the game.
static func cleared_hero() -> Dictionary:
	if FileAccess.file_exists(HERO_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(HERO_PATH))
		if parsed is Dictionary:
			return parsed as Dictionary
	return {}


# The web build is the free taste of the game and leaves the Abyss out:
# beating the Necromancer there ends the run with the credits, and nothing
# unlocks.
static func in_build() -> bool:
	return not Build.web()


# Whether the title offers the mode at all: only once the game has been beaten.
static func available() -> bool:
	return in_build() and unlocked() and not cleared_hero().is_empty()


# A death down here is the end of that run.
static func wipe_run() -> void:
	var p: String = SaveSystem.slot_path(SaveSystem.ABYSS_SLOT)
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


# ── Monsters: one element each ───────────────────────────────────────────────

const ELEMENTS: Array[String] = ["fire", "ice", "thunder", "light", "dark"]

# What each element gives way to: the dragons' chain (ice to fire, thunder to
# ice, fire to thunder, the void's dark to fire), and light to dark.
const WEAK_TO: Dictionary = {
	"fire": "thunder", "ice": "fire", "thunder": "ice", "dark": "fire", "light": "dark",
}

const EPITHET: Dictionary = {
	"fire": "Ember", "ice": "Frost", "thunder": "Storm", "light": "Radiant", "dark": "Umbral",
}

# What each element turns a sprite's main colour to: its hue, how saturated
# against the original, and a nudge to brightness. Light is a pale gold and
# thunder a strong one, so the two stay apart (resources/shaders/palette_swap.gdshader).
const SWAP: Dictionary = {
	"fire":    {hue = 0.01, sat = 1.0,  val =  0.0},
	"ice":     {hue = 0.60, sat = 1.0,  val =  0.0},
	"thunder": {hue = 0.14, sat = 1.1,  val =  0.06},
	"light":   {hue = 0.13, sat = 0.35, val =  0.18},
	"dark":    {hue = 0.77, sat = 0.9,  val = -0.04},
}

const PALETTE_SHADER: Shader = preload("res://resources/shaders/palette_swap.gdshader")
static var _materials: Dictionary = {}     # "sprite|element" -> ShaderMaterial
static var _main_colour: Dictionary = {}   # sprite -> [hue, half-width, coloured share]


# One material per sprite and element, shared by every portrait of it.
static func palette_material(element: String, sprite_id: String) -> ShaderMaterial:
	var key: String = sprite_id + "|" + element
	if _materials.has(key):
		return _materials[key] as ShaderMaterial
	var main: Array = main_colour(sprite_id)
	var to: Dictionary = SWAP.get(element, SWAP["fire"]) as Dictionary
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = PALETTE_SHADER
	m.set_shader_parameter("src_hue", main[0])
	m.set_shader_parameter("src_half", main[1])
	m.set_shader_parameter("dst_hue", to["hue"])
	m.set_shader_parameter("sat_scale", to["sat"])
	m.set_shader_parameter("val_shift", to["val"])
	# Mostly grey (a skeleton, a werebear): its greys take a wash as well.
	m.set_shader_parameter("grey_amount", 1.0 - smoothstep(0.25, 0.5, float(main[2])))
	_materials[key] = m
	return m


# A sprite's main colour, read off its first frame: the 120-degree slice of
# the colour wheel that holds the most coloured pixels, as its mean hue and
# how far its pixels spread from that, and what share of the figure is in it.
static func main_colour(sprite_id: String) -> Array:
	if _main_colour.has(sprite_id):
		return _main_colour[sprite_id] as Array
	var hues: Array[float] = []
	var opaque: int = 0
	var tex: AtlasTexture = AnimatedPortrait.first_frame_texture(sprite_id) as AtlasTexture
	if tex != null:
		var img: Image = tex.atlas.get_image()
		if img.is_compressed():
			img = img.duplicate() as Image
			img.decompress()
		var s: int = img.get_height()
		for y: int in s:
			for x: int in s:
				var c: Color = img.get_pixel(x, y)
				if c.a <= 0.0:
					continue
				opaque += 1
				if c.s > 0.2 and c.v > 0.15:
					hues.append(c.h)
	var result: Array = [0.0, 0.055, 0.0]
	if not hues.is_empty():
		var best: Array[float] = []
		var best_centre: float = 0.0
		for k: int in 36:
			var centre: float = (k + 0.5) / 36.0
			var inside: Array[float] = []
			for h: float in hues:
				var off: float = fposmod(h - centre + 0.5, 1.0) - 0.5
				if absf(off) <= 1.0 / 6.0:
					inside.append(off)
			if inside.size() > best.size():
				best = inside
				best_centre = centre
		var mean: float = 0.0
		for off: float in best:
			mean += off
		mean /= best.size()
		var half: float = 0.0
		for off: float in best:
			half = maxf(half, absf(off - mean))
		result = [fposmod(best_centre + mean, 1.0), clampf(half, 0.055, 0.17),
				float(best.size()) / float(opaque)]
	_main_colour[sprite_id] = result
	return result


# How the elements a variant is not made of fall out, apart from its one
# weakness: mostly it just takes them, sometimes it shrugs or nulls one.
const OTHER_ODDS: Array = [["", 55], ["resist", 25], ["null", 12], ["weak", 8]]


# Repaints a monster in one element: it casts only that, takes its own in one
# of the ways a dragon does, gives way to the element the dragons' chain says,
# and the rest are rolled. Its name carries the element, and so does what the
# bestiary learns about it (Enemy.lore_name). The roll is seeded by the kind
# and the element, so every Frost Orc is the same Frost Orc: what is learned
# about one holds for the next.
static func apply_variant(e: Enemy, element: String) -> void:
	e.abyss_element = element
	e.attack_elements.assign([element])
	e.attack_element = element
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(e.enemy_name + "|" + element)
	var aff: Dictionary = {}
	var own: String = ["drain", "null", "repel"][rng.randi() % 3] if element in ["fire", "ice", "thunder"] \
			else ["null", "resist"][rng.randi() % 2]
	aff[element] = own
	aff[WEAK_TO[element]] = Affinity.WEAK
	var weak_left: int = 1
	for other: String in [Affinity.PHYS] + ELEMENTS:
		if aff.has(other):
			continue
		var roll: int = rng.randi() % 100
		var acc: int = 0
		var pick: String = ""
		for pair: Array in OTHER_ODDS:
			acc += int(pair[1])
			if roll < acc:
				pick = pair[0] as String
				break
		if pick == "weak":
			if weak_left <= 0:
				pick = ""
			weak_left -= 1
		if pick != "":
			aff[other] = pick
	e.affinities = aff
	e.reflect_element = ""
	e.absorb_element = ""
	e.weakness = WEAK_TO[element]
	e.tint = Color.WHITE


static func random_element() -> String:
	return ELEMENTS[randi() % ELEMENTS.size()]


# An encounter in the Abyss: every band's demons together, each in an element
# of its own; now and then a warden, and rarer still a dragon, alone.
const WARDEN_ODDS: int = 5     # percent of encounters
const DRAGON_ODDS: int = 3


static func make_group(floor_num: int) -> Array[Enemy]:
	var roll: int = randi() % 100
	if roll < DRAGON_ODDS:
		var d: Enemy = Enemy.make_boss(floor_num, randi() % Enemy.BOSS_TEMPLATES.size())
		# A roaming one is a hard fight, not a whole band's ending.
		d.max_hp = d.max_hp * 5 / Enemy.BOSS_HP_MULT
		d.hp = d.max_hp
		apply_variant(d, random_element())
		d.weakness = WEAK_TO[d.abyss_element]
		return [d]
	if roll < DRAGON_ODDS + WARDEN_ODDS:
		var w: Enemy = Enemy.make_warden(floor_num, randi() % Enemy.WARDEN_TEMPLATES.size())
		apply_variant(w, random_element())
		return [w]
	var count: int = 1 + randi() % 4
	var group: Array[Enemy] = []
	for _i: int in count:
		var e: Enemy = Enemy._build(Enemy._pick_from_tier(1 + randi() % 4), floor_num)
		apply_variant(e, random_element())
		group.append(e)
	return group


# ── Bosses: one every fifth floor ─────────────────────────────────────────────

# Seeds this run's order of bosses; saved with the run (Main), rolled anew for
# each descent.
static var run_seed: int = 0


# The Abyss ends: the last of its bosses waits at END_DEPTH, the Ancient
# Multihued Dragon (the template marked `final`), and beating it is the end of
# the descent (Main._show_abyss_end).
const END_DEPTH: int = 50


static func is_end_floor(floor_num: int) -> bool:
	return active and depth_of(floor_num) == END_DEPTH


static func boss_floor(floor_num: int) -> bool:
	return active and floor_num > Level.FLOOR_COUNT \
			and depth_of(floor_num) % Level.BOSS_EVERY == 0


# Which of Enemy.ABYSS_BOSS_TEMPLATES waits at this depth. None twice: the
# adults in a shuffled order, then the ancients, and the final one always last,
# at END_DEPTH. The order is this run's own (run_seed).
static func boss_for_depth(depth: int) -> int:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash([run_seed, 0])
	var young: Array[int] = []
	var old: Array[int] = []
	var last: int = 0
	for i: int in Enemy.ABYSS_BOSS_TEMPLATES.size():
		var t: Dictionary = Enemy.ABYSS_BOSS_TEMPLATES[i]
		if t.get("final", false):
			last = i
		elif t.get("ancient", false):
			old.append(i)
		else:
			young.append(i)
	var order: Array[int] = _shuffled(young, rng)
	order.append_array(_shuffled(old, rng))
	order.append(last)
	var n: int = clampi(depth / Level.BOSS_EVERY - 1, 0, order.size() - 1)
	return order[n]


static func _shuffled(list: Array[int], rng: RandomNumberGenerator) -> Array[int]:
	var out: Array[int] = list.duplicate()
	for i: int in range(out.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: int = out[i]
		out[i] = out[j]
		out[j] = tmp
	return out


# ── Gear: a new shelf every five floors ──────────────────────────────────────

const GEAR_PER_KIND: int = 4
const BAND_WORDS: Array[String] = ["Abyssal", "Hollow", "Starless", "Sunken", "Nameless",
		"Umbral", "Fathomless", "Bleak", "Drowned", "Lightless"]
const STAT_KEYS: Array[String] = ["str_bonus", "mag_bonus", "def_bonus", "agl_bonus", "luk_bonus"]


static func band_of_depth(depth: int) -> int:
	return maxi(0, (depth - 1) / 5)


# What this band's orbs stock and its monsters drop: the deepest pieces of the
# main game, reforged harder for each band and given one twist each. Built from
# a seed per band, so the same band always holds the same shelf.
static func gear_for_depth(depth: int) -> Array[Dictionary]:
	var band: int = band_of_depth(depth)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7919 * (band + 1)
	var mult: float = 1.35 + 0.25 * float(band)
	var word: String = BAND_WORDS[band % BAND_WORDS.size()]
	var cycle: int = band / BAND_WORDS.size()
	var out: Array[Dictionary] = []
	for kind: Array in [[Weapon.all(), "weapon"], [Armor.all(), "armor"], [Accessory.all(), "accessory"]]:
		var bases: Array[Dictionary] = []
		for g: Dictionary in kind[0] as Array:
			if int(g.get("floor", 1)) >= 3 and not g.has("wards") and not g.has("first_strike") \
					and not g.has("walk_mp") and not g.has("round_mp"):
				bases.append(g)
		# Drawn without putting back, so a shelf never shows the same piece twice.
		for i: int in mini(GEAR_PER_KIND, bases.size()):
			var base: Dictionary = bases[rng.randi() % bases.size()]
			bases.erase(base)
			out.append(_reforge(base, band, mult, word, cycle, i, rng))
	return out


static func _reforge(base: Dictionary, band: int, mult: float, word: String, cycle: int,
		i: int, rng: RandomNumberGenerator) -> Dictionary:
	var g: Dictionary = base.duplicate(true)
	g["id"] = "%s_abyss%d_%d" % [base["id"], band, i]
	g["name"] = "%s %s%s" % [word, base["name"], " +%d" % cycle if cycle > 0 else ""]
	for k: String in STAT_KEYS:
		if int(g.get(k, 0)) > 0:
			g[k] = maxi(1, roundi(float(g[k]) * mult))
	g.erase("found_only")
	g["floor"] = 4
	g["price"] = roundi(float(20 + 4 * 25) * mult * 2.0)
	# One twist: a weapon may take up an element; worn things may turn one.
	var el: String = ["fire", "ice", "thunder", "light", "dark", Affinity.PHYS][rng.randi() % 6]
	match g.get("type", ""):
		"weapon":
			if rng.randi() % 3 == 0 and el != Affinity.PHYS:
				g["attack_element"] = el
		_:
			if rng.randi() % 2 == 0:
				var r: Array = (g.get("resists", []) as Array).duplicate()
				if not el in r and g.get("resist_element", "") != el:
					r.append(el)
				g["resists"] = r
				var w: Array = (g.get("weaknesses", []) as Array).duplicate()
				w.erase(el)
				g["weaknesses"] = w
				if g.get("weakness", "") == el:
					g["weakness"] = ""
				if g.get("weak_element", "") == el:
					g["weak_element"] = ""
	return g
