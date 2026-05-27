# CombatNegotiation
# Routes each Talk approach to its dedicated handler class.
# _active keeps a strong reference to the handler so GDScript's GC doesn't
# free it while its coroutines are still running between button presses.
class_name CombatNegotiation extends RefCounted

var _s
var _active


func _init(scene) -> void:
	_s = scene


func start(approach: String) -> void:
	match approach:
		"Reason":   _active = CombatNegReason.new(_s);   _active.start()
		"Bribe":    _active = CombatNegBribe.new(_s);    _active.start()
		"Threaten": _active = CombatNegThreaten.new(_s); _active.start()
		"Recruit":  _active = CombatNegRecruit.new(_s);  _active.start()
