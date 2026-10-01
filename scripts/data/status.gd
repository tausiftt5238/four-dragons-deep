class_name Status

const POISON     = "poison"
const PARALYZED  = "paralyzed"
const SILENCE    = "silence"
const BLIND      = "blind"

static var DATA: Dictionary = {
	"poison":    {name="Poison",     noun="poison",    desc="Lose HP each turn.",          color=Color(0.35, 0.85, 0.25)},
	"paralyzed": {name="Paralyzed",  noun="paralysis", desc="Half the time, cannot act.",  color=Color(0.90, 0.80, 0.15)},
	"silence":   {name="Silence",    noun="silence",   desc="Cannot use magic.",           color=Color(0.55, 0.55, 0.90)},
	"blind":     {name="Blind",      noun="blindness", desc="Agility halved.",             color=Color(0.85, 0.50, 0.20)},
}

static func get_data(id: String) -> Dictionary:
	return DATA.get(id, {})
