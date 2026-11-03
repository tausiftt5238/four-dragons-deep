# InputDedupe
# One press, one action, however many ways it arrives.
#
# A Steam Deck in desktop mode hands the game every press twice: the pad
# itself, and the keys Steam's desktop layout turns it into (the d-pad into
# arrow keys, A into Enter, B into Escape), which are keys the game always
# listens to (Controls.FIXED). A second copy of the pad can turn up the same
# way. Each copy walked a step or chose a line of its own.
#
# So the same action pressed again from a different source within WINDOW of
# the first is dropped before anything else sees it. The same source is never
# dropped: hammering A is as many presses as it looks. Held repeats and
# releases go through, and so does a stick, which main reads as it moves.
#
# Godot hands input out last node first, so this sits at the end of the root
# and moves back there whenever a scene arrives after it (Boot does that).
extends Node

const WINDOW: float = 0.08

# Action -> [source, time] of the last press that went through.
var _last: Dictionary = {}


func _input(event: InputEvent) -> void:
	var source: String = _source_of(event)
	if source == "":
		Controls.note(event)
		return
	if not event.is_pressed() or event.is_echo():
		Controls.note(event)
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	var twin: bool = false
	var actions: Array[String] = _actions_of(event)
	for action: String in actions:
		var seen: Variant = _last.get(action)
		if seen != null and (seen as Array)[0] != source \
				and now - float((seen as Array)[1]) < WINDOW:
			twin = true
			# A pad was in it, so the hand is on a pad, whichever copy was first.
			if source.begins_with("pad") or str((seen as Array)[0]).begins_with("pad"):
				Controls.using_pad = true
	if twin:
		get_viewport().set_input_as_handled()
		return
	Controls.note(event)
	for action: String in actions:
		_last[action] = [source, now]


# "key", or "pad" and which pad; "" for anything this leaves alone.
func _source_of(event: InputEvent) -> String:
	if event is InputEventKey:
		return "key"
	if event is InputEventJoypadButton:
		return "pad%d" % event.device
	return ""


# The game's own actions (Controls) and the menus' ui_ ones it drives, as one
# name each, so Enter's ui_accept and A's yes count as the same press.
func _actions_of(event: InputEvent) -> Array[String]:
	var out: Array[String] = []
	for a: Array in Controls.ACTIONS:
		var id: String = a[0] as String
		var ui: String = Controls.UI.get(id, "") as String
		if event.is_action(id) or (ui != "" and event.is_action(ui)):
			out.append(id)
	return out
