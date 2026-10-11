#!/usr/bin/env python3
"""Draw a Hurt and a Death sheet for each dragon from its first Idle frame.

The dragon packs have no hurt animation. The character packs' Hurt sheets are
four frames: normal, the dark outline gone red with the body warmed, a fainter
warm flash, normal. This draws the same thing so a dragon flashes red when hit
like everything else.

The packs have no death either, and a dragon that fell went on idling. The
Death sheet greys it out and then crumbles it: its pixels fall into a heap at
its feet, some blowing away as dust. The game holds a death on its last frame,
so the heap stays.

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


GREY_FRAMES = 3      # draining to grey
CRUMBLE_FRAMES = 7   # falling into the heap
DUST = 0.45          # share of the pixels that blow away rather than land
HEAP = 5             # rows the heap stands at most


def grey(c, t: float):
    """`c` drained of colour by `t` (0 to 1), and darkened a little."""
    lum = 0.30 * c[0] + 0.59 * c[1] + 0.11 * c[2]
    g = lum * 0.85 + 18
    return tuple(clamp(c[i] + (g - c[i]) * t) for i in range(3))


def death_sheet(idle: Image.Image) -> Image.Image:
    import random
    s = idle.height
    base = idle.crop((0, 0, s, s)).convert("RGBA")
    rng = random.Random(hash(base.tobytes()) & 0xffffffff)
    frames = []
    for k in range(1, GREY_FRAMES + 1):
        frames.append(tint(base, lambda c, t=k / GREY_FRAMES: grey(c, t)))
    stone = frames[-1]
    px = stone.load()
    # Where each pixel lands: a low heap at its feet. Each one slides a little
    # outward from the middle as it falls, the columns stack from the floor up,
    # and anything that would stand higher than HEAP rows blows away as dust,
    # as do DUST of them to begin with.
    plan = []   # (x, y, colour, land (x, y) or None, delay)
    cx = (s - 1) / 2.0
    heights = [0] * s
    cells = [(x, y, px[x, y]) for y in range(s - 1, -1, -1) for x in range(s) if px[x, y][3] > 0]
    for x, y, c in cells:
        delay = rng.random() * 0.45 + (1 - y / s) * 0.25
        lx = int(round(x + (x - cx) * 0.35 + rng.choice((-1, 0, 0, 1))))
        lx = min(s - 1, max(0, lx))
        if rng.random() < DUST or heights[lx] >= HEAP:
            plan.append((x, y, c, None, delay))
            continue
        heights[lx] += 1
        plan.append((x, y, c, (lx, s - heights[lx]), delay))
    for k in range(1, CRUMBLE_FRAMES + 1):
        t = k / CRUMBLE_FRAMES
        fr = Image.new("RGBA", (s, s), (0, 0, 0, 0))
        fp = fr.load()
        for x, y, c, land_y, delay in plan:   # land_y: the (x, y) it lands on
            p = min(1.0, max(0.0, (t - delay) / max(0.05, 1.0 - delay)))
            p = p * p   # falls, slow then fast
            if land_y is None:
                # Dust: drifts down and off a little, and thins away.
                if p >= 0.6:
                    continue
                ny = int(round(y + p * 3))
                nx = x + (1 if (x + y) % 2 else -1) * int(p * 2)
                if 0 <= nx < s and 0 <= ny < s and fp[nx, ny][3] == 0:
                    fp[nx, ny] = (c[0], c[1], c[2], int(c[3] * (1 - p / 0.6)))
                continue
            nx = int(round(x + (land_y[0] - x) * p))
            ny = int(round(y + (land_y[1] - y) * p))
            if fp[nx, ny][3] == 0:
                fp[nx, ny] = c
        frames.append(fr)
    sheet = Image.new("RGBA", (s * len(frames), s))
    for i, fr in enumerate(frames):
        sheet.paste(fr, (i * s, 0))
    return sheet


def main() -> None:
    out_dir = sys.argv[1] if len(sys.argv) > 1 else None
    for name in sorted(os.listdir(PRIVATE)):
        idle = os.path.join(PRIVATE, name, f"{name}_Idle.png")
        if not name.endswith("_Dragon") or not os.path.exists(idle):
            continue
        for kind, sheet in (("Hurt", hurt_sheet(Image.open(idle))),
                            ("Death", death_sheet(Image.open(idle)))):
            if out_dir:
                sheet.save(os.path.join(out_dir, f"{name}_{kind}.png"))
                continue
            dst = os.path.join(PRIVATE, name, f"{name}_{kind}.png")
            sheet.save(dst)
            shutil.copy2(dst, os.path.join(LIVE, name, f"{name}_{kind}.png"))
        if not out_dir:
            print(name)


if __name__ == "__main__":
    main()
