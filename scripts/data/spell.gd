# Spell
# Registry for all spells. DATA is the single source of truth used by both
# the in-menu spell list and the in-combat spell chooser.
#
# Fields per spell:
#   name   – display name
#   mp     – MP cost
#   type   – "heal" (castable from menu) | "dmg" (battle only)
#   heal   – HP restored when cast from menu (0 for dmg spells)
#   desc   – one-line description shown in menus
class_name Spell

static var DATA: Dictionary = {
	# ── Elemental damage ──────────────────────────────────────────────────────
	"fire":     {name="Fire",     mp=8,  type="dmg", heal=0, element="fire",    desc="Deals fire damage to one enemy."},
	"fira":     {name="Fira",     mp=16, type="dmg", heal=0, element="fire",    desc="Deals strong fire damage to one enemy."},
	"firaga":   {name="Firaga",   mp=30, type="dmg", heal=0, element="fire",    desc="Deals massive fire damage to one enemy."},
	"thunder":  {name="Thunder",  mp=10, type="dmg", heal=0, element="thunder", desc="Deals lightning damage to one enemy."},
	"thundara": {name="Thundara", mp=18, type="dmg", heal=0, element="thunder", desc="Deals strong lightning damage to one enemy."},
	"blizzard": {name="Blizzard", mp=10, type="dmg", heal=0, element="ice",     desc="Deals ice damage to one enemy."},
	"blizzara": {name="Blizzara", mp=18, type="dmg", heal=0, element="ice",     desc="Deals strong ice damage to one enemy."},
	# ── Banishing: expels outright or does nothing at all ─────────────────────
	"banish":   {name="Banish",   mp=14, type="banish", heal=0, element="light", desc="Tries to expel one enemy outright. Certain things cannot abide the light."},
	"consign":  {name="Consign",  mp=14, type="banish", heal=0, element="dark",  desc="Tries to unmake one enemy outright. Certain things cannot abide the dark."},
	# ── Healing ───────────────────────────────────────────────────────────────
	"cure":     {name="Cure",     mp=6,  type="heal", heal=30,   desc="Restores 30 HP."},
	"cura":     {name="Cura",     mp=15, type="heal", heal=80,   desc="Restores 80 HP."},
	"curaga":   {name="Curaga",   mp=30, type="heal", heal=9999, desc="Fully restores HP."},
	# ── Buffs: the whole party at once ────────────────────────────────────────
	"whet":     {name="Whet",     mp=8,  type="buff", heal=0, stat="atk", delta=1,  scope="party", desc="Sharpens the party's attacks."},
	"ward":     {name="Ward",     mp=8,  type="buff", heal=0, stat="def", delta=1,  scope="party", desc="Hardens the party's guard."},
	"quicken":  {name="Quicken",  mp=8,  type="buff", heal=0, stat="agl", delta=1,  scope="party", desc="Quickens the party — lands and dodges more."},
	"stoke":    {name="Stoke",    mp=8,  type="buff", heal=0, stat="mag", delta=1,  scope="party", desc="Feeds the party's magic — stronger spells and heals."},
	# ── Debuffs: every enemy at once ──────────────────────────────────────────
	"blunt":    {name="Blunt",    mp=10, type="buff", heal=0, stat="atk", delta=-1, scope="foes",  desc="Dulls every enemy's attacks."},
	"sunder":   {name="Sunder",   mp=10, type="buff", heal=0, stat="def", delta=-1, scope="foes",  desc="Breaks every enemy's guard."},
	"mire":     {name="Mire",     mp=10, type="buff", heal=0, stat="agl", delta=-1, scope="foes",  desc="Slows every enemy — they miss more."},
	"damp":     {name="Damp",     mp=10, type="buff", heal=0, stat="mag", delta=-1, scope="foes",  desc="Smothers every enemy's magic."},
	# ── Stripping what the other side stacked ─────────────────────────────────
	"purge":    {name="Purge",    mp=12, type="dispel", heal=0, mode="buffs",   scope="foes",  desc="Strips every enemy buff."},
	"steady":   {name="Steady",   mp=12, type="dispel", heal=0, mode="debuffs", scope="party", desc="Clears the party's debuffs."},
	# ── Ailments ──────────────────────────────────────────────────────────────
	"venom":    {name="Venom",    mp=4,  type="ailment", heal=0, status="poison",     desc="Poisons the enemy."},
	"shock":    {name="Shock",    mp=6,  type="ailment", heal=0, status="paralyzed",  desc="Paralyzes the enemy."},
	"mute":     {name="Mute",     mp=5,  type="ailment", heal=0, status="silence",    desc="Silences the enemy."},
	"bind":     {name="Bind",     mp=4,  type="ailment", heal=0, status="immobilize", desc="Immobilizes the enemy."},
}


static func get_data(spell_id: String) -> Dictionary:
	return DATA.get(spell_id, {})
