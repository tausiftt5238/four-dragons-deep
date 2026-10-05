#!/usr/bin/env python3
"""Google Play store art: the 1024x500 feature graphic and phone screenshots.

  python3 tools/store_art.py feature
  python3 tools/store_art.py header         # developer page header, 4096x2304
  python3 tools/store_art.py shots FRAME_DIR FRAME [FRAME ...]

Both write to build/store/, which git ignores. That matters: these images show
the real character art, which is a commercial pack and must never be committed
(see tools/githooks/). Run them with the real art in place.

The feature graphic is the app icon's corridor on the left, fading into the
dark, with the title, a tagline and the four dragons on the right.

Screenshots come from the frames tools/trailer.gd records (540x1170). Play
refuses a screenshot whose long side is more than twice its short side, and
the game's 1:2.17 is past that, so each frame is doubled with nearest-neighbour
to keep the pixels sharp, brought down to 2160 tall, and set on 1080x2160
with thin dark bars at the sides.
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "build", "store")
FONT = os.path.join(ROOT, "resources", "misc", "OldSchoolAdventures-42j9.ttf")
SPRITES = os.path.join(ROOT, "resources", "characterSprites")
GOLD = (230, 191, 77)
PALE = (204, 209, 224)
BG = (5, 4, 9)


def _text_center(d: ImageDraw.ImageDraw, cx: int, y: int, text: str, font, fill,
                 outline: int = 0) -> int:
    l, t, r, b = d.textbbox((0, 0), text, font=font)
    d.text((cx - (r - l) // 2 - l, y - t), text, font=font, fill=fill,
           stroke_width=outline, stroke_fill=(0, 0, 0))
    return y + (b - t)


def _dragon(name: str, height: int) -> Image.Image:
    strip = Image.open(os.path.join(SPRITES, f"{name}_Dragon", f"{name}_Dragon_Idle.png"))
    f = strip.height
    frame = strip.crop((0, 0, f, f))
    k = max(1, height // f)
    return frame.resize((f * k, f * k), Image.NEAREST)


def feature() -> None:
    w, h = 1024, 500
    img = Image.new("RGB", (w, h), BG)
    # The icon's corridor, its right edge fading into the background.
    icon = Image.open(os.path.join(ROOT, "icon.png")).convert("RGB").resize((h, h), Image.LANCZOS)
    mask = Image.new("L", (h, h), 255)
    md = ImageDraw.Draw(mask)
    fade = 170
    for x in range(fade):
        md.line([(h - fade + x, 0), (h - fade + x, h)], fill=int(255 * (1 - x / fade) ** 1.6))
    img.paste(icon, (0, 0), mask)

    d = ImageDraw.Draw(img)
    cx = 740
    title = ImageFont.truetype(FONT, 50)
    tag = ImageFont.truetype(FONT, 20)
    y = 46
    for line in ("FOUR", "DRAGONS", "DEEP"):
        y = _text_center(d, cx, y, line, title, GOLD, outline=3) + 14
    y = _text_center(d, cx, y + 12, "A dungeon crawler for your phone", tag, PALE) + 34

    names = ("Ice", "Thunder", "Fire", "Void")   # in the order they are met
    dragons = [_dragon(n, 96) for n in names]
    gap = 22
    total = sum(dr.width for dr in dragons) + gap * (len(dragons) - 1)
    x = cx - total // 2
    base = h - 40
    for dr in dragons:
        img.paste(dr, (x, base - dr.height), dr)
        x += dr.width + gap

    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, "feature_graphic.png")
    img.save(path)
    print("wrote", path)


def _figure(sprite_dir: str, sheet: str, scale: int) -> Image.Image:
    """The first frame of a sheet, cropped to the figure, scaled up whole."""
    strip = Image.open(os.path.join(SPRITES, sprite_dir, sheet)).convert("RGBA")
    f = strip.height
    frame = strip.crop((0, 0, f, f))
    box = frame.getbbox() or (0, 0, f, f)
    fig = frame.crop(box)
    return fig.resize((fig.width * scale, fig.height * scale), Image.NEAREST)


def header() -> None:
    """Play's developer page header, 4096x2304: laid out at a quarter of that
    and scaled up 4x with nearest-neighbour, so every pixel stays a pixel."""
    w, h = 1024, 576
    img = Image.new("RGB", (w, h), BG)
    d = ImageDraw.Draw(img)
    # A dim floor of stone flags under everyone, its joints in the first band's cyan.
    floor_y = 400
    wire = (0x55 // 2, 0xE0 // 2, 0xFF // 2)
    d.rectangle([0, floor_y, w, h], fill=(14, 12, 20))
    d.line([(0, floor_y), (w, floor_y)], fill=wire, width=2)
    for i in range(-6, 22):
        x = i * 64
        d.line([(x, floor_y), (x - 40 + (x - w / 2) * 0.35, h)], fill=(30, 40, 50), width=1)
    # Torchlight behind the line-up.
    glow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    for r in range(260, 0, -4):
        a = int(46 * (1 - r / 260) ** 1.8)
        gd.ellipse([w / 2 - r * 1.8, floor_y - r * 0.9, w / 2 + r * 1.8, floor_y + r * 0.5],
                   fill=(255, 190, 90, a))
    img = Image.alpha_composite(img.convert("RGBA"), glow)
    d = ImageDraw.Draw(img)

    # Kept well inside the edges: Play crops the header differently per screen.
    title = ImageFont.truetype(FONT, 44)
    tag = ImageFont.truetype(FONT, 16)
    y = _text_center(d, w // 2, 92, "FOUR DRAGONS DEEP", title, GOLD, outline=3)
    _text_center(d, w // 2, y + 16, "A first-person dungeon crawler for your phone", tag, PALE)

    # The knight in the middle, two dragons either side, all on the floor.
    knight = _figure("Knight", "Knight_Idle.png", 4)
    dragons = [_figure(f"{n}_Dragon", f"{n}_Dragon_Idle.png", 7) for n in ("Ice", "Thunder", "Fire", "Void")]
    slots = [w // 2 - 330, w // 2 - 180, w // 2 + 180, w // 2 + 330]
    for dr, cx in zip(dragons, slots):
        img.alpha_composite(dr, (cx - dr.width // 2, floor_y - dr.height + 6))
    img.alpha_composite(knight, (w // 2 - knight.width // 2, floor_y - knight.height + 4))

    big = img.convert("RGB").resize((w * 4, h * 4), Image.NEAREST)
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, "developer_header.png")
    big.save(path, optimize=True)
    print("wrote", path, "%d KB" % (os.path.getsize(path) // 1024))


def shots(frame_dir: str, frames: list) -> None:
    os.makedirs(OUT, exist_ok=True)
    for i, n in enumerate(frames, 1):
        src = Image.open(os.path.join(frame_dir, "frame%08d.png" % int(n))).convert("RGB")
        big = src.resize((src.width * 2, src.height * 2), Image.NEAREST)
        tall = 2160
        big = big.resize((round(big.width * tall / big.height), tall), Image.LANCZOS)
        canvas = Image.new("RGB", (1080, tall), BG)
        canvas.paste(big, ((1080 - big.width) // 2, 0))
        path = os.path.join(OUT, "screenshot_%d.png" % i)
        canvas.save(path)
        print("wrote", path)


if __name__ == "__main__":
    if len(sys.argv) >= 2 and sys.argv[1] == "feature":
        feature()
    elif len(sys.argv) >= 2 and sys.argv[1] == "header":
        header()
    elif len(sys.argv) >= 4 and sys.argv[1] == "shots":
        shots(sys.argv[2], sys.argv[3:])
    else:
        sys.exit(__doc__)
