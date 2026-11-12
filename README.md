# sabotage.ai

A 2.5D puzzle-platformer for Android, built with Godot 4 (GDScript). You sabotage
data centers to stop capitalists replacing humans with AI.

This README is meant to be enough to set the project up from scratch on a fresh machine,
with no outside help. Commands are for Windows 10/11 (what the project was built on);
macOS/Linux notes are given where the steps differ.

- [1. Requirements](#1-requirements)
- [2. Set up and run on desktop](#2-set-up-and-run-on-desktop)
- [3. Build an Android APK](#3-build-an-android-apk)
- [Play it in a browser (GitHub Pages)](#play-it-in-a-browser-github-pages)
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
   SABOTAGE_LEVEL=test godot --path .   # the test level (a small sandbox) instead of Level 1
   SABOTAGE_PREVIEW=1 godot --path .    # zoomed-out view of the whole level (debug aid)
   SABOTAGE_START="39,78" godot --path .  # start on map tile column,row (debug aid for a big level)
   ```
   With no `SABOTAGE_LEVEL`, the game starts on Level 1. In PowerShell set the variable first:
   `$env:SABOTAGE_LEVEL = "test"; godot --path .`
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

| Action | Keyboard (PC) | Phone |
|---|---|---|
| Move | Left / Right arrows | D-pad left / right |
| Jump | **Space**, **W**, or Up | **JUMP** button, or D-pad up |
| Climb up / down a ladder | Up / Down arrows | D-pad up / down |
| Interact | E | **USE** button |
| Throw an object (weapon) | **Q** | **LIGHT** button |
| Heavy attack | **S** | **HEAVY** button |

Heavy attack is a placeholder for now: the key and button work but `attack_heavy()` in
[scripts/player/player.gd](scripts/player/player.gd) is empty, ready to be filled in.

**Combat.** The light attack throws a random everyday object (a famous painting, a cat photo, a
paintbrush, a vinyl record...: things the AI can't make) in an arc, like a thrown stone
([scripts/player/projectile.gd](scripts/player/projectile.gd)). It takes 50% of an **AI Bro**'s health. AI Bros
([scripts/enemy/ai_bro.gd](scripts/enemy/ai_bro.gd), the zombie sprite) have 20% of the player's health, pace
near their spot or ledge, chase you when you come near and they are facing you, and hit for 10% of your
health. There are two kinds of hazard, with their own classes and sprites. **Spikes** (`^` on the floor, `v` on the
ceiling; [scripts/level/spike_trap.gd](scripts/level/spike_trap.gd)) only hurt: they take 20% of your health
and Bros are immune to them. **Deadly pits** ([scripts/level/pit_hazard.gd](scripts/level/pit_hazard.gd)) kill
anyone (you or a Bro) who falls in: toxic waste (`A`), lava (`F`), nuclear waste (`N`) and a tank of robotic
piranhas (`W`). For the player a pit is GAME OVER and a respawn at
the last checkpoint. Bros never walk off a ledge: they turn round while pacing and stop at an edge while chasing; they climb steps and
hop narrow gaps by jumping, and only notice you within a short range while facing you. Their sensing runs ten
times a second, Bros far from the player sleep (no physics at all), and a dead Bro is freed at once, so a level can
hold many (`tools/tests/enemy_ai_test.gd` checks the movement, the sleeping, and that 200 killed Bros leave nothing
behind). Put a Bro in a level with `B` in the map; it needs enough flat ground to pace on (`LevelData.bro_min_flat_tiles()`,
worked out from its patrol beat and width): the level builder reports a Bro placed where there is not enough room, a
Bro that still ends up cramped is not spawned, and `level1_test.gd` checks every marker.

**Robot piranhas** ([scripts/enemy/piranha.gd](scripts/enemy/piranha.gd)) live in the `W` tanks: they hide under the liquid, pop up
at their own spot and either peek out snapping their jaws or leap to one side, at you when you are near, and a bite takes 10% of
your health. They have no health bar: one thrown object destroys one, and it returns at the same spot a few seconds later (only
then). A tank that is off screen is hidden and does no work (its piranhas, bubbles and glow are switched off), and so is any enemy
far from the player. `tools/tests/piranha_test.gd` checks all of this. Damage numbers are fractions of
`Player.MAX_HEALTH` (see the constants in those scripts). `tools/tests/enemy_test.gd` checks all of this.

**Phone layout** ([scripts/ui/touch_controls.gd](scripts/ui/touch_controls.gd)): an 8-way D-pad at
the bottom-left (slide your thumb around it; up+right together makes a diagonal), and the four
buttons in a diamond at the bottom-right. Several fingers work at once (steer with the D-pad while
tapping JUMP), you can slide a thumb between the buttons without lifting it, and the controls stick
to the real screen corners on wide phones.

The controls are deliberately faint so they don't distract (they brighten while pressed). Tune
`IDLE_ALPHA` / `ACTIVE_ALPHA` at the top of `touch_controls.gd`. On phones the camera also scrolls
`TOUCH_SIDE_PADDING` (in `scripts/core/main.gd`) past each end of the level, over some
decorative wall, so the player is never hidden behind the D-pad or the buttons.

**The overlay only appears on phones.** On PC it is not created at all. To try the phone controls
on a PC, set an environment variable first; the left mouse button then acts as a finger:

```bash
SABOTAGE_TOUCH=1 godot --path .        # Git Bash
$env:SABOTAGE_TOUCH = "1"; godot --path .    # PowerShell
```

**Jump vs. climb.** Space / the JUMP button always jump. Up (W / Up arrow / D-pad up) is both jump and
climb, since you never do both at once: when at least 75% of the character overlaps a ladder, Up
grabs it (from the floor at its bottom, or by catching it mid-jump) and Down grabs it from the top
deck. You then snap onto the ladder's centre line and can only move up/down, with no jumping (Space
is ignored), until you reach the top deck or the floor. At the top deck, Up jumps and Down climbs
back down.

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
export/android/shutdown_adb_on_exit = false
```
(The environment variables `JAVA_HOME` and `ANDROID_HOME` fill in the SDK path, but Godot still
needs `java_sdk_path` set in editor settings, or it fails with "A valid Java SDK path is required".)

**`shutdown_adb_on_exit = false` is important.** In the editor this is
Editor Settings > Export > Android > *Shutdown ADB on Exit*. With it on (the default), Godot runs
`adb kill-server` as it quits, and on Windows that call can block forever. Once the Android SDK
is configured, **every** headless Godot command (`--import`, `--export-debug`, `--script ...`)
then hangs instead of exiting. With it off, they exit normally in a few seconds.

**f) Texture compression (already done in this repo).** Android export requires ETC2/ASTC
textures. `project.godot` already has `textures/vram_compression/import_etc2_astc=true`; if you
ever see "ETC2/ASTC texture compression is required", turn it on in Project Settings >
Rendering > Textures > VRAM Compression. The first export after enabling it recompresses every
texture and takes noticeably longer.

### 3.2 Export

```bash
tools/build_apk.sh        # run in Git Bash from the repo root; writes build/sabotage-debug.apk
```
This takes about 1 minute (longer the very first time). It runs Godot in the background, waits for
the "export DONE" line (or an error), makes sure Godot has stopped, and prints
`OK: build/sabotage-debug.apk (29M)` or the tail of `build/export.log`.

Why a script and not just `godot --headless --export-debug ...`? If the
`shutdown_adb_on_exit = false` setting from 3.1e is missing, Godot never exits after a headless
export (success or failure) and your terminal sticks. With the setting in place a plain command
works too, but the script also protects you from that and from a half-configured machine.
You can also export from the editor: Project > Export > "Android Debug (APK)" > Export Project.

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

## Play it in a browser (GitHub Pages)

The game also exports to the web, and a GitHub Action publishes it for free.

**One-time setup**
1. The repository must be **public** (GitHub Pages is free only for public repositories on a free account; a
   private repository needs a paid plan). If you'd rather keep the code private, export the web build
   (below) and upload the `build/web` folder to a free static host such as itch.io (type "HTML") or
   Cloudflare Pages instead.
2. In the repository on GitHub: **Settings > Pages > Source: GitHub Actions**.
3. Push to `main`. The workflow [.github/workflows/pages.yml](.github/workflows/pages.yml) installs Godot
   and its export templates, exports the **Web** preset and deploys it. The link is shown in the workflow
   run (and under Settings > Pages): `https://<your-user>.github.io/<repo-name>/`. If you upgrade Godot,
   change `GODOT_VERSION` in that file to match.

**Build and try it locally** (needs the Godot export templates, installed through the editor once:
Editor > Manage Export Templates)
```bash
mkdir -p build/web
godot --headless --path . --export-release "Web" build/web/index.html
cd build/web && python -m http.server 8060     # then open http://localhost:8060 in a browser
```
(Opening `index.html` as a file does not work: browsers only run WebAssembly from a web server.)

Notes: the web preset uses the single-threaded build, so it needs no special server headers and runs on
GitHub Pages; it is somewhat slower than the app. The phone controls appear in phone browsers (play in
landscape); on a computer you use the keyboard. `SABOTAGE_LEVEL` and the other environment variables do not
exist on the web: it always starts on Level 1. The first load downloads about 10 MB (compressed).

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
python tools/art/generate_tiles.py assets/tiles/kenney_industrial assets/tiles/data_center
python tools/art/generate_machines.py assets/machines/data_center
python tools/art/generate_projectiles.py
python tools/art/generate_pit_hazards.py
python tools/art/generate_icon.py icon.png
```

After regenerating, run `godot --headless --path . --import` so Godot re-imports the PNGs.

| Script | Produces | Tweak here |
|---|---|---|
| `generate_background.py` | 3 parallax layers + 2 LED layers, blurred for depth of field. Each layer is one *storey* of the hall (racks standing on a floor slab, a gantry with stairs and columns) that tiles vertically, so racks never float and the picture never ends. `W` and `H` must match `TILE_W` and `TILE_H` in `scripts/level/background.gd` | `BLUR_*`, colours, rack layout, `*_FLOOR` |
| `generate_tiles.py` | themed ground, ledges, ladders, crates, spikes + regraded props | palette constants at the top |
| `generate_pit_hazards.py` | The deadly-pit art in `assets/pit_hazards/<kind>/`: recolours of Kenney's CC0 lava and water tiles (kept in `tools/art/sources/kenney_platformer_redux/`) for toxic waste, lava, nuclear waste and the piranha tank, plus the robot piranha painted in parts (body, lower jaw, eye glow) so the game can animate its bite. The liquids' motion is `scripts/level/pit_liquid.gdshader` | `recolour()` values, the piranha drawing |
| `generate_projectiles.py` | The 12 throwable objects in `assets/projectiles/pixel_art/` (6 public-domain paintings shrunk to pixel art from `tools/art/sources/`, a cat photo and 5 everyday objects, drawn in code). A new object is listed in `SpriteLibrary.PROJECTILES` | the per-object functions |
| `generate_machines.py` | GPU rack, supercomputer, monitoring station, server tower + LED layers + shadows + the spinning fan blades (`machine_fan.png`). Also **writes `scripts/level/machine_fans.gd` and `scripts/level/machine_screens.gd`** (where each machine's fans and monitor screens sit), so commit those files after regenerating | the per-machine functions |
| `generate_icon.py` | the 512x512 app icon (`icon.png`) | colours, hero pose |

Brightness of the background layers is set at run time in
[scripts/level/background.gd](scripts/level/background.gd) (`*_TINT` constants), not in the images.

The third-party art by Kenney (CC0) is the source for the character poses
(`assets/characters/kenney_platformer/`) and the base tile sprites (`assets/tiles/kenney_industrial/`);
`assets/tiles/kenney_industrial/NAMES.md` maps the pack's numeric file names to the descriptive names
used here. Each folder keeps its `License.txt`.

## 6. Automated checks

Headless scripts in [tools/tests/](tools/tests/) play the real game with simulated input.
Run all of them (about 5 seconds; each has a hard time limit; logs go to `build/test_*.log`):

```bash
tools/run_tests.sh        # Git Bash, from the repo root; exit code 0 = everything passed
```

Or one at a time (they exit non-zero on failure):

```bash
godot_console --headless --fixed-fps 60 --path . --script res://tools/tests/controls_test.gd # key bindings, Space vs Up, no-op actions
godot_console --headless --fixed-fps 60 --path . --script res://tools/tests/ladder_test.gd   # ladder rules
godot_console --headless --fixed-fps 60 --path . --script res://tools/tests/health_test.gd   # damage, death, respawn
godot_console --headless --fixed-fps 60 --path . --script res://tools/tests/touch_test.gd    # D-pad + 4 buttons
godot_console --headless --fixed-fps 60 --path . --script res://tools/tests/fans_test.gd     # machine fans spin, on their housings
godot_console --headless --fixed-fps 60 --path . --script res://tools/tests/screens_test.gd  # live monitors: layout, text fit, the AI job
godot_console --headless --fixed-fps 60 --path . --script res://tools/tests/assets_test.gd   # every image is where the layout rules say
godot_console --headless --fixed-fps 60 --path . --script res://tools/tests/hud_clearance_test.gd # player never hidden behind the controls
godot_console --headless --fixed-fps 60 --path . --script res://tools/tests/level_bot.gd     # bot beats the test level
godot_console --headless --fixed-fps 60 --path . --script res://tools/tests/fall_test.gd     # fall death, level selection
godot_console --headless --fixed-fps 60 --path . --script res://tools/tests/minigame_test.gd  # all 10 unlock puzzles: solvable, fair, fit the popup, random
godot_console --headless --fixed-fps 60 --path . --script res://tools/tests/laser_test.gd    # laser walls, computers, the puzzle popup
godot_console --headless --fixed-fps 60 --path . --script res://tools/tests/level1_test.gd   # Level 1: finishable, no dead ends, pits not skippable (~1 min)
```

Most tests pin the **test level** (they set `SABOTAGE_LEVEL=test` themselves), because they rely on its
exact layout. `level_bot.gd` is specific to the test level's layout. `level1_test.gd` checks Level 1
with `tools/tests/lib/level_solver.gd`, which simulates the player's jumps from every spot to build a
map of where you can get to. To inspect a level while designing it:
`SABOTAGE_LEVEL=1 godot_console --headless --path . --script res://tools/solve_level.gd`.
`--fixed-fps 60` makes the simulation deterministic and fast.

Two traps if you write your own headless tests:
- Don't put `await` inside `_process`: a coroutine's return value makes Godot quit silently with
  exit code 0 (looks like a pass, ran nothing). Start the async work from a separate function.
- Headless has no real window, so feed simulated touches with `root.push_input(event, true)`;
  `Input.parse_input_event` delivers nothing there.

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
    machine_fans.gd         GENERATED (by generate_machines.py): where each machine's spinning fans sit
    machine_screens.gd      GENERATED (by generate_machines.py): where each machine's monitor screens sit
    monitor_screen.gd       The live monitor displays (graph, "AI job" terminal, oscilloscope); all its strings and
                            timings are documented constants at the top, and it shrinks text that wouldn't fit
    sprite_library.gd       The only place that knows where art lives on disk
  ui/
    touch_controls.gd       On-screen buttons for phones
    vignette.gd             Darkened screen edges
assets/                     Art, nested as  component / style / group / file  (see "Asset layout" below)
tools/
  build_apk.sh              Builds build/sabotage-debug.apk (works around Godot's hanging headless export)
  run_tests.sh              Runs every headless test in tools/tests/ with time limits
  art/                      Art generators (section 5)
  tests/                    Headless playtests (section 6)
build/                      Export output (git-ignored): APK, AAB, export.log
```

### Asset layout

Art is nested as `assets/<component>/<style>/<group>/<file>.png`. File names are never changed by
the layout, so a sprite's name is enough to find it, and `SpriteLibrary` is the only code that
knows the folders.

```
assets/
  characters/
    kenney_platformer/             Kenney's cartoon characters (style)
      player/ adventurer/ female/ soldier/ zombie/    24 poses each: <character>_<pose>.png
  tiles/                           level tiles and props
    kenney_industrial/             the original Kenney set (CC0); NAMES.md maps its old numeric ids
      terrain/ structure/ equipment/ hazards/ lights/ signage/
    data_center/                   our themed replacements, same names and same category folders
      terrain/ structure/ equipment/ hazards/ lights/ signage/
  machines/
    data_center/                   generated machines (style)
      gpu_rack/ supercomputer/ monitoring_station/ server_tower/    image + _leds_a/_leds_b + _shadow
      parts/                       shared moving parts (the fan blades)
  backgrounds/
    data_center/                   the five parallax layers
```

How a name becomes a folder:

- **Tiles:** the first word of the name picks the category, for example `ground_start` -> terrain,
  `siren_blue` -> lights. The word-to-category table is `SpriteLibrary.TILE_CATEGORIES`.
- **Machines:** the machine is the name without the `machine_` prefix and without
  `_leds_a`, `_leds_b` or `_shadow`: `machine_gpu_rack_shadow` -> `gpu_rack/`.
- **Themed over original:** `SpriteLibrary.tile()` uses the sprite from `tiles/data_center/` when one
  exists with the requested name, and falls back to `tiles/kenney_industrial/` otherwise.

To add art: put the file in the right folder with the right name (a new kind of tile also needs its
first word added to `TILE_CATEGORIES`). `tools/tests/assets_test.gd` checks that every file is
where the rules say and that everything loads, so a misplaced file fails `tools/run_tests.sh`.
Godot creates the `.import` file next to each image the first time you import.

## 8. Designing levels

Levels are ASCII grids in `scripts/level/level_data.gd`, one character per tile (tile size is `Level.T`; legend at
the top of that file, including how to place multi-tile machines). Ground/ledge/slime tiles pick
their start/middle/end variant automatically from neighbouring tiles.

The jump limits you design around come from the movement constants in
`scripts/player/player.gd`, so they change whenever you retune the controls. The comment above
each constant has the formulas; in short:

- maximum step height = `JUMP_VELOCITY`² / (2 · `GRAVITY`)
- maximum gap you can jump = `SPEED` · air time, where air time = 2 · |`JUMP_VELOCITY`| / `GRAVITY`

Work them out from the current values (tile size is `Level.T`) and keep steps and gaps
comfortably inside them, so levels stay fair. After retuning, run `tools/run_tests.sh`: the
Level 1 test will tell you if the level became unbeatable or has a dead end.

**Level 1 is four floors tall** (149 x 67 tiles): floor 0 runs left to right through deadly pits, spike strips,
crate hurdles, laser tunnels, stepping-stone pits and crate stairs, then a tower of ladders and ledges climbs
onto floor 1, which runs right to left, and so on up to the exit on floor 3. It is built from small *pieces*
(`_s_pit`, `_s_tunnel`, `_s_stones`, `_s_gauntlet`, `_s_deck`...) listed per floor in `_l1_plan()`; each piece
starts and ends on flat floor so they join in any order, and the odd floors are drawn facing right and then
mirrored. To change a floor, edit its plan. `tools/tests/level1_test.gd` solves the whole level (and each
laser, and the no-stones and no-ladders variants) and checks that a floor is no longer finishable if a piece
is made impossible; `SABOTAGE_FLOOR=2 godot_console --headless --path . --script res://tools/solve_level.gd`
prints and solves one floor.

There are two levels: **Level 1** (`level_1()`, drawn with the `LevelGrid` helpers in
`scripts/level/level_grid.gd`: `slab`, `ledge`, `ladder`, `spikes`, `crate_stack`...) and the **test
level** (`test_level()`), a sandbox that must not be changed. Checkpoints (`K`) set where you respawn.
Falling further than `Player.FALL_DEATH_HEIGHT` kills you, measured from the top of the fall.

**Laser force fields and computers.** A digit `1`-`9` in the map is a laser field (draw one with
`LevelGrid.laser(column, first_row, last_row, id)`); while on it is a solid wall. Each field is switched
off by one computer: put the lock terminal letter `L` (a special 2x3 machine with a single screen, used only for this) in the map and list it in `LevelData.terminals()`
with the field's id and the puzzle to show (`random`, the default in Level 1, picks a different one every time). Stand in front of the computer and
press E (USE on a phone) to open the puzzle in a popup; solving it switches the field off. The terminal's screen shows a red padlock and ACCESS RESTRICTED while the field is on, and a green open padlock and ACCESS GRANTED once it is off. The 10 puzzles are `Minigame` subclasses in `scripts/ui/minigames/`: memory pads, a timing bar, "don't press the red button" (3 s timer bar), "press the button that SAYS green" (colours lie), a dodging "I am not a robot" captcha, "wrong answers only" quiz, a pun quiz, red-dot counting, button mashing and Simon says. To add one, subclass `Minigame` (or `QuizGame` for multiple choice), give it `auto_solve()` / `auto_fail()` test hooks and register it in `HackPopup` (`GAME_NAMES`, `_make_game`); `tools/tests/minigame_test.gd` then checks it. Always put a computer
where the player can reach it before its laser; `tools/tests/level1_test.gd` checks that.
Lamps, sirens and canisters must stand on a floor, slab or ledge (the same test checks nothing floats).

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
| A headless Godot command (`--import`, `--export-debug`, `--script`) never returns once Android is set up | Godot's "Shutdown ADB on Exit" runs `adb kill-server`, which blocks on Windows. Set `export/android/shutdown_adb_on_exit = false` (section 3.1e). You can recognise it: Godot sits at near-zero CPU, and Task Manager shows an `adb.exe kill-server` child that never ends. |
| A command is stuck right now | Stop it by process id (`Stop-Process -Id <pid>` in PowerShell, or `taskkill //F //T //PID <pid>` in Git Bash), including its `adb.exe` child. Don't pipe Godot's output through a filter such as `Select-String`: it hides all progress until the process exits. |
| Two Godot instances on the same project | Stop the stuck one first. Chained commands (`import; import; export`) keep launching the next step each time you kill one. |
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

Art by [Kenney](https://kenney.nl) (CC0): Platformer Pack: Industrial, Platformer Characters 1, and the lava and water tiles of Platformer Pack Redux (the base of the deadly pits' liquids).

The thrown paintings are pixel-art reductions of public-domain works, from Wikimedia Commons: Mona Lisa
(Leonardo da Vinci), The Starry Night (Vincent van Gogh), The Great Wave off Kanagawa (Hokusai), Girl with a
Pearl Earring (Johannes Vermeer), The Scream (Edvard Munch) and Vitruvian Man (Leonardo da Vinci). The
originals are in `tools/art/sources/`.
