# Automated checks

Headless scripts in [tools/tests/](../tools/tests/) play the real game with simulated input.
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
godot_console --headless --fixed-fps 60 --path . --script res://tools/tests/levels_test.gd         # every level in levels/: finishable, no dead ends, laser order, backgrounds
godot_console --headless --fixed-fps 60 --path . --script res://tools/tests/solver_calibration_test.gd # the solver's jump matches the engine's
godot_console --headless --fixed-fps 60 --path . --script res://tools/tests/level_file_test.gd    # level files: read, write, validate, play
godot_console --headless --fixed-fps 60 --path . --script res://tools/tests/level_cli_test.gd     # the level command-line tool
godot_console --headless --fixed-fps 60 --path . --script res://tools/tests/editor_test.gd        # the level editor
```

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


