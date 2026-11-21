# Testing rules

- Every test is a script in `tools/tests/` that prints `PASS`/`FAIL` lines, ends with `ALL PASS` or `SOME FAILED` and exits non-zero on failure.
  `tools/run_tests.sh` runs them all (logs in `tmp/test_logs/`). `REPEAT=n tools/run_tests.sh` runs each n times to find flakiness.
- **Tests must not be flaky.** Never depend on timing luck, random values or frame-perfect input: seed or bound randomness, wait for a condition
  (`while not cond: await process_frame` with a cap) instead of a fixed number of frames when you can, and give margins. A test that fails once in a
  while is a bug: fix it, do not rerun it. After adding a test, run it several times.
- **Element tests** (a mech, a box, spikes, a ladder, a wall, an enemy) are unit tests of one interaction and stay. They run in a purpose-built level
  (`tools/tests/lib/test_arena.gd` + `tools/tests/fixtures/arena.sablevel.json`) or in the code-built test level, never in a real level, so redesigning a
  level never breaks them.
- **Level tests are generic.** `tools/tests/level_traversal_test.gd` (checks in `tools/tests/lib/level_checks.gd`) takes any level and asks whether it can
  be played: exit reachable, no dead ends, gates have computers and really block, power-up box reachable. Do not write tests that check where a tile or an
  enemy is placed. `LEVEL=level_03` or `LEVEL_FILE=path` runs it on one level.
- Scratch tests, probes and screenshots go in `tmp/`, never in `tools/tests/` unless they are meant to stay.
- Headless limits: no music, no real window. Do not `await` inside `_process`. After adding scripts or assets run `godot --headless --path . --import`.
