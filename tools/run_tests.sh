#!/usr/bin/env bash
# Runs every headless test in tools/tests/ and prints a summary. Exit code 0 = all passed.
#
# Usage (Git Bash, from anywhere):  tools/run_tests.sh
#   Optional env var:  GODOT=/path/to/Godot_..._console.exe   (default: the winget install)
#
# Each test gets a hard time limit, so a hung Godot can't block this script. If tests hang,
# check README.md section 9 (Godot's "Shutdown ADB on Exit" setting).
set -u
cd "$(dirname "$0")/.."

GODOT="${GODOT:-$LOCALAPPDATA/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe}"
if [ ! -f "$GODOT" ]; then
  echo "Godot not found at: $GODOT (set GODOT=...)" >&2
  exit 2
fi

mkdir -p build
failed=0
for t in tools/tests/*.gd; do
  name=$(basename "$t" .gd)
  log="build/test_$name.log"
  start=$(date +%s)
  timeout 180 "$GODOT" --headless --fixed-fps 60 --path . --script "res://$t" > "$log" 2>&1
  code=$?
  secs=$(( $(date +%s) - start ))
  # Count FAIL lines too: a test that exits 0 but printed FAIL (or no verdict) is a failure.
  # Also fail on any engine or script error in the log (for example a sprite that failed to load).
  if [ "$code" -eq 0 ] && ! grep -q "^FAIL\|SOME FAILED\|SCRIPT ERROR\|^ERROR:" "$log" && grep -q "ALL PASS\|^PASS$\|^WIN" "$log"; then
    echo "PASS  $name (${secs}s)"
  else
    echo "FAIL  $name (exit $code, ${secs}s) -> see $log"
    grep "^FAIL" "$log" | head -5
    failed=1
  fi
done
exit "$failed"
