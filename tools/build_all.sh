#!/usr/bin/env bash
# Build every version of the game in one go:
#
#   Steam    build/steam/linux/ and build/steam/windows/   (tools/export_steam.sh)
#   Web      build/web/, zipped to build/itch/four-dragons-deep_portable-web.zip
#   Android  build/android/four-dragons-deep_portable.apk, copied to build/itch/
#
#   tools/build_all.sh
#
# build/itch/ ends up holding exactly the two files the itch.io page takes.
# Stops at the first build that fails. Override the Godot binary with $GODOT.
set -euo pipefail
cd "$(dirname "$0")/.."

GODOT="${GODOT:-$HOME/apps/Godot_v4.6.2-stable_linux.x86_64}"
export GODOT

echo "== Steam (Linux, Windows)"
tools/export_steam.sh

echo "== Web"
rm -rf build/web
mkdir -p build/web build/itch
"$GODOT" --headless --export-release "Web" build/web/index.html 2>&1 \
	| grep -vE '^(ADDING|COPYING):|^\s*$|^\[|savepack|first_scan|update_scan' || true
[ -f build/web/index.pck ] || { echo "web export failed: no build/web/index.pck" >&2; exit 1; }
rm -f build/itch/four-dragons-deep_portable-web.zip
(cd build/web && zip -qr ../itch/four-dragons-deep_portable-web.zip .)
echo "built build/itch/four-dragons-deep_portable-web.zip ($(du -h build/itch/four-dragons-deep_portable-web.zip | cut -f1))"

echo "== Android APK"
tools/export_android.sh
cp build/android/four-dragons-deep_portable.apk build/itch/

echo "== Done, from $(git describe --always --dirty)"
ls -la build/steam/linux build/steam/windows build/itch
