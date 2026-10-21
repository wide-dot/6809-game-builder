# A v1 `WaitVBL` main loop becomes a gfxlock frame

v2 has one double buffer, gfxlock (`engine/graphics/buffer/gfxlock.asm`, the
frame in [`../sprites.md`](../sprites.md), *Drawing*). v1's `WaitVBL` is not
imported : a v1 main loop ending in `jsr WaitVBL` is rewritten around
`_gfxlock.on` / `_gfxlock.off`, and the interrupt makes the swap.

## Symptom

`WaitVBL` is an undefined symbol at link time (the file is gone), or, in a
build of before its removal :

- a loop of several frames waits for the beam to leave the screen before it
  swaps : up to a frame lost every loop, half a frame on average ;
- with `DO_NOT_WAIT_VBL` (v1's no-wait), the swap made at once when two
  frames or more went by : the screen torn mid-display (Sky Chase, a camera
  moving every frame : a band of the old image under the new) ;
- the frames a loop ran, `gfxlock.frameDrop.count`, counted from the call to
  `WaitVBL`, not from the swap.

## The v1 idiom

```
LevelMainLoop
        jsr   ReadJoypads
        jsr   RunObjects
        jsr   EraseSprites
        jsr   DrawSprites
        jsr   WaitVBL                  ; beam out of the screen, swap, count
        bra   LevelMainLoop
```

The interrupt counted the frames ; `WaitVBL` polled `$E7E7` for the beam,
wrote the buffer to show to `$E7DD`, mapped the other one to draw, and set
`gfxlock.frameDrop.count` from the frames elapsed, capped by
`Vint_Main_runcount_cap`. Reasonable on v1, whose games ran a frame or two a
loop : the wait was short and the code that wrote the screen could do it
anywhere in the loop. A raster effect was timed by `IrqSync` after the swap.

## The v2 model

The drawing is bracketed, and the interrupt shows what was drawn :

- `_gfxlock.on` before the first write to the screen : it waits only when the
  previous drawing is not yet shown, then maps the buffer to draw ;
- `_gfxlock.off` once the drawing is over ; `_gfxlock.loop` after it toggles
  `gfxlock.backBuffer.id` and sets `gfxlock.frameDrop.count` (its cap
  `gfxlock.frameDrop.max`, 0 none) ;
- the interrupt's user routine calls `gfxlock.bufferSwap.check` first : at the
  VBL, a drawing done is shown. The interrupt is out of the display (line
  255) : the swap never tears.

The logic before `_gfxlock.on` runs while the previous image waits for its
VBL : it overlaps the display instead of waiting for it. Nothing may write
the screen outside `on` and `off` : before the swap, the buffer to draw is
the one shown. A palette change at a line of the display is the split's
(`IRQ_SPLIT`, [`../interrupts.md`](../interrupts.md)), the VBL's interrupt
kept for the swap.

## The fix

1. Include `engine/graphics/buffer/gfxlock.macro.asm` and
   `engine/graphics/buffer/gfxlock.asm` instead of `WaitVBL.asm`.
2. `_gfxlock.init` once the act is loaded and its two buffers drawn ; where
   v1 called `WaitVBL` to show a buffer outside the loop (a start image),
   `gfxlock.bufferSwap.do`.
3. The loop :

   ```
   LevelMainLoop
           jsr   ReadJoypads
           jsr   RunObjects
           _gfxlock.on
           jsr   EraseSprites
           jsr   DrawSprites
           _gfxlock.off
           _gfxlock.loop
           bra   LevelMainLoop
   ```

   A unit with several call sites expands the macros once, as routines
   (`gfxlock.on rts`), and calls those.
4. `jsr gfxlock.bufferSwap.check` first in every user routine the interrupt
   may run (`Irq_user_routine`).
5. Every other writer of the screen inside `on` / `off` : an object that
   writes the screen in its own routine calls `gfxlock.on` first (a second
   call returns at once, the buffer already mapped).
6. `Vint_Main_runcount_cap` becomes `gfxlock.frameDrop.max`.
7. A raster timed by `IrqSync` becomes a split interrupt : `IRQ_SPLIT equ 1`,
   `Irq_split_line` and `Irq_split_routine` (the routine restores the
   cartridge page it changes).
8. A pace on the swap (an image shown n VBLs at least) reads the frame of the
   swap in the user routine (`gfxlock.status` 0 before the check : a swap
   now) and waits before `_gfxlock.off` until `gfxlock.frame.count` is n − 1
   past it : the swap comes at the next VBL.

## Proof

- `examples/irq` (its five tests rewritten on gfxlock : the frame wait, the
  swap at the interrupt, the drop and its cap, the beam) : the bench 19/19,
  the same values as before.
- Sonic 2's special stage (a step paced two VBLs at least, the logic checked
  against s2's model loop by loop by `tools/ss_bench.py`) : 1 000 loops from
  stage 1 into stage 2, 2 521 VBLs on `WaitVBL`, 2 478 on gfxlock ; the
  logic identical.
- Sonic 2's level game mode (loops a second, under toje) : Emerald Hill 1
  running right 9.7 with v1's no wait, 10.3 on gfxlock ; Sky Chase, the
  whole zone, 11.39 and 11.37 — and no tearing : every swap on the VBL's
  line (toje's `hw_trace`, the `$E7DD` writes).
- Sonic 2's title (the same frames of the game's 50 Hz counter, no input) :
  from frame 300 to 1 200, 436 loops on `WaitVBL`, 462 on gfxlock ; its last
  400 frames, where a loop takes more than a frame, 12.9 loops a second then
  15.9. The raster at line 139 unchanged on the screen.

## Met in

Sonic 2 (`wide-dot/sonic-2`), 2026-10-21 : the title (its raster at line 139
moved to the split), the level game mode, the special stage ; Sky Chase's
tearing under `DO_NOT_WAIT_VBL` was the trigger. R-Type was already on
gfxlock. `WaitVBL.asm` removed from the engine (wide-dot/6809-game-builder#85).
