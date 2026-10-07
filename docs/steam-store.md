# Steam store page: Four Dragons Deep

Text and settings for the Steamworks store page, field by field. The images are
made by tools (they show the real art, so they live in gitignored
build/store/steam/ and are never committed):

- Screenshots: `tools/run.sh steam --script tools/store_shots.gd`, nine at
  1920x1080 in `build/store/steam/`.
- Capsules and library art: `python3 tools/store_capsules.py`, into
  `build/store/steam/capsules/`.

Uploading the game itself is `tools/upload_steam.sh`; see its header.

## Short description

Steam allows 300 characters, shown beside the main capsule.

> A first-person dungeon crawler with press-turn combat. Twenty floors, four
> dragons at the bottom of each band, and nearly every monster on the way can
> be talked into joining your party. Hit weaknesses to keep your turn; get it
> wrong and lose the round.

## About This Game

Twenty floors down, four dragons wait. Under them, something has been raising
the dead.

Four Dragons Deep is a first-person dungeon crawler in the old style: step
through the maze a square at a time, map it as you go, find each floor's key
and unlock the way down. Fights run on press turns, the system from the
Shin Megami Tensei games.

**Press-turn combat**
Every member of your party gives you a turn to spend. Hit a weakness or land a
critical and you keep going on half a turn. Miss, or throw fire at something
that drinks it, and you lose turns, or the whole round. Monsters play by the
same rules, so your party's resistances can shut down their turn just as hard.

**Talk them round**
Nearly every monster can be talked to. Reason with it, bribe it, threaten it,
or win it over, and it joins your party, levels up beside you and learns new
skills as it grows. Bats, demons, werewolves, golems, and dragons too: from
hatchlings on the first floors to mature dragons near the bottom, seventeen of
them can be recruited. Build a team that covers each other's weaknesses, and
let go of the ones you outgrow.

**Four dragons, and what lies below them**
Every fifth floor a dragon guards the corridor down: ice, thunder, fire and
void. Each one is weak to the element of the dragon before it, so what beat the
last one is your key to the next. Each band of the dungeon has its own hazard,
from ice that slides you along to charged plates, lava and teleporters, and a
warden holds the key on the floor before each dragon.

**The Abyss**
Beat the game and an endless descent opens for the hero who did it. No bottom
and one life: every monster rises in an element of its own, wardens and dragons
roam among them, new gear waits every five floors, and how deep you get is the
score.

**Features**
- Six elements (physical, fire, ice, thunder, light and dark), and an affinity
  chart to learn for every creature
- Over 50 monsters to fight, and 45 of them can join your party
- Buffs, debuffs, ailments, mirrors and wards
- Save orbs to rest, shop, recruit and save, with a monster gauntlet and a slot
  machine
- Hand-drawn pixel art and an 8-bit soundtrack
- Plays on a keyboard, a mouse or a controller, all rebindable; Steam Deck
  friendly
- Lifetime records: play time, deepest floor, dragons slain and more

## Basic info

- **Genre:** RPG, Indie
- **Developer / Publisher:** your name or studio name, as on the Steamworks
  account
- **Supported languages:** English (interface, subtitles). No full audio:
  there is no voice acting.
- **Controller support:** Full controller support. Fill in the controller
  survey to match: Xbox and PlayStation pads through Steam Input. Retest on a
  real pad first: it has only been tested from the keyboard.
- **Steam Deck:** let Valve test it after release; the 16:10 screen is
  handled (the window stretches to fit).

## Tags

Steam suggests up to twenty; these come first, most important first:

Dungeon Crawler, Turn-Based Combat, RPG, JRPG, Creature Collector, First-Person,
Pixel Graphics, Grid-Based Movement, Turn-Based Tactics, Singleplayer, Retro,
Fantasy, Dragons, Roguelite (for the Abyss), Old School, Party-Based RPG,
2D, Indie, Exploration, Difficult.

## System requirements

The game is small and runs on Godot's OpenGL 3.3 renderer. These are honest
minimums with room to spare; nothing heavier has been measured.

**Windows (minimum)**
- OS: Windows 10, 64-bit
- Processor: dual core, 2 GHz
- Memory: 2 GB RAM
- Graphics: any GPU with OpenGL 3.3 (Intel HD 4000 or newer, GeForce 400
  series, Radeon HD 5000)
- Storage: 300 MB available space

**Linux / SteamOS (minimum)**
- OS: Ubuntu 22.04 or SteamOS 3, 64-bit
- Processor: dual core, 2 GHz
- Memory: 2 GB RAM
- Graphics: OpenGL 3.3 with current Mesa or NVIDIA drivers
- Storage: 300 MB available space

## Content survey

For the questionnaire (it sets the age ratings): fantasy violence against
monsters, demons and the undead, shown as pixel sprites with no blood or gore.
Demons and a necromancer appear, with no real-world religion. No sexual
content, no drugs, no gambling for real money (the slot machine uses in-game
gold only, worth noting where the survey asks about simulated gambling), no
user-generated content and no online features.

## Credits

For the store page's "about" text or a credits line, matching the in-game
credits:

- Art: Zerie, DeepDiveGameStudio
- Music: Momiziba
- Game: Tausif

## Library assets checklist

| File (build/store/steam/capsules/) | Steamworks slot | Size |
| --- | --- | --- |
| header_capsule.png | Header Capsule | 920 x 430 |
| small_capsule.png | Small Capsule | 462 x 174 |
| main_capsule.png | Main Capsule | 1232 x 706 |
| vertical_capsule.png | Vertical Capsule | 748 x 896 |
| page_background.png | Page Background (optional) | 1438 x 810 |
| library_capsule.png | Library Capsule | 600 x 900 |
| library_header.png | Library Header | 920 x 430 |
| library_hero.png | Library Hero (no text) | 3840 x 1240 |
| library_logo.png | Library Logo (transparent) | 1280 x 720 |

Steam's reviewers want the game's name legible on every capsule except the hero
and the background, and no review quotes or award text on them. If Steamworks
asks for a size this table does not list, add it to `CAPSULES` in
`tools/store_capsules.py`.
