# Releasing on Google Play

What is already set up in the repo, and the steps that have to happen on your
own machine and in Play Console.

## Already in the repo

| What | Where |
| --- | --- |
| Package name `com.tausif.fourdragonsdeep` (can never change after the first upload) | `export_presets.cfg`, Android preset |
| App name "Four Dragons Deep", version `1.0.0`, version code `1` | same |
| Exports an **AAB** (App Bundle) through the Gradle build, which Play requires | same |
| `min_sdk` 24, `target_sdk` **36** (Play's requirement for new apps from 31 Aug 2026) | same |
| arm64-v8a and armeabi-v7a | same |
| Launcher icon: legacy 192, adaptive foreground/background/monochrome 432 | `resources/app_icon/`, from `tools/icon_render.gd` + `tools/make_icons.py` |
| Store icon, 512×512 | `icon.png` |
| Autosave when the app is backgrounded or closed, on reaching a floor, and after a fight | `Main._autosave`, slot `SaveSystem.AUTO_SLOT` |
| Back button: closes the open panel; from the bare title it leaves the app | `Main._notification`, `TitleScreen._notification` |
| Debug keys (Q no encounters, N skip floor) only in debug builds | `Main._input` |
| Privacy policy | `docs/privacy-policy.html` (fill in the contact email first) |

## One-time setup on your machine

1. **Export templates.** In Godot: Editor › Manage Export Templates › Download
   and Install, for 4.6.
2. **Android SDK and JDK 17.** Install Android Studio (simplest), or the
   command-line tools. Then in Editor Settings › Export › Android set
   *Java SDK Path* and *Android SDK Path*.
3. **Android build template.** Project › Install Android Build Template. This
   creates `android/`, which `.gitignore` already leaves out of the repo.
4. **Upload key.** Make one keystore and keep it **outside** the repo, backed up
   somewhere safe:

   ```sh
   keytool -genkeypair -v -keystore ~/keys/fourdragonsdeep-upload.jks \
       -alias upload -keyalg RSA -keysize 2048 -validity 10000
   ```

   In Project › Export › Android › Keystore, set *Release* to that file, the user
   `upload` and its password. Godot keeps these in
   `.godot/export_credentials.cfg`, which is not committed.

   With Play App Signing (the default), Google holds the real signing key and
   this is only the upload key; if it is ever lost, Play support can reset it.

## Each release

1. Raise **version/code** by one (Play refuses a code it has seen) and set
   **version/name** (e.g. `1.0.1`) in the Android preset.
2. If you own the real art and music packs, put them in place first
   (`tools/real_art.sh on <dir>`, and `resources/music/`). The repo alone
   exports placeholders and silence.
3. Project › Export › Android › **Export Project** with *Export With Debug* off.
   The file lands at `../builds/four-dragons-deep.aab`.
4. Upload it in Play Console to the track you are on.

## Play Console, the first time

- **App content:** privacy policy URL, ads (none), app access (no login),
  content rating questionnaire, target audience (13+ keeps you out of the
  Families programme), data safety (no data collected or shared).
- **Store listing:** short and full description, the 512 icon, a 1024×500
  feature graphic, at least two phone screenshots.
- **Testing:** a new personal account must run a closed test with at least 12
  testers for 14 days in a row before production can be requested.

## Hosting the privacy policy

Play wants a public URL. If GitHub Pages is turned on for this repo, serving
from `main` › `/docs`, the policy is at
`https://tausiftt5238.github.io/four-dragons-deep/privacy-policy.html`.

## Redrawing the icon

```sh
xvfb-run -a godot --path . --rendering-driver opengl3 --script tools/icon_render.gd
python3 tools/make_icons.py
```

The first renders a corridor in the dungeon's own stone shader, the second
puts the eyes on it and cuts every size. (`xvfb-run` only matters on a machine
with no screen.) To use your
own art instead, replace `icon.png` and the four files in
`resources/app_icon/` at the same sizes.
