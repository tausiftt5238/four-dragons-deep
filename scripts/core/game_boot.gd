# GameBoot
# Carries intent between the title screen and the main game scene.
# pending_slot: 0 = new game, 1-3 = load from that save slot.
class_name GameBoot

static var pending_slot: int = 0
# The Abyss (Abyss): "new" starts a descent with the cleared hero, "continue"
# picks up its autosave. Empty for the main game.
static var pending_abyss: String = ""
