class_name Status

const POISON     = "poison"
const PARALYZED  = "paralyzed"
const SILENCE    = "silence"
const IMMOBILIZE = "immobilize"

static var DATA: Dictionary = {
	"poison":     {name="Poison",     desc="Lose HP each turn.",    color=Color(0.35, 0.85, 0.25)},
	"paralyzed":  {name="Paralyzed",  desc="May be unable to act.", color=Color(0.90, 0.80, 0.15)},
	"silence":    {name="Silence",    desc="Cannot use magic.",     color=Color(0.55, 0.55, 0.90)},
	"immobilize": {name="Immobilize", desc="Cannot attack.",        color=Color(0.85, 0.50, 0.20)},
}

static func get_data(id: String) -> Dictionary:
	return DATA.get(id, {})
