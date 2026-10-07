#!/usr/bin/env python3
"""Draw the Steam store and library capsules from the game's own art.

    python3 tools/store_capsules.py

Run tools/store_shots.gd first: the backdrop is a corridor out of its
01-explore-floor1.png. The four dragon bosses stand over it, scaled up whole
pixels at a time, with the title in the game's font. Everything goes to
build/store/steam/capsules/, which git ignores: the capsules show the real art
and are never committed.

Sizes are Steam's as of 2026; check Steamworks > Store Assets if one is refused.
"""
import os
from PIL import Image, ImageDraw, ImageFont, ImageEnhance

PROJECT = os.path.normpath(os.path.join(os.path.dirname(__file__), ".."))
SPRITES = os.path.join(PROJECT, "art-private", "characterSprites")
FONT = os.path.join(PROJECT, "resources", "misc", "OldSchoolAdventures-42j9.ttf")
SHOT = os.path.join(PROJECT, "build", "store", "steam", "01-explore-floor1.png")
OUT = os.path.join(PROJECT, "build", "store", "steam", "capsules")

GOLD = (230, 191, 77)
INK = (14, 10, 8)
DRAGONS = ["Ice_Dragon", "Thunder_Dragon", "Fire_Dragon", "Void_Dragon"]

# name: (width, height, text). The library hero must carry no text (Steam lays
# the logo over it), and the logo is the title alone on transparency.
CAPSULES = {
    "header_capsule": (920, 430, True),
    "small_capsule": (462, 174, True),
    "main_capsule": (1232, 706, True),
    "vertical_capsule": (748, 896, True),
    "library_capsule": (600, 900, True),
    "library_header": (920, 430, True),
    "library_hero": (3840, 1240, False),
    "page_background": (1438, 810, False),
}


def dragon(name: str) -> Image.Image:
    sheet = Image.open(os.path.join(SPRITES, name, f"{name}_Idle.png")).convert("RGBA")
    s = sheet.height
    return sheet.crop((0, 0, s, s))


def backdrop(w: int, h: int, dim: float) -> Image.Image:
    """The corridor from the explore shot, cropped to the capsule's shape."""
    shot = Image.open(SHOT).convert("RGB")
    # The 3D view is the right-hand part of the Steam screen, right of the map.
    # Below the top bar, whose compass and gold would show through.
    view = shot.crop((int(shot.width * 0.40), int(shot.height * 0.05), shot.width,
                      int(shot.height * 0.80)))
    scale = max(w / view.width, h / view.height)
    view = view.resize((max(w, round(view.width * scale)), max(h, round(view.height * scale))),
                       Image.NEAREST)
    x, y = (view.width - w) // 2, (view.height - h) // 2
    bg = view.crop((x, y, x + w, y + h))
    return ImageEnhance.Brightness(bg).enhance(dim).convert("RGBA")


def draw_title(img: Image.Image, box: tuple, stacked: bool = False) -> None:
    """The title, as large as fits `box` (x, y, w, h), gold with a dark edge.
    `stacked` puts a word to a line, for a tall capsule."""
    x0, y0, bw, bh = box
    lines = ["FOUR", "DRAGONS", "DEEP"] if stacked else ["FOUR DRAGONS DEEP"]
    size = 8
    while True:
        f = ImageFont.truetype(FONT, size + 2)
        widths = [f.getbbox(t)[2] for t in lines]
        if max(widths) > bw or (size + 2) * 1.25 * len(lines) > bh:
            break
        size += 2
    f = ImageFont.truetype(FONT, size)
    d = ImageDraw.Draw(img)
    edge = max(2, size // 12)
    line_h = round(size * 1.25)
    top = y0 + (bh - line_h * len(lines)) // 2
    for i, t in enumerate(lines):
        tw = f.getbbox(t)[2]
        tx, ty = x0 + (bw - tw) // 2, top + i * line_h
        d.text((tx, ty), t, font=f, fill=GOLD, stroke_width=edge, stroke_fill=INK)


def draw_dragons(img: Image.Image, band: tuple, cols: int = 4) -> None:
    """The four dragons across `band` (x, y, w, h) in `cols` columns (4 for a
    row, 2 for a square), whole-pixel scaled and dropped to the band's floor."""
    x0, y0, bw, bh = band
    sprites = [dragon(n) for n in DRAGONS]
    rows = (len(sprites) + cols - 1) // cols
    cell = sprites[0].width
    gap = 0.25
    scale = max(1, int(min(bh / (cell * (rows + gap * (rows - 1))),
                           bw / (cell * (cols + gap * (cols - 1))))))
    size = cell * scale
    step = size + int(size * gap)
    left = x0 + (bw - (size * cols + int(size * gap) * (cols - 1))) // 2
    top = y0 + bh - (size * rows + int(size * gap) * (rows - 1))
    for i, s in enumerate(sprites):
        x, y = left + (i % cols) * step, top + (i // cols) * step
        big = s.resize((size, size), Image.NEAREST)
        shadow = Image.new("RGBA", big.size, (0, 0, 0, 0))
        shadow.paste((0, 0, 0, 140), mask=big.split()[3])
        off = max(2, scale // 2)
        img.alpha_composite(shadow, (x + off, y + off))
        img.alpha_composite(big, (x, y))


def capsule(w: int, h: int, text: bool) -> Image.Image:
    img = backdrop(w, h, 0.55 if text else 0.7)
    if not text:
        draw_dragons(img, (0, int(h * 0.30), w, int(h * 0.62)))
        return img
    if w / h < 1.2:   # tall: a word to a line, the dragons two by two
        draw_title(img, (int(w * 0.06), int(h * 0.04), int(w * 0.88), int(h * 0.40)), stacked=True)
        draw_dragons(img, (int(w * 0.10), int(h * 0.47), int(w * 0.80), int(h * 0.50)), cols=2)
    else:             # wide: dragons along the bottom, title over them
        draw_title(img, (int(w * 0.05), int(h * 0.05), int(w * 0.90), int(h * 0.42)))
        draw_dragons(img, (int(w * 0.05), int(h * 0.50), int(w * 0.90), int(h * 0.46)))
    return img


def logo(w: int = 1280, h: int = 720) -> Image.Image:
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw_title(img, (int(w * 0.04), int(h * 0.10), int(w * 0.92), int(h * 0.80)))
    return img


def main() -> None:
    if not os.path.exists(SHOT):
        raise SystemExit("no explore shot: run tools/run.sh steam --script tools/store_shots.gd first")
    os.makedirs(OUT, exist_ok=True)
    for name, (w, h, text) in CAPSULES.items():
        capsule(w, h, text).convert("RGB").save(os.path.join(OUT, f"{name}.png"))
        print(f"{name}.png  {w}x{h}")
    logo().save(os.path.join(OUT, "library_logo.png"))
    print("library_logo.png  1280x720 (transparent)")


if __name__ == "__main__":
    main()
