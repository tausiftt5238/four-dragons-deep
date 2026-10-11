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
# Each build is also zipped on its own into $DRIVE_DIR (~/four-dragons-deep-builds
# by default), ready for `drive-push` to send up to Google Drive. The zips keep
# the same names each time, so a new build replaces the last.
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

echo "== Zips for Drive"
DRIVE_DIR="${DRIVE_DIR:-$HOME/four-dragons-deep-builds}"
mkdir -p "$DRIVE_DIR"
drive_zip() {   # name, folder or file
	rm -f "$DRIVE_DIR/$1.zip"
	if [ -d "$2" ]; then
		(cd "$2" && zip -qr "$DRIVE_DIR/$1.zip" .)
	else
		zip -qj "$DRIVE_DIR/$1.zip" "$2"
	fi
	echo "zipped $DRIVE_DIR/$1.zip ($(du -h "$DRIVE_DIR/$1.zip" | cut -f1))"
}
drive_zip four-dragons-deep-linux build/steam/linux
drive_zip four-dragons-deep-windows build/steam/windows
drive_zip four-dragons-deep-web build/web
drive_zip four-dragons-deep-android build/android/four-dragons-deep_portable.apk

echo "== Done, from $(git describe --always --dirty)"
ls -la build/steam/linux build/steam/windows build/itch
