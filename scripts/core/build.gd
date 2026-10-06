# Build
# Which game this is. One codebase makes two:
#
#   - Four Dragons Deep Portable (the default): the phone build, upright, for
#     Android and the web.
#   - Four Dragons Deep (the "steam" feature tag on an export preset): the PC
#     build, on its side, for a mouse, a keyboard or a pad.
#
# The variant is a project setting, game/build/variant, which the steam tag
# overrides in project.godot along with the canvas, the window and the name.
# To run the PC build from the editor or the command line without exporting,
# use tools/run.sh steam.
class_name Build


# With the override: a plain get_setting() would ignore the steam tag.
static func variant() -> String:
	return str(ProjectSettings.get_setting_with_override("game/build/variant"))


static func steam() -> bool:
	return variant() == "steam"


static func portable() -> bool:
	return not steam()


# The browser build of Portable, which leaves the Abyss out (Abyss.in_build).
static func web() -> bool:
	return OS.has_feature("web")
