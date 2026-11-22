# Where things go

```
scripts/
  common/                 reusable, feature-independent pieces
    constants/            Groups, InputActions, PhysicsLayers, AssetPaths
    audio/                AudioBuses, Sfx (the sound groups and one-shot effects)
    effects/              Explosion, Debris, ElectricArc, ParticlePreset (anything that makes a visual effect)
    ui/                   HealthBar, ScorePopups, Vignette, HazardStrip, Scanlines, SegmentedMeter, ScreenFlash (generic UI)
    util/                 Sprites, Blend, Geom (small helpers)
  core/                   startup, input, settings and key bindings, music, running totals (GameStats)
  player/ enemy/ boss/ vehicle/ powerup/ level/ ui/     one folder per kind of thing in the game (ui/title/ is the title screen)
assets/                   ALL pictures and sounds, grouped as <category>/<feature>/ (same rule everywhere: a category folder, then the feature's own folder)
  effects/                generic effect pictures (explosion, smoke, fire, sparks, glows)
  levels/                 level art: common/ (tiles, machines, pit_hazards) and <id>/background/ (the art side of levels/)
  vehicles/mech/  powerups/box/  bosses/saltman/  characters/  projectiles/  ui/{icons,captcha,title}/  audio/{music,sfx/<feature>}/
levels/                   level DATA only (no pictures): one folder per level + common/tile_registry.json
tools/                    scripts, art generators (tools/art/), level editor, tests (tools/tests/)
docs/                     the project's documentation
tmp/                      scratch space (git-ignored)
```

- If something in a feature folder could be used by another feature (an effect, a picture, a helper), **move it to `common/` / `assets/effects/`** and
  give it a general name. A script that mentions "mech" in its name must be about the mech.
- A new folder gets its place in this list and in `docs/project-layout.md`.
- Moving a picture: move its `.import` file with it (`git mv`), then re-import (`godot --headless --path . --import`).
