#!/usr/bin/env python3
"""Draws the app icon: a stone corridor running into the dark, and a pair of
eyes waiting at the end of it.

The corridor is the game's own wall and floor texture, cast in one-point
perspective the way the dungeon view is, then fogged out with depth. It is
rendered small and scaled up with nearest-neighbour so it reads as the same
pixel art as the rest of the game.

Writes, from the repo root:
  icon.png                          512  project / web / store icon
  resources/app_icon/icon_192.png   192  Android launcher (legacy)
  resources/app_icon/fg_432.png     432  adaptive foreground: the eyes alone
  resources/app_icon/bg_432.png     432  adaptive background: the corridor
  resources/app_icon/mono_432.png   432  adaptive monochrome: the eyes, white

Adaptive icons are masked to a circle, squircle or the like, and only the
middle 264 of 432 pixels is sure to be seen, so the eyes sit well inside that.

    python3 tools/make_icons.py
"""
import math
import os

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WALL = os.path.join(ROOT, "resources/mapAsset/level_1_wall_0.png")
FLOOR = os.path.join(ROOT, "resources/mapAsset/level_1_floor_1.png")
OUT = os.path.join(ROOT, "resources/app_icon")

PIXEL = 3            # one art pixel is this many screen pixels at 432
TEX_PER_UNIT = 64    # a 128 texture spans a 2-wide corridor
FOG = 0.55           # how fast the corridor goes dark
LIGHT = 0.62         # overall brightness: a dungeon, not a hallway
EYE = (255, 70, 30)


def corridor(size: int) -> Image.Image:
    wall = Image.open(WALL).convert("RGB")
    floor = Image.open(FLOOR).convert("RGB")
    tw, th = wall.size
    fw, fh = floor.size
    img = Image.new("RGB", (size, size))
    px = img.load()
    half = size / 2.0
    for y in range(size):
        v = (y + 0.5 - half) / half
        for x in range(size):
            u = (x + 0.5 - half) / half
            if abs(u) >= abs(v):
                # A side wall. Depth from how far out it is; the brick runs
                # along the depth and up the height.
                z = 1.0 / max(abs(u), 1e-4)
                s = int(z * TEX_PER_UNIT) % tw
                t = int((v * z + 1.0) * TEX_PER_UNIT) % th
                c = wall.getpixel((s, t))
                shade = 0.95
            else:
                z = 1.0 / max(abs(v), 1e-4)
                s = int((u * z + 1.0) * TEX_PER_UNIT) % fw
                t = int(z * TEX_PER_UNIT) % fh
                c = floor.getpixel((s, t))
                # The ceiling is the floor's stone, darker.
                shade = 0.8 if v > 0 else 0.55
            k = LIGHT * shade * math.exp(-(z - 1.0) * FOG)
            # Darker toward the corners too, so the eye goes to the middle.
            k *= 1.0 - 0.35 * min(1.0, (u * u + v * v) / 2.0)
            # A little warmth, as if a torch were behind the viewer.
            px[x, y] = (int(c[0] * k * 1.05), int(c[1] * k * 0.95), int(c[2] * k * 0.85))
    return img


def eyes(size: int, color, glow: bool) -> Image.Image:
    """Two slanted slits a little above the centre, with an optional glow."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx, cy = size / 2.0, size * 0.47
    gap = size * 0.085
    w, h = size * 0.07, size * 0.026
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
    bg = corridor(base // PIXEL).resize((base, base), Image.NEAREST)
    fg = pixelate(eyes(base, EYE + (255,), True), base)
    mono = pixelate(eyes(base, (255, 255, 255, 255), False), base)
    full = Image.alpha_composite(bg.convert("RGBA"), fg)

    bg.save(os.path.join(OUT, "bg_432.png"))
    fg.save(os.path.join(OUT, "fg_432.png"))
    mono.save(os.path.join(OUT, "mono_432.png"))
    full.resize((192, 192), Image.LANCZOS).save(os.path.join(OUT, "icon_192.png"))
    full.resize((512, 512), Image.NEAREST).convert("RGB").save(os.path.join(ROOT, "icon.png"))
    print("wrote icon.png and", OUT)


if __name__ == "__main__":
    main()
