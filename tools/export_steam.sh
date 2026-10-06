#!/usr/bin/env bash
# Build the PC game (the Steam build: Build.steam) for Linux and Windows, from
# the "Linux" and "Windows Desktop" export presets, which carry the "steam"
# feature tag.
#
#   tools/export_steam.sh                 both, into build/steam/
#   tools/export_steam.sh linux           one of them
#   tools/export_steam.sh windows
#
# Each lands in its own folder (build/steam/linux/, build/steam/windows/), as
# a Steam depot wants it: the game binary and its .pck side by side.
#
# The repository alone holds placeholder art and no music, so this refuses to
# build unless the real art and the music are in place. Override the Godot
# binary with $GODOT.
set -euo pipefail
cd "$(dirname "$0")/.."

GODOT="${GODOT:-$HOME/apps/Godot_v4.6.2-stable_linux.x86_64}"
WHICH="${1:-all}"

tools/real_art.sh status | grep -q "REAL ART" || { echo "real enemy art is not in place (tools/real_art.sh on)" >&2; exit 1; }
[ "$(ls resources/music/*.ogg 2>/dev/null | wc -l)" -gt 0 ] || { echo "no music in resources/music/" >&2; exit 1; }
rm -f override.cfg   # a dev run's leftover would ride into the export

build() {
	local preset="$1" out="$2"
	local dir; dir="$(dirname "$out")"
	rm -rf "$dir"
	mkdir -p "$dir"
	"$GODOT" --headless --export-release "$preset" "$out" 2>&1 \
		| grep -vE '^(ADDING|COPYING):|^\s*$|cannot connect to daemon' || true
	[ -f "$out" ] || { echo "export failed: no $out" >&2; exit 1; }
	echo "built $dir ($(du -sh "$dir" | cut -f1))"
}

case "$WHICH" in
	all|linux)   build "Linux" build/steam/linux/four-dragons-deep.x86_64 ;;&
	all|windows) build "Windows Desktop" build/steam/windows/four-dragons-deep.exe ;;
	linux) ;;
	*) echo "usage: tools/export_steam.sh [linux|windows]" >&2; exit 2 ;;
esac
