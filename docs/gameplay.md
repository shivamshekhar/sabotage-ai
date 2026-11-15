# Gameplay and controls

| Action | Keyboard (PC) | Phone |
|---|---|---|
| Move | Left / Right arrows | D-pad left / right |
| Jump | **Space**, **W**, or Up | **JUMP** button, or D-pad up |
| Climb up / down a ladder | Up / Down arrows | D-pad up / down |
| Interact | E | **USE** button |
| Throw an object (weapon) | **Q** | **LIGHT** button |
| Heavy attack | **S** | **HEAVY** button |

Heavy attack is a placeholder for now: the key and button work but `attack_heavy()` in
[scripts/player/player.gd](../scripts/player/player.gd) is empty, ready to be filled in.

**Combat.** The light attack throws a random everyday object (a famous painting, a cat photo, a
paintbrush, a vinyl record...: things the AI can't make) in an arc, like a thrown stone
([scripts/player/projectile.gd](../scripts/player/projectile.gd)). It takes 50% of an **AI Bro**'s health. AI Bros
([scripts/enemy/ai_bro.gd](../scripts/enemy/ai_bro.gd), the zombie sprite) have 20% of the player's health, pace
near their spot or ledge, chase you when you come near and they are facing you, and hit for 10% of your
health. There are two kinds of hazard, with their own classes and sprites. **Spikes** (`^` on the floor, `v` on the
ceiling; [scripts/level/spike_trap.gd](../scripts/level/spike_trap.gd)) only hurt: they take 20% of your health
and Bros are immune to them. **Deadly pits** ([scripts/level/pit_hazard.gd](../scripts/level/pit_hazard.gd)) kill
anyone (you or a Bro) who falls in: toxic waste (`A`), lava (`F`), nuclear waste (`N`) and a tank of robotic
piranhas (`W`). For the player a pit is GAME OVER and a respawn at
the last checkpoint. Bros never walk off a ledge: they turn round while pacing and stop at an edge while chasing; they climb steps and
hop narrow gaps by jumping, and only notice you within a short range while facing you. Their sensing runs ten
times a second, Bros far from the player sleep (no physics at all), and a dead Bro is freed at once, so a level can
hold many (`tools/tests/enemy_ai_test.gd` checks the movement, the sleeping, and that 200 killed Bros leave nothing
behind). Put a Bro in a level with `B` in the map; it needs enough flat ground to pace on (`LevelData.bro_min_flat_tiles()`,
worked out from its patrol beat and width): the level builder reports a Bro placed where there is not enough room, a
Bro that still ends up cramped is not spawned, and `levels_test.gd` checks every marker.

**Robot piranhas** ([scripts/enemy/piranha.gd](../scripts/enemy/piranha.gd)) live in the `W` tanks: they hide under the liquid, pop up
at their own spot and either peek out snapping their jaws or leap to one side, at you when you are near, and a bite takes 10% of
your health. They have no health bar: one thrown object destroys one, and it returns at the same spot a few seconds later (only
then). A tank that is off screen is hidden and does no work (its piranhas, bubbles and glow are switched off), and so is any enemy
far from the player. `tools/tests/piranha_test.gd` checks all of this. Damage numbers are fractions of
`Player.MAX_HEALTH` (see the constants in those scripts). `tools/tests/enemy_test.gd` checks all of this.

**Phone layout** ([scripts/ui/touch_controls.gd](../scripts/ui/touch_controls.gd)): an 8-way D-pad at
the bottom-left (slide your thumb around it; up+right together makes a diagonal), and the four
buttons in a diamond at the bottom-right. Several fingers work at once (steer with the D-pad while
tapping JUMP), you can slide a thumb between the buttons without lifting it, and the controls stick
to the real screen corners on wide phones.

The controls are deliberately faint so they don't distract (they brighten while pressed). Tune
`IDLE_ALPHA` / `ACTIVE_ALPHA` at the top of `touch_controls.gd`. On phones the camera also scrolls
`TOUCH_SIDE_PADDING` (in `scripts/core/main.gd`) past each end of the level, over some
decorative wall, so the player is never hidden behind the D-pad or the buttons.

**The overlay only appears on phones.** On PC it is not created at all. To try the phone controls
on a PC, set an environment variable first; the left mouse button then acts as a finger:

```bash
SABOTAGE_TOUCH=1 godot --path .        # Git Bash
$env:SABOTAGE_TOUCH = "1"; godot --path .    # PowerShell
```

**Jump vs. climb.** Space / the JUMP button always jump. Up (W / Up arrow / D-pad up) is both jump and
climb, since you never do both at once: when at least 75% of the character overlaps a ladder, Up
grabs it (from the floor at its bottom, or by catching it mid-jump) and Down grabs it from the top
deck. You then snap onto the ladder's centre line and can only move up/down, with no jumping (Space
is ignored), until you reach the top deck or the floor. At the top deck, Up jumps and Down climbs
back down.

