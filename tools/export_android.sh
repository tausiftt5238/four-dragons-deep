#!/usr/bin/env bash
# Build a sideloadable Android APK from the "Android APK" export preset.
# (The "Android" preset is the Google Play AAB build; see docs/releasing-android.md.)
#
#   tools/export_android.sh            debug APK, signed with the editor's debug keystore
#   tools/export_android.sh install    same, then install it on the phone over adb
#
# Needs the Android SDK and JDK paths set in the Godot editor settings
# (Editor > Editor Settings > Export > Android) and the 4.6.2 export templates.
# Override the Godot binary with $GODOT.
set -euo pipefail
cd "$(dirname "$0")/.."

GODOT="${GODOT:-$HOME/apps/Godot_v4.6.2-stable_linux.x86_64}"
OUT=build/android/four-dragons-deep.apk

mkdir -p "$(dirname "$OUT")"
rm -f "$OUT" "$OUT.idsig"   # so a failed export can't leave the old APK looking fresh
"$GODOT" --headless --export-debug "Android APK" "$OUT" 2>&1 | grep -vE '^(ADDING|COPYING):|^\s*$' || true
[ -f "$OUT" ] || { echo "export failed: no $OUT" >&2; exit 1; }
echo "built $OUT ($(du -h "$OUT" | cut -f1))"

if [ "${1:-}" = install ]; then
	"${ANDROID_HOME:-$HOME/Android/Sdk}/platform-tools/adb" install -r "$OUT"
fi
