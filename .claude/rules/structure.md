# Where things go

```
scripts/
  common/                 reusable, feature-independent pieces
    constants/            Groups, InputActions, PhysicsLayers, AssetPaths
    effects/              Explosion, Debris, ParticlePreset (anything that makes a visual effect)
    ui/                   HealthBar, ScorePopups, Vignette (generic UI)
    util/                 Sprites, Blend, Geom (small helpers)
  core/                   startup, input, music, running totals (GameStats)
  player/ enemy/ boss/ vehicle/ powerup/ level/ ui/     one folder per kind of thing in the game
assets/
  effects/                generic effect pictures (explosion, smoke, fire, sparks, glows)
  <feature>/              pictures that belong to one feature (powerups/, powerups/mech/, bosses/, characters/, captcha/, projectiles/)
levels/                   one folder per level + common/ (tiles, machines, pit hazards, the tile registry)
tools/                    scripts, art generators (tools/art/), level editor, tests (tools/tests/)
docs/                     the project's documentation
tmp/                      scratch space (git-ignored)
```

- If something in a feature folder could be used by another feature (an effect, a picture, a helper), **move it to `common/` / `assets/effects/`** and
  give it a general name. A script that mentions "mech" in its name must be about the mech.
- A new folder gets its place in this list and in `docs/project-layout.md`.
- Moving a picture: move its `.import` file with it (`git mv`), then re-import (`godot --headless --path . --import`).
