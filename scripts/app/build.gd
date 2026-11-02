# Build
# Which game this is. One codebase makes two:
#
#   - Four Dragons Deep Portable (the default): the phone build, upright, for
#     Android.
#   - Four Dragons Deep (the "steam" feature tag on an export preset): the PC
#     build, on its side, for a mouse, a keyboard or a pad. Windows, Linux,
#     and the web, where it is the demo (Build.demo).
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


# The browser build: the PC game's demo (see demo), which leaves the Abyss out
# (Abyss.in_build).
static func web() -> bool:
	return OS.has_feature("web")


# The browser build is a demo of the PC game (its Web preset carries the steam
# feature, so it is the wide build): the first band, up to and including the Ice
# Dragon, and then the captain thanks the hero and points at the full game
# (Main._show_demo_end). `-- --demo` on the command line makes any build one,
# for trying it without a browser.
static func demo() -> bool:
	return web() or "--demo" in OS.get_cmdline_user_args()
