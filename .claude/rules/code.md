# Code rules

- **Object-oriented and reusable.** One class, one job. When the same logic appears twice, move it to a shared class (see `scripts/common/`) and use it
  from both places. Prefer small classes with a clear name over long scripts; compose behaviour (a `DamageOverTime` for poison and burning, a
  `ParticlePreset` for every particle effect) instead of copying code.
- **No handwritten values.** A number, a string, a colour, a node-group name, an input action, a physics layer or a file path never appears in the middle of
  logic. Use a documented constant: named constants at the top of the class for values that belong to it; shared ones in `scripts/common/constants/`
  (`Groups`, `InputActions`, `PhysicsLayers`, `AssetPaths`). A new group, action, layer or folder is added there first.
- **Constants are documented**: a comment above each says what it is, its unit, and what raising or lowering it does.
- **Generic things are generic.** Anything another feature could use (an explosion, particles, a health bar, geometry helpers, a debris piece) lives in
  `scripts/common/` with a general name, not in the feature that first needed it.
- **Readable first.** Short functions with a doc comment saying _why_. Types on variables and function signatures. GDScript: `:=` cannot infer from a
  Variant (use `var x: Type =`); packed arrays are values, so assign the whole array back.
- **No dead code.** Delete unused functions, constants, scripts and pictures instead of commenting them out. `python tools/audit_assets.py` finds unused files.
- **Performance:** no per-frame `load()` (use `AssetPaths`, which caches); no per-frame allocations of nodes or resources in `_process`; rays and
  queries only as often as needed.
