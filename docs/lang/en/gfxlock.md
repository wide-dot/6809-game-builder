# gfxlock — the double buffer

The screen has two buffers, pages 2 and 3 : one is shown while the other is
drawn. gfxlock (`engine/graphics/buffer/gfxlock.asm`, its macros in
`gfxlock.macro.asm`) is the engine's one double buffer. The main loop says
when it draws ; the 50 Hz interrupt shows what was drawn, at the VBL, out of
the display : a swap never tears.

The MO6 targets and the MPLUS benches keep the v2 base,
`engine/system/thomson/graphics/buffer/gfxlock.asm` (`_gfxlock.swap` in the
interrupt) : the same protocol, the same rule.

## The frame

```asm
LevelMainLoop
        jsr   ReadJoypads
        jsr   RunObjects              ; the logic : no write to the screen
        _gfxlock.on                   ; the buffer to draw mounted
        jsr   EraseSprites            ; every write to the screen, and only here
        jsr   DrawSprites
        _gfxlock.off                  ; the drawing done : the interrupt shows it
        _gfxlock.loop                 ; the frames this loop took
        bra   LevelMainLoop

UserIRQ
        jsr   gfxlock.bufferSwap.check ; first : the swap at the VBL
        ...
```

A unit with several call sites expands each macro once, as a routine
(`gfxlock.on _gfxlock.on rts`), and calls it.

## The state

`gfxlock.status` is the whole protocol between the loop and the interrupt :

| value | meaning | set by |
|---|---|---|
| 1 | a buffer is being drawn | `_gfxlock.on` |
| 0 | a buffer drawn, its swap pending | `_gfxlock.off` |
| -1 | the swap made, nothing pending | `gfxlock.bufferSwap.check`, at the VBL |

- `gfxlock.bufferSwap.check`, in the interrupt, swaps only from 0 : one swap a
  drawing, never one without a drawing.
- `_gfxlock.on` waits only from 0, a loop quicker than the VBL. It then mounts
  the buffer to draw : the data window (`$A000-$DFFF`) and, in background-erase
  mode, the half page `$4000-$5FFF` of the sprites' saved backgrounds.
- The buffer to draw is bit 0 of `gfxlock.backBuffer.status` : page 2 or 3.
  `gfxlock.bufferSwap.do` shows that same page, then flips the state.
  `gfxlock.backBuffer.id` is the sprite structures' copy of it : `_gfxlock.loop`
  flips it, one swap a loop.

Before the swap, the data window still holds the buffer drawn last : the one
on the screen, or about to be. That is why the rule below exists.

## One section a main loop

**Every write to the screen sits between the loop's `_gfxlock.on` and
`_gfxlock.off`, and there is one such section a loop.** Code that writes the
screen moves into the section. Never open a section around the routine that
writes : a `gfxlock.on` in an object would wait for the swap in the middle of
the logic, and the loop would then have two sections.

A write outside the section lands in the image shown, one buffer in two : it
flickers. Writes to the screen include :

- a clear (`ClearDataMem`), a text (`DrawText`), a mask ;
- a compiled image called directly ;
- anything through a pointer into `$A000-$DFFF` or `$4000-$5FFF` ;
- `$E7E5` (the data window) or the half page bit of `$E7C3`.

The palette, the sound, the logic and the RAM tables run anywhere.

Two ways to bring a writer into the section :

- **Objects that draw directly all along** (a title, a menu, a text screen) :
  the section opens before `RunObjects`, and every object runs inside it. The
  logic then no longer overlaps the wait for the VBL : it suits a screen whose
  loop is light.
- **An object that writes now and then, in a loop whose logic must overlap the
  display** (a level) : `RunObjects` stays before the section, and the object
  asks for its writing instead of doing it. It stores its page
  (`_GetCartPageA`) and its routine in a variable of the game mode. Right after
  `_gfxlock.on`, the game mode runs it by `paged.call` and clears it. A
  restart that skips the section clears the request too.

## Start

1. **Before the interrupt starts**, set `gfxlock.status` to -1. A unit just
   loaded holds 0 there, a swap pending : the interrupt would swap in the
   middle of the buffers' drawing.
2. **Draw both buffers as `_gfxlock.on` would mount them**, never page 2 then
   page 3 by name :
   - mount the page given by bit 0 of `gfxlock.backBuffer.status`, and draw it ;
   - `gfxlock.bufferSwap.do` shows it ;
   - mount the page now given by bit 0, and draw it.
3. **`_gfxlock.init`**, then the loop. It reads `gfxlock.backBuffer.status`
   for `gfxlock.backBuffer.id`, and clears the frame-drop cap.

## The border

`gfxlock.bufferSwap.do` writes `$E7DD` : the page shown and the border
colour, `gfxlock.screenBorder.color`. To change the border, set that
variable : `gfxlock.screenBorder.update` takes the colour in B, and the next
swap applies it. Never read `$E7DD` to change its border bits : the register
is write-only, the value read is not the page shown, and writing it back
shows another page.

## Frames and the frame drop

- `gfxlock.frame.count` : the interrupt counts every 50 Hz frame.
- `gfxlock.frameDrop.count` : the frames the last loop took, set by
  `_gfxlock.loop`. The logic catches up on them : an object moves by its
  speed times the frames ([`objects.md`](objects.md)).
- `gfxlock.frameDrop.max` : a cap on that count, 0 for none. Set it after
  `_gfxlock.init`, which clears it.
- `gfxlock.frame.gameCount` : the level's clock. It advances by the capped
  count, so a timeline stays in step with what the screen shows.
- `gfxlock.bufferSwap.count` : the swaps made, one a loop.

To pace the images (each shown n VBLs at least), the interrupt routine keeps
the frame of its swap. That is when `gfxlock.status` was 0 before
`gfxlock.bufferSwap.check`. Before `_gfxlock.off`, the loop then waits until
`gfxlock.frame.count` is n − 1 past it : the swap comes at the next VBL.

## The wait's back process

While `_gfxlock.on` waits for the swap, it can run a routine in a loop :
`_gfxlock.backProcess.on <routine>` sets it, `_gfxlock.backProcess.off`
stops it. The routine runs again and again until the interrupt swaps, so it
does a small piece of work per call (a decompression step, a precomputation),
writes nothing to the screen, and keeps X, Y, U and DP : the code around
`_gfxlock.on` may hold them ; A, B and the condition codes are free.

## See also

- [`interrupts.md`](interrupts.md) : the interrupt, out of the display, and a
  raster through the split's interrupt (`IRQ_SPLIT`).
- [`sprites.md`](sprites.md), *Drawing* : the sprites' order inside the
  section.
- [`migration/waitvbl-to-gfxlock.md`](migration/waitvbl-to-gfxlock.md) : a v1
  `WaitVBL` loop brought to gfxlock.
