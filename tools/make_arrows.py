#!/usr/bin/env python3
"""Draw the arrows on the ways back and on: resources/icons/{back,next}.png
for the small buttons, {back,next}_big.png for the tutorial's wide ones.

  python3 tools/make_arrows.py

White, so a button tints them to the colour of its words. The game's font has
no arrow in it, so they are pixels like the pad icons (make_pad_glyphs.py).
"""
import os

from PIL import Image

PROJECT = os.path.normpath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(PROJECT, "resources", "icons")
INK = (255, 255, 255, 255)


# Pointing left: a chevron `stroke` thick, `half` rows either side of the
# middle, and a shaft `shaft` rows thick out to `width`.
def left_arrow(width: int, half: int, stroke: int, shaft: int) -> Image.Image:
    h = half * 2 + 1
    im = Image.new("RGBA", (width + 1, h), (0, 0, 0, 0))
    for y in range(h):
        d = abs(y - half)
        lo = d
        hi = d + stroke - (1 if d == half else 0)
        for x in range(lo, hi):
            im.putpixel((x, y), INK)
        if d <= shaft // 2:
            for x in range(d, width):
                im.putpixel((x, y), INK)
    return im


def main() -> None:
    small = left_arrow(11, 4, 2, 3)
    big = left_arrow(17, 6, 3, 3)
    for name, im in (("back", small), ("back_big", big)):
        im.save(os.path.join(OUT, name + ".png"))
        im.transpose(Image.FLIP_LEFT_RIGHT).save(
            os.path.join(OUT, name.replace("back", "next") + ".png"))
    print("arrows in", OUT)


if __name__ == "__main__":
    main()
