# Project layout

```
export_presets.cfg          Android export presets (no secrets)
icon.png                    App icon (generated)
scenes/
  title.tscn                The game's starting scene: the title screen (runs ui/title/title_screen.gd)
  main.tscn                 The game itself: a level (just runs core/main.gd)
scripts/
  common/                   Reusable pieces any feature can use
    constants/              Groups, InputActions, PhysicsLayers, AssetPaths: the names, layers and paths (no other script writes them as strings)
    audio/                  AudioBuses (the Music and SFX buses), Sfx (one-shot sound effects)
    effects/                Explosion, Debris, HeldEffect (ElectricArc, EnergyBeam), ParticlePreset, GlowPulse, WhiteFlash, GroundShadow, EffectWarmUp: anything that makes a visual effect
    ui/                     HealthBar, ScorePopups, Vignette, HazardStrip, Scanlines, SegmentedMeter, ScreenFlash: generic interface pieces
    util/                   Sprites, Blend, Geom, Energy, WarmUp, SpriteBatch, OffscreenSleeper: small helpers (sprite settings, blend materials, segment/rectangle geometry, an energy tank, jobs done a few a frame, many tiles in a few nodes, things that sleep off screen)
  core/
    main.gd                 Wires level, player, camera, touch UI, vignette, win banner
    input_setup.gd          Registers the input actions (touch uses the same ones) and loads the settings
    settings.gd             The player's settings file (volumes, keys); key_bindings.gd the keys of each action, their defaults and changing them
    game_stats.gd           The score and what is carried to the next level (health, the vehicle)
    music_player.gd         The looping music (a track per level kind)
  player/
    player.gd               Movement, ladders, health/damage, respawn, vehicle hooks
    damage_over_time.gd     One poison or burn (ticks of damage); the player has one of each
    player_sprite.gd        Picks the character pose; flinch, blink and idle animations
    character_poses.gd      Which pictures show which state of a character (the hero's parts and their order)
    wardrobe_catalog.gd     What the hero can wear: the slots, their styles and colours, how a picture is recoloured
    outfit.gd, wardrobe.gd  What the hero wears (an Outfit), and the one being worn, kept in user://outfit.cfg
    outfit_composer.gd      Puts the parts of a pose together for an outfit (recoloured, kept)
    player_shadow.gd        Halo behind the body + a GroundShadow on the floor (it stays on the floor when the player jumps, smaller and fainter the higher they are)
    projectile.gd           The everyday objects the player throws
  enemy/                    AI Bro, pit creatures
  boss/                     RAM Saltman and the fight (BossFight)
  vehicle/                  The mech: rules (Mech), look and legs (MechVisual), missile, laser beam
  powerup/                  The power-up box and what it gives
  level/
    level.gd                Builds a level from its tiles (sprites, colliders, hazards, lights)
    exit_door.gd            The exit door: slides open, takes the player in, finishes the level (also on the title screen)
    level_data.gd           Finds the levels in levels/ and reads their files; the test level; the piece builder behind the level CLI
    level_file.gd           Reads, writes and checks level files (*.sablevel.json, tiles as CSV numbers)
    tile_registry.gd        The registry of every tile kind (levels/common/tile_registry.json)
    background.gd           Parallax data-center background (3 depth layers, blinking LEDs)
    machine_fans.gd         GENERATED (by generate_machines.py): where each machine's spinning fans sit
    machine_screens.gd      GENERATED (by generate_machines.py): where each machine's monitor screens sit
    monitor_screen.gd       The live monitor displays (graph, "AI job" terminal, oscilloscope); all its strings and
                            timings are documented constants at the top, and it shrinks text that wouldn't fit
    sprite_library.gd       Knows how a tile / machine / pose name becomes a file (folders come from AssetPaths)
  ui/
    hud.gd                  Score and level number
    touch_controls.gd       On-screen buttons for phones (X, Y, A, B)
    hack_popup.gd, hack_style.gd, minigames/   The unlock puzzle window (its look: HackStyle) and the puzzles
    pause_button.gd, pause_menu.gd   The menu button in the game's top-right corner and the pause menu it opens (resume, settings, quit to title)
    settings_panel.gd       The settings window: volumes, and the keys (PC) or the touch buttons (phone)
    wardrobe_panel.gd       The wardrobe window: the hero as dressed, a row per slot (style arrows, colour swatches)
    title/                  The title screen: TitleScreen (the scene), TitleBackdrop (the distant out-of-focus view, defocus.gdshader), TitleMenu, TitleBro
levels/                     Level data only: one folder per level (level.sablevel.json) and common/ (the tile registry)
assets/                     ALL pictures and sounds, as <category>/<feature>/: levels/ (tiles, machines, pit hazards, backgrounds), vehicles/mech/, powerups/box/,
                            bosses/saltman/, characters/ (saboteur/, kenney_platformer/), projectiles/, fonts/ (press_start_2p: the game's font), effects/ (generic), ui/ (icons/, captcha/, title/), audio/ (music/, sfx/) (see art.md)
tools/
  lint.sh                   gdlint (GDScript, gdlintrc) and prettier (docs, settings); --fix repairs the formatting
  install_hooks.sh          Turns on the pre-commit hook (tools/hooks/pre-commit)
  hooks/                    The git hooks: pre-commit runs lint, tests and every build
  export_preset.sh          Exports one preset and checks the file was made (works around Godot's hanging headless export)
  build_all.sh              Builds web, Windows, Linux and the Android APK into build/ (git-ignored)
  build_apk.sh              Builds build/sabotage-debug.apk (works around Godot's hanging headless export)
  run_tests.sh              Runs every headless test in tools/tests/ with time limits (REPEAT=n to hunt flaky tests)
  audit_assets.py           Lists assets and scripts nothing uses (dead files); rules in audit_rules.json
  sync_editor.py            Adds every new tile picture to the tile registry so the level editor offers it
  level_cli.sh              The level command-line tool (create, edit, check level files)
  level_editor.sh           Opens the level editor
  level_editor/             The editor, the CLI code, the catalog and the file format docs
  art/                      Art generators (art.md)
  tests/                    Headless tests (testing.md); lib/ has the level solver, the generic level checks and the test arena
build/                      Export output (git-ignored): APK, AAB, export.log
tmp/                        Scratch space for temporary scripts, screenshots, logs and art previews (git-ignored; created on demand by the scripts that use it)
.claude/                    Rules for AI agents working on the project (CLAUDE.md and rules/)
```
