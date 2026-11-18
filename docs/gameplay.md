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

**Pit creatures** ([scripts/enemy/pit_creature.gd](../scripts/enemy/pit_creature.gd)) live in every deadly pit. They hide under the
liquid, pop up at their own spot and either peek out or leap to one side, at you when you are near, and hurt you if they hit. They have
no health bar: one thrown object destroys one, and it returns at the same spot 5 seconds later (only then); between appearances they wait a fixed 2 seconds (the fireball 3.5 s, and it jumps 30% higher). A pit that is off
screen is silent: only pits on screen, or within `Level.PIT_ACTIVE_BUFFER` (700 px) of its edge in any direction, are awake, so one wakes up just before you reach it; every other pit's creatures, bubbles, gas and glow are hidden and do no work at all (`tools/tests/pit_sleep_test.gd`). Enemies far from the player sleep too. Each
pit has its own:

| Pit | Creature | What it does | Hit |
|---|---|---|---|
| toxic waste `A` | **poisonous puffer fish** | puffs up into a spiky ball as it leaps; the pit gives off drifting poison gas | 8% of your health, then poison: 4% four times, 0.7 s apart (it never kills; you turn green) |
| lava `F` | **fireball** | jumps straight up and down out of the lava, a glowing head with a comet of flame. Thrown objects that hit it **burn up**; it cannot be put out | 15%, then **burning**: 1% every 0.7 s for 16 ticks (a quarter of the poison's rate for four times as long; never kills; you turn orange and catch fire) and **thrown objects only go half as far** while it lasts |
| nuclear waste `N` | **glowing eel** | a long glowing eel that swims through the air; the pit glows and pulses | 12% |
| piranha tank `W` | **robot piranha** ([piranha.gd](../scripts/enemy/piranha.gd)) | snaps its saw-toothed jaws, open while it leaps | 10% |

`tools/tests/piranha_test.gd` and `tools/tests/pit_creature_test.gd` check all of this. Damage numbers are fractions of
`Player.MAX_HEALTH` (the `SPECIES` table in `pit_creature.gd`). A level file can change how many creatures a pit holds, their damage and
how fast they return, per pit (the "Pit creature settings" of the pit in the editor). `tools/tests/enemy_test.gd` checks the liquids.

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

## Boss level (level 6)

The first boss, **RAM Saltman** (a salt shaker full of stolen hardware), is the last level of the game (`levels/level_06`, the level file names it with `meta.boss`; beating it finishes the game). It is a closed arena: invisible walls are its two ends and the camera stops at them. To play just this level run `tools/boss_stage.sh` (Left/Right move, Space or W jump, Q throws). Losing restarts the fight. The boss is 2.16 player-heights tall. While it **hovers** it drifts
left and right and can be hit with thrown objects (28 hits defeat it). Every few seconds it **charges over the player, turns upside down and shakes
itself like a real salt shaker (rocking and bouncing, the hardware inside rattling) while it sprays RAM sticks, CPUs and chipsets** out of the holes in its cap (each hit takes 12% of the player's health); it cannot be hurt
while it attacks. Then it flips back up and hovers again. Below half health it sprays longer and faster.
Code: `scripts/boss/` (`SaltShakerBoss`, `BossBullet`); the fight: `scripts/boss/boss_fight.gd` (`BossFight`); art: `assets/bosses/saltman/` (layers and five expressions: idle, charge, attack, hurt, dead; `pose_sheet.png` shows them), made by
`python tools/art/generate_boss_shaker.py`; test: `tools/tests/boss_test.gd`.

## Power-ups and the mech

A **power-up box** (the `powerup_box` tile, `PowerUpBox`) floats and bobs in a level; the "?" on it glows in slowly changing colours, breathing and blinking, because what is inside is random. **Jump on it** (come down on its top; touching it from the side or below does nothing): you bounce off, it breaks apart in six frames and gives you the power-up inside (`PowerUps`; for now there is one kind, the mech). It cannot be opened while you are already in a vehicle. Place one with the level editor (group "Pickups") or the level tool.

The **mech** (`scripts/vehicle/`: `Mech` the rules, `MechVisual` the look, the legs and the damage, `MechMissile`, `MechBeam`, `MechDebris`) is a four-legged walker with a yellow construction-crane body, tentacle legs like Doctor Octopus's, and you sitting in the cockpit. It is a child of the player, so hits, hazards, the camera and the level all treat it as the player:

- **Size and durability:** 1.5 times the player's size. It has **no health bar and shows no numbers**: it survives **5 hits of any kind** (an enemy, spikes, anything that would hurt the player; the amount does not matter, and the usual short invulnerability after a hit applies). The damage shows on the mech itself: **hit 1** cracks across the body and the cockpit glass, **hit 2** the near front leg snaps (its end falls off and the stump hangs, sparking), **hit 3** smoke from the exhaust and the engine, **hit 4** fire on the engine and the roof and soot over the body, **hit 5** it explodes, its parts fly, and you drop out on foot with your own health untouched. Poison and burning cannot get in; a deadly pit still kills you, mech and all.
- **Walking:** a little slower than on foot. The legs **climb steps** (up to 84 px) just by walking into them. It cannot climb ladders. If the mech stands where not all its legs have a floor (a narrow ledge, an edge), those legs curl up and the **booster burns low** (just for show): it is held up, not floating.
- **Booster and fuel:** the only bar is a blue **fuel** bar above the mech. Hold the jump button and the booster lifts the mech (a tap is a hop) while there is fuel (a full tank is 1.2 s of burning); out of fuel it falls under gravity even with the button held. The tank fills back up progressively, in 3 s from empty, whenever the booster is off.
- **Weapons:** the light attack (Q) fires a **missile** from the roof turret (an exhaust flame, glow, sparks and a smoke trail; slow start, homing a little, blast radius 110 px, kills a Bro); the heavy attack (S) fires a blue **laser** from the front turret (an instant glowing beam with energy rings along it and expanding rings and a starburst at the muzzle; 34% of an enemy's health per hit, 760 px reach). Both turrets aim at the nearest enemy in front of you, otherwise straight ahead.

Art: `assets/powerups/` (the box, `box_base`, `box_question`, six `box_break_*` frames) and `assets/powerups/mech/` (body, canopy, turrets, leg links, joints, claw, hip, flame; `preview.png` shows them assembled) and the damage and weapon effects (cracks, broken link, smoke, fire, soot, missile and its flame, laser rings), made by `python tools/art/generate_powerup.py`, `python tools/art/generate_mech.py` and `python tools/art/generate_mech_effects.py` (run in that order). The box is drawn in the style of the level tiles (the metal crate: steel with a light top lip, rivets, cyan edge lights). Test: `tools/tests/mech_test.gd`. Level 1 has a box near the start.

## HUD

Floating text along the top of the screen, with no bar behind it (`scripts/ui/hud.gd`; thick outlines and a shadow keep it readable), shows the score (**SCORE:** on the left) and the level number (**WORLD:** on the right), both on one line in a small font, numbered like
Super Mario Bros: 1-1, 1-2, 1-3, 1-4, then 2-1 (`LevelData.STAGES_PER_WORLD` levels per world; a level file can set its own with
`meta.stage`). Defeating an AI Bro scores 100 (`GameStats`). More items will be added to the row later. The level's name is no longer
drawn on the background.

While RAM Saltman shakes and sprays in the boss stage, an AI Bro walks in from just beyond the edge of the screen, from the side the player
is FARTHER from, so it never lands on them (at most one per side at a time; they are stand-ins for the real minions). The arena has no
visible side walls: the floor runs on in both directions, but the player is fenced in by two columns of **invisible wall** tiles (Bros
walk through them), and the fight starts calmly with the player and the boss far apart (the boss hovers for 7 seconds before its first
attack). The two small ledges are cover: stand under one while he sprays.
