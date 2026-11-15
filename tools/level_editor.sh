#!/usr/bin/env bash
# Starts the level editor (tools/level_editor/README.md).
#
# Usage (Git Bash, from anywhere):  tools/level_editor.sh
#   Optional env var:  GODOT=/path/to/Godot_..._win64.exe   (default: the winget install)
# The windowed (non-console) Godot is used when it exists, so no console window stays open; set GODOT to the console
# executable if you want to see the engine's log.
set -u
cd "$(dirname "$0")/.."

DIR="$LOCALAPPDATA/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe"
if [ -z "${GODOT:-}" ]; then
  if [ -f "$DIR/Godot_v4.7.2-stable_win64.exe" ]; then
    GODOT="$DIR/Godot_v4.7.2-stable_win64.exe"
  else
    GODOT="$DIR/Godot_v4.7.2-stable_win64_console.exe"
  fi
fi
if [ ! -f "$GODOT" ]; then
  echo "Godot not found at: $GODOT (set GODOT=...)" >&2
  exit 2
fi

exec "$GODOT" --path . res://tools/level_editor/level_editor.tscn "$@"
