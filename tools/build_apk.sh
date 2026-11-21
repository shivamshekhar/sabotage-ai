#!/usr/bin/env bash
# Builds the Android debug APK: build/sabotage-debug.apk
#
# Usage (Git Bash, from anywhere):  tools/build_apk.sh
#   Optional env vars:  GODOT=/path/to/Godot_..._console.exe   (default: the winget install)
#
# Why this wrapper exists: by default Godot runs `adb kill-server` when it quits ("Shutdown ADB
# on Exit"), and on Windows that call can block forever, so *every* headless Godot command
# (--import, --export-debug, --script ...) hangs instead of exiting once the Android SDK is
# configured. The real fix is the editor setting export/android/shutdown_adb_on_exit = false
# (see README.md, section 3.1e). This script is the safety net in case that setting is missing:
# it runs Godot in the background, waits for the "export DONE" line (or an error), and stops the
# Godot process tree if it still hasn't exited.
#
# Prerequisites: see README.md section 3 (JDK 17, Android SDK, export templates, debug keystore,
# Godot editor settings).
set -u
cd "$(dirname "$0")/.."

PRESET="Android Debug (APK)"
OUT="build/sabotage-debug.apk"
LOG="build/export.log"
GODOT="${GODOT:-$LOCALAPPDATA/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe}"

if [ ! -f "$GODOT" ]; then
  echo "Godot not found at: $GODOT" >&2
  echo "Set GODOT=/path/to/Godot_v4.7.2-stable_win64_console.exe" >&2
  exit 2
fi

mkdir -p build
rm -f "$OUT" "$OUT.idsig"
: > "$LOG"

"$GODOT" --headless --path . --export-debug "$PRESET" "$OUT" > "$LOG" 2>&1 &
PID=$!

stop_godot() {
  # Kill the whole Windows process tree (the console wrapper starts the real Godot as a child).
  local winpid
  winpid=$(cat "/proc/$PID/winpid" 2>/dev/null || echo "$PID")
  taskkill //F //T //PID "$winpid" > /dev/null 2>&1 || kill "$PID" 2> /dev/null
}

status=1
for _ in $(seq 1 900); do          # wait up to ~15 minutes (first run recompresses textures)
  if ! kill -0 "$PID" 2> /dev/null; then
    # Godot exited by itself.
    if [ -s "$OUT" ]; then status=0; fi
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
  echo "OK: $OUT ($(du -h "$OUT" | cut -f1))"
else
  echo "FAILED. Last lines of $LOG:" >&2
  tail -n 15 "$LOG" >&2
  stop_godot
fi
exit "$status"
