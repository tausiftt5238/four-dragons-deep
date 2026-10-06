# DemonLevelUpUI
# One bound demon's level-up, shown on its own after the result screen. A demon
# places its own points, so the first page only says what grew and which of its
# lines climbed a rung. A brand-new skill is different: each one it is offered
# gets a page of its own after that, to learn or pass on — and, when all its
# slots are taken, to say what it forgets to make room.
class_name DemonLevelUpUI extends Control

signal dismissed

var demon_name: String = ""
var before:     Dictionary     # {lv, max_hp, max_mp, str, def, mag, agl}
var after:      Dictionary
var learned:    Array = []     # names of lines that climbed a rung this fight
var offers:     Array = []     # skill entries it may learn, one page each
var player:     PlayerCharacter

var _vbox: VBoxContainer
var _panel: Panel

const STATS: Array[Array] = [
	["HP", "max_hp"], ["MP", "max_mp"],
	["STR", "str"], ["DEF", "def"], ["MAG", "mag"], ["AGL", "agl"],
]


func _ready() -> void:
	Sfx.play("level_up")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()


func _build() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.04, 0.03, 0.06, 0.88)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Everything tappable lives in the lower pane, under where the map sits.
	var lower: Control = Control.new()
	Layout.lower_pane(lower)
	lower.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lower)

	var panel: Panel = Panel.new()
	_panel = panel
	panel.anchor_left   = 0.5;  panel.anchor_right  = 0.5
	panel.anchor_top    = 0.5;  panel.anchor_bottom = 0.5
	panel.offset_left   = -210; panel.offset_right  = 210
	panel.offset_top    = -220; panel.offset_bottom = 220
	lower.add_child(panel)
	Layout.dress(panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for s: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(s, 20)
	panel.add_child(margin)

	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 10)
	margin.add_child(_vbox)
	_show_stats()


func _clear() -> void:
	for c: Node in _vbox.get_children():
		_vbox.remove_child(c)
		c.queue_free()
	_set_height(PANEL_H)


# A full list has five slots to show on top of the offer, so that page gets a
# taller panel; every other page keeps the stat page's size. Set per page
# rather than measured: a wrapping label has no honest height until it is laid
# out.
const PANEL_H: float = 440.0
const PANEL_FULL_H: float = 600.0

func _set_height(h: float) -> void:
	_panel.offset_top    = -h / 2.0
	_panel.offset_bottom =  h / 2.0


func _header(vbox: VBoxContainer) -> void:
	var header: Label = Label.new()
	header.text = demon_name
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_color_override("font_color", Color(0.80, 0.62, 1.00))
	header.add_theme_font_size_override("font_size", 24)
	vbox.add_child(header)


func _show_stats() -> void:
	_clear()
	var vbox: VBoxContainer = _vbox
	_header(vbox)

	var lv_lbl: Label = Label.new()
	lv_lbl.text = "LEVEL  %d  ->  %d" % [int(before.get("lv", 1)), int(after.get("lv", 1))]
	lv_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lv_lbl.add_theme_color_override("font_color", Color(0.90, 0.82, 0.50))
	vbox.add_child(lv_lbl)

	vbox.add_child(HSeparator.new())

	var grid: GridContainer = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 6)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(grid)
	for row: Array in STATS:
		var key: String = row[1] as String
		var was: int = int(before.get(key, 0))
		var now: int = int(after.get(key, 0))
		_cell(grid, row[0] as String,
				StageArrows.tint_for(row[0] as String, Color(0.68, 0.68, 0.68)))
		_cell(grid, "%d  ->  %d" % [was, now], Color(0.90, 0.90, 0.90))
		_cell(grid, "+%d" % (now - was) if now > was else "",
				Color(0.55, 0.90, 0.55))

	if not learned.is_empty():
		vbox.add_child(HSeparator.new())
		for skill: Variant in learned:
			var lbl: Label = Label.new()
			lbl.text = "Now  %s" % str(skill)
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			lbl.add_theme_color_override("font_color", Color(0.50, 0.85, 1.00))
			vbox.add_child(lbl)

	vbox.add_child(HSeparator.new())

	var btn: Button = _button("Continue")
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(_next_offer)
	vbox.add_child(btn)


# The offers are worked through front to back; the popup closes after the last.
func _next_offer() -> void:
	if offers.is_empty() or player == null:
		dismissed.emit()
		return
	_show_offer(offers.pop_front() as Dictionary)


func _show_offer(offer: Dictionary) -> void:
	_clear()
	_header(_vbox)
	var known: Array = player.skills_of(demon_name)
	var full: bool = known.size() >= PlayerCharacter.DEMON_SKILL_CAP

	var wants: Label = Label.new()
	wants.text = "can learn"
	wants.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wants.add_theme_color_override("font_color", Color(0.68, 0.68, 0.68))
	_vbox.add_child(wants)

	var name_lbl: Label = Label.new()
	name_lbl.text = PlayerCharacter.skill_name(offer)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 22)
	name_lbl.add_theme_color_override("font_color", Color(0.50, 0.85, 1.00))
	_vbox.add_child(name_lbl)

	# Rich text so a buff's stat can carry its colour ("AGL-" in green).
	var about: RichTextLabel = RichTextLabel.new()
	about.bbcode_enabled = true
	about.fit_content = true
	about.scroll_active = false
	about.text = "[center]%s[/center]" % _describe(offer)
	about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	about.add_theme_color_override("default_color", Color(0.85, 0.85, 0.85))
	_vbox.add_child(about)

	_vbox.add_child(HSeparator.new())

	if not full:
		var row: HBoxContainer = HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 16)
		_vbox.add_child(row)
		var learn: Button = _button("Learn")
		learn.pressed.connect(func() -> void:
			player.learn_demon_skill(demon_name, offer)
			_next_offer())
		row.add_child(learn)
		var skip: Button = _button("Skip")
		skip.pressed.connect(_next_offer)
		row.add_child(skip)
		return

	# Full: every slot it has is a way to say yes, and the last one says no.
	_set_height(PANEL_FULL_H)
	var note: Label = Label.new()
	note.text = "All %d slots are full. Pick one to forget:" % PlayerCharacter.DEMON_SKILL_CAP
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_color_override("font_color", Color(0.90, 0.82, 0.50))
	_vbox.add_child(note)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	_vbox.add_child(grid)
	for i: int in known.size():
		var old: Dictionary = known[i] as Dictionary
		var forget: Button = _button(PlayerCharacter.skill_name(old))
		forget.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(forget)
		forget.pressed.connect(func() -> void:
			player.learn_demon_skill(demon_name, offer, i)
			_next_offer())
	var keep: Button = _button("Skip")
	keep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	keep.pressed.connect(_next_offer)
	_vbox.add_child(keep)


# What the skill does, in the words the magic tab uses for the same spell.
static func _describe(skill: Dictionary) -> String:
	var id: String = skill.get("id", "") as String
	if skill.get("kind", "") != "support":
		id = Spell.elemental_id(skill.get("element", "") as String,
				int(skill.get("rung", 1)), skill.get("shape", Spell.SHAPE_ONE) as String)
	var d: Dictionary = Spell.get_data(id)
	if d.is_empty():
		return ""
	var head: String = ""
	if skill.get("kind", "") == "support":
		head = "%s %s" % [ItemInfo.stat_tag(d.get("stat", "") as String,
				int(d.get("delta", 1))),
				"party" if d.get("scope", "party") == "party" else "foes"]
	else:
		head = "%s %s" % [Affinity.element_name(d.get("element", "") as String),
				Spell.reach_tag(id)]
	var cost: String = Spell.cost_text(id) if int(d.get("hp", 0)) > 0 \
			or skill.get("kind", "") == "support" else ""
	return "%s%s  —  %s" % [head, ("  " + cost) if cost != "" else "",
			d.get("desc", "")]


func _button(text: String) -> Button:
	var btn: Button = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(130, 36)
	return btn


func _cell(grid: GridContainer, text: String, color: Color) -> void:
	var lbl: Label = Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", color)
	grid.add_child(lbl)
