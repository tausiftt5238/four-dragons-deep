# How the code is put together

A map of `scripts/` for anyone picking the code up, including to build a
different game on it. Read this first, then the header comment of whichever
file you open: every script starts with a few lines on what it is for.

## The shape of it

Three scenes, almost everything else built in code:

```
scenes/title.tscn   TitleScreen        new game, load, options, the Abyss
       │  GameBoot.pending_slot = which save (0 = new game)
       ▼  LoadingScreen.change_scene
scenes/main.tscn    Main               the dungeon: walking, the map, the HUD
       ├─ scenes/map.tscn (a Level)    the current floor's maze, made at load
       ├─ Dungeon                      turns the maze into 3D walls and floors
       ├─ Roamer × n                   monsters walking the floor
       └─ CombatScene (on a CanvasLayer, made per fight, freed after)
              └─ combat_ended(result) → Main._on_combat_ended → rewards, level-ups
```

`Main` (`scripts/game/main.gd`) owns the run: the player, the floor, every
overlay (menu, orb, chest, saves, endings). It makes each screen with `.new()`,
puts it on a CanvasLayer and listens for its signal. There is one autoload,
`Boot` (`scripts/app/boot.gd`), which sets up controls and the window before
the first scene.

Nearly every script has a `class_name`, so code refers to classes by name and
never by path. Moving a file needs no code changes. The exceptions are
`project.godot` (the autoload), the three `.tscn` files and
`Boot`'s `load()` of `input_dedupe.gd`.

### Two builds, one codebase

`Build.steam()` (`scripts/app/build.gd`) says which game is running: the phone
build ("Portable", upright) or the PC build (Steam, on its side). It comes from
the `steam` feature tag on the export preset; `tools/run.sh steam` fakes it
without exporting. Most code is shared. Where the two differ in layout:

- `CombatScene` holds all of the combat rules; `CombatScenePortable` and
  `CombatSceneSteam` only lay out the screen (the "Layout hooks" at the end
  of `combat_scene.gd` are what they override).
- `Layout` puts the map in a band (phone) or a column (PC).
- On the PC build the menu and the orb open in `SidePanel` beside the
  dungeon; on the phone they cover it.

## The folders

```
scripts/
├── app/        start-up, the two builds, input, settings, files on disk
├── audio/      music and the synthesised sound effects
├── combat/     the battle rules, with no UI: press turns, damage, talking
├── data/       the tables: spells, items, gear, affinities, the slot machine
├── entities/   things with stats: the hero, monsters, floor roamers
├── game/       the run itself (Main) and the Abyss
├── world/      the maze, its 3D, the minimap
└── ui/
    ├── combat/             the battle screen
    │   ├── fx/             hit flashes, spell bursts, stat arrows
    │   └── negotiation/    the four kinds of talking, as steps of the screen
    ├── explore/            what sits over the dungeon: HUD, orb, chests, level-ups
    ├── menu/               the pause menu and its tabs
    ├── screens/            whole screens: title, intro, ending, options, saves
    └── widgets/            small reusable controls used everywhere
```

A rough rule for where a new file goes: if it draws nothing, it belongs
outside `ui/`. If it is a rule of the battle that a test could run without a
screen, `combat/`. If it is a table of things the player can find or learn,
`data/`. If it draws, it goes under `ui/` beside what it is shown with, and
into `widgets/` once two unrelated screens use it.

### app/

| File | Class | What it does |
| --- | --- | --- |
| `boot.gd` | autoload `Boot` | Runs before the first scene: controls, window, input de-duplication |
| `game_boot.gd` | `GameBoot` | Carries "new game or which slot" from the title to `Main` |
| `build.gd` | `Build` | Which build is running (Portable or Steam), and the demo flag |
| `layout.gd` | `Layout` | Screen geometry that differs per build |
| `controls.gd` | `Controls` | The eight presses the game runs on, rebindable |
| `input_dedupe.gd` | (node) | One press arriving twice (Steam Deck desktop mode) counts once |
| `settings.gd` | `Settings` | Device preferences in `user://settings.cfg` |
| `save_system.gd` | `SaveSystem` | Reads and writes `user://save_slot_N.json` |
| `records.gd` | `Records` | Lifetime numbers in `user://records.cfg` |

### audio/

| File | Class | What it does |
| --- | --- | --- |
| `music.gd` | `Music` | One looping track, picked by place; a missing file is silence |
| `sfx.gd` | `Sfx` | Plays named sounds, at most the biggest one per frame |
| `sfx_synth.gd` | `SfxSynth` | Builds each sound from `data/sfx_recipes.json` |

### combat/

| File | Class | What it does |
| --- | --- | --- |
| `press_turn.gd` | `PressTurn` | The turn icons: full, half, and what each outcome costs |
| `combat_math.gd` | `CombatMath` | Damage, hit, crit, ambush odds; no scene references |
| `negotiation.gd` | `Negotiation` | The arithmetic of talking a monster round |

### data/

The game's tables live in code as constants (`Spell.DATA`, `Enemy.TEMPLATES`
and so on). The CSV files in `data/` are exports of those tables for editing
in a spreadsheet and for the balance report; the game does not read them
(`tools/README.md` has the commands). `sfx_recipes.json` is the exception:
it is read at run time.

| File | Class | What it does |
| --- | --- | --- |
| `affinity.gd` | `Affinity` | Elements and weak/resist/null/drain/repel |
| `spell.gd` | `Spell` | Every spell and skill |
| `item.gd` | `Item` | Consumables and scrolls |
| `weapon.gd`, `armor.gd`, `accessory.gd` | `Weapon`, `Armor`, `Accessory` | Gear |
| `status.gd` | `Status` | Ailment names |
| `passive_skill.gd` | `PassiveSkill` | Passive skill names |
| `gacha.gd` | `Gacha` | The orb's slot machine |

### entities/

| File | Class | What it does |
| --- | --- | --- |
| `character_sheet.gd` | `CharacterSheet` | Stats, HP/MP, buff stages, ailments: shared by both sides |
| `player_character.gd` | `PlayerCharacter` | The hero: inventory, gear, spells, gold, the demons in the party |
| `enemy.gd` | `Enemy` | Every monster, warden, dragon and the Necromancer (`TEMPLATES` and friends) |
| `roamer.gd` | `Roamer` | A monster walking the floor that starts a fight on contact |

### game/

| File | Class | What it does |
| --- | --- | --- |
| `main.gd` | `Main` | The run: floors, walking, starting and ending fights, every overlay, saving |
| `abyss.gd` | `Abyss` | The endless mode after the ending |

`main.gd` is long. Its sections, in order: the two panes, level loading,
one-time setup, per-frame movement, the wide-screen HUD, roaming demons,
starting a fight, after a fight, screens over the dungeon, floor hazards,
the menu, the side panel, chests, the orb, saving and loading.

### world/

| File | Class | What it does |
| --- | --- | --- |
| `level.gd` | `Level` | A floor's data: maze, colours, portals, which band and hazard |
| `map.gd` | (`map.tscn`) | Generates the maze for a floor (and the Necromancer's hall) |
| `dungeon.gd` | `Dungeon` | Builds the 3D from a `Level` |
| `minimap.gd` | `Minimap` | The 2D map drawn over it |
| `dragon_banner.gd` | `DragonBanner` | The dragon standing at the end of a boss corridor |

### ui/combat/

`combat_scene.gd` is the biggest file in the game. Its sections, in order:
helpers, submenus, item and action logic, who is acting, a demon losing its
nerve, player-side actions, the enemy side, ailments, calling demons in and
out, swapping, recalling, the party and enemy line-ups, target picking,
refreshing, the phase flow, fleeing, actions and buttons, skills, leeches,
action icons, damage numbers, casting, wide casts, dispels, physical swings,
enemy actions, the Necromancer, wardens, wide casts from the other side, and
the layout hooks the two builds override.

| File | What it does |
| --- | --- |
| `combat_scene.gd` | All of the battle: phases, actions, enemy turns, bosses |
| `combat_scene_portable.gd`, `combat_scene_steam.gd` | The screen layout of each build |
| `combat_result_ui.gd` | The results card after a win |
| `status_overlay.gd` | Ailment marks drawn over a portrait |
| `fx/` | `SlashFX`, `SpellFX`, `BanishFX`, `StageFX`, `StageArrows` |
| `negotiation/` | `CombatNegotiation` and one helper per kind of talk (bribe, reason, recruit, threaten) |

### ui/explore/, ui/menu/, ui/screens/, ui/widgets/

- **explore:** `ExploreHUD` (PC HUD), `SidePanel`, `ChestUI`, `OrbUI` (rest,
  shop, recruit, gauntlet, slots), `LevelUpUI`, `DemonLevelUpUI`.
- **menu:** `MenuUI` and its tabs (`MenuTab*`), `GearTooltip`.
- **screens:** `TitleScreen` (with `TitleVignette`, `TitleMarch`), `IntroUI`,
  `EndingUI`, `GameOverUI`, `LoadingScreen`, `ScreenFade`, `NameEntry`,
  `SaveSlotUI`, `OptionsUI`, `TutorialUI`.
- **widgets:** `AnimatedPortrait` (sprite sheets), `AffinityChart`,
  `ItemInfo`, `SlotList` (the fixed-row lists), `FitLabel`, `FitRichText`,
  `MarqueeLabel`, `KeyIcon`, `ButtonHint`, `UIGlyph`, `TouchScroll`.

## Common jobs

- **A new monster:** a row in `Enemy.TEMPLATES` (`scripts/entities/enemy.gd`)
  and a sprite folder under `resources/characterSprites/`. Then re-export the
  CSV and the bestiary (`tools/README.md`).
- **A new spell or skill:** an entry in `Spell.DATA`. Casting goes through
  `CombatScene`'s "Casting" section; the effect art is in `resources/spellFX/`.
- **A new item or piece of gear:** `Item`, `Weapon`, `Armor` or `Accessory`.
  Shops read the same tables by floor tier.
- **A new boss behaviour:** see "The Necromancer" and "Wardens" in
  `combat_scene.gd`; a boss acts through its own `_x_act` function, called
  from the enemy phase.
- **A new screen over the dungeon:** make a `Control` in `ui/explore/` or
  `ui/screens/`, have `Main` create it on the overlay layer
  (`_get_overlay_layer`), and close it from its own signal.
- **A new sound:** a recipe in `data/sfx_recipes.json`, then `Sfx.play("name")`.

## What is on disk

| File (`user://`) | Written by |
| --- | --- |
| `save_slot_N.json` | `SaveSystem`, from `Main._gather_save_data` |
| `settings.cfg` | `Settings` |
| `records.cfg` | `Records` |
| `abyss.cfg`, `abyss_hero.json` | `Abyss` |

## Building another game on this

The parts that know nothing about dragons:

- `app/`: start-up, two builds from one codebase, rebindable controls, input
  de-duplication, settings and save files.
- `audio/`: a music player and a recipe sound synth (no audio files needed).
- `combat/press_turn.gd` and most of `combat/combat_math.gd`: the press-turn
  economy and the damage formulas.
- `data/affinity.gd` and `entities/character_sheet.gd`: elements and a stat
  block with buffs and ailments.
- `ui/widgets/`: sprite-sheet portraits, fitted labels, the fixed-row lists.
- `world/dungeon.gd` and `world/minimap.gd`: any grid maze as 3D and a map.

The parts that are this game: `game/`, the tables in `data/`, `Enemy`'s
templates, and the screens in `ui/`. A new game would keep the first list,
replace the tables, and write its own `Main`.

Things that will surprise you:

- The real art and music are not in git. A clone shows silhouettes and plays
  silence until `tools/real_art.sh` and the music folder are filled in (see
  the README).
- A fresh clone needs one import pass (`godot --headless --editor --quit`)
  before anything runs, or every class name reads as undeclared.
- Debug-only helpers check `OS.is_debug_build()` (for example
  `Main.debug_level_party`), so they never work in a release export.
- `tools/playtester.gd` plays the whole game headless and is the quickest way
  to check a change did not break a run: see `tools/README.md`.
