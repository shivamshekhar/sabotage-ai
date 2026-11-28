#!/usr/bin/env bash
# Builds the Android debug APK: build/sabotage-debug.apk
#
# Usage (Git Bash, from anywhere):  tools/build_apk.sh
#   Optional env vars:  GODOT=/path/to/Godot_..._console.exe   (default: the winget install)
#
# The work (and the reason for not calling Godot directly) is in tools/export_preset.sh.
# Prerequisites: see README.md section 3 (JDK 17, Android SDK, export templates, debug keystore, Godot editor settings).
cd "$(dirname "$0")/.." || exit 2
exec tools/export_preset.sh "Android Debug (APK)" build/sabotage-debug.apk debug
