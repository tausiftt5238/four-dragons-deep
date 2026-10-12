# Controls
# The whole game runs on eight presses: the four directions, two strafes, yes
# and no. One key and one pad button each, rebindable from Options (Button
# mapping) and kept in settings.cfg beside the other preferences.
#
# In the dungeon up and down walk, left and right turn, the strafes step
# sideways (the PC build only), yes acts on what is in front of you and no
# opens the menu. Everywhere else yes chooses and no backs
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
# Yes is the pad's bottom face button (A) and no the right one (B), the way
# the Steam Deck and an Xbox pad have it.
const ACTIONS: Array = [
	["up", "Up", KEY_W, JOY_BUTTON_DPAD_UP],
	["down", "Down", KEY_S, JOY_BUTTON_DPAD_DOWN],
	["left", "Left", KEY_A, JOY_BUTTON_DPAD_LEFT],
	["right", "Right", KEY_D, JOY_BUTTON_DPAD_RIGHT],
	["strafe_left", "Strafe left", KEY_Q, JOY_BUTTON_LEFT_SHOULDER],
	["strafe_right", "Strafe right", KEY_E, JOY_BUTTON_RIGHT_SHOULDER],
	["yes", "Yes", KEY_Z, JOY_BUTTON_A],
	["no", "No", KEY_X, JOY_BUTTON_B],
]

# The keys that always work as well, whatever is bound.
const FIXED: Dictionary = {
	up = [KEY_UP], down = [KEY_DOWN], left = [KEY_LEFT], right = [KEY_RIGHT],
	yes = [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE], no = [KEY_ESCAPE],
}

# The engine's own action each one drives as well (the strafes drive none).
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


# The pad's buttons by the names on a Steam Deck (and an Xbox pad), and the
# icon drawn for each (tools/make_pad_glyphs.py). The back grips are SDL's
# paddles: one and two the upper right and left, three and four the lower.
const PAD_GLYPHS: Dictionary = {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_BACK: "View", JOY_BUTTON_START: "Menu",
	JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_DPAD_UP: "D_Up", JOY_BUTTON_DPAD_DOWN: "D_Down",
	JOY_BUTTON_DPAD_LEFT: "D_Left", JOY_BUTTON_DPAD_RIGHT: "D_Right",
	JOY_BUTTON_PADDLE1: "R4", JOY_BUTTON_PADDLE2: "L4",
	JOY_BUTTON_PADDLE3: "R5", JOY_BUTTON_PADDLE4: "L5",
}
const PAD_ICON_DIR: String = "res://resources/icons/pad/"


static func pad_name(button: int) -> String:
	match button:
		JOY_BUTTON_GUIDE: return "Steam"
		JOY_BUTTON_DPAD_UP: return "D-Up"
		JOY_BUTTON_DPAD_DOWN: return "D-Down"
		JOY_BUTTON_DPAD_LEFT: return "D-Left"
		JOY_BUTTON_DPAD_RIGHT: return "D-Right"
	if PAD_GLYPHS.has(button):
		return PAD_GLYPHS[button] as String
	return "Button %d" % button if button >= 0 else "-"


# The icon for a pad button, or null for one without (the name stands in).
static func pad_icon(button: int) -> Texture2D:
	if not PAD_GLYPHS.has(button):
		return null
	var path: String = PAD_ICON_DIR + (PAD_GLYPHS[button] as String) + ".png"
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


# Whether the last thing pressed was on a pad, so what the screen names is the
# button in your hands. Boot hands every event here.
static var using_pad: bool = false


static func note(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		using_pad = false
	elif event is InputEventJoypadButton and event.pressed:
		using_pad = true
	elif event is InputEventJoypadMotion \
			and absf((event as InputEventJoypadMotion).axis_value) > 0.6:
		using_pad = true


static func _apply() -> void:
	for a: Array in ACTIONS:
		var id: String = a[0] as String
		if not InputMap.has_action(id):
			InputMap.add_action(id)
		# The ui_ action keeps what the engine gave it for the sticks; its
		# keys and buttons are these.
		var drives: Array[String] = [id]
		if UI.has(id):
			drives.append(UI[id] as String)
		for action: String in drives:
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


# What a screen that waits for a tap says: the tap on a phone, the yes key on
# a wide screen (ButtonHint shows the pad's icon instead, once a pad is used).
static func continue_hint() -> String:
	if not Build.steam():
		return "tap to continue"
	return "%s to continue" % key_name(key_of("yes"))
