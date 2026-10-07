#!/usr/bin/env python3
"""Draw a Hurt sheet for each dragon from its first Idle frame.

The dragon packs have no hurt animation. The character packs' Hurt sheets are
four frames: normal, the dark outline gone red with the body warmed, a fainter
warm flash, normal. This draws the same thing so a dragon flashes red when hit
like everything else.

    python3 tools/make_dragon_hurt.py [out_dir]

Reads and writes art-private/characterSprites/*_Dragon/ and copies the result
into resources/characterSprites/ (git stores only its silhouette).
"""
import os, shutil, sys
from PIL import Image

PROJECT = os.path.normpath(os.path.join(os.path.dirname(__file__), ".."))
PRIVATE = os.path.join(PROJECT, "art-private", "characterSprites")
LIVE = os.path.join(PROJECT, "resources", "characterSprites")
RED = (237, 13, 13, 255)


def outline(img: Image.Image) -> set:
    """Dark pixels on the figure's edge: next to transparency or the frame's."""
    px, (w, h) = img.load(), img.size
    out = set()
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0 or r + g + b > 150:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if not (0 <= nx < w and 0 <= ny < h) or px[nx, ny][3] == 0:
                    out.add((x, y))
                    break
    return out


def tint(img: Image.Image, f, edge: set = frozenset()) -> Image.Image:
    out = img.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            p = px[x, y]
            if p[3] == 0:
                continue
            px[x, y] = RED if (x, y) in edge else (*f(p[:3]), p[3])
    return out


def clamp(v: float) -> int:
    return max(0, min(255, int(v)))


def hurt_sheet(idle: Image.Image) -> Image.Image:
    s = idle.height
    base = idle.crop((0, 0, s, s)).convert("RGBA")
    hit = tint(base, lambda c: (c[0], clamp(c[1] * 0.7), clamp(c[2] * 0.4)), outline(base))
    flash = tint(base, lambda c: (clamp(c[0] + 35), clamp(c[1] - 11), clamp(c[2] - 12)))
    sheet = Image.new("RGBA", (s * 4, s))
    for i, fr in enumerate((base, hit, flash, base)):
        sheet.paste(fr, (i * s, 0))
    return sheet


def main() -> None:
    out_dir = sys.argv[1] if len(sys.argv) > 1 else None
    for name in sorted(os.listdir(PRIVATE)):
        idle = os.path.join(PRIVATE, name, f"{name}_Idle.png")
        if not name.endswith("_Dragon") or not os.path.exists(idle):
            continue
        sheet = hurt_sheet(Image.open(idle))
        if out_dir:
            sheet.save(os.path.join(out_dir, f"{name}_Hurt.png"))
            continue
        dst = os.path.join(PRIVATE, name, f"{name}_Hurt.png")
        sheet.save(dst)
        shutil.copy2(dst, os.path.join(LIVE, name, f"{name}_Hurt.png"))
        print(name)


if __name__ == "__main__":
    main()
