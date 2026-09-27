#!/usr/bin/env python3
"""Silhouette the commercial characterSprite art so only silhouettes reach git.

The real sprites live in the working tree and in art-private/characterSprites/
(gitignored). Git is wired up by tools/install_git_hooks.sh:

    --filter PATH   clean filter: PNG on stdin -> silhouette on stdout. A real
                    (non-silhouette) input is also saved to art-private/ first,
                    so new or edited art is never lost.
    --check PATH..  exit 1 if any staged blob for PATH is not a silhouette
                    (pre-commit safety net, in case the filter isn't set up).

Manual use:
    python3 tools/silhouette_sprites.py            # silhouette the working tree
    python3 tools/silhouette_sprites.py file.png   # silhouette specific files
"""
import io, os, subprocess, sys
from PIL import Image

PROJECT = os.path.normpath(os.path.join(os.path.dirname(__file__), ".."))
SPRITE_DIR = os.path.join(PROJECT, "resources", "characterSprites")
BACKUP_DIR = os.path.join(PROJECT, "art-private", "characterSprites")
SILHOUETTE_COLOR = (40, 40, 50)


def to_silhouette(data: bytes) -> bytes:
    img = Image.open(io.BytesIO(data)).convert("RGBA")
    img.putdata([(*SILHOUETTE_COLOR, a) if a > 0 else (r, g, b, a)
                 for r, g, b, a in img.getdata()])
    out = io.BytesIO()
    img.save(out, "PNG")
    return out.getvalue()


def is_silhouette(data: bytes) -> bool:
    img = Image.open(io.BytesIO(data)).convert("RGBA")
    return all(p[:3] == SILHOUETTE_COLOR for p in img.getdata() if p[3] > 0)


def backup_path(path: str) -> str:
    rel = os.path.relpath(os.path.join(PROJECT, path), SPRITE_DIR)
    return os.path.join(BACKUP_DIR, rel)


def backup(path: str, data: bytes) -> None:
    dst = backup_path(path)
    if os.path.exists(dst) and open(dst, "rb").read() == data:
        return
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    with open(dst, "wb") as f:
        f.write(data)


def run_filter(path: str) -> None:
    data = sys.stdin.buffer.read()
    if not is_silhouette(data):
        backup(path, data)
    sys.stdout.buffer.write(to_silhouette(data))


def run_check(paths: list[str]) -> int:
    bad = []
    for p in paths:
        data = subprocess.run(["git", "show", f":{p}"], cwd=PROJECT,
                              capture_output=True, check=True).stdout
        if not is_silhouette(data):
            bad.append(p)
    for p in bad:
        print(f"  real art staged: {p}", file=sys.stderr)
    return 1 if bad else 0


def silhouette_file(path: str) -> None:
    data = open(path, "rb").read()
    if not is_silhouette(data):
        backup(os.path.relpath(path, PROJECT), data)
    with open(path, "wb") as f:
        f.write(to_silhouette(data))


def main() -> int:
    args = sys.argv[1:]
    if args[:1] == ["--filter"]:
        run_filter(args[1])
        return 0
    if args[:1] == ["--check"]:
        return run_check(args[1:])
    if args:
        files = [f for f in args if f.endswith(".png") and os.path.isfile(f)]
    else:
        files = [os.path.join(r, f) for r, _, fs in os.walk(SPRITE_DIR)
                 for f in fs if f.endswith(".png")]
    for f in files:
        silhouette_file(f)
    print(f"Replaced {len(files)} sprites with silhouettes (originals in art-private/characterSprites/)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
