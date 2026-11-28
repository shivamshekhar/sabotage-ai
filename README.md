# sabotage.ai

A 2D side-scrolling platformer built with Godot 4 (GDScript), for Android, the web and desktop. You sabotage data centers to stop
capitalists replacing humans with AI.

**Play in a browser:** https://shivamshekhar.github.io/sabotage-ai/

## Quick start

1. Install [Godot 4.7.2](https://godotengine.org/) (standard build) and Git.
2. Clone and import once:
   ```bash
   git clone https://github.com/shivamshekhar/sabotage-ai.git
   cd sabotage-ai
   godot --headless --path . --import    # run twice
   ```
3. Play: `godot --path .`
4. Contributing? Run `tools/install_hooks.sh` once: it turns on the pre-commit hook (lint, formatting, tests, web, desktop and phone builds). Check the code by hand with `tools/lint.sh` (see [docs/testing.md](docs/testing.md#lint-and-formatting)).

Keyboard (change it in SETTINGS): arrows move, Space jumps, E uses computers, Q throws (in the mech: the laser), S heavy attack (in the mech: the missile), Enter starts the game. More in [docs/gameplay.md](docs/gameplay.md).

## Docs

|                                            |                                                       |
| ------------------------------------------ | ----------------------------------------------------- |
| [Setup](docs/setup.md)                     | requirements, running on desktop, VS Code             |
| [Gameplay and controls](docs/gameplay.md)  | controls, combat, enemies, phone layout               |
| [Designing levels](docs/level-design.md)   | the levels, the level editor, the level CLI           |
| [Android](docs/android.md)                 | debug APK and Google Play release builds              |
| [Web](docs/web.md)                         | the browser build and GitHub Pages                    |
| [Art](docs/art.md)                         | regenerating the art, asset layout                    |
| [Player sprites](docs/player-sprites.md)   | the hero's part folders, style folders and file names |
| [Tests](docs/testing.md)                   | `tools/run_tests.sh` and the headless tests           |
| [Project layout](docs/project-layout.md)   | what lives where                                      |
| [Troubleshooting](docs/troubleshooting.md) | common problems and fixes                             |

## License and credits

Captcha pictures are Google Noto Emoji (Apache License 2.0; credits: [assets/ui/captcha/CREDITS.md](assets/ui/captcha/CREDITS.md)). The **code** is under the [GNU GPL v3](LICENSE); the game's **own assets** (generated art and sounds, name, logo, characters, levels) are All Rights Reserved: see [LICENSE-ASSETS.md](LICENSE-ASSETS.md), which also lists the third-party assets and their licences. Character and tile art by [Kenney](https://kenney.nl) (CC0); the
thrown paintings are pixel-art reductions of public-domain works from Wikimedia Commons (Mona Lisa, The Starry Night, The Great
Wave off Kanagawa, Girl with a Pearl Earring, The Scream, Vitruvian Man). The title logo is drawn with two fonts under the SIL Open Font License 1.1 (Black Ops One by Castle Type, Orbitron by Matt McInerney), downloaded by the generator and not shipped. Details in [docs/art.md](docs/art.md).
