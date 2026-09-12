# Spell
# Registry for all spells. DATA is the single source of truth used by both
# the in-menu spell list and the in-combat spell chooser.
#
# Fields per spell:
#   name    – display name
#   mp      – MP cost
#   type    – "dmg" | "banish" | "heal" | "buff" | "ailment"
#   element – affinity key it is scored against ("" for the ones that aren't)
#   shape   – SHAPE_ONE | SHAPE_FEW | SHAPE_ALL, how many demons it reaches
#   spread  – what each target gets when the cast is split; 1.0 for single
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

# Damage keeps more of itself when split than a banishing cast does. Expelling
# three demons at once for 36 MP would end most fights outright, so the wide
# banishing spells give up nearly half their odds to exist at all.
const SPREAD_FEW_DMG:    float = 0.75
const SPREAD_ALL_DMG:    float = 0.60
const SPREAD_FEW_BANISH: float = 0.70
const SPREAD_ALL_BANISH: float = 0.50

static var DATA: Dictionary = {
	# ── Fire ──────────────────────────────────────────────────────────────────
	"ember":       {name="Ember",       mp=8,  type="dmg", heal=0, element="fire",
		shape=SHAPE_ONE, spread=1.0,
		desc="A flame set on one demon."},
	"cinderfall":  {name="Cinderfall",  mp=14, type="dmg", heal=0, element="fire",
		shape=SHAPE_FEW, spread=SPREAD_FEW_DMG,
		desc="Embers fall across two or three of them."},
	"pyre":        {name="Pyre",        mp=22, type="dmg", heal=0, element="fire",
		shape=SHAPE_ALL, spread=SPREAD_ALL_DMG,
		desc="The whole room catches."},

	# ── Ice ───────────────────────────────────────────────────────────────────
	"rime":        {name="Rime",        mp=8,  type="dmg", heal=0, element="ice",
		shape=SHAPE_ONE, spread=1.0,
		desc="Frost closes over one demon."},
	"hailfall":    {name="Hailfall",    mp=14, type="dmg", heal=0, element="ice",
		shape=SHAPE_FEW, spread=SPREAD_FEW_DMG,
		desc="Hail comes down on two or three of them."},
	"whiteout":    {name="Whiteout",    mp=22, type="dmg", heal=0, element="ice",
		shape=SHAPE_ALL, spread=SPREAD_ALL_DMG,
		desc="Everything in the room goes cold at once."},

	# ── Thunder ───────────────────────────────────────────────────────────────
	"arc":         {name="Arc",         mp=8,  type="dmg", heal=0, element="thunder",
		shape=SHAPE_ONE, spread=1.0,
		desc="Current jumps to one demon."},
	"forkfall":    {name="Forkfall",    mp=14, type="dmg", heal=0, element="thunder",
		shape=SHAPE_FEW, spread=SPREAD_FEW_DMG,
		desc="The current forks into two or three of them."},
	"thunderhead": {name="Thunderhead", mp=22, type="dmg", heal=0, element="thunder",
		shape=SHAPE_ALL, spread=SPREAD_ALL_DMG,
		desc="It breaks over all of them together."},

	# ── Light: expels, or does nothing ────────────────────────────────────────
	"banish":      {name="Banish",      mp=14, type="banish", heal=0, element="light",
		shape=SHAPE_ONE, spread=1.0,
		desc="Tries to expel one demon outright. Some things cannot abide the light."},
	"winnow":      {name="Winnow",      mp=24, type="banish", heal=0, element="light",
		shape=SHAPE_FEW, spread=SPREAD_FEW_BANISH,
		desc="Reaches for two or three at once, and holds each of them less firmly."},
	"daybreak":    {name="Daybreak",    mp=36, type="banish", heal=0, element="light",
		shape=SHAPE_ALL, spread=SPREAD_ALL_BANISH,
		desc="Opens the light on every demon standing. Thin, across that many."},

	# ── Dark: unmakes, or does nothing ────────────────────────────────────────
	"consign":     {name="Consign",     mp=14, type="banish", heal=0, element="dark",
		shape=SHAPE_ONE, spread=1.0,
		desc="Tries to unmake one demon outright. Some things cannot abide the dark."},
	"cull":        {name="Cull",        mp=24, type="banish", heal=0, element="dark",
		shape=SHAPE_FEW, spread=SPREAD_FEW_BANISH,
		desc="Takes two or three together, and takes each of them less surely."},
	"nightfall":   {name="Nightfall",   mp=36, type="banish", heal=0, element="dark",
		shape=SHAPE_ALL, spread=SPREAD_ALL_BANISH,
		desc="Closes the dark over the whole room. Thin, across that many."},

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

	# Stripping what the other side stacked is deliberately absent for now —
	# the dekaja/dekunda pair comes in a later pass, and until it does a stacked
	# buff is answered by out-stacking it.

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


# Short tag for the menus: "ONE" / "2-3" / "ALL".
static func reach_tag(spell_id: String) -> String:
	match shape_of(spell_id):
		SHAPE_FEW: return "2-3"
		SHAPE_ALL: return "ALL"
	return "ONE"
