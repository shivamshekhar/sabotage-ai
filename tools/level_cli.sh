#!/usr/bin/env bash
# The level command-line tool: create, edit and check level files (*.sablevel.json) without the editor window.
#   tools/level_cli.sh help
#   tools/level_cli.sh from-plan levels/my_level.sablevel.json --plan @plan.json && tools/level_cli.sh solve levels/my_level.sablevel.json
# Prints one JSON object (the part of Godot's output between the LEVEL_CLI markers); exit code 0 = the command worked.
# Optional env var:  GODOT=/path/to/Godot_..._console.exe   (default: the winget install)
# Details: tools/level_editor/CLI.md
set -u
cd "$(dirname "$0")/.."
GODOT="${GODOT:-$LOCALAPPDATA/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe}"
if [ ! -f "$GODOT" ]; then
  echo "Godot not found at: $GODOT (set GODOT=...)" >&2
  exit 2
fi
# (timeout: a script error in the project can leave Godot waiting forever; it is stopped after 5 minutes)
out=$(timeout 300 "$GODOT" --headless --path . --script res://tools/level_editor/level_cli.gd -- "$@" 2>&1)
code=$?
# Print only the tool's own output; if the markers are missing something went wrong in the engine, so show everything.
if echo "$out" | grep -q '<<<LEVEL_CLI'; then
  echo "$out" | sed -n '/<<<LEVEL_CLI/,/LEVEL_CLI>>>/p' | sed '1d;$d'
else
  echo "$out"
  code=1
fi

# A new level's background images were copied: have Godot import them, or the game cannot load them.
if echo "$out" | grep -q '"needs_import": true'; then
  "$GODOT" --headless --path . --import >/dev/null 2>&1
  echo "(imported the new background images)" >&2
fi
exit $code
