#!/usr/bin/env bash
# Exports one preset of export_presets.cfg and checks that the file was made.
#
# Usage:  tools/export_preset.sh "<preset name>" <output file> [debug|release]     (default: release)
#   Optional env vars:  GODOT=/path/to/Godot_..._console.exe   (default: the winget install)
#
# Why it does not simply call `godot --export-...` and wait: by default Godot runs `adb kill-server` when it quits ("Shutdown ADB on
# Exit"), and on Windows that call can block forever, so *every* headless Godot command hangs once the Android SDK is configured. The
# real fix is the editor setting export/android/shutdown_adb_on_exit = false (README.md, section 3.1e). This script is the safety net
# in case that setting is missing: it runs Godot in the background, waits for the "export DONE" line (or an error), and stops the
# Godot process tree if it still hasn't exited. The log is next to the output: <output>.log
set -u
cd "$(dirname "$0")/.."

PRESET="${1:?usage: tools/export_preset.sh \"<preset name>\" <output file> [debug|release]}"
OUT="${2:?usage: tools/export_preset.sh \"<preset name>\" <output file> [debug|release]}"
MODE="${3:-release}"
GODOT="${GODOT:-$LOCALAPPDATA/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe}"

# WAIT_SECONDS: how long one export may take (the first run recompresses all the textures). Raise it on a slow machine.
WAIT_SECONDS=900

if ! command -v "$GODOT" > /dev/null; then
  echo "Godot not found at: $GODOT" >&2
  echo "Set GODOT=/path/to/Godot_v4.7.2-stable_win64_console.exe" >&2
  exit 2
fi

LOG="$OUT.log"
mkdir -p "$(dirname "$OUT")"
rm -f "$OUT" "$OUT.idsig"
: > "$LOG"

"$GODOT" --headless --path . "--export-$MODE" "$PRESET" "$OUT" > "$LOG" 2>&1 &
PID=$!

stop_godot() {
  # Kill the whole Windows process tree (the console wrapper starts the real Godot as a child).
  local winpid
  winpid=$(cat "/proc/$PID/winpid" 2>/dev/null || echo "$PID")
  taskkill //F //T //PID "$winpid" > /dev/null 2>&1 || kill "$PID" 2> /dev/null
}

status=1
for _ in $(seq 1 "$WAIT_SECONDS"); do
  if ! kill -0 "$PID" 2> /dev/null; then
    # Godot exited by itself.
    if [ -s "$OUT" ] && ! grep -q "Cannot export project with preset\|Project export for preset.*failed\|^ERROR:" "$LOG"; then status=0; fi
    break
  fi
  if grep -q "DONE.*export" "$LOG" && [ -s "$OUT" ]; then
    sleep 2
    stop_godot
    status=0
    break
  fi
  if grep -q "Cannot export project with preset\|Project export for preset.*failed" "$LOG"; then
    stop_godot
    break
  fi
  sleep 1
done

if [ "$status" -eq 0 ]; then
  echo "OK: $PRESET -> $OUT ($(du -h "$OUT" | cut -f1))"
else
  echo "FAILED: $PRESET. Last lines of $LOG:" >&2
  tail -n 15 "$LOG" >&2
  stop_godot
fi
exit "$status"
