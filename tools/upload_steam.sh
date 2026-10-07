#!/usr/bin/env bash
# Upload the PC game to Steam with SteamPipe: the Windows and Linux builds
# from tools/export_steam.sh, one depot each.
#
#   tools/upload_steam.sh preview     check what would upload, upload nothing
#   tools/upload_steam.sh             upload a new build
#
# The IDs come from tools/steam_ids.cfg (Steamworks gives you the app ID; the
# depots are made under SteamPipe > Depots, usually app ID + 1 and + 2). The
# build lands on Steamworks under Builds, live on no branch: set it live there,
# by hand, once it has been checked.
#
# Needs steamcmd. On Ubuntu: `sudo add-apt-repository multiverse && sudo apt
# install steamcmd`, or Valve's tarball from the Steamworks docs. It asks for
# your Steam password and Steam Guard code the first time, then remembers the
# login; run it in your own terminal, not through Claude, so it can ask.
#
# Launch options (Steamworks > Installation > General) to go with it:
#   Windows: four-dragons-deep.exe
#   Linux:   four-dragons-deep.x86_64
set -euo pipefail
cd "$(dirname "$0")/.."

source tools/steam_ids.cfg
: "${APP_ID:?set APP_ID in tools/steam_ids.cfg}"
: "${DEPOT_WINDOWS:?set DEPOT_WINDOWS in tools/steam_ids.cfg}"
: "${DEPOT_LINUX:?set DEPOT_LINUX in tools/steam_ids.cfg}"
: "${STEAM_USER:?set STEAM_USER in tools/steam_ids.cfg}"
STEAMCMD="${STEAMCMD:-$(command -v steamcmd || true)}"
[ -n "$STEAMCMD" ] || { echo "steamcmd not found (see the header of this script)" >&2; exit 1; }

PREVIEW=0
[ "${1:-}" = preview ] && PREVIEW=1

for f in build/steam/windows/four-dragons-deep.exe build/steam/linux/four-dragons-deep.x86_64; do
	[ -f "$f" ] || { echo "no $f: run tools/export_steam.sh first" >&2; exit 1; }
done

ROOT="$(pwd)/build/steam"
# steamcmd splits its command line on spaces, and this checkout's path has one
# ("game project"), so the build scripts it is pointed at live somewhere that
# has none. The paths inside them are quoted and can keep theirs.
SCRIPTS="${XDG_CACHE_HOME:-$HOME/.cache}/four-dragons-deep-steampipe"
mkdir -p "$SCRIPTS" "$ROOT/output"
DESC="$(git describe --always --dirty) $(date +%Y-%m-%d)"

depot() {   # depot id, folder under build/steam
	cat > "$SCRIPTS/depot_$1.vdf" <<EOF
"DepotBuild"
{
	"DepotID" "$1"
	"ContentRoot" "$ROOT/$2"
	"FileMapping"
	{
		"LocalPath" "*"
		"DepotPath" "."
		"Recursive" "1"
	}
}
EOF
}
depot "$DEPOT_WINDOWS" windows
depot "$DEPOT_LINUX" linux

cat > "$SCRIPTS/app_build.vdf" <<EOF
"AppBuild"
{
	"AppID" "$APP_ID"
	"Desc" "$DESC"
	"Preview" "$PREVIEW"
	"BuildOutput" "$ROOT/output"
	"Depots"
	{
		"$DEPOT_WINDOWS" "$SCRIPTS/depot_$DEPOT_WINDOWS.vdf"
		"$DEPOT_LINUX" "$SCRIPTS/depot_$DEPOT_LINUX.vdf"
	}
}
EOF

echo "uploading \"$DESC\" to app $APP_ID (preview=$PREVIEW)"
"$STEAMCMD" +login "$STEAM_USER" +run_app_build "$SCRIPTS/app_build.vdf" +quit
