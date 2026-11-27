# Gameplay and controls

| Action | Keyboard (PC, the defaults) | Phone |
|---|---|---|
| Move | Left / Right arrows | D-pad left / right |
| Jump | **Space**, **W**, or Up | **B** button, or D-pad up |
| Climb up / down a ladder | Up / Down arrows | D-pad up / down |
| Use (a computer) | E | **Y** button |
| Light attack: throw an object; in the mech the laser (hold) | **Q** | **A** button |
| Heavy attack: the EMP gun on foot, the missile in the mech | **S** | **X** button |
| Start the game (title screen) | **Enter** | tap anywhere |

The PC keys can be changed in the settings (title screen, SETTINGS: click a key, press the new one); on a phone the settings list what the buttons (X, Y, A, B) do. Heavy attack on foot fires the **EMP gun**: the player takes the gun out (the `shoot` picture of the hero, with the gun drawn in the fist, made by `tools/art/generate_player.py` and shown by `PlayerSprite`, which also makes the figure vibrate a little with the recoil) and [`EmpGun`](../scripts/player/emp_gun.gd) keeps firing a stream of electricity
([`ElectricArc`](../scripts/common/effects/electric_arc.gd): a bolt of lightning made of straight, jagged pieces that strikes a new path every 0.05 s, with hard forks, a soft glow that lights the level round it and sparks where it hits; in the martial-arts outfit, which has no gun (its `wave` pose has both hands held round a ball of energy), the stream is a wide wave of energy, [`EnergyBeam`](../scripts/common/effects/energy_beam.gd), that hits what it covers) straight ahead **for as long as the button is held**, like the mech's laser: **560 px** reach, stopped by a wall,
**40 damage** to the first enemy it rests on every 0.6 s, and it uses the energy bar up very fast (**1.5 s** of firing for a full bar; no throwing meanwhile, and the bar refills only after you let go). In the mech the heavy attack is the missile instead.

## The title screen and the settings

The game starts on the title screen ([scenes/title.tscn](../scenes/title.tscn), `scripts/ui/title/`): the logo in the middle with PRESS ENTER TO START (TAP ANYWHERE TO START on a phone), the menu down
the left, the hero standing on the floor in front of an exit door, and a distant, out-of-focus stretch of a data center drifting behind (the real level backgrounds, floors, racks, pits
with their creatures and pacing bros: `TitleBackdrop`, put out of focus by `defocus.gdshader`). The level's music plays on it and carries on into the game. Starting makes the hero
walk to the door by himself and go in; the screen flashes white and level 1 clears away from the white. The menu (`TitleMenu`) has LEVELS, UPGRADES, VEHICLES and GADGETS as places for later (a tap says
"coming soon") and a working SETTINGS (`SettingsPanel`): the music and sound-effect volumes (block meters: tap or drag), and the controls (see above). Settings are kept in `user://settings.cfg`
(`Settings`, `KeyBindings`); music and effects play on the `Music` and `SFX` audio buses (`AudioBuses`, `Sfx`). Running with a level chosen (`SABOTAGE_LEVEL`, `-- --level-file=`) or `SABOTAGE_NO_TITLE=1` skips the title.

## The wardrobe

The title menu's WARDROBE (`WardrobePanel`) changes how the hero looks. The hero is made of **parts**, each a picture of its own per pose (`assets/characters/saboteur/player/<part>/<style>/player_<pose>_<part>.png`,
see `tools/art/generate_player.py`): boots, pants, arms (bare, the hands too), torso, gloves, head (face and neck), hair and goggles (and the gun in the shooting pose). Six of them can be changed (the slots of
[`WardrobeCatalog`](../scripts/player/wardrobe_catalog.gd)): **hair** (quiff, crop, spiky, bald), **goggles** (on the chest, glasses, visor, none), **torso** (t-shirt, long sleeves, martial-arts top, sleeveless), **gloves**
(fingerless, wristbands, bare hands), **pants** (cargo, martial-arts, plain) and **boots** (sneakers, martial-arts, plain), each in one of 6 to 9 colours. A style is a folder of the part (`hair/crop/`): **the wardrobe lists the folders, so a new style is a new folder** with the part's pictures for the poses (named like the other styles' pictures) and nothing else to register; the folder's name is what the screen says (`long_sleeves` is LONG SLEEVES). A colour is not a style; a colour is made
when the picture is drawn: the tones that are the part's colour (the hair, the shirt, ...) are shifted to the new colour with their shading kept, and the outlines, lights and trim (the yellow stripe, the cyan
wristbands, the laces) stay. The martial-arts pieces (top, pants, boots, wristbands) are orange with a blue sash, boots and wristbands, and have no colours to choose; the hair can still be dyed. The window shows the hero dressed as chosen, standing, walking, jumping or firing the EMP gun, and has RANDOM and ORIGINAL buttons. What is worn (an [`Outfit`](../scripts/player/outfit.gd))
is kept in `user://outfit.cfg` by `Wardrobe`; `OutfitComposer` puts the parts of a pose together the first time the pose is drawn (a few milliseconds a pose) and keeps the result, and
`SpriteLibrary.character_pose()` gives that picture to everything that draws the hero (the game, the title screen, the mech's pilot). To add a style, put its folder (all its poses, drawn in the generator or by hand) in the part's folder and run
`tools/tests/wardrobe_test.gd`, which checks that every style the folders hold has its standing picture; to add a colour, add it to the slot's palette in the catalog.

## The pause menu

A square menu button in the top-right corner of the game screen (`PauseButton`, in the HUD; **Esc** does the same on a PC) pauses the game and opens the pause menu (`PauseMenu`), with the items in the
usual order: **RESUME** (focused; Esc also resumes), **SETTINGS** (the same window as on the title: volumes and the controls; changes apply at once) and **QUIT TO TITLE** (last, in red; it asks first, with
CANCEL as the default, and leaving means the score and what was carried start over). `tools/tests/pause_menu_test.gd` checks it.

## The exit door

A level ends at an **exit door** ([scripts/level/exit_door.gd](../scripts/level/exit_door.gd), art by `tools/art/generate_door.py`; the map's `E`): a heavy data-center sliding door, 2 tiles wide and 3 tall,
standing on the exit's tile. The leaves slide apart and the lamp turns green as the player comes near; reaching the doorway, the player walks to its middle by themselves (their controls do nothing
and nothing can hurt them, `Player.walk_to()`), fades into the dark corridor, the door closes, and only then is the level finished (`Level.goal_reached`).

**Combat.** The light attack throws a random everyday object (a famous painting, a cat photo, a
paintbrush, a vinyl record...: things the AI can't make) in an arc, like a thrown stone
([scripts/player/projectile.gd](../scripts/player/projectile.gd)). It does **10 damage** (an **AI Bro** has 20 hit points, so two throws beat one). AI Bros
([scripts/enemy/ai_bro.gd](../scripts/enemy/ai_bro.gd), the zombie sprite; a Bro hits only when the player's body box overlaps its **strike box**, `AIBro.strike_box()`: the same everywhere, 60 px tall from its feet, so a player who jumps clear above it is safe; it hops up only to a player standing on a ledge above it, never at one in mid-air) have 20% of the player's health, pace
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

**Warning signs** ([scripts/level/pit_signs.gd](../scripts/level/pit_signs.gd)): every deadly pit has a small signboard planted on the ground tile just before it (on top of the wall instead when a wall rises there, where the jump starts), with what is in it: a **green skull** for toxic waste, a **flame** for lava, the yellow and black **radiation trefoil** for nuclear waste, a **piranha with open jaws** for the piranha tank. Two small **red warning lights** stand on tiny rods on the board's top corners and glow and dim in turn (one is bright while the other is dim; `GlowPulse`, set by the tile's `glows` entry in the registry). The signs are decor tiles (`decor_sign_pit_*`), so the level editor offers them; the level generator and `level_cli pit-signs <file>` place them, and the level checks fail a level whose pit has none. `tools/tests/pit_signs_test.gd` checks it.

**Pit creatures** ([scripts/enemy/pit_creature.gd](../scripts/enemy/pit_creature.gd)) live in every deadly pit. They hide under the
liquid, pop up at their own spot and either peek out or leap to one side, at you when you are near, and hurt you if they hit. They have
no health bar: one thrown object destroys one, and it returns at the same spot 5 seconds later (only then); between appearances they wait a fixed 2 seconds (the fireball 3.5 s, and it jumps 30% higher). A pit that is off
screen is silent: only pits on screen, or within `Level.PIT_ACTIVE_BUFFER` (700 px) of its edge in any direction, are awake, so one wakes up just before you reach it; every other pit's creatures, bubbles, gas and glow are hidden and do no work at all (`tools/tests/pit_sleep_test.gd`). Enemies far from the player sleep too. Each
pit has its own:

| Pit | Creature | What it does | Hit |
|---|---|---|---|
| toxic waste `A` | **poisonous puffer fish** | puffs up into a spiky ball as it leaps; the pit gives off drifting poison gas | 8% of your health, then poison: 4% four times, 0.7 s apart (it never kills; you turn green) |
| lava `F` | **fireball** | jumps straight up and down out of the lava, a glowing head with a comet of flame. Thrown objects that hit it **burn up**; it cannot be put out | 15%, then **burning**: 1% every 0.7 s for 16 ticks (a quarter of the poison's rate for four times as long; never kills; you turn orange and catch fire) and **thrown objects only go half as far** while it lasts |
| nuclear waste `N` | **glowing eel** | a long glowing eel that swims through the air; the pit glows and pulses | 12%, then **radiation sickness**: a third of a burn's rate (1/3 of a point every 0.7 s, so 1 point every 2.1 s) for twice as long (32 ticks, about 22 s; never kills), and **every hit from an enemy does 1.5 times its damage** until it wears off (spikes are not made worse). You glow a radioactive green |
| piranha tank `W` | **robot piranha** ([piranha.gd](../scripts/enemy/piranha.gd)) | snaps its saw-toothed jaws, open while it leaps | 10%, then **bleeding**: 1% every 0.7 s for 16 ticks (the same as a burn; never kills). Your **energy bar refills at half speed** and you flash red and drip blood |

`tools/tests/piranha_test.gd` and `tools/tests/pit_creature_test.gd` check all of this. Damage numbers are fractions of
`Player.MAX_HEALTH` (the `SPECIES` table in `pit_creature.gd`). A level file can change how many creatures a pit holds, their damage and
how fast they return, per pit (the "Pit creature settings" of the pit in the editor). `tools/tests/enemy_test.gd` checks the liquids.

**Phone layout** ([scripts/ui/touch_controls.gd](../scripts/ui/touch_controls.gd)): an 8-way D-pad at
the bottom-left (slide your thumb around it; up+right together makes a diagonal), and the four
buttons in a diamond at the bottom-right, laid out like a Nintendo Switch pad: X top, Y left, A right, B bottom (B jump, Y use, A light attack, X heavy attack; the settings list them). Several fingers work at once (steer with the D-pad while
tapping A), you can slide a thumb between the buttons without lifting it, and the controls stick
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

**Jump vs. climb.** Space / the B button always jump. Up (W / Up arrow / D-pad up) is both jump and
climb, since you never do both at once: when at least 75% of the character overlaps a ladder, Up
grabs it (from the floor at its bottom, or by catching it mid-jump) and Down grabs it from the top
deck. You then snap onto the ladder's centre line and can only move up/down, with no jumping (Space
is ignored), until you reach the top deck or the floor. At the top deck, Up jumps and Down climbs
back down.

## Boss level (level 6)

The first boss, **RAM Saltman** (a salt shaker full of stolen hardware), is the last level of the game (`levels/level_06`, the level file names it with `meta.boss`; beating it finishes the game). It is a closed arena: invisible walls are its two ends and the camera stops at them. To play just this level run `tools/boss_stage.sh` (Left/Right move, Space or W jump, Q throws). Losing restarts the fight. The boss is 2.16 player-heights tall. While it **hovers** it drifts
left and right and can be hit with thrown objects (500 hit points; a thrown object does 10, the mech's laser 20 per hit and a missile 80). Every few seconds it **charges over the player, turns upside down and shakes
itself like a real salt shaker (rocking and bouncing, the hardware inside rattling) while it sprays RAM sticks, CPUs and chipsets** out of the holes in its cap (each hit takes 12% of the player's health); it cannot be hurt
while it attacks. Then it flips back up and hovers again. Below half health it sprays longer and faster.
Code: `scripts/boss/` (`SaltShakerBoss`, `BossBullet`); the fight: `scripts/boss/boss_fight.gd` (`BossFight`); art: `assets/bosses/saltman/` (layers and five expressions: idle, charge, attack, hurt, dead; `pose_sheet.png` shows them), made by
`python tools/art/generate_boss_shaker.py`; test: `tools/tests/boss_test.gd`.

## Energy

A thin blue **energy bar** sits under the health bar. Every thrown object costs **10%** of it (with less than 10% left you cannot throw). While you are not throwing or firing the EMP gun it refills at **10% of the bar per second** (`Player.ENERGY_RECOVERY`), a little every step (not in jumps once a second); bleeding halves that. It is `Energy` ([energy.gd](../scripts/common/util/energy.gd)), also used by the mech; it is carried to the next level and full again after a respawn. `tools/tests/energy_test.gd` checks it.

## Power-ups and the mech

A **power-up box** (the `powerup_box` tile, `PowerUpBox`) floats and bobs in a level; the "?" on it glows in slowly changing colours, breathing and blinking, because what is inside is random. **Touch it**: the moment your body (or the mech's) overlaps it, from any side, it breaks apart in six frames and gives you the power-up inside (`PowerUps`; for now there is one kind, the mech). The pickup works like a vehicle power-up in Jetpack Joyride (`MechAssembly`): **you stop where you are, held in the air**, and the parts of the mech (body, cab glass, both turrets, four legs with joints and claws) **fly in from all sides and snap together round you** (about 1.4 s, so there is time to see where you are and get ready for the landing: the boxes hang over pits). You cannot move or be hurt meanwhile. As the last part begins to attach, a big, soft white glow (`WhiteFlash`, three times the size of the player, no flash over the screen) swells round the mech and **every part flashes white**; at the peak the real mech takes your place underneath and the white parts fade away over it, so it melts into view, and you fall as usual. If you are **already in the mech**, the box mends it (no damage, a full tank) and gives you **500 points** instead. Place one with the level editor (group "Pickups") or the level tool.

**Every level has one box**, placed as a small challenge: it hangs over a pit or a gap, a tile or two past the end of a ledge and 105 px above the ledge's top, so you have to jump from the ledge out over the gap and reach it with your body. A player on foot can just reach it; `tools/tests/powerup_levels_test.gd` checks that for every level.

**What goes with you to the next level:** your health, your energy and the mech, in the state it was in (its damage still showing, its energy level) are carried into the next level, as is the score. A new game (and the game starting over after the last level) starts from nothing. (`GameStats.carried`; dying inside a level still respawns you at the checkpoint on foot, with the score kept.)

**Score and points text:** the score goes up the moment something is earned, and a small gold "+100" floats up from where it was earned and fades (`ScorePopups`): no delay, and nothing is added together, so every award has its own text. Points: a Bro 100; a destroyed pit creature (a piranha, a puffer fish or an eel) 50 (the lava's fireball cannot be destroyed, so it scores nothing); each hit on the boss 100 and the boss 2500; mending the mech 500. The score is kept when you respawn and goes with you from level to level (points earned while a level is being finished still count). It goes back to 0 only when the game ends: after the boss level (the "THE END" banner) the game starts again from level 1.

The **mech** (`scripts/vehicle/`: `Mech` the rules, `MechVisual` the look, the legs and the damage, `MechMissile`, `LaserBeam`; the explosion, debris and particles are shared effects in `scripts/common/effects/`) is a four-legged walker with a yellow construction-crane body, tentacle legs like Doctor Octopus's, and you sitting in the cockpit. It is a child of the player, so hits, the camera and the level treat it as the player:

- **Size and durability:** 1.5 times the player's size. It has **no health bar and shows no numbers**: it survives **2 hits and the 3rd destroys it**, whatever the hits are (an enemy, a boss's attack, anything that hurts the player except spikes; the amount does not matter, and the usual short invulnerability after a hit applies). **Spikes do not hurt it**: it is meant to go over obstacles. The damage shows on the mech itself: **hit 1** cracks across the body and the cockpit glass, **hit 2** the near front leg snaps (its end falls off and the stump hangs, sparking) and smoke streams from the exhaust and the engine, **hit 3** it explodes (a fireball, a shock ring, sparks, smoke, its parts flying), and you drop out on foot with your own health untouched. Poison, burning, bleeding and radiation cannot get in; a deadly pit still kills you, mech and all. **A mech that is lost stays lost**: when it is destroyed (or lost with your life) it is no longer carried, so a level that starts again (the boss fight after a defeat) does not give it back; you find another in a power-up box.
- **Solid where it is drawn:** besides the player's box it has a second box for the cab, engine block and hull (150 x 104 px) and a thin one for the laser barrel, so walls, crates and laser gates stop it where its body is, not 30 px inside them. The hull's two bottom corners are cut away steeply, so when it lands on the edge of a ledge or a block with its middle past the edge it **slides off** and lands, instead of lying on its belly with its feet dangling (it stands on the ledge when it is properly on it). Its legs are not solid and fold in when a wall is beside them. Enemies stop at the edge of its body.
- **Walking:** a little slower than on foot. The legs **climb a step of one tile** (up to 76 px) just by walking up to it, without stopping or jumping: the body starts rising as it nears the step (a ray from above finds the step's exact height), is held at that height while it moves over, and walking down a step keeps the feet on the floor; a step of **two tiles or more stops it**, and the booster takes it over. **The gait is a diagonal trot**: the legs are two pairs (rear and second-from-front, second-from-rear and front) that take turns, so two feet are always on the ground; the cycle follows the distance walked (one step per foot every 120 px), so slower walking means slower steps, about 2.7 steps a second per foot at full speed. The body bobs twice per cycle, a foot that is down shows an open, flat claw standing on the floor (a separate picture, `claw_open.png`; a foot in the air keeps the curled claw), and a mech that stops puts its feet square again. A foot is never farther than 145 px from its hip (a leg is about 116 px long at rest), and after a jump the feet come down onto the floor at once. The mech cannot climb ladders: Up at a ladder does nothing (it does not light the booster). If the mech stands where not all its legs have a floor (a narrow ledge, an edge), those legs curl up and the **booster burns low** (just for show): it is held up, not floating.
- **Booster and energy:** the only bar is a blue **energy** bar (no label) above the mech (under the hull instead when there is a low ceiling above). Hold the jump button and the booster lifts the mech (a tap is a hop) while there is energy (a full tank is 1.32 s of boosting); out of energy it falls under gravity even with the button held. The tank fills back up progressively, in 3 s from empty, whenever neither the booster nor the laser is on. Laser gates are sealed from the floor to the ceiling, so it cannot fly over them.
- **Weapons:** the heavy attack (S, the X button) fires a **missile** from the roof turret (detailed tube ends with the missile's red nose showing; an exhaust flame, glow, sparks and a smoke trail; slow start, homing a little, blast radius 110 px, 80 damage; it blows up in a fireball with a shock ring, sparks and smoke); the light attack (Q, the C button) works a blue **laser** from the front turret **for as long as the button is held**, using the same energy (a full tank is 4 s of laser; it stops when the energy is gone). A missile uses **60% of the energy** and nothing else holds it back: there is no wait between missiles, only the tank (it needs 60% left). (The laser is a thin bright beam with a soft blue glow, a white-blue flare at the muzzle and where it ends, blue embers along it and a burst of sparks on a hit; it hurts an enemy it rests on for 20 damage every half second, 760 px reach). Both turrets aim at the nearest enemy in front of you, otherwise straight ahead, and neither weapon is ever stopped by the mech itself.

Art: `assets/powerups/box/` (the box, `box_base`, `box_question`, six `box_break_*` frames) and `assets/vehicles/mech/` (body, canopy, turrets, leg links, joints, claw, hip, flame; `preview.png` shows them assembled) and the damage and weapon effects (cracks, broken link, smoke, missile and its flame, laser rings), made by `python tools/art/generate_powerup.py`, `python tools/art/generate_mech.py` and `python tools/art/generate_mech_effects.py` (run in that order; the last one also draws the explosion frames and the laser's flare). The box is drawn in the style of the level tiles (the metal crate: steel with a light top lip, rivets, cyan edge lights). Test: `tools/tests/mech_test.gd`. Level 1 has a box near the start.

## HUD

Floating text along the top of the screen, with no bar behind it (`scripts/ui/hud.gd`; thick outlines and a shadow keep it readable), shows the score (**SCORE:** on the left) and the level number (**WORLD:** on the right), both on one line in a small font, numbered like
Super Mario Bros: the six levels of the game are 1-1 to 1-6 (the boss level is 1-6; `LevelData.STAGES_PER_WORLD` levels per world; a level file can set its own with
`meta.stage`). Defeating an AI Bro scores 100 (`GameStats`). More items will be added to the row later. The level's name is no longer
drawn on the background.

While RAM Saltman shakes and sprays in the boss stage, an AI Bro walks in from just beyond the edge of the screen, from the side the player
is FARTHER from, so it never lands on them (at most one per side at a time; they are stand-ins for the real minions). The arena has no
visible side walls: the floor runs on in both directions, but the player is fenced in by two columns of **invisible wall** tiles (Bros
walk through them), and the fight starts calmly with the player and the boss far apart (the boss hovers for 7 seconds before its first
attack). The two small ledges are cover: stand under one while he sprays.
