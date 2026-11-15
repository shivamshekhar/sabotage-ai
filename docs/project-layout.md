# Project layout

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
    level.gd                Builds a level from its tiles (sprites, colliders, hazards, lights)
    level_data.gd           Finds the levels in levels/ and reads their files; the test level; the piece builder behind the level CLI
    level_file.gd           Reads, writes and checks level files (*.sablevel.json, tiles as CSV numbers)
    tile_registry.gd        The registry of every tile kind (levels/common/tile_registry.json)
    background.gd           Parallax data-center background (3 depth layers, blinking LEDs)
    machine_fans.gd         GENERATED (by generate_machines.py): where each machine's spinning fans sit
    machine_screens.gd      GENERATED (by generate_machines.py): where each machine's monitor screens sit
    monitor_screen.gd       The live monitor displays (graph, "AI job" terminal, oscilloscope); all its strings and
                            timings are documented constants at the top, and it shrinks text that wouldn't fit
    sprite_library.gd       The only place that knows where art lives on disk
  ui/
    touch_controls.gd       On-screen buttons for phones
    vignette.gd             Darkened screen edges
levels/                     One folder per level (level.sablevel.json + background/) and common/ (art shared by all levels)
assets/                     Characters and thrown objects, nested as  component / style / group / file  (see art.md)
tools/
  build_apk.sh              Builds build/sabotage-debug.apk (works around Godot's hanging headless export)
  run_tests.sh              Runs every headless test in tools/tests/ with time limits
  level_cli.sh              The level command-line tool (create, edit, check level files)
  level_editor.sh           Opens the level editor
  level_editor/             The editor, the CLI code, the catalog and the file format docs
  art/                      Art generators (art.md)
  tests/                    Headless playtests (testing.md)
build/                      Export output (git-ignored): APK, AAB, export.log
```


