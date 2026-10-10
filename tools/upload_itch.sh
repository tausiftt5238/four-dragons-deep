#!/usr/bin/env bash
# Upload the itch.io builds with butler (itch's uploader), each to its own
# channel on the page: the browser demo, the Android APK, and the full PC game
# for Linux and Windows (the Steam builds, from build/steam/).
#
#   tools/upload_itch.sh             all four
#   tools/upload_itch.sh web         the browser demo only
#   tools/upload_itch.sh android     the APK only
#   tools/upload_itch.sh linux       the Linux build only
#   tools/upload_itch.sh windows     the Windows build only
#   tools/upload_itch.sh --dry-run   say what would go up, upload nothing
#
# Build first (tools/build_all.sh). butler sends only what changed since the
# last push to a channel, so a second upload is quick.
#
# One-time setup:
#   - butler is in ~/apps/butler, linked from ~/.local/bin/butler. To reinstall,
#     unzip https://broth.itch.zone/butler/linux-amd64/LATEST/archive/default there.
#   - `butler login` once, in your own terminal: it opens the browser to
#     authorise, and remembers the key in ~/.config/itch/butler_creds.
#   - After the first push to the "web" channel, open the upload on the itch.io
#     page's Edit screen and tick "This file will be played in the browser"
#     (docs/itch-description.md has the embed settings). itch remembers it for
#     later pushes to the same channel.
#
# The page is $ITCH_TARGET, user/game as in the page's address.
set -euo pipefail
cd "$(dirname "$0")/.."

TARGET="${ITCH_TARGET:-tausiftt5238/four-dragons-deep}"
BUTLER="${BUTLER:-$(command -v butler || echo "$HOME/apps/butler/butler")}"
[ -x "$BUTLER" ] || { echo "butler not found (see the header of this script)" >&2; exit 1; }

DRY=()
WHICH=all
for arg in "$@"; do
	case "$arg" in
		--dry-run) DRY=(--dry-run) ;;
		web|android|linux|windows|all) WHICH="$arg" ;;
		*) echo "usage: tools/upload_itch.sh [web|android|linux|windows] [--dry-run]" >&2; exit 2 ;;
	esac
done

VERSION="$(git describe --always --dirty)"

push() {   # what, channel
	[ -e "$1" ] || { echo "no $1: run tools/build_all.sh first" >&2; exit 1; }
	echo "== $1 -> $TARGET:$2 ($VERSION)"
	"$BUTLER" push "${DRY[@]}" --userversion "$VERSION" "$1" "$TARGET:$2"
}

case "$WHICH" in
	all|web)     push build/web web ;;&
	all|android) push build/android/four-dragons-deep_portable.apk android ;;&
	# itch reads the platform off the channel name, so these two come up as
	# Linux and Windows downloads with no setting on the page.
	all|linux)   push build/steam/linux linux ;;&
	all|windows) push build/steam/windows windows ;;
esac

[ ${#DRY[@]} -gt 0 ] || "$BUTLER" status "$TARGET"
