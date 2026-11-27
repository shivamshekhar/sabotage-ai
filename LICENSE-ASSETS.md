# Licence of the game's assets

Copyright (c) 2026 shivamshekhar. All rights reserved.

The source code of sabotage.ai is free software under the GNU General Public License v3 (see [LICENSE](LICENSE)). **The game's own assets are not.**

## What is covered (All Rights Reserved)

Everything the project made itself, in `assets/` and the files that make it:

- the pictures drawn by the generators in `tools/art/` (the mech, the bosses, the exit door, the power-up box, the machines and the data-centre tiles, the
  effects, the interface icons, the thrown objects, the backgrounds, the title logo), the hero's sprites in `assets/characters/saboteur/` (drawn by
  `tools/art/generate_player.py` on top of a CC0 character by Kenney, see below: our additions and our new poses are covered, the Kenney base stays CC0)
  and the sounds made by `tools/art/generate_sfx.py`;
- the name "sabotage.ai", its logo, the characters, the story and the level designs (`levels/`).

You may not copy, redistribute, sell or use them in another work, with or without changes, without written permission. The generator **scripts** are code,
so they are under the GPL (running them yourself makes pictures you may not distribute). Playing the game, and reading and studying the pictures
in the repository, is of course fine.

## What is not covered: other people's work

These keep the licence of their authors; none of it is made by this project:

| Where | What | Licence |
|-------|------|---------|
| `assets/characters/kenney_platformer/` | character art by [Kenney](https://kenney.nl) (the zombie) | CC0 |
| `tools/art/sources/kenney_platformer_player/` | the original hero by [Kenney](https://kenney.nl), the base of `assets/characters/saboteur/` | CC0 |
| `assets/levels/common/tiles/kenney_industrial/` | tile art by [Kenney](https://kenney.nl) | CC0 |
| `assets/ui/captcha/` | Google Noto Emoji | Apache License 2.0 |
| `assets/fonts/press_start_2p/` | the game's font, Press Start 2P by Cody "CodeMan38" Boisclair (licence text in `OFL.txt`) | SIL Open Font License 1.1 |
| `assets/audio/music/` | music from Pixabay | Pixabay Content Licence |
| `assets/audio/sfx/` except `ui/` (listed in [assets/audio/CREDITS.md](assets/audio/CREDITS.md)) | sound effects by [Kenney](https://kenney.nl) and others | CC0 |

The thrown paintings are pixel-art reductions (made by the project) of public-domain works; the originals are in the public domain, the reductions are
covered above. The title logo is drawn with Black Ops One and Orbitron (SIL Open Font License 1.1), which are downloaded by the generator and not shipped.

## Contributions

Code contributions are accepted under the GPL. Because the assets stay proprietary and the owner may publish the game commercially, a contribution is only
merged after its author agrees in writing that the owner may also use it under other terms (a contributor licence agreement).
