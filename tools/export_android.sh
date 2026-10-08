#!/usr/bin/env bash
# Build a sideloadable Android APK from the "Android APK" export preset.
# (The "Android" preset is the Google Play AAB build; see docs/releasing-android.md.)
#
#   tools/export_android.sh            APK, signed with the editor's debug keystore
#   tools/export_android.sh install    same, then install it on the phone over adb
#
# Needs the Android SDK and JDK paths set in the Godot editor settings
# (Editor > Editor Settings > Export > Android) and the 4.6.2 export templates.
# Override the Godot binary with $GODOT.
set -euo pipefail
cd "$(dirname "$0")/.."

GODOT="${GODOT:-$HOME/apps/Godot_v4.6.2-stable_linux.x86_64}"
OUT=build/android/four-dragons-deep_portable.apk

mkdir -p "$(dirname "$OUT")"
rm -f "$OUT" "$OUT.idsig"   # so a failed export can't leave the old APK looking fresh
# A release export, so players get no debug keys (Q, N) and no diagnostics in
# the corner, signed with the editor's debug keystore as the debug exports
# were: the same key means it installs over an old copy and keeps its saves.
# The game is not on Google Play, which is the only thing that would need a
# real release key.
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="${GODOT_ANDROID_KEYSTORE_RELEASE_PATH:-$HOME/.local/share/godot/keystores/debug.keystore}"
export GODOT_ANDROID_KEYSTORE_RELEASE_USER="${GODOT_ANDROID_KEYSTORE_RELEASE_USER:-androiddebugkey}"
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="${GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD:-android}"
"$GODOT" --headless --export-release "Android APK" "$OUT" 2>&1 | grep -vE '^(ADDING|COPYING):|^\s*$' || true
[ -f "$OUT" ] || { echo "export failed: no $OUT" >&2; exit 1; }
echo "built $OUT ($(du -h "$OUT" | cut -f1))"

if [ "${1:-}" = install ]; then
	"${ANDROID_HOME:-$HOME/Android/Sdk}/platform-tools/adb" install -r "$OUT"
fi
