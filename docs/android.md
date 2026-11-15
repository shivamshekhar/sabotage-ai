# Build an Android APK

This produces a **debug** APK you can install on your own phone. The export presets are already
in [export_presets.cfg](../export_presets.cfg): "Android Debug (APK)" (arm64, no Gradle) and
"Android Release (AAB)" (see [release builds](#release-builds-for-google-play)).

## 3.1 One-time setup

**a) JDK 17.**
```bash
winget install --id EclipseAdoptium.Temurin.17.JDK -e
```
It installs to `C:\Program Files\Eclipse Adoptium\jdk-17.x.x.x-hotspot`. Note that exact path.

**b) Android SDK.** You do not need Android Studio. Download the "Command line tools only"
zip for your OS from <https://developer.android.com/studio#command-line-tools-only> (this
project used `commandlinetools-win-11076708_latest.zip`) and unpack it so that you end up
with `<SDK>\cmdline-tools\latest\bin\sdkmanager.bat`, where `<SDK>` is, for example,
`%LOCALAPPDATA%\Android\Sdk`. The zip contains a folder named `cmdline-tools`; rename it
to `latest` and put it inside `<SDK>\cmdline-tools\`.

Then, in **Git Bash** (the `yes |` trick answers the licence prompts):
```bash
export JAVA_HOME="C:/Program Files/Eclipse Adoptium/jdk-17.0.21.9-hotspot"   # your JDK path
SDK="$LOCALAPPDATA/Android/Sdk"
SM="$SDK/cmdline-tools/latest/bin/sdkmanager.bat"
yes | "$SM" --sdk_root="$SDK" --licenses        # accepts Google's Android SDK licences
"$SM" --sdk_root="$SDK" --install "platform-tools" "build-tools;35.0.1" "platforms;android-35"
```
Running `--licenses` means you accept Google's Android SDK licence agreements. Read them first
if you care; they are shown as they scroll by.

**c) Godot export templates (4.7.2.stable).** Download
`Godot_v4.7.2-stable_export_templates.tpz` from
<https://github.com/godotengine/godot/releases/tag/4.7.2-stable> (about 1.2 GB) and either:
- in the editor: Editor > Manage Export Templates > Install from File, or
- by hand: a `.tpz` is a zip; copy its `templates/` contents into
  `%APPDATA%\Godot\export_templates\4.7.2.stable\` (the folder must contain
  `android_debug.apk`, `android_release.apk`, `android_source.zip`, `version.txt`...).

**d) Debug signing key.** Debug builds are signed with a throwaway key. Create it once:
```bash
mkdir -p "$APPDATA/Godot/keystores"
"C:/Program Files/Eclipse Adoptium/jdk-17.0.21.9-hotspot/bin/keytool.exe" -genkeypair \
  -keystore "$APPDATA/Godot/keystores/debug.keystore" -alias androiddebugkey \
  -keyalg RSA -keysize 2048 -validity 10000 -storepass android -keypass android \
  -dname "CN=Android Debug,O=Android,C=US"
```
(This is the standard Android debug key, not your release key. see the release section below.)

**e) Tell Godot where everything is.** Either use the editor (Editor > Editor Settings >
Export > Android) or edit `%APPDATA%\Godot\editor_settings-4.7.tres` while Godot is closed and set:
```
export/android/java_sdk_path = "C:/Program Files/Eclipse Adoptium/jdk-17.0.21.9-hotspot"
export/android/android_sdk_path = "C:/Users/<you>/AppData/Local/Android/Sdk"
export/android/debug_keystore = "C:/Users/<you>/AppData/Roaming/Godot/keystores/debug.keystore"
export/android/debug_keystore_user = "androiddebugkey"
export/android/debug_keystore_pass = "android"
export/android/shutdown_adb_on_exit = false
```
(The environment variables `JAVA_HOME` and `ANDROID_HOME` fill in the SDK path, but Godot still
needs `java_sdk_path` set in editor settings, or it fails with "A valid Java SDK path is required".)

**`shutdown_adb_on_exit = false` is important.** In the editor this is
Editor Settings > Export > Android > *Shutdown ADB on Exit*. With it on (the default), Godot runs
`adb kill-server` as it quits, and on Windows that call can block forever. Once the Android SDK
is configured, **every** headless Godot command (`--import`, `--export-debug`, `--script ...`)
then hangs instead of exiting. With it off, they exit normally in a few seconds.

**f) Texture compression (already done in this repo).** Android export requires ETC2/ASTC
textures. `project.godot` already has `textures/vram_compression/import_etc2_astc=true`; if you
ever see "ETC2/ASTC texture compression is required", turn it on in Project Settings >
Rendering > Textures > VRAM Compression. The first export after enabling it recompresses every
texture and takes noticeably longer.

## 3.2 Export

```bash
tools/build_apk.sh        # run in Git Bash from the repo root; writes build/sabotage-debug.apk
```
This takes about 1 minute (longer the very first time). It runs Godot in the background, waits for
the "export DONE" line (or an error), makes sure Godot has stopped, and prints
`OK: build/sabotage-debug.apk (29M)` or the tail of `build/export.log`.

Why a script and not just `godot --headless --export-debug ...`? If the
`shutdown_adb_on_exit = false` setting from 3.1e is missing, Godot never exits after a headless
export (success or failure) and your terminal sticks. With the setting in place a plain command
works too, but the script also protects you from that and from a half-configured machine.
You can also export from the editor: Project > Export > "Android Debug (APK)" > Export Project.

The warning `Could not find version of build tools that matches Target SDK, using 35.0.1` is harmless.

The resulting APK is signed (v2/v3), package `com.shivamshekhar.sabotageai`, min Android 7.0
(API 24), arm64 only, landscape. It requires a **Vulkan-capable** phone, because the project uses
the "Mobile" renderer (almost every phone from the last several years qualifies). To support
older phones too, switch Project Settings > Rendering > Renderer to "Compatibility" (OpenGL).

## 3.3 Install on your phone

1. On the phone: Settings > About phone > tap *Build number* 7 times, then Settings > Developer
   options > turn on **USB debugging**. Plug it in and accept the prompt on the phone.
2. Install:
   ```bash
   "$LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe" devices        # your phone should be listed
   "$LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe" install -r build/sabotage-debug.apk
   ```
   Or copy `build/sabotage-debug.apk` to the phone and open it (allow "install unknown apps").

`build/` is git-ignored. The package name is `com.shivamshekhar.sabotageai`; change it (and the
version) in `export_presets.cfg` or the export dialog.

# Release builds for Google Play

> Not yet exercised end to end in this repo: the preset exists, but only the debug APK has been
> built and checked. Expect to fix small things the first time.

Google Play requires an **Android App Bundle (.aab)**, signed with your own release key.

1. **Make a release keystore** and **back it up somewhere safe** (and never commit it; `*.keystore`
   and `*.jks` are git-ignored). If you lose it you cannot update the app unless you enrolled in
   Play App Signing.
   ```bash
   keytool -genkeypair -v -keystore sabotage-release.keystore -alias sabotage \
     -keyalg RSA -keysize 2048 -validity 10000
   ```
2. **Give Godot the credentials through environment variables** (they are deliberately not stored
   in `export_presets.cfg`, which is committed):
   ```
   GODOT_ANDROID_KEYSTORE_RELEASE_PATH=C:/path/to/sabotage-release.keystore
   GODOT_ANDROID_KEYSTORE_RELEASE_USER=sabotage
   GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=<your password>
   ```
3. **Install the Android build template** (needed for `.aab`): in the editor, Project > Install
   Android Build Template. This creates `android/build/` (git-ignored). Gradle downloads its own
   dependencies the first time.
4. **Export:**
   ```bash
   godot_console --headless --path . --export-release "Android Release (AAB)" build/sabotage-release.aab
   ```
   The same hang applies (Godot does not exit after a headless export). Either export from the
   editor (Project > Export), or copy `tools/build_apk.sh` and change `PRESET`, `OUT` and
   `--export-debug` to `--export-release` at the top so it stops Godot for you.
5. **Before every upload**, raise `version/code` in the preset (Play rejects repeats).
6. **Play Console basics:** a one-time US$25 developer account; new personal accounts have
   needed a closed test with about 12 testers for 14 days before production (check Google's
   current rules); a privacy policy URL, content rating questionnaire, screenshots and a feature
   graphic; the target API level must meet Google's current requirement.



