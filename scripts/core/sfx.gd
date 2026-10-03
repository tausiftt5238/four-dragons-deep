# Sfx
# Short sounds for things happening. Every one is made in code from a recipe in
# data/sfx_recipes.json (see SfxSynth), so there are no audio files to ship or
# to keep out of the repository. A sound with no recipe is silence.
#
# A sound asked for is played at the end of the frame rather than at once, so
# one blow that is both a hit and a weakness, or a hit and a kill, sounds as the
# bigger of the two instead of both stacked.
class_name Sfx

const RECIPES: String = "res://data/sfx_recipes.json"

# A louder sound in the same frame swallows these.
const OUTRANKS: Dictionary = {
	"weak":      ["hit", "hurt"],
	"defeat":    ["hit", "hurt"],
	"game_over": ["hit", "hurt", "trap"],
	"jackpot":   ["pair"],
}

# Buttons whose label says they take you back out rather than in.
const BACK_LABELS: Array[String] = ["back", "close", "leave", "leave it", "cancel"]

static var _hub: _Hub
static var _recipes: Dictionary = {}
static var _master: Dictionary = {}
static var _players: Dictionary = {}
# Sound -> semitones to shift it by; NAN is "pick a little at random".
static var _queued: Dictionary = {}
# Recipes still to be rendered ahead of their first use.
static var _warm: Array = []


# Starts listening for buttons and begins rendering the sounds. Safe to call
# from every scene's _ready.
static func init() -> void:
	_get_hub()


# `semitones` shifts it by a set amount, as the gacha's reels climb a chord;
# left out, it wanders by the recipe's own variation so repeats differ.
static func play(sound: String, semitones: float = NAN) -> void:
	var hub: _Hub = _get_hub()
	if hub == null:
		return
	if _queued.is_empty():
		hub.flush.call_deferred()
	_queued[sound] = semitones


# The spell's own element if it has a sound, else the plain cast.
static func cast(element: String) -> void:
	play("cast_" + element if _recipes.has("cast_" + element) else "cast")


static func _flush() -> void:
	var names: Array = _queued.keys()
	for loud: String in OUTRANKS:
		if loud in names:
			for quiet: String in OUTRANKS[loud]:
				names.erase(quiet)
	for sound: String in names:
		var p: AudioStreamPlayer = _player_for(sound)
		if p == null:
			continue
		var shift: float = _queued[sound]
		if is_nan(shift):
			var j: float = float((_recipes[sound] as Dictionary).get("jitter", 0.0))
			shift = randf_range(-j, j)
		p.pitch_scale = pow(2.0, shift / 12.0)
		p.play()
	_queued.clear()


static func _player_for(sound: String) -> AudioStreamPlayer:
	if _players.has(sound):
		return _players[sound]
	if not _recipes.has(sound):
		return null
	var p: AudioStreamPlayer = AudioStreamPlayer.new()
	p.stream = SfxSynth.render(_recipes[sound], _master)
	p.max_polyphony = 4
	p.bus = Settings.audio_bus(Settings.SFX_BUS)
	_hub.add_child(p)
	_players[sound] = p
	_warm.erase(sound)
	return p


# Lives on the tree's root, so sounds outlast the scene that asked for them.
static func _get_hub() -> _Hub:
	if is_instance_valid(_hub):
		return _hub
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	_hub = _Hub.new()
	_hub.name = "Sfx"
	_players.clear()
	_load_recipes()
	tree.root.add_child.call_deferred(_hub)
	tree.node_added.connect(_hub.on_node_added)
	return _hub


static func _load_recipes() -> void:
	_recipes = {}
	_master = {}
	if not ResourceLoader.exists(RECIPES):
		return
	var json: JSON = load(RECIPES) as JSON
	if json == null or not json.data is Dictionary:
		return
	for key: String in json.data:
		if key == "_master":
			_master = json.data[key]
		else:
			_recipes[key] = json.data[key]
	# Shortest first: those are the ones heard soonest, taps and steps.
	_warm = _recipes.keys()
	_warm.sort_custom(func(x: String, y: String) -> bool:
		return _length(x) < _length(y))


static func _length(sound: String) -> float:
	var out: float = 0.0
	for L: Dictionary in (_recipes[sound] as Dictionary).get("layers", []):
		out = maxf(out, float(L.get("delay", 0.0)) + float(L["a"]) + float(L["d"]) \
				+ (maxi(1, (L.get("notes", [0]) as Array).size()) - 1) * float(L.get("step", 0.0)))
	return out


static func _on_button(btn: Button) -> void:
	var label: String = btn.text.strip_edges().trim_prefix("<").strip_edges().to_lower()
	play("back" if label in BACK_LABELS else "tap")


class _Hub extends Node:
	# One sound a frame, so rendering them all never stalls a single frame
	# for long — the web build has no threads to hand it to.
	func _process(_delta: float) -> void:
		if Sfx._warm.is_empty():
			set_process(false)
			return
		Sfx._player_for(Sfx._warm[0])

	func flush() -> void:
		Sfx._flush()

	func on_node_added(node: Node) -> void:
		if node is Button:
			var btn: Button = node as Button
			btn.pressed.connect(func() -> void: Sfx._on_button(btn))
