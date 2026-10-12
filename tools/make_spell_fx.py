#!/usr/bin/env python3
"""Build the higher-rung spell sheets from the Tiny RPG Character Asset Packs.

SpellFX plays these over a portrait for rung II and III casts (rung I keeps
the drawn motes, blooms and slash). They are the packs' own effect sheets,
some mirrored or recoloured to fit an element the packs never drew:

  Fire_II   Wizard's fireball, mirrored so it flies at the foes (left)
  Fire_III  Warlock's flame column
  Ice       Wizard's ice star
  Thunder   Warlock's flame column in the thunder icon's yellow, mirrored so
            it is not Fire_III again in another colour
  Light     Priest's pillar of light
  Dark      Black Knight C's skull pillar in the dark spells' violet
  Phys      Lava Slime's rock spikes
  Heal      Priest's healing crosses

Commercial art, like every sprite under resources/characterSprites/: git keeps
silhouettes only (see tools/install_git_hooks.sh). The real sheets are written
to the working tree and to art-private/ beside the others.

  python3 tools/make_spell_fx.py
"""
import colorsys
import io
import os
import shutil
import zipfile

from PIL import Image

PROJECT = os.path.normpath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(PROJECT, "resources", "characterSprites", "SpellFX")
PRIVATE = os.path.join(PROJECT, "art-private", "characterSprites", "SpellFX")
DOWNLOADS = os.path.expanduser("~/Downloads")
PACK1 = "Tiny RPG Character Asset Pack 01 v2.0 -Full 22 Characters.zip"
PACK2 = "Tiny RPG Character Asset Pack 02 v1.01-Full 20 Characters.zip"


def sheet(pack: str, folder: str, name: str) -> Image.Image:
    with zipfile.ZipFile(os.path.join(DOWNLOADS, pack)) as z:
        for entry in z.namelist():
            if entry.endswith(f"/{folder}/{name}") and "100x100 split" in entry:
                return Image.open(io.BytesIO(z.read(entry))).convert("RGBA")
    raise SystemExit(f"{name} not found in {pack}")


# Each frame turned around on its own spot, so the sheet still plays in order.
def mirror(im: Image.Image) -> Image.Image:
    h = im.size[1]
    out = Image.new("RGBA", im.size)
    for i in range(im.size[0] // h):
        out.paste(im.crop((i * h, 0, i * h + h, h)).transpose(Image.FLIP_LEFT_RIGHT), (i * h, 0))
    return out


def recolour(im: Image.Image, fn) -> Image.Image:
    im = im.copy()
    px = im.load()
    for y in range(im.size[1]):
        for x in range(im.size[0]):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            nr, ng, nb = fn(h, s, v)
            px[x, y] = (int(nr * 255), int(ng * 255), int(nb * 255), a)
    return im


# Red-to-orange onto the violet BanishFX draws dark in (about hue 0.75).
def violet(h: float, s: float, v: float):
    return colorsys.hsv_to_rgb(0.75 + (h if h < 0.5 else h - 1) * 0.5, min(1, s * 0.95), min(1, v * 1.15))


# Onto the thunder icon's yellow; the hottest parts go nearly white.
def yellow(h: float, s: float, v: float):
    return colorsys.hsv_to_rgb(0.135, s * (0.55 if v > 0.8 else 0.9), min(1, v * 1.2))


def main() -> None:
    warlock = sheet(PACK2, "Magic(projectile)", "Warlock_Attack02_Effect.png")
    built = {
        "Fire_II": mirror(sheet(PACK1, "Magic(projectile)", "Wizard_Attack02_Effect.png")),
        "Fire_III": warlock,
        "Ice": sheet(PACK1, "Magic(projectile)", "Wizard_Attack01_Effect.png"),
        "Thunder": mirror(recolour(warlock, yellow)),
        "Light": sheet(PACK1, "Magic(projectile)", "Priest_Attack_effect.png"),
        "Dark": recolour(sheet(PACK2, "Beam(projectile)", "Black Knight_C_Beam.png"), violet),
        "Phys": sheet(PACK2, "Spike(projectile)", "Lava Slime_Spike.png"),
        "Heal": sheet(PACK1, "Magic(projectile)", "Priest_Heal_effect.png"),
    }
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(PRIVATE, exist_ok=True)
    for name, im in built.items():
        path = os.path.join(OUT, f"{name}.png")
        im.save(path)
        shutil.copy2(path, os.path.join(PRIVATE, f"{name}.png"))
        print(f"{name}.png  {im.size[0] // im.size[1]} frames")


if __name__ == "__main__":
    main()
