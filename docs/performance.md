# Performance

How the game is kept smooth, what was measured, and how to measure it again. The target is 60 frames a second on a phone; a frame that takes longer than 33 ms (two missed frames) is a stutter.

## What the game does about it

| Problem (measured) | What the game does | Where |
|--------------------|--------------------|-------|
| The first time a pose of the hero was shown (jump, throw, shoot) its picture was made: pictures read, recoloured, blended: 10-20 ms each on a PC, far more on a phone. | Every pose of the outfit worn is made **in advance, a little at a time** when a level starts and while the wardrobe is open. Recoloured parts are kept (changing one piece of an outfit recolours only that piece). | `OutfitComposer.warm_up()`, `WarmUp` |
| The first explosion, bolt, energy wave, thrown object and sound each cost a few frames when first needed (pictures read, materials set up). | `EffectWarmUp` makes each effect once, nearly invisible, in the middle of the screen, and reads the throwable pictures and every sound, a little at a time at the start of a level. Sounds are kept (`Sfx.stream` used to read the file at every play). | `EffectWarmUp`, `Sfx` |
| A level was 1,300 to 2,300 `Sprite2D` nodes (every tile; the solid ones twice, with their shadow): slow to build (about 110 ms of a level's 200 ms on a PC) and heavy to keep. | The still tiles are **batched**: one `MultiMeshInstance2D` for all the pictures that share a texture, a depth and a tint. The same pixels, 85% fewer nodes. Tiles that need to be nodes (lamps, sirens, pulsing lights) still are. | `SpriteBatch`, `Level._place()` |
| Live screens, pulsing lights and laser fields redrew every frame wherever the camera was. | An `OffscreenSleeper` in each level puts them to sleep (no `_process`) while they are further than 320 px from the screen and wakes them before they are seen. | `OffscreenSleeper`, `Level.sleeper` |
| Losing to the boss loaded the whole level again. | The boss fight is taken down and started again in the same level (`BossFight.clear()`, `Main._restart_fight()`). Dying elsewhere already respawns at the checkpoint without loading anything; finishing a level still builds the next one. | `Main` |

`WarmUp` is the shared tool: it does a list of jobs a few a frame (3 ms of each frame at most, and at least one job) and removes itself. A new thing that costs a stutter the first time can be made ready the same way.

## Measuring

- **See stutters while playing:** start the game with `SABOTAGE_PERF=1`. A corner of the screen shows the frame rate, the average and worst frame of the last second, the number of stutters and the node count; every frame over 33 ms is printed in the console (`PERF spike: 41 ms at 3.2 s`). F3 hides and shows it. (`PerfOverlay`)
- **On a phone:** use Godot's remote debugger (Debugger > Monitors and Profiler) with the phone connected over USB; the overlay needs the environment variable, which a phone build does not have.
- **Headless tests cannot show rendering costs.** Time things in a real window: `godot --path . --script res://tmp/<probe>.gd --disable-vsync` (a window opens) and read the frame times from `Time.get_ticks_usec()` between frames; `Performance.get_monitor()` has the node and draw-call counts.

## Measured (a PC with a mid-range laptop GPU; a phone is several times slower)

| | Before | After |
|-|--------|-------|
| Nodes in level 3 / level 5 | 1,784 / 2,348 | 279 / 305 |
| Frames over 12 ms after the first half second (scripted run: run, jump, throw, heavy attack; 14 s) | 8-9 | 0 |
| Average frame | 1.5-1.8 ms | 1.2-1.3 ms |
| Worst frame after the first half second | 24-43 ms | none over 12 ms (only the first two frames of a scene start are long) |

## Ideas not done yet

- A `TileMapLayer` instead of the batches would make the level's tiles editable in a standard way and cull off-screen tiles; the batches already remove the node cost.
- Palette-swap shader instead of recolouring pictures in script: recolouring is about 2 ms of the 10-20 ms a pose costs (the rest is reading pictures), so it was not worth the change.
- Building the next level while the "level complete" message shows (it needs its tiles and nodes made off the main thread).
