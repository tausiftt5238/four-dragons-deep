#!/usr/bin/env bash
# One-time setup per clone: commit silhouettes, keep real sprites locally.
#
# - The "silhouette" clean filter (see .gitattributes) turns every
#   resources/characterSprites PNG into a silhouette as git stores it, so the
#   working tree keeps the real art and git status stays clean.
# - Hooks in tools/githooks: pre-commit blocks real art if the filter is
#   missing; post-checkout/merge/rewrite copy the real art back from
#   art-private/characterSprites/ after git writes silhouettes.
set -euo pipefail
cd "$(dirname "$0")/.."
git config filter.silhouette.clean 'python3 tools/silhouette_sprites.py --filter %f'
git config filter.silhouette.smudge cat
git config filter.silhouette.required true
git config core.hooksPath tools/githooks
chmod +x tools/githooks/*
python3 tools/restore_sprites.py
echo "silhouette filter and hooks installed"
