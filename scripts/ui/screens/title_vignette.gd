# TitleVignette
# A little scene under the title, played on a loop: the knight walks in, a
# slime comes the other way, one swing, and the knight walks on. Something
# moving on the first screen says "this is a game" before a word is read.
#
# Everything is timed by tweens owned by this node, so leaving the title frees
# them with it and no coroutine wakes up on a screen that is gone.
class_name TitleVignette extends Control

const STAGE: Vector2 = Vector2(500, 150)
# The sprite box, and how far into the 100px frame to crop: the figures stand
# small in the middle of their frames.
const BOX: float = 240.0
const ZOOM: float = 1.8
# Both packs stand their figures on y = 56 of the frame. Cropped and scaled
# into the box, this is where that lands, so a box is placed by its feet.
const FEET_IN_BOX: float = (56.0 - (100.0 - 100.0 / ZOOM) / 2.0) / (100.0 / ZOOM) * BOX
const GROUND_Y: float = 138.0
# The slime's box sits this far right of the knight's when they meet, which
# puts it at the end of the sword.
const REACH: float = BOX / 2.0
const WALK_TIME: float = 3.0
const ATTACKS: Array[String] = ["attack01", "attack02"]

var _knight: AnimatedPortrait
var _slime: AnimatedPortrait
var _round: int = 0


func _ready() -> void:
	custom_minimum_size = STAGE
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var ground: ColorRect = ColorRect.new()
	ground.color = Color(0.22, 0.18, 0.28)
	ground.position = Vector2(0, GROUND_Y)
	ground.size = Vector2(STAGE.x, 2)
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ground)

	_knight = _actor("Knight", false)
	_slime = _actor("Slime", true)
	_loop()


func _actor(sprite_id: String, face_left: bool) -> AnimatedPortrait:
	var a: AnimatedPortrait = AnimatedPortrait.new()
	a.mouse_filter = Control.MOUSE_FILTER_IGNORE
	a.size = Vector2(BOX, BOX)
	a.flip_h = face_left
	a.load_sprite_id(sprite_id)
	a.set_zoom(ZOOM)
	add_child(a)
	return a


func _loop() -> void:
	var top: float = GROUND_Y - FEET_IN_BOX
	var meet: float = STAGE.x / 2.0 - BOX / 2.0 - REACH / 2.0
	_knight.position = Vector2(-BOX, top)
	_slime.position = Vector2(STAGE.x, top)
	_slime.modulate.a = 1.0
	_knight.play("walk")
	_slime.play("walk")

	# Both walk in and meet in the middle.
	var t: Tween = create_tween().set_parallel()
	t.tween_property(_knight, "position:x", meet, WALK_TIME)
	t.tween_property(_slime, "position:x", meet + REACH, WALK_TIME)
	await t.finished

	# One swing. The blow lands a few frames in, which is when the slime flinches.
	_slime.play("idle")
	_knight.play_once(ATTACKS[_round % ATTACKS.size()])
	_round += 1
	t = create_tween()
	t.tween_interval(0.4)
	await t.finished
	Sfx.play("hit")
	_slime.play_once("hurt")
	t = create_tween()
	t.tween_property(_slime, "position:x", meet + REACH + 14.0, 0.15) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	t.tween_interval(0.35)
	await t.finished

	# Down it goes, and away.
	_slime.play_once("death")
	t = create_tween()
	t.tween_interval(0.5)
	t.tween_property(_slime, "modulate:a", 0.0, 0.5)
	await t.finished

	# A breath, then on through where it stood and off the far side.
	_knight.play("idle")
	t = create_tween()
	t.tween_interval(0.6)
	await t.finished
	_knight.play("walk")
	t = create_tween()
	t.tween_property(_knight, "position:x", STAGE.x + 10.0, WALK_TIME)
	t.tween_interval(1.2)
	await t.finished
	_loop()
