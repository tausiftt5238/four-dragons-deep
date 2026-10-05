# Layout
# Which way up the screen is, and where things go because of it. The phone
# build is portrait (540x1170): the floor map in a band across the top, the
# dungeon and everything you act on below it, where a thumb is. The Steam build
# is landscape (a 960x540 canvas, scaled to the window): the dungeon fills the
# left and the map stands down the right.
#
# Read off the viewport rather than a build flag, so one codebase lays out
# either way and a gameplay change made for one build merges into the other.
class_name Layout

# Portrait: how tall the map band across the top is.
const MAP_PANE_H: int = 520
# Landscape: how wide the map column down the right is.
const MAP_PANE_W: int = 380


static func landscape() -> bool:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return false
	var s: Vector2 = tree.root.get_visible_rect().size
	return s.x > s.y


# Where the part of the screen you act in begins, from the top: under the map
# when it is upright, the top of the screen when it is on its side.
static func lower_top() -> float:
	return 0.0 if landscape() else float(MAP_PANE_H)


# How wide a centred panel may be, so one written for a 540-wide phone does not
# stretch across a wide screen.
const PANEL_W: float = 560.0


# Narrows a full-width Control to PANEL_W around the middle when the screen is
# wide; leaves it alone on a phone.
static func centre_column(c: Control) -> void:
	if not landscape():
		return
	c.anchor_left = 0.5
	c.anchor_right = 0.5
	c.offset_left = -PANEL_W / 2.0
	c.offset_right = PANEL_W / 2.0
