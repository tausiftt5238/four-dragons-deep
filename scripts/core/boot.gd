# Boot
# The one autoload. It runs before the first scene, so whatever must be true
# from the very first frame is set here:
#
#   - the controls (Controls): the title is driven by the same yes and no as
#     the rest of the game, keyboard or pad;
#   - on the PC build, the window (Settings.apply_window): fullscreen by
#     default, or a window that fits the screen it is on. A fixed 1920x1080
#     window ran off a Steam Deck's 1280x800 screen with the title's buttons
#     out of sight.
#
# It also stays for F11 and Alt+Enter, which switch fullscreen on and off on
# any screen of the PC build.
extends Node


func _ready() -> void:
	Controls.ensure()
	# A test or a tool run (--script) keeps the window it was given.
	if Build.steam() and not "--script" in OS.get_cmdline_args():
		# Once the window is up: asked for before then, the mode is lost.
		await get_tree().process_frame
		await get_tree().process_frame
		Settings.apply_window()


func _unhandled_input(event: InputEvent) -> void:
	if not Build.steam() or not (event is InputEventKey and event.pressed and not event.echo):
		return
	var k: InputEventKey = event as InputEventKey
	if k.keycode == KEY_F11 or (k.keycode == KEY_ENTER and k.alt_pressed):
		get_viewport().set_input_as_handled()
		Settings.set_fullscreen(not Settings.fullscreen())
