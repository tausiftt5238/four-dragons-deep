# Spell
# Registry for all spells. DATA is the single source of truth used by both
# the in-menu spell list and the in-combat spell chooser.
#
# Fields per spell:
#   name    – display name
#   mp      – MP cost
#   type    – "dmg" | "banish" | "heal" | "buff" | "dispel" | "ailment"
#   element – affinity key it is scored against ("" for the ones that aren't)
#   shape   – SHAPE_ONE | SHAPE_FEW | SHAPE_ALL, how many demons it reaches
#   spread  – what each target gets when the cast is split; 1.0 for single
#   power   – multiplier on MAG (damage spells); the rung it sits on
#   boost   – added to the expulsion odds (banishing spells); the same rung
#   heal    – HP restored (heals only)
#   desc    – one line, shown in the menu
class_name Spell

# ── Reach ─────────────────────────────────────────────────────────────────────
#
# Every element is learnable at all three reaches from the first floor, so the
# choice is never "do I have the big one yet" but "is this a fight worth paying
# 22 MP to open". Width is paid for twice: once in MP, once in the spread, which
# is what keeps the single-target spell in the loadout.
const SHAPE_ONE: String = "single"
const SHAPE_FEW: String = "few"     # 2-3 demons, chosen at random
const SHAPE_ALL: String = "all"

# ── Rungs ─────────────────────────────────────────────────────────────────────
#
# Reach is one axis; this is the other. Every element has the same three-by-three
# block — three reaches on three rungs — and a rung is bought with depth: the
# scroll for it does not appear at an orb until you have been far enough down to
# be sold it. A rung raises what the cast does, never what the chart says: a
# demon that nulls fire nulls Worldfire too, and a banishing rung is added to
# odds that are still zero against something that cannot be expelled at all.
const POWER_I:   float = 2.0
const POWER_II:  float = 3.2
const POWER_III: float = 4.6

const BOOST_I:   float = 0.00
const BOOST_II:  float = 0.10
const BOOST_III: float = 0.20

# Damage keeps more of itself when split than a banishing cast does. Expelling
# three demons at once for 36 MP would end most fights outright, so the wide
# banishing spells give up nearly half their odds to exist at all.
const SPREAD_FEW_DMG:    float = 0.75
const SPREAD_ALL_DMG:    float = 0.60
const SPREAD_FEW_BANISH: float = 0.70
const SPREAD_ALL_BANISH: float = 0.50

static var DATA: Dictionary = {
	# ── Fire ──────────────────────────────────────────────────────────────────
	"ember":         {name="Ember",        mp=8, type="dmg", heal=0, element="fire",
		shape=SHAPE_ONE, spread=1.0, power=POWER_I,
		desc="A flame set on one demon."},
	"cinderfall":    {name="Cinderfall",   mp=14, type="dmg", heal=0, element="fire",
		shape=SHAPE_FEW, spread=SPREAD_FEW_DMG, power=POWER_I,
		desc="Embers fall across two or three of them."},
	"pyre":          {name="Pyre",         mp=22, type="dmg", heal=0, element="fire",
		shape=SHAPE_ALL, spread=SPREAD_ALL_DMG, power=POWER_I,
		desc="The whole room catches."},

	"blaze":         {name="Blaze",        mp=18, type="dmg", heal=0, element="fire",
		shape=SHAPE_ONE, spread=1.0, power=POWER_II,
		desc="A flame that does not go out until it has finished."},
	"firestorm":     {name="Firestorm",    mp=30, type="dmg", heal=0, element="fire",
		shape=SHAPE_FEW, spread=SPREAD_FEW_DMG, power=POWER_II,
		desc="Wind and fire together, over two or three."},
	"inferno":       {name="Inferno",      mp=46, type="dmg", heal=0, element="fire",
		shape=SHAPE_ALL, spread=SPREAD_ALL_DMG, power=POWER_II,
		desc="The air itself burns, wall to wall."},

	"immolate":      {name="Immolate",     mp=32, type="dmg", heal=0, element="fire",
		shape=SHAPE_ONE, spread=1.0, power=POWER_III,
		desc="One demon, and nothing left of it to bury."},
	"ashfall":       {name="Ashfall",      mp=54, type="dmg", heal=0, element="fire",
		shape=SHAPE_FEW, spread=SPREAD_FEW_DMG, power=POWER_III,
		desc="Two or three of them go up and come down as ash."},
	"worldfire":     {name="Worldfire",    mp=82, type="dmg", heal=0, element="fire",
		shape=SHAPE_ALL, spread=SPREAD_ALL_DMG, power=POWER_III,
		desc="Everything standing, all at once, down to the stone."},

	# ── Ice ───────────────────────────────────────────────────────────────────
	"rime":          {name="Rime",         mp=8, type="dmg", heal=0, element="ice",
		shape=SHAPE_ONE, spread=1.0, power=POWER_I,
		desc="Frost closes over one demon."},
	"hailfall":      {name="Hailfall",     mp=14, type="dmg", heal=0, element="ice",
		shape=SHAPE_FEW, spread=SPREAD_FEW_DMG, power=POWER_I,
		desc="Hail comes down on two or three of them."},
	"whiteout":      {name="Whiteout",     mp=22, type="dmg", heal=0, element="ice",
		shape=SHAPE_ALL, spread=SPREAD_ALL_DMG, power=POWER_I,
		desc="Everything in the room goes cold at once."},

	"frostbite":     {name="Frostbite",    mp=18, type="dmg", heal=0, element="ice",
		shape=SHAPE_ONE, spread=1.0, power=POWER_II,
		desc="The cold gets into one demon and stays."},
	"blizzard":      {name="Blizzard",     mp=30, type="dmg", heal=0, element="ice",
		shape=SHAPE_FEW, spread=SPREAD_FEW_DMG, power=POWER_II,
		desc="A wind full of ice, across two or three."},
	"deepwinter":    {name="Deep Winter",  mp=46, type="dmg", heal=0, element="ice",
		shape=SHAPE_ALL, spread=SPREAD_ALL_DMG, power=POWER_II,
		desc="Winter arrives in the room and does not leave."},

	"glaciate":      {name="Glaciate",     mp=32, type="dmg", heal=0, element="ice",
		shape=SHAPE_ONE, spread=1.0, power=POWER_III,
		desc="One demon, taken down to still."},
	"shardfall":     {name="Shardfall",    mp=54, type="dmg", heal=0, element="ice",
		shape=SHAPE_FEW, spread=SPREAD_FEW_DMG, power=POWER_III,
		desc="Ice falls in pieces on two or three of them."},
	"killingfrost":  {name="Killing Frost",  mp=82, type="dmg", heal=0, element="ice",
		shape=SHAPE_ALL, spread=SPREAD_ALL_DMG, power=POWER_III,
		desc="The whole room stops moving together."},

	# ── Thunder ───────────────────────────────────────────────────────────────
	"arc":           {name="Arc",          mp=8, type="dmg", heal=0, element="thunder",
		shape=SHAPE_ONE, spread=1.0, power=POWER_I,
		desc="Current jumps to one demon."},
	"forkfall":      {name="Forkfall",     mp=14, type="dmg", heal=0, element="thunder",
		shape=SHAPE_FEW, spread=SPREAD_FEW_DMG, power=POWER_I,
		desc="The current forks into two or three of them."},
	"thunderhead":   {name="Thunderhead",  mp=22, type="dmg", heal=0, element="thunder",
		shape=SHAPE_ALL, spread=SPREAD_ALL_DMG, power=POWER_I,
		desc="It breaks over all of them together."},

	"bolt":          {name="Bolt",         mp=18, type="dmg", heal=0, element="thunder",
		shape=SHAPE_ONE, spread=1.0, power=POWER_II,
		desc="One line of it, straight through one demon."},
	"thunderstorm":  {name="Thunderstorm",  mp=30, type="dmg", heal=0, element="thunder",
		shape=SHAPE_FEW, spread=SPREAD_FEW_DMG, power=POWER_II,
		desc="It keeps finding two or three of them."},
	"tempest":       {name="Tempest",      mp=46, type="dmg", heal=0, element="thunder",
		shape=SHAPE_ALL, spread=SPREAD_ALL_DMG, power=POWER_II,
		desc="The room becomes weather."},

	"levin":         {name="Levin",        mp=32, type="dmg", heal=0, element="thunder",
		shape=SHAPE_ONE, spread=1.0, power=POWER_III,
		desc="White fire, and one demon in the way of it."},
	"skyfall":       {name="Skyfall",      mp=54, type="dmg", heal=0, element="thunder",
		shape=SHAPE_FEW, spread=SPREAD_FEW_DMG, power=POWER_III,
		desc="It comes down on two or three at once."},
	"stormcrown":    {name="Stormcrown",   mp=82, type="dmg", heal=0, element="thunder",
		shape=SHAPE_ALL, spread=SPREAD_ALL_DMG, power=POWER_III,
		desc="Everything standing is standing under it."},

	# ── Light: expels, or does nothing ────────────────────────────────────────
	"banish":        {name="Banish",       mp=14, type="banish", heal=0, element="light",
		shape=SHAPE_ONE, spread=1.0, boost=BOOST_I,
		desc="Tries to expel one demon outright. Some things cannot abide the light."},
	"winnow":        {name="Winnow",       mp=24, type="banish", heal=0, element="light",
		shape=SHAPE_FEW, spread=SPREAD_FEW_BANISH, boost=BOOST_I,
		desc="Reaches for two or three at once, and holds each of them less firmly."},
	"daybreak":      {name="Daybreak",     mp=36, type="banish", heal=0, element="light",
		shape=SHAPE_ALL, spread=SPREAD_ALL_BANISH, boost=BOOST_I,
		desc="Opens the light on every demon standing. Thin, across that many."},

	"exile":         {name="Exile",        mp=26, type="banish", heal=0, element="light",
		shape=SHAPE_ONE, spread=1.0, boost=BOOST_II,
		desc="A firmer hand on one demon than Banish can manage."},
	"scour":         {name="Scour",        mp=44, type="banish", heal=0, element="light",
		shape=SHAPE_FEW, spread=SPREAD_FEW_BANISH, boost=BOOST_II,
		desc="Two or three of them, and it does not let go as easily."},
	"zenith":        {name="Zenith",       mp=64, type="banish", heal=0, element="light",
		shape=SHAPE_ALL, spread=SPREAD_ALL_BANISH, boost=BOOST_II,
		desc="Light from directly overhead, on all of them."},

	"absolve":       {name="Absolve",      mp=42, type="banish", heal=0, element="light",
		shape=SHAPE_ONE, spread=1.0, boost=BOOST_III,
		desc="One demon, and very little argument about it."},
	"sunburst":      {name="Sunburst",     mp=70, type="banish", heal=0, element="light",
		shape=SHAPE_FEW, spread=SPREAD_FEW_BANISH, boost=BOOST_III,
		desc="Two or three caught in the open at once."},
	"whitehour":     {name="White Hour",   mp=104, type="banish", heal=0, element="light",
		shape=SHAPE_ALL, spread=SPREAD_ALL_BANISH, boost=BOOST_III,
		desc="Nowhere in the room is dark enough to stand in."},

	# ── Dark: unmakes, or does nothing ────────────────────────────────────────
	"consign":       {name="Consign",      mp=14, type="banish", heal=0, element="dark",
		shape=SHAPE_ONE, spread=1.0, boost=BOOST_I,
		desc="Tries to unmake one demon outright. Some things cannot abide the dark."},
	"cull":          {name="Cull",         mp=24, type="banish", heal=0, element="dark",
		shape=SHAPE_FEW, spread=SPREAD_FEW_BANISH, boost=BOOST_I,
		desc="Takes two or three together, and takes each of them less surely."},
	"nightfall":     {name="Nightfall",    mp=36, type="banish", heal=0, element="dark",
		shape=SHAPE_ALL, spread=SPREAD_ALL_BANISH, boost=BOOST_I,
		desc="Closes the dark over the whole room. Thin, across that many."},

	"erase":         {name="Erase",        mp=26, type="banish", heal=0, element="dark",
		shape=SHAPE_ONE, spread=1.0, boost=BOOST_II,
		desc="One demon, and a better chance there is nothing left."},
	"reap":          {name="Reap",         mp=44, type="banish", heal=0, element="dark",
		shape=SHAPE_FEW, spread=SPREAD_FEW_BANISH, boost=BOOST_II,
		desc="Two or three of them, cut down in one pass."},
	"eclipse":       {name="Eclipse",      mp=64, type="banish", heal=0, element="dark",
		shape=SHAPE_ALL, spread=SPREAD_ALL_BANISH, boost=BOOST_II,
		desc="The light goes out on all of them at once."},

	"unmake":        {name="Unmake",       mp=42, type="banish", heal=0, element="dark",
		shape=SHAPE_ONE, spread=1.0, boost=BOOST_III,
		desc="One demon, and very little of it survives the asking."},
	"harvest":       {name="Harvest",      mp=70, type="banish", heal=0, element="dark",
		shape=SHAPE_FEW, spread=SPREAD_FEW_BANISH, boost=BOOST_III,
		desc="Two or three taken together and not given back."},
	"longnight":     {name="Long Night",   mp=104, type="banish", heal=0, element="dark",
		shape=SHAPE_ALL, spread=SPREAD_ALL_BANISH, boost=BOOST_III,
		desc="The dark closes over everything standing and stays closed."},

	# ── Healing ───────────────────────────────────────────────────────────────
	"cure":      {name="Cure", mp=6, type="heal", heal=30,
		desc="Restores 30 HP."},
	"cura":      {name="Cura", mp=15, type="heal", heal=80,
		desc="Restores 80 HP."},
	"curaga":    {name="Curaga", mp=30, type="heal", heal=9999,
		desc="Fully restores HP."},

	# ── Buffs: the whole party at once ────────────────────────────────────────
	"whet":      {name="Whet", mp=8, type="buff", heal=0,
		stat="atk", delta=1, scope="party",
		desc="Sharpens the party's attacks."},
	"ward":      {name="Ward", mp=8, type="buff", heal=0,
		stat="def", delta=1, scope="party",
		desc="Hardens the party's guard."},
	"quicken":   {name="Quicken", mp=8, type="buff", heal=0,
		stat="agl", delta=1, scope="party",
		desc="Quickens the party — lands and dodges more."},
	"stoke":     {name="Stoke", mp=8, type="buff", heal=0,
		stat="mag", delta=1, scope="party",
		desc="Feeds the party's magic — stronger spells and heals."},

	# ── Debuffs: every enemy at once ──────────────────────────────────────────
	"blunt":     {name="Blunt", mp=10, type="buff", heal=0,
		stat="atk", delta=-1, scope="foes",
		desc="Dulls every enemy's attacks."},
	"sunder":    {name="Sunder", mp=10, type="buff", heal=0,
		stat="def", delta=-1, scope="foes",
		desc="Breaks every enemy's guard."},
	"mire":      {name="Mire", mp=10, type="buff", heal=0,
		stat="agl", delta=-1, scope="foes",
		desc="Slows every enemy — they miss more."},
	"damp":      {name="Damp", mp=10, type="buff", heal=0,
		stat="mag", delta=-1, scope="foes",
		desc="Smothers every enemy's magic."},

	# ── Dispels: take back what a side has stacked ────────────────────────────
	#
	# Both are read from where the caster stands, so a demon casting Purge
	# strips the party and a demon casting Steady clears itself. All or nothing
	# across a whole side, and dearer than the single stage they answer — which
	# is what keeps out-stacking one buff the cheaper reply and saves these for
	# a line that has been stacking for three phases.
	"purge":     {name="Purge", mp=20, type="dispel", heal=0,
		scope="foes", clears="buffs",
		desc="Strips the other side of everything it has raised."},
	"steady":    {name="Steady", mp=20, type="dispel", heal=0,
		scope="party", clears="debuffs",
		desc="Clears every penalty stacked on your own side."},

	# ── Ailments ──────────────────────────────────────────────────────────────
	"venom":     {name="Venom", mp=4, type="ailment", heal=0,
		status="poison",
		desc="Poisons the enemy."},
	"shock":     {name="Shock", mp=6, type="ailment", heal=0,
		status="paralyzed",
		desc="Paralyzes the enemy."},
	"mute":      {name="Mute", mp=5, type="ailment", heal=0,
		status="silence",
		desc="Silences the enemy."},
	"bind":      {name="Bind", mp=4, type="ailment", heal=0,
		status="immobilize",
		desc="Immobilizes the enemy."},
}


static func get_data(spell_id: String) -> Dictionary:
	return DATA.get(spell_id, {})


static func shape_of(spell_id: String) -> String:
	return DATA.get(spell_id, {}).get("shape", SHAPE_ONE) as String


# True when the spell picks its own targets and must not open the target menu.
static func is_multi(spell_id: String) -> bool:
	return shape_of(spell_id) != SHAPE_ONE


# Short tag for the menus: "one" / "2-3" / "all".
static func reach_tag(spell_id: String) -> String:
	return reach_tag_for(shape_of(spell_id))


# The same tag off a bare shape, for the demons that carry one without a spell.
static func reach_tag_for(shape: String) -> String:
	match shape:
		SHAPE_FEW: return "2-3"
		SHAPE_ALL: return "all"
	return "one"
