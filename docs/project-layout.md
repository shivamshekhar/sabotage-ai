# Project layout

```
export_presets.cfg          Android export presets (no secrets)
icon.png                    App icon (generated)
scenes/
  main.tscn                 Entry scene (just runs core/main.gd)
scripts/
  common/                   Reusable pieces any feature can use
    constants/              Groups, InputActions, PhysicsLayers, AssetPaths: the names, layers and paths (no other script writes them as strings)
    effects/                Explosion, Debris, ParticlePreset: anything that makes a visual effect
    ui/                     HealthBar, ScorePopups, Vignette: generic interface pieces
    util/                   Sprites, Blend, Geom: small helpers (sprite settings, blend materials, segment/rectangle geometry)
  core/
    main.gd                 Wires level, player, camera, touch UI, vignette, win banner
    input_setup.gd          Registers keyboard input actions (touch uses the same ones)
    game_stats.gd           The score and what is carried to the next level (health, the vehicle)
    music_player.gd         The looping music (a track per level kind)
  player/
    player.gd               Movement, ladders, health/damage, respawn, vehicle hooks
    damage_over_time.gd     One poison or burn (ticks of damage); the player has one of each
    player_sprite.gd        Picks the character pose; flinch and blink animations
    player_shadow.gd        Halo + contact shadow that lift the player off the background
    projectile.gd           The everyday objects the player throws
  enemy/                    AI Bro, pit creatures
  boss/                     RAM Saltman and the fight (BossFight)
  vehicle/                  The mech: rules (Mech), look and legs (MechVisual), missile, laser beam
  powerup/                  The power-up box and what it gives
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
    sprite_library.gd       Knows how a tile / machine / pose name becomes a file (folders come from AssetPaths)
  ui/
    hud.gd                  Score and level number
    touch_controls.gd       On-screen buttons for phones
    hack_popup.gd, minigames/   The unlock puzzles
levels/                     One folder per level (level.sablevel.json + background/) and common/ (art shared by all levels)
assets/                     effects/ (generic: explosion, smoke, fire, sparks, glows), powerups/, bosses/, characters/, captcha/, projectiles/ (see art.md)
tools/
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


