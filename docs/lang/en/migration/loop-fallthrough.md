# A v1 main loop is jumped to; a v2 stage body is fallen into

v1 put its dispatch variable and its jump table *between* the dispatch and the
first routine. That is safe there, and unsafe here — for a reason that has
nothing to do with the loop and everything to do with what a unit is.

## Symptom

The stage opens normally, plays, and then the machine is somewhere it has no
business being: `PC` inside the `$A000-$DFFF` window with no code in it, `DP`
back on the monitor's page, the player's OST in direct page reading `$FF`
end to end. The trace ring shows a two-byte loop at an address that appears in
no listing.

Nothing upstream reports anything. The unit loaded, the link resolved, the
opening frames drew.

## The v1 idiom

```asm
LevelMainLoop
        lda   mainloop.state
        ldx   #mainloop.routines
        jmp   [a,x]

mainloop.state.RUNNING    equ 0
mainloop.state.DEAD       equ 2
mainloop.state.CHECKPOINT equ 4
mainloop.state
        fcb 0

mainloop.routines
        fdb   mainloop.routine.running
        fdb   mainloop.routine.dead
        fdb   mainloop.routine.checkpoint

mainloop.routine.running
        ...
```

The byte and the table sit in the instruction stream and are never executed,
because **nothing falls into `LevelMainLoop`**. A v1 game mode reaches its loop
by `jmp LevelMainLoop`, from init code that ends with that jump. The label is an
address someone wrote down.

## The v2 model

A stage unit is one linear block whose entry point is its first byte (see
[A unit begins at its entry point](unit-entry-point.md)). Its opening code is
therefore *above* the loop in the same section, and it reaches the loop by
**falling into it** — there is no jump to write, and no reason to write one.

That single change turns the v1 layout into a bug: the last instruction of the
opening is followed by `fcb 0`, which the CPU executes. `$00` is `NEG` direct,
so it writes through `DP` first, then the address table decodes as more
instructions. By the time anything is observable, the direct page — where the
player's OST lives — has been rewritten and `PC` is off in video RAM.

## The fix

Put the variable and the table **after** the `jmp`, where nothing can reach
them:

```asm
stage.loop
        lda   mainloop.state
        ldx   #stage.states
        jmp   [a,x]
stage.states
        fdb   stage.state.running
        fdb   stage.state.dead
        fdb   stage.state.checkpoint
mainloop.state fcb 0

stage.state.running
        ...
```

The general rule, and it is worth stating without the loop: **in a v2 unit,
every `fcb`/`fdb`/`fcc` must sit behind an unconditional `jmp`, `bra` or `rts`.**
v1 code can be copied verbatim everywhere except here, because v1's entry
convention hid the constraint.

## While you are there: do not re-derive the dispatch

The same port also grew an `asla` that v1 does not have. The state constants are
already **word offsets** (0, 2, 4) precisely so the dispatch can index the table
without scaling. Doubling them sends `DEAD` to the `CHECKPOINT` entry and
`CHECKPOINT` two words past the end of the table — the same class of symptom,
from the same cause: rewriting three lines instead of copying them.

Both faults were introduced in one sitting, by someone who had the v1 source
open. Copy first, understand second; a 1:1 import you retyped is not an import.

## Proof

The listing answers it without running anything. The entry code's last
instruction and the first byte of `stage.loop` must be adjacent, and the first
data byte must come after a `jmp`:

```
00FD BD0000    jsr   IrqOn
0100           stage.loop
0104 8E0000    ldx   #stage.states
0109           stage.states
010F 00        mainloop.state fcb 0
0110           stage.state.running
```

`$0109` and `$010F` are both past the `jmp` at `$0106`. Before the fix,
`mainloop.state` was at `$0100` — the byte `jsr IrqOn` returned into.

## Met in

`games/r-type`, 2026-08-03, porting the v1 death / checkpoint state machine
into the shared stage body.
