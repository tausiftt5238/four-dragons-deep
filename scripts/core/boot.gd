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
#
# An exported debug build (tools/export_steam.sh debug) also puts a line of
# diagnostics in the corner: the window, the screen, the pads it can see and
# the last few inputs, for finding out what a machine like a Steam Deck is
# actually sending.
extends Node

var _diag: Label
var _seen: Array[String] = []


func _ready() -> void:
	Controls.ensure()
	if OS.is_debug_build() and OS.has_feature("template"):
		_start_diagnostics()
	# A test or a tool run (--script) keeps the window it was given, and so
	# does a browser: the page sizes the canvas, and fullscreen there needs a
	# click first (Options has it).
	if Build.steam() and not Build.web() and not "--script" in OS.get_cmdline_args():
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


func _input(event: InputEvent) -> void:
	if _diag == null or event is InputEventMouseMotion or event is InputEventJoypadMotion \
			and absf((event as InputEventJoypadMotion).axis_value) < 0.5:
		return
	var what: String = event.as_text()
	if event is InputEventScreenTouch:
		what = "touch %s at %s" % ["down" if event.pressed else "up", (event as InputEventScreenTouch).position]
	elif event is InputEventMouseButton:
		what = "mouse %d %s at %s" % [(event as InputEventMouseButton).button_index,
				"down" if event.pressed else "up", (event as InputEventMouseButton).position]
	elif event is InputEventJoypadButton:
		what = "pad %d button %d %s" % [event.device, (event as InputEventJoypadButton).button_index,
				"down" if event.pressed else "up"]
	_seen.push_front(what)
	_seen.resize(mini(_seen.size(), 8))


func _start_diagnostics() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 128
	add_child(layer)
	_diag = Label.new()
	_diag.position = Vector2(6, 6)
	_diag.add_theme_font_size_override("font_size", 10)
	_diag.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
	_diag.add_theme_color_override("font_outline_color", Color.BLACK)
	_diag.add_theme_constant_override("outline_size", 4)
	_diag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_diag)
	var t: Timer = Timer.new()
	t.wait_time = 0.25
	t.autostart = true
	t.timeout.connect(_paint_diagnostics)
	add_child(t)


func _paint_diagnostics() -> void:
	var pads: Array[String] = []
	for id: int in Input.get_connected_joypads():
		pads.append("%d %s" % [id, Input.get_joy_name(id)])
	var focus: Control = get_viewport().gui_get_focus_owner()
	_diag.text = "window %s mode %d at %s | screen %s scale %.2f | canvas %s\n" % [
			DisplayServer.window_get_size(), DisplayServer.window_get_mode(),
			DisplayServer.window_get_position(), DisplayServer.screen_get_size(),
			DisplayServer.screen_get_scale(), get_viewport().get_visible_rect().size] \
		+ "focused window %s | focus %s | pads: %s\n" % [
			DisplayServer.window_is_focused(), focus.name if focus != null else "none",
			", ".join(pads) if not pads.is_empty() else "none"] \
		+ "\n".join(_seen)
