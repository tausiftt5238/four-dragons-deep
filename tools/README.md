# The two builds

One codebase makes two games (`scripts/core/build.gd`):

- **Four Dragons Deep Portable**, the default: upright, for Android and the web.
- **Four Dragons Deep** for Steam: on its side, for a mouse, keyboard or pad.
  The Windows and Linux export presets carry the `steam` feature tag, which
  switches `game/build/variant` and the canvas, window and name in
  `project.godot`.

To run either one without exporting:

```
tools/run.sh portable [godot args...]
tools/run.sh steam    [godot args...]
```

Anything after the variant goes to Godot, so a test script or the playtester
runs as `tools/run.sh steam --headless --script tools/playtester.gd`. For Steam
it writes a temporary `override.cfg` (gitignored) and removes it afterwards.

# Regenerating the bestiary

`docs/bestiary.html` is generated, not hand-edited. Two steps, from the repo root:

```
~/apps/Godot_v4.6.2-stable_linux.x86_64 --headless --path . --script tools/bestiary_dump.gd
python3 tools/bestiary_html.py
```

The first builds every template at the first and last floor of its band and
writes the numbers to JSON; the second renders the page. Both read the live
tables, so a change to `Enemy.TEMPLATES` or `Spell.DATA` is one rerun away from
being on the page. The dump writes `.godot/bestiary.json` and the renderer reads
it from there — gitignored, and it survives between sessions.

The page's CSS is lifted from the previous `docs/bestiary.html` on each run, so
edit the style there and it survives the next regeneration.

# The enemy art

`make_placeholder_sprites.py` draws the stand-in enemy sprites that ship in this
repository, and `real_art.sh` swaps the real commercial pack in and out of the
working tree without letting git see it. Both are documented in their own
headers, and the README explains why they exist.

# The character art

The character sprites in `resources/characterSprites/` are also a commercial
pack. Git stores only silhouettes of them: run `install_git_hooks.sh` once per
clone to set up the clean filter (`silhouette_sprites.py`) and the hooks in
`githooks/`. The real art stays in your working tree, with a copy in the
gitignored `art-private/characterSprites/`, and `restore_sprites.py` puts it
back whenever a checkout writes the silhouettes.

# The tutorial screenshots

The title screen's Tutorial shows pictures from `resources/tutorial/`, and
`tutorial_shots.gd` takes them by playing a short scripted run. It needs a real
display (or `xvfb-run`); the header has the command. Run it with the real art
in the working tree, or the shots show the silhouettes git stores.

# The trailer

`trailer.gd` plays a scripted run (walking, a chest, a fight, the party, the
key and the door, the stairs, the four dragons) with captions, and Godot's
Movie Maker records it frame by frame. `trailer_encode.sh` turns the frames
into a 1080x2340 MP4 with GStreamer. Both headers have the commands. Like the
tutorial shots, it needs a real display and the real art in the working tree.

# Reworking monsters

`data/monsters.csv` is the whole roster, one row per monster, for editing in
Google Sheets (File > Import > Upload, then File > Download > CSV to bring it
back). It holds only the fields the game reads; levels, exp and gold come from
the floor, so they are not columns. Affinity columns take `weak`, `resist`,
`null`, `reflect`, `drain` or blank.

```
godot --headless --path . --script tools/monster_export.gd   # tables -> CSV
godot --headless --path . --script tools/monster_report.gd   # CSV -> docs/monster-balance.md
```

The report reads the CSV, so an edited sheet can be checked before the game
reads it. The game itself still builds monsters from `Enemy`'s tables for now.

# Android test builds

`export_android.sh` builds a debug APK from the "Android APK" preset (no
Gradle, arm64 only) into `build/android/`; `export_android.sh install` also
puts it on a phone over adb. The "Android" preset is the Play Store AAB; see
`docs/releasing-android.md`.
