# Setup

## Requirements

| What                                    | Version used                                                                  | Needed for                     | How to get it (Windows)                                 |
| --------------------------------------- | ----------------------------------------------------------------------------- | ------------------------------ | ------------------------------------------------------- |
| Git                                     | any recent                                                                    | cloning, version control       | `winget install --id Git.Git -e`                        |
| Godot (standard build, **not** .NET)    | **4.7.2 stable**                                                              | running and exporting the game | `winget install --id GodotEngine.GodotEngine -e`        |
| VS Code + the **godot-tools** extension | optional                                                                      | editing GDScript               | `winget install --id Microsoft.VisualStudioCode -e`     |
| JDK                                     | **17** (Eclipse Temurin 17.0.x)                                               | Android export                 | `winget install --id EclipseAdoptium.Temurin.17.JDK -e` |
| Android SDK                             | cmdline-tools, `platform-tools`, `build-tools;35.0.1`, `platforms;android-35` | Android export                 | see [Android](android.md)(android.md)                   |
| Godot export templates                  | **4.7.2.stable** (about 1.2 GB download)                                      | Android export                 | see [Android](android.md)(android.md)                   |
| Python 3 + Pillow                       | Python 3.12, Pillow 13                                                        | regenerating art only          | `pip install pillow`                                    |
| GitHub CLI                              | optional                                                                      | working with the GitHub repo   | `winget install --id GitHub.cli -e`                     |

You do **not** need Python, the JDK or the Android SDK just to play or edit the game on
desktop. Godot alone is enough for that.

Stick to Godot 4.7.x. The project files and the export templates must be the same version.

## Set up and run on desktop

1. Install Git and Godot (table above). **Fully quit and reopen VS Code / your terminal**
   afterwards, otherwise new programs are not on `PATH` yet.
2. Clone the repo:
   ```bash
   git clone https://github.com/shivamshekhar/sabotage-ai.git
   cd sabotage-ai
   ```
3. Make `godot` runnable from a terminal. On Windows, winget installs Godot but cannot create
   the `godot` command without admin rights. Either run it by full path, or add this to
   `~/.bashrc` in Git Bash (adjust the version in the file name if you install another):
   ```bash
   GODOT_DIR="$LOCALAPPDATA/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe"
   godot() { "$GODOT_DIR"/Godot_v4.7.2-stable_win64.exe "$@"; }
   godot_console() { "$GODOT_DIR"/Godot_v4.7.2-stable_win64_console.exe "$@"; }
   ```
   (`godot_console` prints logs to the terminal, which is handy for scripts and tests.)
4. **First time only**, let Godot import the assets and register the script classes. Without
   this, scripts fail with "Could not find type ... in the current scope":
   ```bash
   godot --headless --path . --import
   godot --headless --path . --import      # run twice; the second pass picks up new class names
   ```
5. Run the game:
   ```bash
   godot --path .                       # play
   SABOTAGE_LEVEL=test godot --path .   # the test level (a small sandbox) instead of the first level (other ids: `level_02` ... `level_05`, the folders in `levels/`)
   SABOTAGE_PREVIEW=1 godot --path .    # zoomed-out view of the whole level (debug aid)
   SABOTAGE_START="39,78" godot --path .  # start on map tile column,row (debug aid for a big level)
   ```
   With no `SABOTAGE_LEVEL`, the game starts on `level_01`. In PowerShell set the variable first:
   `$env:SABOTAGE_LEVEL = "test"; godot --path .`
   Or open the folder in the Godot editor (Project Manager > Import > pick `project.godot`) and press F5.

### Editing in VS Code (optional)

1. Install the **godot-tools** extension.
2. In Godot: Editor > Editor Settings > Text Editor > External. Turn on _Use External Editor_,
   set _Exec Path_ to your `Code.exe` (for example
   `C:\Users\<you>\AppData\Local\Programs\Microsoft VS Code\Code.exe`) and _Exec Flags_ to
   `{project} --goto {file}:{line}:{col}`.
3. Keep the Godot editor open while you edit; godot-tools talks to its language server.

The repo's [.vscode/settings.json](../.vscode/settings.json) makes Git Bash the default terminal.
