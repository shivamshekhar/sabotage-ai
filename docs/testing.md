# Automated checks

Headless scripts in [tools/tests/](../tools/tests/) play the real game with simulated input.
Run all of them (about 5 seconds; each has a hard time limit; logs go to `tmp/test_logs/`):

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
godot_console --headless --fixed-fps 60 --path . --script res://tools/tests/levels_test.gd         # the campaign: chained levels, titles, backgrounds
godot_console --headless --fixed-fps 60 --path . --script res://tools/tests/level_traversal_test.gd # ANY level can be played: exit reachable, no dead ends, gates, power-up box (LEVEL=id or LEVEL_FILE=path for one)
godot_console --headless --fixed-fps 60 --path . --script res://tools/tests/powerup_levels_test.gd # the power-up boxes and laser gates of every level, with the real physics
godot_console --headless --fixed-fps 60 --path . --script res://tools/tests/mech_test.gd           # the mech: size, legs, booster, energy, weapons, damage stages (in the test arena)
godot_console --headless --fixed-fps 60 --path . --script res://tools/tests/energy_test.gd         # the player's energy bar, bleeding, radiation sickness, the mech weapons' rays
godot_console --headless --fixed-fps 60 --path . --script res://tools/tests/carry_test.gd          # carry-over between levels, points text, repair, spikes, walls
godot_console --headless --fixed-fps 60 --path . --script res://tools/tests/wardrobe_test.gd            # the wardrobe: every style and colour has its pictures, the outfit (set, step, save, load), the pictures made for an outfit, the hero's sprite wearing it, the window
godot_console --headless --fixed-fps 60 --path . --script res://tools/tests/ground_shadow_test.gd      # the player's shadow lies on the floor under the feet, stays there in a jump, shrinks and fades with the height, is gone with no floor in reach
godot_console --headless --fixed-fps 60 --path . --script res://tools/tests/emp_test.gd            # the EMP gun: fires while the button is held, 40 damage every 0.6 s, 1.5 s of energy, reach, one held bolt, the gun in the hand, no fire in the mech
godot_console --headless --fixed-fps 60 --path . --script res://tools/tests/door_test.gd           # the exit door: opens as you near it, takes you in (on foot and in the mech), finishes the level once
godot_console --headless --fixed-fps 60 --path . --script res://tools/tests/settings_test.gd       # volumes and audio buses, key bindings (change, clash, reserved, file), the block meter, the settings window
godot_console --headless --fixed-fps 60 --path . --script res://tools/tests/pause_menu_test.gd    # the in-game menu button and pause menu: resume, settings, quit to title
godot_console --headless --fixed-fps 60 --path . --script res://tools/tests/sfx_test.gd             # every sound in Sfx loads, the throw sounds, the looping booster, a SfxLoop fades out
godot_console --headless --fixed-fps 60 --path . --script res://tools/tests/title_test.gd          # the title screen: menu, prompt, backdrop, starting with Enter or a tap, the white flash
godot_console --headless --fixed-fps 60 --path . --script res://tools/tests/editor_sync_test.gd    # the level editor offers everything the game has
godot_console --headless --fixed-fps 60 --path . --script res://tools/tests/solver_calibration_test.gd # the solver's jump matches the engine's
godot_console --headless --fixed-fps 60 --path . --script res://tools/tests/level_file_test.gd    # level files: read, write, validate, play
godot_console --headless --fixed-fps 60 --path . --script res://tools/tests/level_cli_test.gd     # the level command-line tool
godot_console --headless --fixed-fps 60 --path . --script res://tools/tests/editor_test.gd        # the level editor
```

**Rules for tests** (details in [.claude/rules/testing.md](../.claude/rules/testing.md)): they must pass every time (`REPEAT=5 tools/run_tests.sh` runs
each one five times to find flakiness); tests of one element's behaviour run in the test arena (`tools/tests/lib/test_arena.gd`) or the test level, never in
a real level; tests of the real levels are generic (`lib/level_checks.gd`) and never look at where a tile is placed; scratch scripts and screenshots go in
`tmp/`, which is git-ignored.

Most tests pin the **test level** (they set `SABOTAGE_LEVEL=test` themselves), because they rely on its
exact layout. `level_bot.gd` is specific to the test level's layout. `levels_test.gd` checks every level in `levels/`
with `tools/tests/lib/level_solver.gd`, which simulates the player's jumps from every spot to build a
map of where you can get to. To inspect a level while designing it:
`SABOTAGE_LEVEL=level_01 godot_console --headless --path . --script res://tools/solve_level.gd`.
`--fixed-fps 60` makes the simulation deterministic and fast.

Two traps if you write your own headless tests:

- Don't put `await` inside `_process`: a coroutine's return value makes Godot quit silently with
  exit code 0 (looks like a pass, ran nothing). Start the async work from a separate function.
- Headless has no real window, so feed simulated touches with `root.push_input(event, true)`;
  `Input.parse_input_event` delivers nothing there.

## Lint and formatting

`tools/lint.sh` checks the code without running the game (`tools/lint.sh --fix` also repairs the formatting):

- **GDScript:** [gdlint](https://github.com/Scony/godot-gdscript-toolkit) on every `.gd` file. Install it with `python -m pip install --user gdtoolkit`. The settings are in [gdlintrc](../gdlintrc): a rule is switched off there only with a reason written next to it.
- **Text files:** [prettier](https://prettier.io) on the docs, workflows and settings (`npm ci` installs the pinned version; settings in `.prettierrc.json`). GDScript is not formatted by it. What a tool writes itself (levels, the tile registry, generated manifests) is listed in `.prettierignore`: add a new generated file there.

The same checks run in CI ([ci.yml](../.github/workflows/ci.yml)): lint, asset audit, every test, and the web, Windows, Linux and Android builds, on every push and pull request.

## Before every commit (the pre-commit hook)

Run `tools/install_hooks.sh` once per clone. After that git runs [tools/hooks/pre-commit](../tools/hooks/pre-commit) before every commit, and the commit is refused unless all of this passes:

1. no build output is staged (`build/` is git-ignored; the hook also stops a forced `git add -f`);
2. `tools/lint.sh`: **gdlint** on every `.gd` file (settings in [gdlintrc](../gdlintrc)) and **prettier** on the docs and settings files (settings in `.prettierrc.json`; the files tools write themselves are listed in `.prettierignore`). `tools/lint.sh --fix` fixes the formatting;
3. `python tools/audit_assets.py` and `python tools/sync_editor.py --check`;
4. `tools/run_tests.sh`, every test;
5. `tools/build_all.sh`: the **web**, **Windows**, **Linux** and **Android APK** builds (presets in `export_presets.cfg`, each made by `tools/export_preset.sh`), into `build/`.

It needs `pip install --user gdtoolkit`, Node (`npm ci` runs by itself) and the Godot export templates (see [android.md](android.md)). It takes a few minutes. `git commit --no-verify` skips it in an emergency.
