# TitleMarch
# The wide title's scene (Build.steam): the knight walks on and on along a
# floor that slides under him, and the first band's monsters come at him one
# by one. Each one meets the sword, falls, and the walk goes on to the next.
# The phone's title has the smaller TitleVignette instead.
#
# Driven from _process with the fight's beats on tweens this node owns, so
# leaving the title stops all of it at once.
class_name TitleMarch extends Control

const HEIGHT: float = 260.0
# The sprite box, and how far into the 100px frame to crop: the figures stand
# small in the middle of their frames.
const BOX: float = 330.0
const ZOOM: float = 1.8
# Both packs stand their figures on y = 56 of the frame; cropped and scaled
# into the box, this is where that lands, so a box is placed by its feet.
const FEET_IN_BOX: float = (56.0 - (100.0 - 100.0 / ZOOM) / 2.0) / (100.0 / ZOOM) * BOX
# The floor's line, this far above the stage's foot.
const GROUND_LIFT: float = 36.0
# Where along the stage the knight walks, as a share of its width.
const KNIGHT_AT: float = 0.34
# The floor goes by at the knight's pace; a monster comes on a little faster.
const PACE: float = 70.0
const CHARGE: float = 40.0
# How far ahead of the knight a monster stops: the end of the sword.
const REACH: float = 150.0
const ATTACKS: Array[String] = ["attack01", "attack02", "attack03"]
const GROUND: Color = Color(0.22, 0.18, 0.28)
const STONE: Color = Color(0.13, 0.11, 0.17)

var _knight: AnimatedPortrait
var _foe: AnimatedPortrait
var _roster: Array[String] = []
var _next: int = 0
var _scroll: float = 0.0
var _walking: bool = true
var _swing: int = 0


func _ready() -> void:
	custom_minimum_size = Vector2(0, HEIGHT)
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The first band, in the order the tables give them.
	for t: Dictionary in Enemy.TEMPLATES:
		if int(t.get("tier", 0)) == 1 and str(t.get("sprite_id", "")) != "":
			_roster.append(str(t["sprite_id"]))
	_knight = _actor("Knight", false)
	_knight.play("walk")
	resized.connect(_place_knight)
	_place_knight()


func _actor(sprite_id: String, face_left: bool) -> AnimatedPortrait:
	var a: AnimatedPortrait = AnimatedPortrait.new()
	a.mouse_filter = Control.MOUSE_FILTER_IGNORE
	a.size = Vector2(BOX, BOX)
	a.flip_h = face_left
	a.load_sprite_id(sprite_id)
	a.set_zoom(ZOOM)
	add_child(a)
	return a


func _ground() -> float:
	return size.y - GROUND_LIFT


func _place_knight() -> void:
	_knight.position = Vector2(size.x * KNIGHT_AT - BOX / 2.0, _ground() - FEET_IN_BOX)


# What a creature moves with: its walk, or its wings.
static func _move_anim(a: AnimatedPortrait) -> String:
	return "flying" if a._anims.has("flying") and not a._anims.has("walk") else "walk"


func _process(delta: float) -> void:
	if not _walking:
		return
	_scroll = fmod(_scroll + PACE * delta, 48.0)
	queue_redraw()
	if _foe == null:
		_send_next()
		return
	_foe.position.x -= (PACE + CHARGE) * delta
	if _foe.position.x <= _knight.position.x + REACH:
		_foe.position.x = _knight.position.x + REACH
		_fight()


func _send_next() -> void:
	if _roster.is_empty():
		return
	_foe = _actor(_roster[_next % _roster.size()], true)
	_next += 1
	_foe.position = Vector2(size.x + 20.0, _ground() - FEET_IN_BOX)
	_foe.play(_move_anim(_foe))


# One swing, the monster flinches, falls and fades, and the walk goes on.
func _fight() -> void:
	_walking = false
	var foe: AnimatedPortrait = _foe
	_knight.play_once(ATTACKS[_swing % ATTACKS.size()])
	_swing += 1
	var t: Tween = create_tween()
	t.tween_interval(0.4)
	await t.finished
	if not is_instance_valid(foe):
		return
	foe.play_once("hurt")
	t = create_tween()
	t.tween_property(foe, "position:x", foe.position.x + 14.0, 0.15) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	t.tween_interval(0.3)
	await t.finished
	foe.play_once("death")
	t = create_tween()
	t.tween_interval(0.5)
	t.tween_property(foe, "modulate:a", 0.0, 0.4)
	await t.finished
	foe.queue_free()
	_foe = null
	_knight.play("walk")
	t = create_tween()
	t.tween_interval(0.5)
	await t.finished
	_walking = true


# The floor: a line, and flagstone joints sliding back under the walk.
func _draw() -> void:
	var g: float = _ground()
	draw_rect(Rect2(0, g, size.x, 2), GROUND)
	var x: float = -_scroll
	while x < size.x:
		draw_line(Vector2(x, g + 2), Vector2(x - 18.0, size.y), STONE, 2.0)
		x += 48.0
