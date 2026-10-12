#!/usr/bin/env python3
"""Draw the controller button icons the game shows in place of a button's name.

One PNG per button under resources/icons/pad/, at 1x pixel size, in the Steam
Deck's own look: a black button with white lettering and a shadow under it.
Face buttons (A B X Y) and stick clicks (L3 R3) are circles; shoulders,
triggers, back grips and View/Menu are pills; the d-pad is a cross with the
pressed arm lit. The letters are a hand-set pixel font, so they stay sharp at
any whole-number zoom.

  python3 tools/make_pad_glyphs.py

Each button has a thin grey rim: black on the game's dark panels, with only a
shadow to set it apart, all but disappeared.
"""
import os

from PIL import Image

PROJECT = os.path.normpath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(PROJECT, "resources", "icons", "pad")

BODY = (16, 16, 18, 255)
SHADOW = (0, 0, 0, 150)
RIM = (92, 92, 104, 255)
INK = (255, 255, 255, 255)
SHADOW_DROP = 2
PILL_H = 13

# 5x7 capitals for a button with one letter on it.
BIG = {
    "A": ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
    "B": ["11110", "10001", "10001", "11110", "10001", "10001", "11110"],
    "X": ["10001", "10001", "01010", "00100", "01010", "10001", "10001"],
    "Y": ["10001", "10001", "01010", "00100", "00100", "00100", "00100"],
}
# 3x5 for the two-character labels.
SMALL = {
    "L": ["100", "100", "100", "100", "111"],
    "R": ["110", "101", "110", "101", "101"],
    "B": ["110", "101", "110", "101", "110"],
    "T": ["111", "010", "010", "010", "010"],
    "3": ["111", "001", "011", "001", "111"],
    "4": ["101", "101", "111", "001", "001"],
    "5": ["111", "100", "111", "001", "111"],
}


def blank(w: int, h: int) -> Image.Image:
    return Image.new("RGBA", (w, h + SHADOW_DROP), (0, 0, 0, 0))


def stamp(im: Image.Image, glyph: list, x0: int, y0: int) -> None:
    for y, row in enumerate(glyph):
        for x, bit in enumerate(row):
            if bit == "1":
                im.putpixel((x0 + x, y0 + y), INK)


def text_width(text: str, font: dict) -> int:
    return sum(len(font[c][0]) for c in text) + (len(text) - 1)


def write(im: Image.Image, text: str, font: dict, cx: float, cy: float) -> None:
    w = text_width(text, font)
    h = len(next(iter(font.values())))
    x = int(round(cx - w / 2))
    y = int(round(cy - h / 2))
    for c in text:
        stamp(im, font[c], x, y)
        x += len(font[c][0]) + 1


def fill_shape(im: Image.Image, inside, w: int, h: int, rim: bool) -> None:
    # Shadow first, the body over it, dropped so only its lower edge shows.
    for y in range(h):
        for x in range(w):
            if inside(x, y):
                im.putpixel((x, y + SHADOW_DROP), SHADOW)
    for y in range(h):
        for x in range(w):
            if not inside(x, y):
                continue
            edge = not all(inside(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
            im.putpixel((x, y), RIM if (rim and edge) else BODY)


def circle(label: str, font: dict, rim: bool, d: int = 17) -> Image.Image:
    im = blank(d, d)
    r = d / 2
    fill_shape(im, lambda x, y: 0 <= x < d and 0 <= y < d and (x + 0.5 - r) ** 2 + (y + 0.5 - r) ** 2 <= r * r,
               d, d, rim)
    write(im, label, font, r - 0.5 + 0.5, r - 0.5 + 0.5)
    return im


def pill(w: int, h: int, rim: bool) -> tuple:
    im = blank(w, h)
    rad = h / 2

    def inside(x: int, y: int) -> bool:
        if not (0 <= x < w and 0 <= y < h):
            return False
        cx = min(max(x + 0.5, rad), w - rad)
        return (x + 0.5 - cx) ** 2 + (y + 0.5 - rad) ** 2 <= rad * rad

    fill_shape(im, inside, w, h, rim)
    return im, inside


def pill_label(label: str, rim: bool) -> Image.Image:
    w = text_width(label, SMALL) + 10
    im, _ = pill(w, PILL_H, rim)
    write(im, label, SMALL, w / 2, PILL_H / 2)
    return im


# View: two overlapping squares. Menu: three lines.
def pill_icon(kind: str, rim: bool) -> Image.Image:
    im, _ = pill(19, PILL_H, rim)
    if kind == "view":
        for x in range(6, 11):
            for y in range(3, 8):
                if x in (6, 10) or y in (3, 7):
                    im.putpixel((x, y), INK)
        for x in range(8, 13):
            for y in range(5, 10):
                if x in (8, 12) or y in (5, 9):
                    im.putpixel((x, y), INK)
    else:
        for y in (4, 6, 8):
            for x in range(6, 13):
                im.putpixel((x, y), INK)
    return im


# The d-pad: a cross, the pressed arm white.
def dpad(arm: str, rim: bool) -> Image.Image:
    s, t = 17, 5
    lo, hi = (s - t) // 2, (s - t) // 2 + t
    im = blank(s, s)
    inside = lambda x, y: 0 <= x < s and 0 <= y < s and (lo <= x < hi or lo <= y < hi)
    fill_shape(im, inside, s, s, rim)
    arms = {"up": (lo + 1, 1, hi - 1, lo), "down": (lo + 1, hi, hi - 1, s - 1),
            "left": (1, lo + 1, lo, hi - 1), "right": (hi, lo + 1, s - 1, hi - 1)}
    x0, y0, x1, y1 = arms[arm]
    for y in range(y0, y1):
        for x in range(x0, x1):
            im.putpixel((x, y), INK)
    return im


def build(rim: bool) -> dict:
    out = {}
    for name in "ABXY":
        out[name] = circle(name, BIG, rim)
    for name in ("L3", "R3"):
        out[name] = circle(name, SMALL, rim)
    for name in ("LB", "RB", "LT", "RT", "L4", "R4", "L5", "R5"):
        out[name] = pill_label(name, rim)
    out["View"] = pill_icon("view", rim)
    out["Menu"] = pill_icon("menu", rim)
    for arm in ("up", "down", "left", "right"):
        out["D_" + arm.capitalize()] = dpad(arm, rim)
    return out


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    glyphs = build(True)
    for name, im in glyphs.items():
        im.save(os.path.join(OUT, f"{name}.png"))
    print(f"{len(glyphs)} glyphs in {OUT}")


if __name__ == "__main__":
    main()
