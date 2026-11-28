#!/usr/bin/env bash
# Builds the game for the web, the desktop (Windows and Linux) and the phone (Android APK), and fails if any build fails.
# The files are made in build/ (git-ignored). Used by the pre-commit hook (tools/hooks/pre-commit).
#
# Usage (Git Bash, from anywhere):  tools/build_all.sh
#            tools/build_all.sh Web Linux          builds only these (the first word of the preset name: Web, Windows, Linux, Android) (the CI builds the phone one in its own job)
#   Optional env vars:  GODOT=/path/to/Godot_..._console.exe, or just godot (default: the winget install)
cd "$(dirname "$0")/.." || exit 2

# BUILDS: "<preset name>|<output file>|<debug or release>", one per line. A new platform is one more line here (and a preset in
# export_presets.cfg). The presets are the ones the CI uses: Web release (pages.yml), Android debug APK (android-release.yml).
BUILDS=(
  "Web|build/web/index.html|release"
  "Windows Desktop|build/desktop/windows/sabotage-ai.exe|release"
  "Linux|build/desktop/linux/sabotage-ai.x86_64|release"
  "Android Debug (APK)|build/sabotage-debug.apk|debug"
)

# Pictures and scripts must be imported before any export (the second pass registers the script class names, as in the CI).
GODOT="${GODOT:-$LOCALAPPDATA/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe}"
for _ in 1 2; do
  timeout 600 "$GODOT" --headless --path . --import > /dev/null 2>&1
done

failed=0
for entry in "${BUILDS[@]}"; do
  IFS='|' read -r preset out mode <<< "$entry"
  if [ "$#" -gt 0 ] && [[ " $* " != *" ${preset%% *} "* ]]; then      # (a name given on the command line is the first word of the preset: Web, Windows, Linux, Android)
    continue
  fi
  tools/export_preset.sh "$preset" "$out" "$mode" || failed=1
done
exit "$failed"
