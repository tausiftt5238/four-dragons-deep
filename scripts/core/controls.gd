# Controls
# The whole game runs on six presses: the four directions, ○ for yes and ×
# for no. One key and one pad button each, rebindable from Options (Button
# mapping) and kept in settings.cfg beside the other preferences.
#
# In the dungeon up and down walk, left and right turn, ○ acts on what is in
# front of you and × opens the menu. Everywhere else ○ chooses and × backs
# out. The engine's ui_ actions, which every menu and the fight read, are
# rebuilt from the same bindings, so a rebinding holds everywhere at once.
#
# Some keys are fixed and always work as well, so nothing can be bound away
# into a corner the player cannot get out of: the arrow keys, Enter (and
# Space) for yes, Escape for no.
class_name Controls

const SECTION_KEYS: String = "keys"
const SECTION_PAD: String = "pad"

# In the order Options lists them: [action, name, default key, default button].
# ○ is the pad's right face button and × the bottom one: yes on the right,
# the way the Japanese releases have it.
const ACTIONS: Array = [
	["up", "Up", KEY_W, JOY_BUTTON_DPAD_UP],
	["down", "Down", KEY_S, JOY_BUTTON_DPAD_DOWN],
	["left", "Left", KEY_A, JOY_BUTTON_DPAD_LEFT],
	["right", "Right", KEY_D, JOY_BUTTON_DPAD_RIGHT],
	["yes", "O  Yes", KEY_Z, JOY_BUTTON_B],
	["no", "X  No", KEY_X, JOY_BUTTON_A],
]

# The keys that always work as well, whatever is bound.
const FIXED: Dictionary = {
	up = [KEY_UP], down = [KEY_DOWN], left = [KEY_LEFT], right = [KEY_RIGHT],
	yes = [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE], no = [KEY_ESCAPE],
}

# The engine's own action each one drives as well.
const UI: Dictionary = {up = "ui_up", down = "ui_down", left = "ui_left",
		right = "ui_right", yes = "ui_accept", no = "ui_cancel"}

static var _keys: Dictionary = {}
static var _pads: Dictionary = {}
static var _ready_done: bool = false


# Builds the actions from the saved file (or the defaults). Safe to call from
# anywhere, any number of times.
static func ensure() -> void:
	if _ready_done:
		return
	_ready_done = true
	var cfg: ConfigFile = ConfigFile.new()
	cfg.load(Settings.PATH)
	for a: Array in ACTIONS:
		var id: String = a[0] as String
		_keys[id] = int(cfg.get_value(SECTION_KEYS, id, a[2]))
		_pads[id] = int(cfg.get_value(SECTION_PAD, id, a[3]))
	_apply()


static func key_of(action: String) -> int:
	ensure()
	return int(_keys.get(action, KEY_NONE))


static func pad_of(action: String) -> int:
	ensure()
	return int(_pads.get(action, JOY_BUTTON_INVALID))


# Binds `action` to a key. Another action already on that key takes this
# one's old key instead, so no key ever does two things and none is lost.
static func set_key(action: String, key: int) -> void:
	ensure()
	var old: int = key_of(action)
	for other: String in _keys:
		if other != action and int(_keys[other]) == key:
			_keys[other] = old
	_keys[action] = key
	_apply()
	_save()


static func set_pad(action: String, button: int) -> void:
	ensure()
	var old: int = pad_of(action)
	for other: String in _pads:
		if other != action and int(_pads[other]) == button:
			_pads[other] = old
	_pads[action] = button
	_apply()
	_save()


static func reset() -> void:
	ensure()
	for a: Array in ACTIONS:
		_keys[a[0]] = a[2]
		_pads[a[0]] = a[3]
	_apply()
	_save()


# A key Options may not bind: the ones kept fixed above, and the debug keys.
static func reserved(key: int) -> bool:
	return key in [KEY_ESCAPE, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_ENTER,
			KEY_KP_ENTER, KEY_SPACE, KEY_F9]


static func key_name(key: int) -> String:
	return OS.get_keycode_string(key) if key != KEY_NONE else "-"


# What the pad's buttons are called, by the shapes on them: the game's own
# words for yes and no are O and X.
static func pad_name(button: int) -> String:
	match button:
		JOY_BUTTON_A: return "X"
		JOY_BUTTON_B: return "O"
		JOY_BUTTON_X: return "Square"
		JOY_BUTTON_Y: return "Triangle"
		JOY_BUTTON_BACK: return "Back"
		JOY_BUTTON_START: return "Start"
		JOY_BUTTON_GUIDE: return "Guide"
		JOY_BUTTON_LEFT_STICK: return "LS"
		JOY_BUTTON_RIGHT_STICK: return "RS"
		JOY_BUTTON_LEFT_SHOULDER: return "LB"
		JOY_BUTTON_RIGHT_SHOULDER: return "RB"
		JOY_BUTTON_DPAD_UP: return "D-Up"
		JOY_BUTTON_DPAD_DOWN: return "D-Down"
		JOY_BUTTON_DPAD_LEFT: return "D-Left"
		JOY_BUTTON_DPAD_RIGHT: return "D-Right"
	return "Button %d" % button if button >= 0 else "-"


static func _apply() -> void:
	for a: Array in ACTIONS:
		var id: String = a[0] as String
		if not InputMap.has_action(id):
			InputMap.add_action(id)
		# The ui_ action keeps what the engine gave it for the sticks; its
		# keys and buttons are these.
		for action: String in [id, UI[id] as String]:
			for ev: InputEvent in InputMap.action_get_events(action):
				if ev is InputEventKey or ev is InputEventJoypadButton:
					InputMap.action_erase_event(action, ev)
			var keys: Array = [int(_keys[id])]
			keys.append_array(FIXED.get(id, []))
			for key: Variant in keys:
				var k: InputEventKey = InputEventKey.new()
				k.keycode = int(key) as Key
				InputMap.action_add_event(action, k)
			var b: InputEventJoypadButton = InputEventJoypadButton.new()
			b.button_index = int(_pads[id]) as JoyButton
			InputMap.action_add_event(action, b)


static func _save() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.load(Settings.PATH)
	for id: String in _keys:
		cfg.set_value(SECTION_KEYS, id, _keys[id])
		cfg.set_value(SECTION_PAD, id, _pads[id])
	cfg.save(Settings.PATH)


# What a screen that waits for a tap says: the tap on a phone, the yes button
# on a wide screen.
static func continue_hint() -> String:
	if not Build.steam():
		return "tap to continue"
	return "%s to continue" % key_name(key_of("yes"))
