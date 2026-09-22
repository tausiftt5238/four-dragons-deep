# Four Dragons Deep

A first-person dungeon crawler built in portrait orientation, for phones. Twenty
floors of a fantasy gauntlet: you descend, you fight what lives there, and you
talk some of it into coming with you.
This is the implemention of the press turn system, my favorite way of playing a jrpg. 

Made in Godot 4.6 against the GL Compatibility renderer, and shipped as a web
build.

## A note on the art

The enemy sprites in this repository are **generated placeholders** — coloured
silhouettes at the right names and sizes. The real art is a commercial pack that
cannot be redistributed, so it is not here, and it is not anywhere in the git
history either.

This means a clone boots and plays, with every enemy a blob. If you own the pack,
`tools/real_art.sh on <dir>` copies it into place and marks those files
skip-worktree so git will not pick them up; `tools/real_art.sh off` puts the
placeholders back. `tools/make_placeholder_sprites.py` draws the placeholders.

Everything else — the code, the shader, the map and spell art, the font — is in
the repository as it is in the game.

## Running it

The project targets **Godot 4.6** (`config/features` pins `4.6` and
`GL Compatibility`). Open the folder in the editor, or from the command line:

```
godot --path .
```

A fresh clone needs one import pass before it will run, because `.godot/` is not
committed. Without it you get a cascade of misleading "Identifier not declared"
parse errors:

```
godot --headless --editor --path . --quit    # imports assets, once
godot --headless --path . --quit             # parse check, should be silent
```

The main scene is `scenes/title.tscn`.

## Layout

| Path | What's in it |
| --- | --- |
| `scripts/core` | `main.gd` — the run loop, floor transitions, save/load |
| `scripts/data` | Static tables: spells, items, shop stock |
| `scripts/entities` | `enemy.gd` (`TEMPLATES`), the player, floor roamers |
| `scripts/ui` | Combat, negotiation, shop, map and title screens |
| `scripts/world` | `level.gd` (`FLOOR_COUNT = 20`) and floor generation |
| `scenes` | Four scenes: `title`, `main`, `combat`, `map` |
| `resources` | Map and spell art, shaders, the font, placeholder enemies |
| `docs` | Player and design reference — see below |
| `tools` | Generators and the art swap script |

## Docs

`docs/how-to-play.md` is the player-facing page. The rest are generated or
hand-kept reference: `bestiary.html`, `demon-registry.html`,
`equipment-catalog.html`, `tier-palette.html`, `drawing-the-afflictions.html`.

`bestiary.html` is **generated, not hand-edited** — `tools/README.md` has the two
commands that rebuild it from `Enemy.TEMPLATES` and `Spell.DATA`.

## Exporting

Four presets are configured: Web, Windows, Linux, Android. Web is the one that
ships.

One setting is load-bearing and easy to undo by accident: the Web preset's
`variant/thread_support` **must stay `false`**. Turning it on makes the export
require cross-origin isolation headers, which itch.io does not serve — the build
then fails to boot rather than degrading. Mobile VRAM texture compression is on.

## Licence

The source code is MIT licensed — see `LICENSE`. The art and audio under
`resources/` are not covered by it and are not offered for reuse.
