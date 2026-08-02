# The opening pre-scroll paints the viewport — port it

A v1 level does not start by drawing its first screen once. It **replays the
scroll**, painting the whole viewport column by column into both buffers. Port
that step, even when the screen looks right without it.

## Symptom

The screen looks correct. The scenery is there, pixel-aligned with v1, the
palette is right, the camera advances at the right speed. Nothing suggests a
missing init step.

Then something that reads the background does nothing at all. In the case that
produced this file it was the starfield: its entire test is *"is this sky pixel
`$F`?"*, and the sky was `$00`. Every star was skipped, silently, and the effect
simply never appeared.

The measurement, which took a minute and ended a long guess: take a star's VRAM
address straight from the generated table and read it.

```
$A916 → 00 00 00 00 00 00 00 00     ; sky is $00
                                     ; the effect wants $F
```

The general shape of the trap: **the viewport is only partially painted, and
nothing that draws on top of it will tell you.** Tiles, sprites and overlays all
write unconditionally, so they hide the gap. Only an effect that *reads* the
background before writing exposes it.

## The v1 idiom

`checkpoint.scroll` (in the game's `global/checkpoint.asm`) is called at level
start **and** at every checkpoint reload. It expects a blank palette on entry
and does:

- clear both buffers;
- rewind the scroll state — camera, `scroll_map_pos`, `buffer_x_pos` — to the
  entry position;
- then replay the scroll: start with a viewport **zero columns wide**, flush
  right (`scroll_vp_x_pos = 8+144-4`), and walk left 4 pixels at a time, adding
  one column every three steps, calling `DrawTiles` in **both** buffers at each
  step;
- restore the real viewport parameters;
- fade in.

Every column is therefore painted at each of its sub-positions, exactly as if it
had entered from the right.

## The v2 model

Unchanged — this is game code, not engine code, and it ports as-is. What changes
is that its absence is *no longer obvious*, because the v2 stage init paints a
plausible-looking first screen on its own: `InitScroll` leaves
`buffer_x_pos = -1`, so the first `Scroll` sees a mismatch and `DrawTiles` runs.
But it draws only the columns for the **current camera position**, so the
background rank never reaches the screen.

That is why "the screen looks right" is not evidence that the step is
unnecessary. It was skipped once on exactly that reasoning, and cost a full
debugging pass later.

## The fix

Port the routine into the stage body and call it right after `InitScroll`:

```asm
        ldd   #map.COLS*12-144
        std   scroll_max

        lda   #0                       ; entry position, in 24 px collision tiles
        jsr   stage.preScroll
```

Keep the position parameter even if the stage always passes zero — it is what
checkpoints will need, and it costs nothing.

The routine drives the scroll's internal state directly (`scroll_map_pos`,
`buffer_x_pos`, `glb_camera_x_pos_old`, `tile_buffer`, `tile_buffer_page`,
`scroll_tile_pos_offset`), so those have to cross the interface. They are
labels on variables inside the resident unit — real addresses, so they belong
there, unlike the constants in
[equates-link-boundary](equates-link-boundary.md).

## Proof

Read the background where the consumer expects it, not the screen. A star
address from the generated table is ideal: it is a real coordinate the effect
will use.

```
$A916 → FF FF …      ; sky now carries the nibble the effect tests for
```

Then the effect itself: stars present, **all** of them displaced between two
consecutive frames, and no accumulation after several hundred frames.

## The general lesson

When a v1 init sequence contains a step you cannot justify from the screen,
assume it is load-bearing for something not yet ported, and port it anyway.
Init steps are where a game pays once for invariants the rest of the frame
takes for granted — here, "the untouched sky is `$FF`", which the main loop
never re-establishes.

## Met in

`games/r-type`, 2026-08-02, porting the starfield. The step had been examined
and deliberately skipped earlier in the same session, on the grounds that the
first screen already looked identical to v1 — which it did.
