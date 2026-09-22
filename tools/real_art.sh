#!/usr/bin/env bash
# Swap the real enemy art in and out of the working tree.
#
# The real sprites are a commercial pack that must not be redistributed, so the
# repository holds generated placeholders at those paths instead. This script
# copies the real art over them for local work and marks the files
# skip-worktree, so git stops reporting them as modified and `git add -A` and
# `git commit -a` cannot pick them up. That flag is the safety catch: without
# it, one absent-minded `git commit -a` publishes the pack.
#
#   tools/real_art.sh on  [dir]   copy real art in and hide it from git
#   tools/real_art.sh off         unhide, and restore the placeholders
#   tools/real_art.sh status      show which mode the tree is in
#
# [dir] defaults to $FDD_REAL_ART, else ../first-person-dungeon-crawler/resources/enemySprites

set -euo pipefail
cd "$(dirname "$0")/.."
DEST="resources/enemySprites"
DEFAULT="${FDD_REAL_ART:-../first-person-dungeon-crawler/resources/enemySprites}"

files() { git ls-files "$DEST"/'*.png'; }

case "${1:-status}" in
  on)
    SRC="${2:-$DEFAULT}"
    [ -d "$SRC" ] || { echo "no such directory: $SRC" >&2; exit 1; }
    n=0
    while IFS= read -r f; do
      if [ -f "$SRC/$(basename "$f")" ]; then
        git update-index --skip-worktree "$f"
        cp "$SRC/$(basename "$f")" "$f"
        n=$((n + 1))
      else
        echo "  missing in source, left as placeholder: $(basename "$f")" >&2
      fi
    done < <(files)
    echo "real art in place for $n sprites; git is ignoring changes to them"
    ;;
  off)
    while IFS= read -r f; do git update-index --no-skip-worktree "$f"; done < <(files)
    git checkout -- "$DEST"
    echo "placeholders restored; git is tracking these files again"
    ;;
  status)
    hidden=$(git ls-files -v "$DEST" | grep -c '^S' || true)
    total=$(files | wc -l)
    if [ "$hidden" -gt 0 ]; then
      echo "REAL ART: $hidden/$total sprites hidden from git"
    else
      echo "PLACEHOLDERS: all $total sprites tracked normally"
    fi
    ;;
  *) echo "usage: tools/real_art.sh {on [dir]|off|status}" >&2; exit 1 ;;
esac
