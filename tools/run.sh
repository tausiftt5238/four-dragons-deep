#!/usr/bin/env bash
# Run either build from the project without exporting it.
#
#   tools/run.sh portable [godot args...]   the phone build (the default)
#   tools/run.sh steam    [godot args...]   the PC build
#
# Anything after the variant goes to Godot, so a test script runs as
#   tools/run.sh steam --resolution 1920x1080 --script tools/_shot.gd
#
# An exported build takes its variant from the "steam" feature tag on its
# preset (project.godot's *.steam overrides). Outside an export there is no
# tag, so for the PC build this writes the same values to override.cfg, which
# Godot reads at start-up, and takes it away again afterwards.
set -euo pipefail
cd "$(dirname "$0")/.."

GODOT="${GODOT:-$HOME/apps/Godot_v4.6.2-stable_linux.x86_64}"
VARIANT="${1:-portable}"
shift || true

rm -f override.cfg
case "$VARIANT" in
	portable) ;;
	steam)
		trap 'rm -f override.cfg' EXIT
		cat > override.cfg <<'CFG'
[application]
config/name="Four Dragons Deep"

[display]
window/size/viewport_width=960
window/size/viewport_height=540
window/size/window_width_override=1920
window/size/window_height_override=1080
window/stretch/aspect="expand"

[game]
build/variant="steam"
CFG
		;;
	*) echo "usage: tools/run.sh portable|steam [godot args...]" >&2; exit 2 ;;
esac

"$GODOT" --path . "$@"
