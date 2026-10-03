#!/usr/bin/env python3
"""Draws the app icon: a stone corridor running into the dark, and a pair of
eyes waiting at the end of it.

The corridor is the game itself: tools/icon_render.gd builds a straight run in
the dungeon's stone shader, with its wire lines, torchlight and field of view,
and renders it to .godot/icon_corridor.png. This script puts the eyes on it
and cuts every size Android and the store want. Render first, then run this:

    xvfb-run -a godot --path . --rendering-driver opengl3 --script tools/icon_render.gd
    python3 tools/make_icons.py

Writes, from the repo root:
  icon.png                          512  project / web / store icon
  resources/app_icon/icon_192.png   192  Android launcher (legacy)
  resources/app_icon/fg_432.png     432  adaptive foreground: the eyes alone
  resources/app_icon/bg_432.png     432  adaptive background: the corridor
  resources/app_icon/mono_432.png   432  adaptive monochrome: the eyes, white

Adaptive icons are masked to a circle, squircle or the like, and only the
middle 264 of 432 pixels is sure to be seen, so the eyes sit well inside that.
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RENDER = os.path.join(ROOT, ".godot/icon_corridor.png")
OUT = os.path.join(ROOT, "resources/app_icon")

PIXEL = 3            # the eyes are drawn at this chunkiness, to match the stone
EYE = (255, 70, 30)


def corridor(size: int) -> Image.Image:
    if not os.path.exists(RENDER):
        sys.exit("No %s: run tools/icon_render.gd first (see the top of this file)." % RENDER)
    return Image.open(RENDER).convert("RGB").resize((size, size), Image.NEAREST)


def eyes(size: int, color, glow: bool) -> Image.Image:
    """Two slanted slits a little above the centre, with an optional glow."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # On the vanishing point: the camera is at the walls' mid-height.
    cx, cy = size / 2.0, size * 0.5
    # Small enough that both sit inside the dark doorway at the far end.
    gap = size * 0.05
    w, h = size * 0.038, size * 0.015
    for side in (-1, 1):
        ex = cx + side * gap
        # A slit that tips down toward the nose: the look of something angry.
        pts = [
            (ex - w, cy - h * (0.2 if side < 0 else 1.6)),
            (ex + w, cy - h * (1.6 if side < 0 else 0.2)),
            (ex + w * 0.7, cy + h),
            (ex - w * 0.7, cy + h),
        ]
        d.polygon(pts, fill=color)
    if not glow:
        return img
    halo = img.filter(ImageFilter.GaussianBlur(size * 0.03))
    halo2 = img.filter(ImageFilter.GaussianBlur(size * 0.09))
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    for layer, strength in ((halo2, 1.6), (halo, 1.4)):
        r, g, b, a = layer.split()
        a = a.point(lambda p: min(255, int(p * strength)))
        out = Image.alpha_composite(out, Image.merge("RGBA", (r, g, b, a)))
    out = Image.alpha_composite(out, img)
    # A hot core in each slit.
    core = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    cd = ImageDraw.Draw(core)
    for side in (-1, 1):
        ex = cx + side * gap
        cd.ellipse([ex - w * 0.35, cy - h * 0.5, ex + w * 0.35, cy + h * 0.5],
                   fill=(255, 220, 140, 255))
    return Image.alpha_composite(out, core)


def pixelate(img: Image.Image, size: int) -> Image.Image:
    small = img.resize((size // PIXEL, size // PIXEL), Image.NEAREST)
    return small.resize((size, size), Image.NEAREST)


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    base = 432
    bg = corridor(base)
    fg = pixelate(eyes(base, EYE + (255,), True), base)
    mono = pixelate(eyes(base, (255, 255, 255, 255), False), base)
    full = Image.alpha_composite(bg.convert("RGBA"), fg)

    bg.save(os.path.join(OUT, "bg_432.png"))
    fg.save(os.path.join(OUT, "fg_432.png"))
    mono.save(os.path.join(OUT, "mono_432.png"))
    full.resize((192, 192), Image.LANCZOS).save(os.path.join(OUT, "icon_192.png"))
    full.resize((512, 512), Image.LANCZOS).convert("RGB").save(os.path.join(ROOT, "icon.png"))
    print("wrote icon.png and", OUT)


if __name__ == "__main__":
    main()
