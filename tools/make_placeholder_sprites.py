#!/usr/bin/env python3
"""Draw the stand-in enemy sprites.

The real enemy art is a commercial pack and is not redistributable, so it is
kept out of this repository entirely — out of the working tree and out of the
history. What ships here instead is a set of generated silhouettes at exactly
the right filenames and pixel dimensions, so a fresh clone imports, boots and
plays with every enemy visible and obviously a placeholder.

Run from the repo root:

    python3 tools/make_placeholder_sprites.py

It overwrites everything in resources/enemySprites/, so do not run it while the
real art is copied in — see `tools/real_art.sh`.
"""

import colorsys
import hashlib
import os

from PIL import Image, ImageDraw

OUT = "resources/enemySprites"

# name -> (width, height). These are the dimensions the real pack uses; the
# placeholders have to match or the billboards change size on screen.
SPRITES = {
    "AnimatedPlant": (48, 48), "AnimatedPlantB": (48, 48),
    "Bandit": (48, 64), "BanditB": (48, 64),
    "BarrowWight": (54, 64),
    "Bat": (55, 32), "BatB": (55, 32),
    "BoneSorcerer": (48, 74),
    "Fairy": (48, 64), "FairyB": (48, 64),
    "FireDragon": (64, 64),
    "Gargoyle": (64, 64),
    "GelatinousCube": (48, 48), "GelatinousCubeB": (48, 48),
    "GiantHornet": (48, 48), "GiantHornetB": (48, 48),
    "GiantRat": (64, 48), "GiantRatB": (64, 48),
    "Goblin": (48, 48), "GoblinB": (48, 48),
    "IceDragon": (64, 64),
    "Mimic": (48, 48),
    "Ogre": (64, 64), "OgreB": (64, 64),
    "Orc": (52, 64), "OrcB": (52, 64),
    "ShadowKnight": (52, 64),
    "Skeleton": (54, 64), "SkeletonB": (54, 64),
    "Slug": (48, 32), "SlugB": (48, 32),
    "ThunderDragon": (64, 64),
    "Treant": (48, 64), "TreantB": (48, 64),
    "VoidDragon": (64, 64),
    "WildBoar": (48, 56), "WildBoarB": (48, 56),
    "Wizard": (48, 74), "WizardB": (48, 74),
}


def hue_for(name: str) -> float:
    """A stable hue per creature. A `B` variant sits a little off its base, the
    way a palette swap does, so the pair reads as related rather than random."""
    base = name[:-1] if name.endswith("B") and name[:-1] in SPRITES else name
    h = int(hashlib.md5(base.encode()).hexdigest()[:8], 16) / 0xFFFFFFFF
    if name != base:
        h = (h + 0.08) % 1.0
    return h


def shade(hue: float, sat: float, val: float) -> tuple:
    r, g, b = colorsys.hsv_to_rgb(hue, sat, val)
    return (int(r * 255), int(g * 255), int(b * 255), 255)


def draw(name: str, w: int, h: int) -> Image.Image:
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    hue = hue_for(name)
    fill, edge = shade(hue, 0.45, 0.72), shade(hue, 0.55, 0.38)

    pad = max(2, w // 12)
    wide = w > h  # bats, rats and slugs are wider than they are tall

    if wide:
        # One squat body, no head — a head on a wide sprite reads as a mistake.
        d.ellipse([pad, pad, w - pad - 1, h - pad - 1], fill=fill, outline=edge)
        eye_y = h // 2 - max(1, h // 12)
    else:
        head_r = max(3, w // 5)
        head_cx, head_cy = w // 2, pad + head_r
        # Body first, so the head overlaps it rather than floating above.
        d.ellipse([pad, head_cy, w - pad - 1, h - pad - 1], fill=fill, outline=edge)
        d.ellipse([head_cx - head_r, head_cy - head_r,
                   head_cx + head_r, head_cy + head_r], fill=fill, outline=edge)
        eye_y = head_cy - max(1, head_r // 4)

    # Two eyes, so it is legible as a creature at the size it is drawn on screen.
    eye_r = max(1, w // 24)
    for dx in (-max(2, w // 8), max(2, w // 8)):
        cx = w // 2 + dx
        d.ellipse([cx - eye_r, eye_y - eye_r, cx + eye_r, eye_y + eye_r],
                  fill=(20, 18, 24, 255))

    # A ground shadow anchors it; without one the billboard looks like it hovers.
    sw = w // 3
    d.ellipse([w // 2 - sw, h - max(2, h // 14), w // 2 + sw, h - 1],
              fill=(0, 0, 0, 70))
    return img


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    for name, (w, h) in sorted(SPRITES.items()):
        draw(name, w, h).save(os.path.join(OUT, name + ".png"))
    print(f"wrote {len(SPRITES)} placeholder sprites to {OUT}/")


if __name__ == "__main__":
    main()
