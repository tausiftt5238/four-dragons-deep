# IntroUI
# The opening of a new run: the captain of the Tower Watch tells the hero what
# has gone wrong, hands over the Hellbat, and sends them down. One line at a
# time, typed out; a tap finishes the line being typed, or moves to the next.
# Skip is there for a second run.
class_name IntroUI extends Control

signal finished

const _FONT := preload("res://resources/misc/OldSchoolAdventures-42j9.ttf") as FontFile

const SPEAKER: String = "Captain Ysolde"
const CHARS_PER_SEC: float = 45.0
const BOX: float = 380.0
const ZOOM: float = 2.0
# When the Hellbat comes out: how far the captain steps aside, and where the
# bat's box flies in from and settles, all from the middle of the screen.
const CAPTAIN_STEP: float = BOX * 0.27
const BAT_FROM: float = BOX * 0.15
const BAT_TO: float = -BOX * 0.12

# A line beginning with ">" brings the Hellbat out before it is said.
const LINES: Array[String] = [
	"Ah, there you are. Come in out of the wind, traveller, and let me look at you.",
	"I am Ysolde, Captain of the Tower Watch. For three hundred years my order has kept a single vigil.",
	"The Inverted Tower. A spire driven down into the earth instead of up toward the sky, floor beneath floor, into the dark.",
	"Its seal was laid by hands far wiser than mine, so that whatever dwells below would stay below.",
	"Three nights ago, that seal broke.",
	"Since then they have not stopped coming. Bats with ember eyes. Slimes that eat the stone. Things the old bestiaries have no names for. They pour up the stair like water from a cracked jar.",
	"So the Watch sent word to every village and crossroads, asking for one soul brave enough to go down.",
	"You answered. You have my thanks, and the thanks of every family sleeping behind a barred door tonight, uhhh...",
	"...hero. Right? Yes. Hero. That will do nicely.",
	"Your task is simple to say and hard to do: go down, and learn how the seal came undone. Seals like that do not break on their own.",
	">But you will not go alone. This one flew up out of the stair on the first night.",
	"It did not bite. It did not flee. It hung from the rafters and watched us, and when we spoke, it listened.",
	"That is the strangest thing of all. The creatures below are more than beasts. They think. They want. Some may even bargain.",
	"So before you draw steel, try words. Speak with them. You may find allies where you expected only teeth.",
	"Go now, hero. The Tower is waiting, and it is a long way down.",
]

# The Abyss mode's opening: the captain sends for the hero again.
const ABYSS_LINES: Array[String] = [
	"Hero. I hoped I would never have to send for you again.",
	"I am sorry to be the one to tell you. When the Necromancer fell, the Tower closed... and something else opened where it stood.",
	"There is no Tower now. Only a pit. An abyss, with no stair and no floor that any of us can see.",
	"We lowered a lantern on a thousand feet of rope. We never felt it land.",
	"Things are coming up out of it. Old things, in new colours. Fire, frost, storm, light, shadow.",
	"We do not know where it ends. Perhaps it does not.",
	"So I am asking you, not ordering you: go down, and see how far you can go.",
	"And when you can go no further, the Watch will be at the top of the rope. We will pull you back up.",
]

# The Abyss mode's last scene: she hauls the fallen hero back up the rope.
const RESCUE_LINES: Array[String] = [
	"Hold on. Hold on, I have you.",
	"Easy, hero. Do not try to stand. The Watch has the rope, and we are pulling you up.",
	"You did your best. You went deeper than any of us dared to look.",
	"Rest now. We have you, and we are not letting go. Do not worry.",
	"The Abyss will still be there tomorrow. So will we.",
]

# What this telling says, and how it closes. The defaults are the main game's
# opening; the Abyss sets its own (TitleScreen, Main._show_game_over).
var lines: Array[String] = LINES
var closing_text: String = "And so, the descent begins."
# The rescue: the captain hauling the fallen hero up a rope, rising as she
# talks, with no Hellbat.
var rescue: bool = false

var _idx: int = -1
var _typing: bool = false
var _shown: float = 0.0
var _text: Label
var _arrow: Label
var _captain: AnimatedPortrait
var _bat: AnimatedPortrait
var _done: bool = false
var _box: PanelContainer
var _hint: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Music.play(Music.ORB if rescue else Music.INTRO)
	_build()
	if rescue:
		_build_rescue()
	# The title fades through black to this; the first line waits for that.
	var t: Tween = create_tween()
	t.tween_interval(0.6)
	t.tween_callback(_next)


func _build() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.04, 0.03, 0.07, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	bg.gui_input.connect(_on_input)
	add_child(bg)

	# The stage: the captain in the middle of the upper pane, standing on a
	# faint floor; the Hellbat comes in at her side later.
	var stage: Control = Control.new()
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.anchor_bottom = 0.0
	stage.offset_bottom = Main.MAP_PANE_H
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)

	var floor_line: ColorRect = ColorRect.new()
	floor_line.color = Color(0.22, 0.18, 0.28)
	floor_line.anchor_left = 0.08
	floor_line.anchor_right = 0.92
	floor_line.offset_top = _feet_y()
	floor_line.offset_bottom = _feet_y() + 2
	floor_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(floor_line)

	_captain = _actor("Swordsman")
	_captain.anchor_left = 0.5
	_captain.anchor_right = 0.5
	_captain.offset_left = -BOX / 2.0
	_captain.offset_right = BOX / 2.0
	stage.add_child(_captain)

	_bat = _actor("Hellbat")
	_bat.flip_h = true
	_bat.anchor_left = 0.5
	_bat.anchor_right = 0.5
	_bat.offset_left = BAT_FROM
	_bat.offset_right = BAT_FROM + BOX
	# Hangs in the air rather than standing on the floor.
	_bat.offset_top -= BOX * 0.2
	_bat.offset_bottom -= BOX * 0.2
	_bat.modulate.a = 0.0
	stage.add_child(_bat)

	# The dialogue box, across the lower pane where the thumb is.
	var box: PanelContainer = PanelContainer.new()
	_box = box
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.06, 0.11)
	style.border_color = Color(0.90, 0.75, 0.30)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(16)
	box.add_theme_stylebox_override("panel", style)
	box.anchor_left = 0.0
	box.anchor_right = 1.0
	box.offset_left = 18.0
	box.offset_right = -18.0
	box.offset_top = _feet_y() + 50.0
	box.offset_bottom = _feet_y() + (220.0 if Build.steam() else 330.0)
	if Build.steam():
		# A reading width, not the whole screen.
		box.anchor_left = 0.5
		box.anchor_right = 0.5
		box.offset_left = -340.0
		box.offset_right = 340.0
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)

	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(col)

	col.add_child(_label(SPEAKER, 20, Color(0.90, 0.75, 0.30)))

	_text = _label("", 20, Color(0.88, 0.86, 0.92))
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	col.add_child(_text)

	_arrow = _label("▼", 18, Color(0.90, 0.75, 0.30))
	_arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_arrow.visible = false
	col.add_child(_arrow)
	var blink: Tween = _arrow.create_tween().set_loops()
	blink.tween_property(_arrow, "modulate:a", 0.2, 0.45)
	blink.tween_property(_arrow, "modulate:a", 1.0, 0.45)

	var hint: Label = _label(Controls.continue_hint(), 13, Color(0.40, 0.37, 0.46))
	_hint = hint
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.anchor_left = 0.0
	hint.anchor_right = 1.0
	var below: float = _feet_y() + (226.0 if Build.steam() else 340.0)
	hint.offset_top = below
	hint.offset_bottom = below + 30.0
	add_child(hint)

	var skip: Button = Button.new()
	skip.text = "Skip"
	skip.anchor_left = 1.0
	skip.anchor_right = 1.0
	skip.offset_left = -110.0
	skip.offset_right = -14.0
	skip.offset_top = 14.0
	skip.offset_bottom = 58.0
	skip.add_theme_font_override("font", _FONT)
	skip.add_theme_font_size_override("font_size", 18)
	skip.pressed.connect(_finish)
	add_child(skip)


# The floor the captain stands on, just above the dialogue box: under the
# phone's map band, or in the upper half of a wide screen.
func _feet_y() -> float:
	return 250.0 if Build.steam() else Main.MAP_PANE_H + 160.0


func _actor(sprite_id: String) -> AnimatedPortrait:
	var a: AnimatedPortrait = AnimatedPortrait.new()
	a.mouse_filter = Control.MOUSE_FILTER_IGNORE
	a.load_sprite_id(sprite_id)
	a.set_zoom(ZOOM)
	# Placed by its feet: the box's top is the floor less where the feet sit
	# inside it.
	var crop: float = 100.0 / ZOOM
	var feet_in_box: float = (56.0 - (100.0 - crop) / 2.0) / crop * BOX
	a.offset_top = _feet_y() - feet_in_box
	a.offset_bottom = a.offset_top + BOX
	return a


func _on_input(event: InputEvent) -> void:
	# Touch arrives as an emulated click too; listening for both would take
	# two steps per tap.
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	_advance()


# Yes on a keyboard or a pad does what a tap does.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_advance()


# A tap or a yes: finish the line being typed, or go on to the next.
func _advance() -> void:
	if _typing:
		_shown = float(_text.text.length())
		_text.visible_characters = -1
		_typing = false
		_arrow.visible = true
	else:
		Sfx.play("tap")
		_next()


func _next() -> void:
	if _done:
		return
	_idx += 1
	if _idx >= lines.size():
		_closing()
		return
	var line: String = lines[_idx]
	if line.begins_with(">"):
		line = line.substr(1)
		_bring_bat()
	_text.text = line
	_text.visible_characters = 0
	_shown = 0.0
	_typing = true
	_arrow.visible = false


func _process(delta: float) -> void:
	if not _typing:
		return
	_shown += delta * CHARS_PER_SEC
	var n: int = int(_shown)
	if n >= _text.text.length():
		_text.visible_characters = -1
		_typing = false
		_arrow.visible = true
	else:
		_text.visible_characters = n


# The captain steps aside and the Hellbat flutters in beside her.
func _bring_bat() -> void:
	Sfx.play("recruit")
	var t: Tween = create_tween().set_parallel()
	t.tween_property(_captain, "offset_left", -BOX / 2.0 - CAPTAIN_STEP, 0.6) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	t.tween_property(_captain, "offset_right", BOX / 2.0 - CAPTAIN_STEP, 0.6) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	t.tween_property(_bat, "modulate:a", 1.0, 0.6)
	t.tween_property(_bat, "offset_left", BAT_TO, 0.6) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	t.tween_property(_bat, "offset_right", BAT_TO + BOX, 0.6) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)


# The box clears, and one last line stands on its own before the dark.
func _closing() -> void:
	_done = true
	var line: Label = _label(closing_text, 24, Color(0.90, 0.75, 0.30))
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.anchor_right = 1.0
	line.offset_top = _box.offset_top
	line.offset_bottom = _box.offset_bottom
	line.modulate.a = 0.0
	add_child(line)
	var t: Tween = create_tween()
	t.tween_property(_box, "modulate:a", 0.0, 0.4)
	t.parallel().tween_property(_hint, "modulate:a", 0.0, 0.4)
	t.tween_property(line, "modulate:a", 1.0, 0.8)
	t.tween_interval(1.6)
	t.tween_callback(func() -> void: finished.emit())


func _finish() -> void:
	if _done:
		return
	_done = true
	_typing = false
	finished.emit()


# The rope from above, the captain holding it, and the hero lying at her feet,
# all rising slowly while she talks: the Watch hauling the two of them up.
func _build_rescue() -> void:
	var stage: Control = _captain.get_parent() as Control
	_bat.visible = false
	var hero: AnimatedPortrait = _actor("Knight")
	hero.anchor_left = 0.5
	hero.anchor_right = 0.5
	hero.offset_left = -BOX / 2.0 - CAPTAIN_STEP * 1.2
	hero.offset_right = BOX / 2.0 - CAPTAIN_STEP * 1.2
	stage.add_child(hero)
	hero.play_once("death")          # and it stays down: death holds its last frame
	_captain.flip_h = true
	_captain.offset_left += CAPTAIN_STEP * 0.9
	_captain.offset_right += CAPTAIN_STEP * 0.9
	var rope: ColorRect = ColorRect.new()
	rope.color = Color(0.55, 0.45, 0.30)
	rope.anchor_left = 0.5
	rope.anchor_right = 0.5
	rope.offset_left = CAPTAIN_STEP * 0.9 - 2.0
	rope.offset_right = CAPTAIN_STEP * 0.9 + 1.0
	rope.offset_top = -40.0
	rope.offset_bottom = _feet_y() - BOX * 0.18
	rope.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(rope)
	stage.move_child(rope, 0)
	var rise: float = 150.0
	var t: Tween = create_tween().set_parallel()
	for n: Control in [_captain, hero, rope]:
		t.tween_property(n, "offset_top", n.offset_top - rise, 30.0)
		t.tween_property(n, "offset_bottom", n.offset_bottom - rise, 30.0)


func _label(text: String, size: int, color: Color) -> Label:
	var lbl: Label = Label.new()
	lbl.text = text
	lbl.add_theme_font_override("font", _FONT)
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl
