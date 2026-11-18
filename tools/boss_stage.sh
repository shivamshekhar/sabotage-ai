#!/usr/bin/env bash
# Play just the boss level (level_06, the fight against RAM Saltman) without playing the levels before it.
#   tools/boss_stage.sh            (Left/Right move, Space or W jumps, Q throws)
# Optional env var:  GODOT=/path/to/Godot_..._win64.exe   (default: the winget install)
cd "$(dirname "$0")/.."
GODOT="${GODOT:-$LOCALAPPDATA/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64.exe}"
SABOTAGE_LEVEL=level_06 exec "$GODOT" --path .
