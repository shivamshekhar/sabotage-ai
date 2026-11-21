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

Keyboard: arrows move, Space jumps, E uses computers, Q throws, S heavy attack. More in [docs/gameplay.md](docs/gameplay.md).

## Docs

| | |
|---|---|
| [Setup](docs/setup.md) | requirements, running on desktop, VS Code |
| [Gameplay and controls](docs/gameplay.md) | controls, combat, enemies, phone layout |
| [Designing levels](docs/level-design.md) | the levels, the level editor, the level CLI |
| [Android](docs/android.md) | debug APK and Google Play release builds |
| [Web](docs/web.md) | the browser build and GitHub Pages |
| [Art](docs/art.md) | regenerating the art, asset layout |
| [Tests](docs/testing.md) | `tools/run_tests.sh` and the headless tests |
| [Project layout](docs/project-layout.md) | what lives where |
| [Troubleshooting](docs/troubleshooting.md) | common problems and fixes |

## License and credits

Captcha pictures are Google Noto Emoji (Apache License 2.0; credits: [assets/ui/captcha/CREDITS.md](assets/ui/captcha/CREDITS.md)). Code and generated art are under the [MIT License](LICENSE). Character and tile art by [Kenney](https://kenney.nl) (CC0); the
thrown paintings are pixel-art reductions of public-domain works from Wikimedia Commons (Mona Lisa, The Starry Night, The Great
Wave off Kanagawa, Girl with a Pearl Earring, The Scream, Vitruvian Man). Details in [docs/art.md](docs/art.md).
