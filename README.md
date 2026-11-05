# sabotage.ai

A 2.5D puzzle-platformer for Android, built with Godot 4 (GDScript). You sabotage
data centers to stop capitalists replacing humans with AI.

This README is meant to be enough to set the project up from scratch on a fresh machine,
with no outside help. Commands are for Windows 10/11 (what the project was built on);
macOS/Linux notes are given where the steps differ.

- [1. Requirements](#1-requirements)
- [2. Set up and run on desktop](#2-set-up-and-run-on-desktop)
- [3. Build an Android APK](#3-build-an-android-apk)
- [4. Release builds for Google Play](#4-release-builds-for-google-play)
- [5. Regenerating the art](#5-regenerating-the-art)
- [6. Automated checks](#6-automated-checks)
- [7. Project layout](#7-project-layout)
- [8. Designing levels](#8-designing-levels)
- [9. Troubleshooting](#9-troubleshooting)
- [License and credits](#license-and-credits)

## 1. Requirements

| What | Version used | Needed for | How to get it (Windows) |
|---|---|---|---|
| Git | any recent | cloning, version control | `winget install --id Git.Git -e` |
| Godot (standard build, **not** .NET) | **4.7.2 stable** | running and exporting the game | `winget install --id GodotEngine.GodotEngine -e` |
| VS Code + the **godot-tools** extension | optional | editing GDScript | `winget install --id Microsoft.VisualStudioCode -e` |
| JDK | **17** (Eclipse Temurin 17.0.x) | Android export | `winget install --id EclipseAdoptium.Temurin.17.JDK -e` |
| Android SDK | cmdline-tools, `platform-tools`, `build-tools;35.0.1`, `platforms;android-35` | Android export | see [section 3](#3-build-an-android-apk) |
| Godot export templates | **4.7.2.stable** (about 1.2 GB download) | Android export | see [section 3](#3-build-an-android-apk) |
| Python 3 + Pillow | Python 3.12, Pillow 13 | regenerating art only | `pip install pillow` |
| GitHub CLI | optional | working with the GitHub repo | `winget install --id GitHub.cli -e` |

You do **not** need Python, the JDK or the Android SDK just to play or edit the game on
desktop. Godot alone is enough for that.

Stick to Godot 4.7.x. The project files and the export templates must be the same version.

## 2. Set up and run on desktop

1. Install Git and Godot (table above). **Fully quit and reopen VS Code / your terminal**
   afterwards, otherwise new programs are not on `PATH` yet.
2. Clone the repo:
   ```bash
   git clone https://github.com/shivamshekhar/sabotage-ai.git
   cd sabotage-ai
   ```
3. Make `godot` runnable from a terminal. On Windows, winget installs Godot but cannot create
   the `godot` command without admin rights. Either run it by full path, or add this to
   `~/.bashrc` in Git Bash (adjust the version in the file name if you install another):
   ```bash
   GODOT_DIR="$LOCALAPPDATA/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe"
   godot() { "$GODOT_DIR"/Godot_v4.7.2-stable_win64.exe "$@"; }
   godot_console() { "$GODOT_DIR"/Godot_v4.7.2-stable_win64_console.exe "$@"; }
   ```
   (`godot_console` prints logs to the terminal, which is handy for scripts and tests.)
4. **First time only**, let Godot import the assets and register the script classes. Without
   this, scripts fail with "Could not find type ... in the current scope":
   ```bash
   godot --headless --path . --import
   godot --headless --path . --import      # run twice; the second pass picks up new class names
   ```
5. Run the game:
   ```bash
   godot --path .                       # play
   SABOTAGE_PREVIEW=1 godot --path .    # zoomed-out view of the whole level (debug aid)
   ```
   Or open the folder in the Godot editor (Project Manager > Import > pick `project.godot`) and press F5.

### Editing in VS Code (optional)

1. Install the **godot-tools** extension.
2. In Godot: Editor > Editor Settings > Text Editor > External. Turn on *Use External Editor*,
   set *Exec Path* to your `Code.exe` (for example
   `C:\Users\<you>\AppData\Local\Programs\Microsoft VS Code\Code.exe`) and *Exec Flags* to
   `{project} --goto {file}:{line}:{col}`.
3. Keep the Godot editor open while you edit; godot-tools talks to its language server.

The repo's [.vscode/settings.json](.vscode/settings.json) makes Git Bash the default terminal.

### Controls

A/D or Left/Right to move, W or Up to jump, S or Down to go down.
On-screen touch buttons (`<  >  UP  DOWN`) drive the same input actions on a phone.

Up is both jump and climb, since you never do both at once. Ladders: when at least 75% of the
character overlaps a ladder, Up grabs it (from the floor at its bottom, or by catching it
mid-jump) and Down grabs it from the top deck. You then snap onto the ladder's centre line and
can only move up/down, with no jumping, until you reach the top deck or the floor. At the top
deck, Up jumps and Down climbs back down.

## 3. Build an Android APK

This produces a **debug** APK you can install on your own phone. The export presets are already
in [export_presets.cfg](export_presets.cfg): "Android Debug (APK)" (arm64, no Gradle) and
"Android Release (AAB)" (see [section 4](#4-release-builds-for-google-play)).

### 3.1 One-time setup

**a) JDK 17.**
```bash
winget install --id EclipseAdoptium.Temurin.17.JDK -e
```
It installs to `C:\Program Files\Eclipse Adoptium\jdk-17.x.x.x-hotspot`. Note that exact path.

**b) Android SDK.** You do not need Android Studio. Download the "Command line tools only"
zip for your OS from <https://developer.android.com/studio#command-line-tools-only> (this
project used `commandlinetools-win-11076708_latest.zip`) and unpack it so that you end up
with `<SDK>\cmdline-tools\latest\bin\sdkmanager.bat`, where `<SDK>` is, for example,
`%LOCALAPPDATA%\Android\Sdk`. The zip contains a folder named `cmdline-tools`; rename it
to `latest` and put it inside `<SDK>\cmdline-tools\`.

Then, in **Git Bash** (the `yes |` trick answers the licence prompts):
```bash
export JAVA_HOME="C:/Program Files/Eclipse Adoptium/jdk-17.0.21.9-hotspot"   # your JDK path
SDK="$LOCALAPPDATA/Android/Sdk"
SM="$SDK/cmdline-tools/latest/bin/sdkmanager.bat"
yes | "$SM" --sdk_root="$SDK" --licenses        # accepts Google's Android SDK licences
"$SM" --sdk_root="$SDK" --install "platform-tools" "build-tools;35.0.1" "platforms;android-35"
```
Running `--licenses` means you accept Google's Android SDK licence agreements. Read them first
if you care; they are shown as they scroll by.

**c) Godot export templates (4.7.2.stable).** Download
`Godot_v4.7.2-stable_export_templates.tpz` from
<https://github.com/godotengine/godot/releases/tag/4.7.2-stable> (about 1.2 GB) and either:
- in the editor: Editor > Manage Export Templates > Install from File, or
- by hand: a `.tpz` is a zip; copy its `templates/` contents into
  `%APPDATA%\Godot\export_templates\4.7.2.stable\` (the folder must contain
  `android_debug.apk`, `android_release.apk`, `android_source.zip`, `version.txt`...).

**d) Debug signing key.** Debug builds are signed with a throwaway key. Create it once:
```bash
mkdir -p "$APPDATA/Godot/keystores"
"C:/Program Files/Eclipse Adoptium/jdk-17.0.21.9-hotspot/bin/keytool.exe" -genkeypair \
  -keystore "$APPDATA/Godot/keystores/debug.keystore" -alias androiddebugkey \
  -keyalg RSA -keysize 2048 -validity 10000 -storepass android -keypass android \
  -dname "CN=Android Debug,O=Android,C=US"
```
(This is the standard Android debug key, not your release key. See section 4 for that.)

**e) Tell Godot where everything is.** Either use the editor (Editor > Editor Settings >
Export > Android) or edit `%APPDATA%\Godot\editor_settings-4.7.tres` while Godot is closed and set:
```
export/android/java_sdk_path = "C:/Program Files/Eclipse Adoptium/jdk-17.0.21.9-hotspot"
export/android/android_sdk_path = "C:/Users/<you>/AppData/Local/Android/Sdk"
export/android/debug_keystore = "C:/Users/<you>/AppData/Roaming/Godot/keystores/debug.keystore"
export/android/debug_keystore_user = "androiddebugkey"
export/android/debug_keystore_pass = "android"
```
(The environment variables `JAVA_HOME` and `ANDROID_HOME` fill in the SDK path, but Godot still
needs `java_sdk_path` set in editor settings, or it fails with "A valid Java SDK path is required".)

**f) Texture compression (already done in this repo).** Android export requires ETC2/ASTC
textures. `project.godot` already has `textures/vram_compression/import_etc2_astc=true`; if you
ever see "ETC2/ASTC texture compression is required", turn it on in Project Settings >
Rendering > Textures > VRAM Compression. The first export after enabling it recompresses every
texture and takes noticeably longer.

### 3.2 Export

```bash
tools/build_apk.sh        # run in Git Bash from the repo root; writes build/sabotage-debug.apk
```
This takes about 1 minute (longer the very first time). Use the script rather than calling Godot
directly, because **Godot 4.7.2's headless export never exits**, not after success and not after
an error, so a plain `godot --headless --export-debug ...` leaves your terminal stuck forever.
The script runs Godot in the background, waits for the "export DONE" line (or an error), stops
Godot, and prints `OK: build/sabotage-debug.apk (29M)` or the tail of `build/export.log`.

Doing it by hand, if you prefer: run
`godot_console --headless --path . --export-debug "Android Debug (APK)" build/sabotage-debug.apk > build/export.log 2>&1`
in the background, watch the log for `[ DONE ] export`, then stop the Godot process yourself.
Or use the editor: Project > Export > "Android Debug (APK)" > Export Project (this one is fine,
the hang only affects headless runs).

The warning `Could not find version of build tools that matches Target SDK, using 35.0.1` is harmless.

The resulting APK is signed (v2/v3), package `com.shivamshekhar.sabotageai`, min Android 7.0
(API 24), arm64 only, landscape. It requires a **Vulkan-capable** phone, because the project uses
the "Mobile" renderer (almost every phone from the last several years qualifies). To support
older phones too, switch Project Settings > Rendering > Renderer to "Compatibility" (OpenGL).

### 3.3 Install on your phone

1. On the phone: Settings > About phone > tap *Build number* 7 times, then Settings > Developer
   options > turn on **USB debugging**. Plug it in and accept the prompt on the phone.
2. Install:
   ```bash
   "$LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe" devices        # your phone should be listed
   "$LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe" install -r build/sabotage-debug.apk
   ```
   Or copy `build/sabotage-debug.apk` to the phone and open it (allow "install unknown apps").

`build/` is git-ignored. The package name is `com.shivamshekhar.sabotageai`; change it (and the
version) in `export_presets.cfg` or the export dialog.

## 4. Release builds for Google Play

> Not yet exercised end to end in this repo: the preset exists, but only the debug APK has been
> built and checked. Expect to fix small things the first time.

Google Play requires an **Android App Bundle (.aab)**, signed with your own release key.

1. **Make a release keystore** and **back it up somewhere safe** (and never commit it; `*.keystore`
   and `*.jks` are git-ignored). If you lose it you cannot update the app unless you enrolled in
   Play App Signing.
   ```bash
   keytool -genkeypair -v -keystore sabotage-release.keystore -alias sabotage \
     -keyalg RSA -keysize 2048 -validity 10000
   ```
2. **Give Godot the credentials through environment variables** (they are deliberately not stored
   in `export_presets.cfg`, which is committed):
   ```
   GODOT_ANDROID_KEYSTORE_RELEASE_PATH=C:/path/to/sabotage-release.keystore
   GODOT_ANDROID_KEYSTORE_RELEASE_USER=sabotage
   GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=<your password>
   ```
3. **Install the Android build template** (needed for `.aab`): in the editor, Project > Install
   Android Build Template. This creates `android/build/` (git-ignored). Gradle downloads its own
   dependencies the first time.
4. **Export:**
   ```bash
   godot_console --headless --path . --export-release "Android Release (AAB)" build/sabotage-release.aab
   ```
   The same hang applies (Godot does not exit after a headless export). Either export from the
   editor (Project > Export), or copy `tools/build_apk.sh` and change `PRESET`, `OUT` and
   `--export-debug` to `--export-release` at the top so it stops Godot for you.
5. **Before every upload**, raise `version/code` in the preset (Play rejects repeats).
6. **Play Console basics:** a one-time US$25 developer account; new personal accounts have
   needed a closed test with about 12 testers for 14 days before production (check Google's
   current rules); a privacy policy URL, content rating questionnaire, screenshots and a feature
   graphic; the target API level must meet Google's current requirement.

## 5. Regenerating the art

Most art is generated by scripts so you can restyle it. They need Python 3 and Pillow
(`pip install pillow`) and are run from the repo root:

```bash
python tools/art/generate_background.py assets/backgrounds/data_center
python tools/art/generate_tiles.py assets/kenney/platformer-pack-industrial/sprites assets/tiles/data_center
python tools/art/generate_machines.py assets/machines/data_center
python tools/art/generate_icon.py icon.png
```

After regenerating, run `godot --headless --path . --import` so Godot re-imports the PNGs.

| Script | Produces | Tweak here |
|---|---|---|
| `generate_background.py` | 3 parallax layers + 2 LED layers, blurred for depth of field | `BLUR_*`, colours, rack layout |
| `generate_tiles.py` | themed ground, ledges, ladders, crates, spikes + regraded props | palette constants at the top |
| `generate_machines.py` | GPU rack, supercomputer, monitoring station, server tower + LED layers + shadows | the per-machine functions |
| `generate_icon.py` | the 512x512 app icon (`icon.png`) | colours, hero pose |

Brightness of the background layers is set at run time in
[scripts/level/background.gd](scripts/level/background.gd) (`*_TINT` constants), not in the images.

The third-party art in `assets/kenney/` (Kenney, CC0) is the source for the character poses and
the base sprites; `assets/kenney/.../sprites/NAMES.md` maps the pack's numeric file names to the
descriptive names used here.

## 6. Automated checks

Headless scripts in [tools/tests/](tools/tests/) play the real game with simulated key presses.
Run them from the repo root (they exit non-zero on failure):

```bash
godot_console --headless --fixed-fps 60 --path . --script res://tools/tests/ladder_test.gd   # ladder + jump rules
godot_console --headless --fixed-fps 60 --path . --script res://tools/tests/health_test.gd   # damage, death, respawn
godot_console --headless --fixed-fps 60 --path . --script res://tools/tests/level_bot.gd     # bot beats level 1
```

`level_bot.gd` is specific to level 1's layout; it will need updating if the map changes.
`--fixed-fps 60` makes the simulation deterministic and fast.

## 7. Project layout

```
export_presets.cfg          Android export presets (no secrets)
icon.png                    App icon (generated)
scenes/
  main.tscn                 Entry scene (just runs core/main.gd)
scripts/
  core/
    main.gd                 Wires level, player, camera, touch UI, vignette, win banner
    input_setup.gd          Registers keyboard input actions (touch uses the same ones)
  player/
    player.gd               Movement, ladders, health/damage, respawn
    player_sprite.gd        Picks the character pose; flinch and blink animations
    player_shadow.gd        Halo + contact shadow that lift the player off the background
    health_bar.gd           Bar above the player (green = health left, red = damage taken)
  level/
    level.gd                Builds a level from an ASCII map (sprites, colliders, hazards, lights)
    level_data.gd           The level maps themselves (edit these to design levels)
    background.gd           Parallax data-center background (3 depth layers, blinking LEDs)
    sprite_library.gd       The only place that knows where art lives on disk
  ui/
    touch_controls.gd       On-screen buttons for phones
    vignette.gd             Darkened screen edges
assets/
  kenney/
    platformer-pack-industrial/sprites/   Level art (see NAMES.md for the old numeric IDs)
    platformer-characters/<name>/         Character poses (player, adventurer, female, soldier, zombie)
  backgrounds/data_center/  Generated parallax layers
  tiles/data_center/        Themed foreground tiles (same names as the Kenney sprites)
  machines/data_center/     GPU rack, supercomputer, monitoring station, server tower (+ LED layers)
tools/
  build_apk.sh              Builds build/sabotage-debug.apk (works around Godot's hanging headless export)
  art/                      Art generators (section 5)
  tests/                    Headless playtests (section 6)
build/                      Export output (git-ignored): APK, AAB, export.log
```

`SpriteLibrary` uses a tile from `assets/tiles/data_center/` when one exists with the requested
name, and falls back to the Kenney original otherwise.

## 8. Designing levels

Levels are ASCII grids in `scripts/level/level_data.gd`, one character per 70px tile (legend at
the top of that file, including how to place multi-tile machines). Ground/ledge/slime tiles pick
their start/middle/end variant automatically from neighbouring tiles.

Jump limits to design around (physics in `player.gd`): about 136px high (a bit under 2 tiles) and
about 264px far (about 3.7 tiles) at full speed. Keep steps to 1 tile and gaps to 3 tiles or less.

To swap the hero, change `CHARACTER` in `scripts/player/player_sprite.gd` to `adventurer`,
`female`, `soldier` or `zombie`.

## 9. Troubleshooting

| Symptom | Fix |
|---|---|
| `godot: command not found` | winget cannot create the alias without admin. Use the shell function in section 2, or the full path. |
| A program you just installed is "not found" | Fully quit and reopen VS Code / the terminal so it picks up the new `PATH`. |
| `Could not find type "Player" (or Level, ...) in the current scope` | The script class cache is missing. Run `godot --headless --path . --import` twice. |
| Export: `A valid Java SDK path is required in Editor Settings` | Set `export/android/java_sdk_path` (section 3.1e). |
| Export: missing templates / `No export template found` | Install templates for exactly 4.7.2.stable (section 3.1c). |
| A headless Godot command (export, sometimes `--import`) never returns | Godot 4.7.2 does not exit after a headless export, even a successful one. Use `tools/build_apk.sh`. If something is stuck, stop it by process id (`Stop-Process -Id <pid>` in PowerShell, or `taskkill //F //T //PID <pid>` in Git Bash). Also don't pipe export output through a filter such as `Select-String`: it hides all progress until the process exits. |
| Two Godot instances on the same project (for example a stuck one plus a new one) | Stop the stuck one first. Chained commands (`import; import; export`) keep launching the next step when you kill one. |
| Export: `ETC2/ASTC texture compression is required` | Enable `import_etc2_astc` (section 3.1f). Already on in this repo. |
| `sdkmanager` says licences are not accepted | `yes \| sdkmanager --licenses` in Git Bash (piping from PowerShell does not answer the prompts). |
| Unzipping the SDK tools fails on a long path | Extract directly into the SDK folder with a short path (use `unzip` in Git Bash). |
| `adb devices` shows nothing / `unauthorized` | Turn on USB debugging, use a data cable, accept the prompt on the phone. |
| Phone blocks installing the APK | Allow "install unknown apps" for the app you opened it from. |
| Background looks too dark or too bright | Adjust the `*_TINT` constants in `scripts/level/background.gd`. |

## License and credits

Code and generated art are released under the [MIT License](LICENSE): use and modify them freely,
with no warranty and no liability. Third-party art in `assets/kenney/` is CC0 by Kenney (license
files included alongside it).

Art by [Kenney](https://kenney.nl) (CC0): Platformer Pack: Industrial, Platformer Characters 1.
