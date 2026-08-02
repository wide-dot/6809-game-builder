# Screen coordinates are offset

`x_pixel` / `y_pixel` live in `screen_left..screen_right` ×
`screen_top..screen_bottom` — 48..207 × 28..227 — not 0..159 / 0..199.

## Symptom

A sprite placed at what looks like a sensible position is never drawn, and
nothing says why. At `x = 40` it is off-screen by the engine's reckoning, so it
is silently skipped through the `rsv_render_outofrange` flag.

## The v1 idiom

Same engine, same offsets — this is not a v2 change. It bites during migration
because a port often re-derives coordinates from artwork or from a level
editor, where the natural origin is zero.

## The v2 model

Unchanged. Two rules to hold together:

- **pixel coordinates are offset**, as above;
- **playfield coordinates are ignored unless you ask for them**: without the
  `render_playfieldcoord` flag the engine does not look at `x_pos` / `y_pos`
  at all.

## The fix

Add the offsets, or set `render_playfieldcoord` and work in playfield space.
Whichever you choose, be explicit — the failure is silent in both directions.

## A companion gotcha: `DisplaySprite` is called every frame

`DisplaySprite` is not a one-off registration. The object's own routine calls
it **on every frame**: it enrols the object in the priority structure of the
*current* buffer, and there is one structure per buffer. Call it once and the
sprite appears in one buffer out of two, which reads as a flicker rather than
as a missing call.

## Proof

The sprite appears. If it does not, check the out-of-range flag before
suspecting the draw routine — the engine already decided not to draw.

## Met in

Recorded from the `sound/to8` pilot, 2026-07-31.
