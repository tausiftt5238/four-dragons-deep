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
	# ── Healing ───────────────────────────────────────────────────────────────
	"cure":     {name="Cure",     mp=6,  type="heal", heal=30,   desc="Restores 30 HP."},
	"cura":     {name="Cura",     mp=15, type="heal", heal=80,   desc="Restores 80 HP."},
	"curaga":   {name="Curaga",   mp=30, type="heal", heal=9999, desc="Fully restores HP."},
	# ── Ailments ──────────────────────────────────────────────────────────────
	"venom":    {name="Venom",    mp=4,  type="ailment", heal=0, status="poison",     desc="Poisons the enemy."},
	"shock":    {name="Shock",    mp=6,  type="ailment", heal=0, status="paralyzed",  desc="Paralyzes the enemy."},
	"mute":     {name="Mute",     mp=5,  type="ailment", heal=0, status="silence",    desc="Silences the enemy."},
	"bind":     {name="Bind",     mp=4,  type="ailment", heal=0, status="immobilize", desc="Immobilizes the enemy."},
}


static func get_data(spell_id: String) -> Dictionary:
	return DATA.get(spell_id, {})
