# Layout
# Where the exploring screen's map goes in each build (Build): a band across
# the top of the phone, a column down the side of the PC screen.
class_name Layout

# Portable: how tall the map band across the top is.
const MAP_PANE_H: int = 520
# Steam: how wide the map column is.
const MAP_PANE_W: int = 380


# The part of the screen an overlay (level up, a fight's result, a chest, the
# save slots, game over) belongs in: under the map band on a phone, over the
# dungeon view beside the map column on a wide screen. `c` is full-rect.
static func lower_pane(c: Control) -> void:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if Build.steam():
		c.offset_left = MAP_PANE_W
	else:
		c.offset_top = MAP_PANE_H


# An overlay's panel in the fight's window style on a wide screen; the phone
# keeps the theme's own.
static func dress(panel: Control) -> void:
	if Build.steam():
		panel.add_theme_stylebox_override("panel", ExploreHUD.window_box())


# On a wide screen, played on a keyboard or a pad, a screen that comes up gives
# its first button the focus, so yes presses it without a mouse. A layer calls
# this for each screen it is handed (Main.overlay_layer and the like).
static func focus_first(screen: Node) -> void:
	if not Build.steam() or not is_instance_valid(screen):
		return
	var first: Control = SidePanel._first_focusable(screen)
	if first != null:
		first.grab_focus()


# Makes `layer` focus each screen as it arrives (focus_first), a frame after,
# once the screen has built itself.
static func focus_arrivals(layer: CanvasLayer) -> void:
	if Build.steam():
		layer.child_entered_tree.connect(func(n: Node) -> void: focus_first.call_deferred(n))
