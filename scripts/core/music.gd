# Music
# One looping track at a time, chosen by where the player is: the band's
# dungeon theme, a fight's theme, the orb, the slot machine. The tracks are a
# commercial pack kept out of the repository (resources/music/ is gitignored),
# so a clone without them must still run: a track whose file is missing is
# simply silence, and nothing else notices.
class_name Music

const DIR: String = "res://resources/music/"

const CAVE:    String = "underground_cave"
const TOWER:   String = "creepy_tower"
const FORT:    String = "demon_fort"
const BATTLE:  String = "battle"
const BATTLE2: String = "battle-two"
const WARDEN:  String = "engage_in_a_bloody_feud"
const DRAGON:  String = "the_battle_of_galfer"
const NECRO:   String = "demon_decisive_battle"
const ORB:     String = "calm_houses"
const CASINO:  String = "a_moment_at_the_casino"
const TITLE:   String = "overture"

const VOLUME_DB: float = -8.0
const FADE: float = 0.6

static var _player: AudioStreamPlayer
static var _current: String = ""
static var _tween: Tween


# The floor's own theme: the first two bands in the cave, the last two in the
# tower, the Abyss in the fort.
static func dungeon_track(floor_num: int) -> String:
	if Level.is_abyss(floor_num):
		return FORT
	return CAVE if Level.tier_of(floor_num) <= 2 else TOWER


# A fight's theme, read off who is in it.
static func battle_track(group: Array[Enemy], floor_num: int, warden: bool) -> String:
	for foe: Enemy in group:
		if foe.is_necromancer():
			return NECRO
		if foe.is_dragon():
			return DRAGON
	if warden:
		return WARDEN
	return BATTLE if Level.band_of(floor_num) <= 2 else BATTLE2


# Fades over to a track. Asking for the one already playing does nothing, so
# callers can ask freely rather than tracking what is on.
static func play(track: String) -> void:
	if track == _current:
		return
	_current = track
	var path: String = DIR + track + ".ogg"
	var stream: AudioStream = null
	if ResourceLoader.exists(path):
		stream = load(path) as AudioStream
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	var p: AudioStreamPlayer = _get_player()
	if p == null:
		return
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = (Engine.get_main_loop() as SceneTree).create_tween()
	if p.playing:
		_tween.tween_property(p, "volume_db", -40.0, FADE)
	_tween.tween_callback(func() -> void:
		p.stop()
		p.stream = stream
		if stream == null:
			return
		p.volume_db = -40.0
		p.play()
	)
	if stream != null:
		_tween.tween_property(p, "volume_db", VOLUME_DB, FADE)


static func stop() -> void:
	play("")


# Lives on the tree's root rather than in a scene, so a track carries on across
# a scene change instead of restarting.
static func _get_player() -> AudioStreamPlayer:
	if is_instance_valid(_player):
		return _player
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	_player = AudioStreamPlayer.new()
	_player.name = "Music"
	_player.volume_db = VOLUME_DB
	_player.bus = Settings.audio_bus(Settings.MUSIC_BUS)
	tree.root.add_child.call_deferred(_player)
	return _player
