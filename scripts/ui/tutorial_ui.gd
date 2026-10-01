# TutorialUI
# The title screen's Tutorial: one page per thing a first run trips over, each a
# screenshot of it happening and a few lines on what it means. The pictures
# come from tools/tutorial_shots.gd, which plays a scripted run to take them.
#
# Built for a phone held upright: the picture on top, the words under it at a
# size you can read at arm's length, and Back / Next where the thumb is.
class_name TutorialUI extends Control

signal closed

const _FONT := preload("res://resources/misc/OldSchoolAdventures-42j9.ttf") as FontFile
const _DIR: String = "res://resources/tutorial/"

const PAGES: Array[Dictionary] = [
	{title = "Moving", shot = "explore.png",
		text = "Swipe up to step forward and down to step back. Swipe left or right to turn. "
			+ "On a keyboard: arrow keys or WASD.\n\n"
			+ "The map on top fills in as you walk. Walking also brings your MP back."},
	{title = "Keys and doors", shot = "key.png",
		text = "Every floor is locked. Find the key (the violet shard) and walk onto it.\n\n"
			+ "On floors 4, 9, 14 and 19 a warden holds the key instead. Beat it.\n\n"
			+ "Walk into the door to unlock it, then walk in again to go down."},
	{title = "Floors and chests", shot = "trap.png",
		text = "Each stretch of the Deep has its own floor to watch for. Ice slides you to "
			+ "solid ground. Charged plates change every two steps; a lit one hurts, so step back and forth to wait. Lava "
			+ "burns every crossing. Teleporters carry you to their twin.\n\n"
			+ "Chests sit in alcoves in the walls. Walk into one to open it."},
	{title = "Save orbs", shot = "orb.png",
		text = "Orbs are the only place to save. Stand on one and tap Orb to rest, shop, sell, "
			+ "buy back monsters and save.\n\n"
			+ "Save often. Death ends the run.\n\n"
			+ "Every dragon's corridor has an orb just inside it."},
	{title = "Fighting", shot = "combat.png",
		text = "Your side gets one turn icon per member standing.\n\n"
			+ "Hit a weakness or crit: half an icon.\n"
			+ "Miss, or it nulls you: two icons.\n"
			+ "It reflects or drains you: your turn ends.\n\n"
			+ "The boxes under a monster are its chart: W weak, S strong, N null, R reflect, D drain. "
			+ "Hit it, Analyze it or kill one to fill them in."},
	{title = "Talking", shot = "talk.png",
		text = "You don't have to fight everything. Tap Talk to Negotiate, Bribe or Threaten your "
			+ "way out, or Recruit the monster to your side.\n\n"
			+ "Analyze shows its temper, so you can pick the approach it answers to."},
	{title = "Your party", shot = "party.png",
		text = "Three monsters fight with you, and six can be on your roster. Swap them in the "
			+ "menu's Party tab. The bench still earns half the EXP.\n\n"
			+ "A monster that falls and isn't revived before the fight ends is gone for good."},
	{title = "Four dragons", shot = "dragon.png",
		text = "A dragon waits at floors 5, 10, 15 and 20: Ice, Thunder, Fire, then Void.\n\n"
			+ "Each one is weak to the dragon before it. You start with Ember, which is why "
			+ "Ice comes first.\n\n"
			+ "Good luck. Four dragons deep is further than it sounds."},
]

var _page: int = 0
var _title: Label
var _shot: TextureRect
var _text: Label
var _count: Label
var _back_btn: Button
var _next_btn: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	_show(0)


func _build() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.04, 0.03, 0.07, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 18)
	add_child(margin)

	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	margin.add_child(col)

	var top: HBoxContainer = HBoxContainer.new()
	col.add_child(top)

	_title = _label("", 30, Color(0.90, 0.75, 0.30))
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_title)

	var close_btn: Button = _button("Close")
	close_btn.pressed.connect(func() -> void: closed.emit())
	top.add_child(close_btn)

	# A frame around the shot, so a dark screenshot does not melt into the
	# dark page behind it.
	var frame: PanelContainer = PanelContainer.new()
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = Color(0.0, 0.0, 0.0)
	box.border_color = Color(0.35, 0.30, 0.45)
	box.set_border_width_all(2)
	box.set_content_margin_all(2)
	frame.add_theme_stylebox_override("panel", box)
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(frame)

	_shot = TextureRect.new()
	_shot.custom_minimum_size = Vector2(250, 540)
	_shot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_shot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	frame.add_child(_shot)

	_text = _label("", 19, Color(0.86, 0.84, 0.90))
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.add_theme_constant_override("line_spacing", 6)
	col.add_child(_text)

	var nav: HBoxContainer = HBoxContainer.new()
	nav.add_theme_constant_override("separation", 10)
	col.add_child(nav)

	_back_btn = _button("< Back")
	_back_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_back_btn.pressed.connect(func() -> void: _show(_page - 1))
	nav.add_child(_back_btn)

	_count = _label("", 18, Color(0.55, 0.50, 0.62))
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count.custom_minimum_size = Vector2(70, 0)
	nav.add_child(_count)

	_next_btn = _button("Next >")
	_next_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_next_btn.pressed.connect(func() -> void:
		if _page >= PAGES.size() - 1:
			closed.emit()
		else:
			_show(_page + 1))
	nav.add_child(_next_btn)


func _show(page: int) -> void:
	_page = clampi(page, 0, PAGES.size() - 1)
	var p: Dictionary = PAGES[_page]
	_title.text = p["title"] as String
	_text.text  = p["text"] as String
	var path: String = _DIR + (p["shot"] as String)
	_shot.texture = load(path) as Texture2D if ResourceLoader.exists(path) else null
	_count.text = "%d / %d" % [_page + 1, PAGES.size()]
	_back_btn.disabled = _page == 0
	_next_btn.text = "Done" if _page == PAGES.size() - 1 else "Next >"


func _label(text: String, size: int, color: Color) -> Label:
	var lbl: Label = Label.new()
	lbl.text = text
	lbl.add_theme_font_override("font", _FONT)
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	return lbl


func _button(text: String) -> Button:
	var btn: Button = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 52)
	btn.add_theme_font_override("font", _FONT)
	btn.add_theme_font_size_override("font_size", 20)
	return btn
