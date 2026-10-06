# ExploreHUD
# The exploring screen on a wide screen (the Steam build), dressed like the
# fight so walking into one changes only the picture above the party:
#
#   - a strip across the top of the view: the floor, which way you face, what
#     you are wearing that changes the walk, and your gold;
#   - the party along the bottom of the view, a window each;
#   - a prompt over the party when there is something in front of you to use;
#   - down the left, the map in its own window, with the key, a legend, and
#     the keys that do things. The view is on the right, where the party
#     stands in a fight.
#
# Main builds it, hands it the minimap to hold, and calls refresh() after
# anything that moves, spends or heals. The phone build never makes one.
class_name ExploreHUD extends Control

const STRIP_H: float = 30.0
const PARTY_H: float = 84.0
const GAP: float = 6.0
const TEXT: int = 14
const SMALL: int = 11

const GOLD: Color = Color(1.0, 0.86, 0.42)
const PALE: Color = Color(0.84, 0.86, 0.92)
const DIM: Color = Color(0.50, 0.50, 0.58)
const HP_GREEN: Color = Color(0.30, 0.74, 0.34)
const HP_LOW: Color = Color(0.94, 0.59, 0.24)
const MP_BLUE: Color = Color(0.27, 0.47, 0.92)
const WIN_BG: Color = Color(0.063, 0.07, 0.18)
const WIN_EDGE: Color = Color(0.78, 0.80, 0.90)

signal menu_pressed
signal act_pressed

var main: Main
var map_w: float = 380.0

var _floor_lbl: Label
var _life_lbl: Label
var _compass: Array[Label] = []
var _charms: HBoxContainer
var _gold_lbl: Label
var _party_box: HBoxContainer
var _party_sig: String = ""
var _party_cards: Array[Dictionary] = []
var _demons: Array[Enemy] = []
var _prompt: PanelContainer
var _prompt_lbl: Label
var _map_win: PanelContainer
var _map_title: Label
var _key_lbl: Label
var _key_pic: KeyIcon
var _map_holder: Control
var _hint_btns: Dictionary = {}
var _pad: bool = false
# The map's column (its dark and its window) and everything over the view,
# kept as two groups so the menu and the orb can push the one and fade the
# other (push_map).
var _map_col: Control
var _view_bits: Control


func _init(owner_main: Main, column_w: float) -> void:
	main = owner_main
	map_w = column_w
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The map column's own dark, so the engine's grey never shows round the
	# window.
	_view_bits = _group()
	_map_col = _group()
	var column: ColorRect = ColorRect.new()
	column.color = Color(0.04, 0.03, 0.07)
	column.anchor_bottom = 1.0
	column.offset_right = map_w
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_col.add_child(column)
	_build_strip()
	_build_party()
	_build_prompt()
	_build_map()


# Main gives every Button a large font as it enters the tree, which is after
# _init built these; set their size back once they are in.
func _ready() -> void:
	for b: Button in _hint_btns.values():
		b.add_theme_font_size_override("font_size", SMALL)


func _group() -> Control:
	var g: Control = Control.new()
	g.set_anchors_preset(Control.PRESET_FULL_RECT)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(g)
	return g


# How far a side panel (the menu, the orb) has come in, 0 to 1: the map's
# column is pushed right by `by` pixels at 1, staying against the panel's
# edge, and the view's strip, party and prompt fade under it.
func push_map(t: float, by: float) -> void:
	_map_col.position.x = by * t
	_view_bits.modulate.a = 1.0 - t


func _exit_tree() -> void:
	for d: Enemy in _demons:
		if is_instance_valid(d):
			d.free()
	_demons.clear()


# ── Building ─────────────────────────────────────────────────────────────────

static func window_box(alpha: float = 1.0) -> StyleBoxFlat:
	var st: StyleBoxFlat = StyleBoxFlat.new()
	st.bg_color = Color(WIN_BG, alpha)
	st.border_color = WIN_EDGE
	st.set_border_width_all(2)
	st.set_corner_radius_all(6)
	st.set_content_margin_all(8)
	return st


func _label(text: String, size: int, color: Color) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _build_strip() -> void:
	var strip: PanelContainer = PanelContainer.new()
	var st: StyleBoxFlat = StyleBoxFlat.new()
	st.bg_color = Color(0.02, 0.02, 0.055, 0.92)
	st.content_margin_left = 10
	st.content_margin_right = 10
	strip.add_theme_stylebox_override("panel", st)
	strip.anchor_right = 1.0
	strip.offset_left = map_w
	strip.offset_bottom = STRIP_H
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view_bits.add_child(strip)

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	strip.add_child(row)
	_floor_lbl = _label("", TEXT, PALE)
	row.add_child(_floor_lbl)
	# The Abyss gives one life, and the strip says so the whole way down.
	_life_lbl = _label("one life", SMALL, Color(1.0, 0.42, 0.42))
	_life_lbl.visible = false
	row.add_child(_life_lbl)

	var left: Control = Control.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)
	# Left of you, ahead, right of you: the one you face lit in gold.
	for i: int in 3:
		var c: Label = _label("", TEXT if i == 1 else SMALL, GOLD if i == 1 else DIM)
		c.custom_minimum_size = Vector2(22, 0)
		c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(c)
		_compass.append(c)
	var right: Control = Control.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)

	_charms = HBoxContainer.new()
	_charms.add_theme_constant_override("separation", 8)
	row.add_child(_charms)
	_gold_lbl = _label("", TEXT, GOLD)
	row.add_child(_gold_lbl)


func _build_party() -> void:
	_party_box = HBoxContainer.new()
	_party_box.anchor_top = 1.0
	_party_box.anchor_right = 1.0
	_party_box.anchor_bottom = 1.0
	_party_box.offset_left = map_w + 8
	_party_box.offset_right = -8
	_party_box.offset_top = -PARTY_H - 8
	_party_box.offset_bottom = -8
	_party_box.add_theme_constant_override("separation", int(GAP))
	_party_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view_bits.add_child(_party_box)


func _build_prompt() -> void:
	_prompt = PanelContainer.new()
	_prompt.add_theme_stylebox_override("panel", window_box(0.92))
	_prompt.anchor_left = 0.0
	_prompt.anchor_right = 1.0
	_prompt.anchor_top = 1.0
	_prompt.anchor_bottom = 1.0
	_prompt.offset_left = map_w + 90
	_prompt.offset_right = -90
	_prompt.offset_bottom = -PARTY_H - 8 - GAP
	_prompt.offset_top = _prompt.offset_bottom - 34
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt.visible = false
	_view_bits.add_child(_prompt)
	_prompt_lbl = _label("", TEXT, PALE)
	_prompt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_child(_prompt_lbl)


func _build_map() -> void:
	_map_win = PanelContainer.new()
	_map_win.add_theme_stylebox_override("panel", window_box())
	_map_col.add_child(_map_win)
	_place_map()
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	_map_win.add_child(col)

	var head: HBoxContainer = HBoxContainer.new()
	col.add_child(head)
	_map_title = _label("", TEXT, GOLD)
	_map_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_map_title)
	_key_lbl = _label("", SMALL, DIM)
	head.add_child(_key_lbl)
	_key_pic = KeyIcon.new()
	_key_pic.custom_minimum_size = Vector2(26, 22)
	head.add_child(_key_pic)

	_map_holder = Control.new()
	_map_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_holder.clip_contents = true
	col.add_child(_map_holder)

	var legend: GridContainer = GridContainer.new()
	legend.columns = 3
	legend.add_theme_constant_override("h_separation", 10)
	for entry: Array in [["you", "You"], ["orb", "Orb"], ["portal", "Portal"],
			["warden", "Warden"], ["chest", "Chest"], ["trap", "Trap"]]:
		var cell: HBoxContainer = HBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var mark: _LegendMark = _LegendMark.new()
		mark.kind = entry[0] as String
		mark.custom_minimum_size = Vector2(12, 12)
		mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		cell.add_child(mark)
		cell.add_child(_label(entry[1] as String, SMALL, PALE))
		legend.add_child(cell)
	col.add_child(legend)

	var rule: ColorRect = ColorRect.new()
	rule.color = Color(WIN_EDGE, 0.30)
	rule.custom_minimum_size = Vector2(0, 1)
	col.add_child(rule)

	var hints: HBoxContainer = HBoxContainer.new()
	hints.add_theme_constant_override("separation", 6)
	col.add_child(hints)
	for h: Array in [["yes", act_pressed], ["no", menu_pressed]]:
		var b: Button = Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect((h[1] as Signal).emit)
		b.clip_text = true
		hints.add_child(b)
		_hint_btns[h[0]] = b
	_paint_hints()


# The map's window, down its column.
func _place_map() -> void:
	_map_win.anchor_bottom = 1.0
	_map_win.offset_left = 8
	_map_win.offset_top = 8
	_map_win.offset_bottom = -8
	_map_win.offset_right = map_w - 8


# The minimap moves in and fills the space between the title and the legend.
func hold_map(minimap: Control) -> void:
	if minimap.get_parent() != null:
		minimap.get_parent().remove_child(minimap)
	_map_holder.add_child(minimap)
	minimap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


# ── Keeping it current ───────────────────────────────────────────────────────

const _DIRS: Array[String] = ["N", "E", "S", "W"]


func refresh() -> void:
	if main == null or main.player_char == null:
		return
	var p: PlayerCharacter = main.player_char
	_floor_lbl.text = Abyss.floor_title(main.floor_num)
	_life_lbl.visible = Abyss.active and main.floor_num > Level.FLOOR_COUNT
	var f: int = main.player_facing
	_compass[0].text = _DIRS[(f + 3) % 4]
	_compass[1].text = _DIRS[f]
	_compass[2].text = _DIRS[(f + 1) % 4]
	_gold_lbl.text = "%s G" % _thousands(p.gold)
	_map_title.text = Abyss.floor_title(main.floor_num)
	var held: bool = main.has_floor_key()
	_key_lbl.text = "key" if held else "no key"
	_key_lbl.add_theme_color_override("font_color", GOLD if held else DIM)
	_key_pic.modulate = Color(1, 1, 1, 1.0 if held else 0.35)
	_refresh_charms(p)
	_refresh_party(p)
	_refresh_prompt()


func _refresh_charms(p: PlayerCharacter) -> void:
	for c: Node in _charms.get_children():
		c.queue_free()
	if p.never_ambushed():
		_charms.add_child(_label("Whistle", SMALL, Color(0.60, 0.90, 1.0)))
	if p.recovers_mp_walking():
		_charms.add_child(_label("Wellspring", SMALL, MP_BLUE.lightened(0.3)))


func _refresh_prompt() -> void:
	var what: String = main.facing_prompt()
	_prompt.visible = what != ""
	if what == "":
		return
	_prompt_lbl.text = "%s  %s" % [_key_name("yes"), what]


static func _thousands(n: int) -> String:
	var s: String = str(absi(n))
	var out: String = ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


func _refresh_party(p: PlayerCharacter) -> void:
	var sig: String = p.hero_sprite_id()
	for n: String in p.active_demons:
		sig += "|%s:%d" % [n, int(p.bound_level.get(n, 1))]
	if sig != _party_sig:
		_party_sig = sig
		_rebuild_party(p)
	for card: Dictionary in _party_cards:
		var m: CharacterSheet = card["member"] as CharacterSheet
		var hp_bar: ProgressBar = card["hp"] as ProgressBar
		hp_bar.max_value = m.max_hp
		hp_bar.value = m.hp
		var low: bool = float(m.hp) <= float(m.max_hp) * 0.5
		(hp_bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = HP_LOW if low else HP_GREEN
		(card["hp_lbl"] as Label).text = str(m.hp)
		var mp_bar: ProgressBar = card["mp"] as ProgressBar
		mp_bar.max_value = maxi(1, m.max_mp)
		mp_bar.value = m.mp
		(card["mp_lbl"] as Label).text = str(m.mp)
		(card["lv"] as Label).text = "Lv%d" % m.lv


func _rebuild_party(p: PlayerCharacter) -> void:
	for c: Node in _party_box.get_children():
		c.queue_free()
	_party_cards.clear()
	for d: Enemy in _demons:
		if is_instance_valid(d):
			d.free()
	_demons.clear()
	var members: Array[CharacterSheet] = [p]
	# A bound demon is called up whole at the start of every fight, so on the
	# walk it is always at its full; built here only to read what that is.
	for n: String in p.active_demons:
		var d: Enemy = p.bound_demon(n)
		d.hp = d.max_hp
		d.mp = d.max_mp
		_demons.append(d)
		members.append(d)
	for m: CharacterSheet in members:
		_party_box.add_child(_party_card(m, m == p))
	# Empty places keep the windows the same width with a short party.
	for _i: int in range(members.size(), 4):
		var spacer: Control = Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spacer.size_flags_stretch_ratio = 1.0
		_party_box.add_child(spacer)


func _party_card(m: CharacterSheet, is_hero: bool) -> PanelContainer:
	var win: PanelContainer = PanelContainer.new()
	var st: StyleBoxFlat = window_box(0.94)
	st.set_content_margin_all(6)
	win.add_theme_stylebox_override("panel", st)
	win.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	win.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	win.add_child(col)

	var top: HBoxContainer = HBoxContainer.new()
	top.add_theme_constant_override("separation", 3)
	col.add_child(top)
	var pic: AnimatedPortrait = AnimatedPortrait.new()
	pic.custom_minimum_size = Vector2(32, 32)
	pic.set_zoom(2.2)
	if is_hero:
		pic.load_sprite_id((m as PlayerCharacter).hero_sprite_id())
	else:
		var d: Enemy = m as Enemy
		if d.abyss_element != "":
			pic.material = Abyss.palette_material(d.abyss_element)
		if d.sprite_id != "":
			pic.load_sprite_id(d.sprite_id)
		elif d.sprite_path != "":
			pic.load_static(load(d.sprite_path) as Texture2D)
	top.add_child(pic)
	var names: VBoxContainer = VBoxContainer.new()
	names.add_theme_constant_override("separation", -2)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(names)
	var name_lbl: Label = _label(m.display_name() if m.has_method("display_name") else "Hero",
			TEXT, GOLD if is_hero else PALE)
	if is_hero:
		name_lbl.text = "Hero"
	name_lbl.clip_text = true
	names.add_child(name_lbl)
	# No ailment marks: a fight's ailments end with the fight.
	var lv: Label = _label("", SMALL, DIM)
	names.add_child(lv)

	var hp: Array = _bar_row(col, HP_GREEN)
	var mp: Array = _bar_row(col, MP_BLUE)
	var card: Dictionary = {member = m, hp = hp[0], hp_lbl = hp[1], mp = mp[0], mp_lbl = mp[1],
			lv = lv}
	_party_cards.append(card)
	return win


func _bar_row(col: VBoxContainer, color: Color) -> Array:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	col.add_child(row)
	var bar: ProgressBar = ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 5)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.bg_color = Color(0.12, 0.12, 0.20)
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	row.add_child(bar)
	var num: Label = _label("", SMALL, PALE)
	num.custom_minimum_size = Vector2(30, 0)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(num)
	return [bar, num]


# ── Key names: the keyboard's or the pad's, whichever was touched last ───────

const _WORDS: Dictionary = {yes = "Act", no = "Menu"}


# Whatever the action is bound to now (Controls), so a rebinding shows here.
func _key_name(what: String) -> String:
	return "[%s]" % (Controls.pad_name(Controls.pad_of(what)) if _pad
			else Controls.key_name(Controls.key_of(what)))


# Options can rebind while the HUD is up behind the menu.
func repaint_keys() -> void:
	_paint_hints()
	_refresh_prompt()


func _paint_hints() -> void:
	for what: String in _hint_btns:
		(_hint_btns[what] as Button).text = "%s %s" % [_key_name(what), _WORDS[what] as String]


func set_pad(on: bool) -> void:
	if on == _pad:
		return
	_pad = on
	_paint_hints()
	_refresh_prompt()


# One mark of the legend, drawn like the map draws it.
class _LegendMark extends Control:
	var kind: String = ""

	func _draw() -> void:
		var s: Vector2 = size
		var c: Vector2 = s / 2.0
		match kind:
			"you":
				draw_colored_polygon(PackedVector2Array([Vector2(c.x, 0), Vector2(0, s.y),
						Vector2(s.x, s.y)]), Color(1.0, 0.86, 0.42))
			"orb":
				draw_circle(c, s.x / 2.0, Minimap.C_ORB)
			"portal":
				draw_rect(Rect2(Vector2.ZERO, s), Minimap.C_PORTAL)
			"warden":
				draw_circle(c, s.x / 2.0, Minimap.C_WARDEN)
			"chest":
				draw_rect(Rect2(Vector2(0, 2), Vector2(s.x, s.y - 4)), Minimap.C_CHEST)
			"trap":
				draw_line(Vector2.ZERO, s, Minimap.C_TRAP, 2.0)
				draw_line(Vector2(0, s.y), Vector2(s.x, 0), Minimap.C_TRAP, 2.0)
