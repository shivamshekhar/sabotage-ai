#!/usr/bin/env bash
# Look at every question of the "I am not a robot" captcha (arrow keys: next/previous, Space: new pictures, A: show the answer).
cd "$(dirname "$0")/.."
GODOT="${GODOT:-$LOCALAPPDATA/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64.exe}"
exec "$GODOT" --path . res://tools/captcha_preview.tscn
