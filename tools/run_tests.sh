#!/usr/bin/env bash
# Runs every headless test in tools/tests/ and prints a summary. Exit code 0 = all passed.
#
# Usage (Git Bash, from anywhere):  tools/run_tests.sh
#   Optional env vars:
#     GODOT=/path/to/Godot_..._console.exe   (default: the winget install)
#     REPEAT=n                               run every test n times (to find a test that fails now and then; default 1)
#     ONLY=name                              run only tools/tests/name.gd
#
# Each test gets a hard time limit, so a hung Godot can't block this script. If tests hang,
# check README.md section 9 (Godot's "Shutdown ADB on Exit" setting). Logs go to tmp/test_logs/ (git-ignored).
set -u
cd "$(dirname "$0")/.."

GODOT="${GODOT:-$LOCALAPPDATA/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe}"
if ! command -v "$GODOT" > /dev/null; then
  echo "Godot not found at: $GODOT (set GODOT=...)" >&2
  exit 2
fi

REPEAT="${REPEAT:-1}"
ONLY="${ONLY:-}"
mkdir -p tmp/test_logs
failed=0
for t in tools/tests/*.gd; do
  name=$(basename "$t" .gd)
  if [ -n "$ONLY" ] && [ "$ONLY" != "$name" ]; then
    continue
  fi
  for run in $(seq 1 "$REPEAT"); do
    log="tmp/test_logs/$name.log"
    label="$name"
    if [ "$REPEAT" -gt 1 ]; then
      label="$name (run $run of $REPEAT)"
    fi
    start=$(date +%s)
    timeout 600 "$GODOT" --headless --fixed-fps 60 --path . --script "res://$t" > "$log" 2>&1
    code=$?
    secs=$(( $(date +%s) - start ))
    # Count FAIL lines too: a test that exits 0 but printed FAIL (or no verdict) is a failure.
    # Also fail on any engine or script error in the log (for example a sprite that failed to load).
    if [ "$code" -eq 0 ] && ! grep -q "^FAIL\|SOME FAILED\|SCRIPT ERROR\|^ERROR:" "$log" && grep -q "ALL PASS\|^PASS$\|^WIN" "$log"; then
      echo "PASS  $label (${secs}s)"
    else
      echo "FAIL  $label (exit $code, ${secs}s) -> see $log"
      grep "^FAIL" "$log" | head -5
      failed=1
      cp "$log" "tmp/test_logs/$name.failed.log"
    fi
  done
done
exit "$failed"
