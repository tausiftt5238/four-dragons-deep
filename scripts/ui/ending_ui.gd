# EndingUI
# What follows the Necromancer: the knight on the road home with the demons
# still walking with him, while the tale is told underneath; then thanks and
# credits, and back to the title.
#
# The road is drawn rather than drawn from a sheet: flagstones sliding by under
# walkers who walk on the spot, coloured band by band from the Abyss's bone
# white back to the cyan of the first floor, with daylight growing ahead.
class_name EndingUI extends Control

signal finished

const _FONT := preload("res://resources/misc/OldSchoolAdventures-42j9.ttf") as FontFile

const LINES: Array[String] = [
	"The Necromancer falls, and with it the dark that held the Tower open.",
	"Floor by floor, the brave knight and those still at his side make their way back toward the light, past the cold halls where four dragons once kept their watch.",
	"At the mouth of the Tower, the old seal knits itself whole. Nothing more will crawl up out of the deep.",
	"And so the brave knight returns to the surface, the Necromancer defeated once and for all, and peace comes home to the kingdom at last.",
]
const LINE_TIME: float = 5.5
# How long the walk lasts, so the road's colour reaches the first floor's as
# the last line is read.
const CLIMB_TIME: float = LINE_TIME * 4.0

const CREDITS: Array = [
	["Art", "Zerie\nDeepDiveGameStudio"],
	["Music", "Momiziba"],
	["Game", "Tausif\nwith help from Claude"],
]

# The sprite ids of the demons still with the hero, front to back (Main).
var team: Array[String] = []

var _walk: _Walk
var _text: Label
var _line: int = -1
var _line_tween: Tween
var _in_credits: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Music.play(Music.ENDING)
	_build_climb()
	var t: Tween = create_tween()
	t.tween_interval(0.8)
	t.tween_callback(_next_line)


func _build_climb() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.03, 0.025, 0.05)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	bg.gui_input.connect(_on_input)
	add_child(bg)

	_walk = _Walk.new()
	_walk.team = team
	# Full height, so the road runs on down under the tale rather than
	# stopping at an edge; the walkers' place on it is set by the upper pane.
	_walk.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_walk.climb_time = CLIMB_TIME
	add_child(_walk)

	_text = Label.new()
	_text.anchor_right = 1.0
	_text.offset_left = 36.0
	_text.offset_right = -36.0
	_text.offset_top = Main.MAP_PANE_H + 170.0
	_text.offset_bottom = Main.MAP_PANE_H + 470.0
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_font_override("font", _FONT)
	_text.add_theme_font_size_override("font_size", 21)
	_text.add_theme_color_override("font_color", Color(0.90, 0.88, 0.94))
	_text.add_theme_constant_override("line_spacing", 6)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.modulate.a = 0.0
	add_child(_text)

	var hint: Label = _label("tap to continue", 13, Color(0.40, 0.37, 0.46))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.anchor_right = 1.0
	hint.offset_top = -80.0
	hint.offset_bottom = -50.0
	add_child(hint)


# A tap moves the tale on rather than waiting out the line.
func _on_input(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	if not _in_credits:
		_next_line()


func _next_line() -> void:
	if _in_credits:
		return
	_line += 1
	if _line_tween and _line_tween.is_valid():
		_line_tween.kill()
	if _line >= LINES.size():
		_to_credits()
		return
	_line_tween = create_tween()
	if _text.modulate.a > 0.0:
		_line_tween.tween_property(_text, "modulate:a", 0.0, 0.4)
	_line_tween.tween_callback(func() -> void: _text.text = LINES[_line])
	_line_tween.tween_property(_text, "modulate:a", 1.0, 0.8)
	_line_tween.tween_interval(LINE_TIME - 1.2)
	_line_tween.tween_callback(_next_line)


func _to_credits() -> void:
	_in_credits = true
	var fade: ScreenFade = ScreenFade.cover(get_tree(), "", 1.0)
	await fade.covered
	for child: Node in get_children():
		child.queue_free()
	_build_credits()
	fade.reveal(0.8)


func _build_credits() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.04, 0.03, 0.07)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var col: VBoxContainer = VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 30.0
	col.offset_right = -30.0
	col.offset_top = 90.0
	col.offset_bottom = -60.0
	col.add_theme_constant_override("separation", 14)
	add_child(col)

	var thanks: Label = _label("Thank you\nfor playing!", 40, Color(0.90, 0.75, 0.30))
	thanks.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(thanks)

	# The two of them, done, side by side.
	var pair: HBoxContainer = HBoxContainer.new()
	pair.alignment = BoxContainer.ALIGNMENT_CENTER
	pair.add_theme_constant_override("separation", -60)
	col.add_child(pair)
	for id: String in [PlayerCharacter.SPRITE_KNIGHT, PlayerCharacter.STARTING_DEMON]:
		var a: AnimatedPortrait = AnimatedPortrait.new()
		a.custom_minimum_size = Vector2(260, 260)
		a.mouse_filter = Control.MOUSE_FILTER_IGNORE
		a.load_sprite_id(id)
		a.set_zoom(2.2)
		a.flip_h = id != PlayerCharacter.SPRITE_KNIGHT
		pair.add_child(a)

	for entry: Array in CREDITS:
		var head: Label = _label(entry[0] as String, 15, Color(0.55, 0.50, 0.62))
		head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(head)
		var names: Label = _label(entry[1] as String, 22, Color(0.90, 0.88, 0.94))
		names.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(names)

	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)

	var back: Button = Button.new()
	back.text = "Return to Title"
	back.custom_minimum_size = Vector2(0, 52)
	back.add_theme_font_override("font", _FONT)
	back.add_theme_font_size_override("font_size", 20)
	back.pressed.connect(func() -> void: finished.emit())
	col.add_child(back)


func _label(text: String, size: int, color: Color) -> Label:
	var lbl: Label = Label.new()
	lbl.text = text
	lbl.add_theme_font_override("font", _FONT)
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl


# The road home. The knight walks on the spot at the head of whoever is still
# with him, the demons he walks with filing along behind, while the ground
# slides by underneath and the light grows ahead, coloured band by band from
# the Abyss's bone white back to the first floor's cyan.
class _Walk extends Control:
	const BOX: float = 230.0
	const ZOOM: float = 2.2
	const GAP: float = 112.0      # between one walker and the next
	const SPEED: float = 70.0     # how fast the ground goes by, px a second

	var climb_time: float = 20.0
	var team: Array[String] = []  # the demons' sprite ids, front to back
	var _t: float = 0.0
	var _knight: AnimatedPortrait
	var _followers: Array[AnimatedPortrait] = []
	var _flies: Array[bool] = []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip_contents = true
		_knight = _actor(PlayerCharacter.SPRITE_KNIGHT)
		_knight.play("walk")
		for id: String in team:
			var a: AnimatedPortrait = _actor(id)
			a.play("walk")
			_followers.append(a)
			_flies.append(a._anims.has("flying") and not a._anims.has("walk"))

	func _actor(id: String) -> AnimatedPortrait:
		var a: AnimatedPortrait = AnimatedPortrait.new()
		a.mouse_filter = Control.MOUSE_FILTER_IGNORE
		a.size = Vector2(BOX, BOX)
		a.load_sprite_id(id)
		a.set_zoom(ZOOM)
		add_child(a)
		return a

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()
		var ground: float = _ground_y()
		var crop: float = 100.0 / ZOOM
		var feet_in_box: float = (56.0 - (100.0 - crop) / 2.0) / crop * BOX
		# The party is centred on the screen, the knight at its head.
		var span: float = GAP * float(_followers.size())
		var head_x: float = size.x / 2.0 + span / 2.0
		_knight.position = Vector2(head_x - BOX / 2.0, ground - feet_in_box)
		for i: int in _followers.size():
			var x: float = head_x - GAP * float(i + 1)
			var y: float = ground - feet_in_box
			if _flies[i]:
				y += -70.0 + sin(_t * 3.0 + float(i)) * 8.0
			_followers[i].position = Vector2(x - BOX / 2.0, y)

	func _ground_y() -> float:
		return Main.MAP_PANE_H * 0.80

	# How far along the road home, 0 at the Necromancer, 1 at the surface.
	func _progress() -> float:
		return clampf(_t / climb_time, 0.0, 1.0)

	# The band he is passing through: the Abyss's colour first, the first
	# floor's last, blended as he goes.
	func _band_color() -> Color:
		var bands: Array[Color] = Level.TIER_WIRE.duplicate()
		bands.reverse()
		var x: float = _progress() * (bands.size() - 1)
		var i: int = mini(int(x), bands.size() - 2)
		return bands[i].lerp(bands[i + 1], x - i)

	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		var p: float = _progress()
		# Daylight ahead and above, growing as the surface nears.
		var sky: Color = Color(0.95, 0.80, 0.45)
		var glow_h: float = Main.MAP_PANE_H
		for i: int in 64:
			var y0: float = glow_h * float(i) / 64.0
			var a: float = p * 0.22 * (1.0 - float(i) / 64.0)
			draw_rect(Rect2(0, y0, w, glow_h / 64.0 + 1.0), Color(sky, a))
		# The road: a floor in the band's colour, its flagstones sliding by.
		var col: Color = _band_color()
		var gy: float = _ground_y()
		draw_rect(Rect2(0, gy, w, h - gy), Color(col.r * 0.10, col.g * 0.10, col.b * 0.13))
		draw_line(Vector2(0, gy), Vector2(w, gy), col, 2.0)
		var tile: float = 64.0
		var off: float = fposmod(_t * SPEED, tile)
		var x: float = -off
		while x < w + tile:
			draw_line(Vector2(x, gy), Vector2(x - 26.0, gy + 30.0), Color(col, 0.45), 2.0)
			x += tile
