# Building everything

`tools/build_all.sh` builds every version in one go: Steam for Linux and
Windows (`build/steam/`), the web build (`build/web/`) and the APK, and leaves
the two files the itch.io page takes in `build/itch/`.

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

To export the PC game for Steam, Linux and Windows:

```
tools/export_steam.sh            # both, into build/steam/linux/ and build/steam/windows/
tools/export_steam.sh linux      # or one of them
```

It refuses to build without the real art and the music in place. Each folder
is what a Steam depot takes: the binary and its `.pck`. `tools/` and `docs/`
are left out of every export.

`tools/screen_survey.gd` screenshots every screen outside the dungeon (title,
tutorial, intro, the overlays, ending, game over) in whichever build it runs
under, for checking a layout at a glance.

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

The dragon packs have no hurt animation, so `make_dragon_hurt.py` draws a
`_Hurt.png` for every `*_Dragon` from its first Idle frame: the outline goes
red and the body warms, the same four frames the character packs use.

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

# The Steam store

`docs/steam-store.md` has the store page text, field by field. The images show
the real art, so they go to gitignored `build/store/steam/`:

```
tools/run.sh steam --script tools/store_shots.gd    # nine 1920x1080 shots
python3 tools/store_capsules.py                      # capsules and library art
```

`store_shots.gd` doubles the Steam build's 960x540 canvas to 1920x1080, whole
pixels. It turns vsync off, because with the display asleep every frame waits
about a second.

`upload_steam.sh` sends `build/steam/windows` and `build/steam/linux` up as two
depots with SteamPipe, using the IDs in `steam_ids.cfg`. Run it in your own
terminal: steamcmd asks for the password and the Steam Guard code.

The Windows exe needs no rcedit: Godot 4.6 writes the project icon and the
version info into it on export.
