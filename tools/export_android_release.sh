#!/usr/bin/env bash
# Build the Google Play release: a signed AAB from the "Android" preset
# (Gradle build, arm64 + armv7, version and package as the preset says).
#
#   FDD_KEYSTORE_PASS=... tools/export_android_release.sh
#
# Signed with the upload key, ~/keys/fourdragonsdeep-upload.jks, alias
# "upload" (override with FDD_KEYSTORE / FDD_KEYSTORE_ALIAS). The password is
# read from FDD_KEYSTORE_PASS, or asked for if that is unset; it is handed to
# Godot through its own environment variables and written nowhere.
#
# The repository alone holds placeholder art and no music, so this refuses to
# build unless the real art and the music are in place: a store build of
# silhouettes and silence is never what was meant.
set -euo pipefail
cd "$(dirname "$0")/.."

GODOT="${GODOT:-$HOME/apps/Godot_v4.6.2-stable_linux.x86_64}"
KEYSTORE="${FDD_KEYSTORE:-$HOME/keys/fourdragonsdeep-upload.jks}"
ALIAS="${FDD_KEYSTORE_ALIAS:-upload}"
OUT=build/android/four-dragons-deep.aab

[ -f "$KEYSTORE" ] || { echo "no upload keystore at $KEYSTORE (see docs/releasing-android.md)" >&2; exit 1; }
tools/real_art.sh status | grep -q "REAL ART" || { echo "real enemy art is not in place (tools/real_art.sh on)" >&2; exit 1; }
[ "$(ls resources/music/*.ogg 2>/dev/null | wc -l)" -gt 0 ] || { echo "no music in resources/music/" >&2; exit 1; }

if [ -z "${FDD_KEYSTORE_PASS:-}" ]; then
	read -r -s -p "Upload keystore password: " FDD_KEYSTORE_PASS
	echo
fi

export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$KEYSTORE"
export GODOT_ANDROID_KEYSTORE_RELEASE_USER="$ALIAS"
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="$FDD_KEYSTORE_PASS"

mkdir -p "$(dirname "$OUT")"
rm -f "$OUT"
"$GODOT" --headless --export-release "Android" "$OUT" 2>&1 | grep -vE '^(ADDING|COPYING):|^\s*$' || true
[ -f "$OUT" ] || { echo "export failed: no $OUT" >&2; exit 1; }

# Confirm what came out is signed by the upload key and not the debug one.
if jarsigner -verify -certs "$OUT" 2>/dev/null | grep -q "Android Debug"; then
	echo "warning: $OUT is signed with the DEBUG key, not the upload key" >&2
	exit 1
fi
echo "built $OUT ($(du -h "$OUT" | cut -f1))"
grep -E "^version/(code|name)" export_presets.cfg | sed -n '/version/p' | head -4
