#!/usr/bin/env python3
"""Copy the real sprites from art-private/characterSprites/ over the silhouettes.

Runs automatically from the post-checkout and post-merge hooks. Files that
already match are left alone, so Godot doesn't reimport them needlessly.
"""
import os, shutil, subprocess

PROJECT = os.path.normpath(os.path.join(os.path.dirname(__file__), ".."))
BACKUP_DIR = os.path.join(PROJECT, "art-private", "characterSprites")
SPRITE_DIR = os.path.join(PROJECT, "resources", "characterSprites")


def same(a: str, b: str) -> bool:
    return os.path.exists(b) and open(a, "rb").read() == open(b, "rb").read()


def main() -> None:
    if not os.path.isdir(BACKUP_DIR):
        print("No art-private/characterSprites/ found — nothing to restore.")
        return
    restored = []
    for root, _, files in os.walk(BACKUP_DIR):
        for f in files:
            if not f.endswith(".png"):
                continue
            backup = os.path.join(root, f)
            target = os.path.join(SPRITE_DIR, os.path.relpath(backup, BACKUP_DIR))
            # Only swap files git has checked out; a backup with no file here
            # belongs to another commit and would show up as untracked.
            if not os.path.exists(target) or same(backup, target):
                continue
            shutil.copy2(backup, target)
            restored.append(target)
    if restored:
        # Git sees a new file size and reports the sprite modified without
        # running the filter; re-adding refreshes the index to the same blob.
        subprocess.run(["git", "add", "--", *restored], cwd=PROJECT)
        print(f"Restored {len(restored)} real sprites from art-private/characterSprites/")


if __name__ == "__main__":
    main()
