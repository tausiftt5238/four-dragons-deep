# TouchScroll
# A ScrollContainer that a finger can drag from anywhere in it.
#
# Godot only scrolls on a drag the container itself receives. A Button stops
# the touch by default (MOUSE_FILTER_STOP), so a drag that began on one, which
# in a list of rows is most of them, went to the button and the list never
# moved: scrolling worked only from the gaps and the text. Here every control
# put inside is switched to MOUSE_FILTER_PASS, which still lets a tap press the
# button but hands the drag up to the container. Once the drag passes the
# deadzone the container tells its children scrolling began, and a button
# drops the press it was holding, so a scroll never buys anything.
class_name TouchScroll extends ScrollContainer


func _ready() -> void:
	for n: Node in find_children("*", "Control", true, false):
		_pass_through(n)
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(n: Node) -> void:
	if is_ancestor_of(n):
		_pass_through(n)


func _pass_through(n: Node) -> void:
	var c: Control = n as Control
	if c != null and c.mouse_filter == Control.MOUSE_FILTER_STOP:
		c.mouse_filter = Control.MOUSE_FILTER_PASS
