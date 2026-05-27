# MenuTabs
# Routes tab selection to the appropriate tab builder class.
class_name MenuTabs extends RefCounted

var _m


func _init(menu) -> void:
	_m = menu


func build_stats() -> void:     MenuTabStats.new(_m).build()
func build_items() -> void:     MenuTabItems.new(_m).build()
func build_equipment() -> void: MenuTabEquipment.new(_m).build()
func build_magic() -> void:     MenuTabMagic.new(_m).build()
func build_bestiary() -> void:  MenuTabBestiary.new(_m).build()
