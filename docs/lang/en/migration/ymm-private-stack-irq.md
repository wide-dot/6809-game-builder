---
status: SHIPPED
updated: 2026-08-15
governs: engine/sound/ymm.asm
---

# The YMM private stack vs. the main-loop IRQ

## The v1 idiom

The v1 YM2413 player (`engine/sound/YM2413vgm.asm`) runs entirely **under
the VInt**: the music frame — wait handling, register writes, and the
on-the-fly ZX0 unpacking that feeds the ring buffer — executes inside the
interrupt handler, where further IRQs are implicitly masked. The unpacker
suspends itself between frames by parking its registers on a **private
stack** carved right inside the module (`lds #@stackContext`, 32 bytes),
with its state variables (`@stackContextPos`, `@mode`, `@flip`,
`@zx0_bit`) living directly below that stack.

Under the VInt this is safe by construction: nothing can preempt the
producer while S points into the private zone, so the only bytes ever
pushed there are the producer's own (parked context + a few `bsr`
returns), well within the 32-byte margin.

## What broke in v2

The v2 KEPT-V2 module (`engine/sound/ymm.asm`) moved the frame call out of
the interrupt: `ymm.frame.play` runs from the **main loop, IRQs open**.
The streaming adaptation had already been caught twice forgetting state
the VInt context used to guarantee (`@flip` reset at launch, the buffer
padding that keeps the ring-wrap shortcut valid — both documented in the
module). This is the third member of the same family, and the sneakiest:

- the producer runs thousands of cycles per frame with S parked on the
  private stack ;
- when the 50 Hz IRQ lands in that window, it pushes its **12-byte machine
  state plus the handler's own stack depth** onto the private stack ;
- past the 32-byte margin it smashes `@stackContextPos` / `@mode` /
  `@flip` / `@zx0_bit` — the byte-parity tracker breaks, frame boundaries
  shift by one byte, **no wait byte is ever seen in phase again**, and the
  machine spends its frames writing YM registers (~1 game frame per
  second, camera apparently frozen).

Whether it hits is pure IRQ phase at the moment of the launch: a coin
flip on every `ymm.obj.play` / `ymm.restart` / loop-restart, re-drawn by
any relayout that shifts code addresses. It was repeatedly misdiagnosed
as "relaunching the player mid-stream desyncs the ring", and "fixed" by
adding `ymm.stop` before relaunches — pure phase shims: `ymm.obj.play`
already does a full reset (`ymm.buffer.reset`, fresh decompress, `@flip`
cleared), and stop-then-play is semantically identical to play alone.

## The v2 rule

**IRQs are masked whenever S sits on the private stack.** Both entry
points (`ymm.decompress`, `ymm.frame.resume`) push the caller's CC, mask
with `orcc #$50`, and every exit funnels through `@zx0_eof`, which
restores the caller's mask (`puls cc,pc`). Callers keep whatever IRQ
discipline they had — call sites that already run IRQ-off are unaffected.

The general lesson for KEPT-V2 modules extracted from an interrupt
context: list what the old context guaranteed implicitly — masking,
register banks, mounted pages, phase — and re-establish each guarantee
explicitly. This module needed three of them; they were found one costly
symptom at a time.
