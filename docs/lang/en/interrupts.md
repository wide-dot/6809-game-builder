# Interrupts

`engine/irq/Irq.asm` runs the game's frame on the MC6846 timer : one
interrupt a frame, set on a line of the display, the frame counted
(`gfxlock.frame.count`) and the game's routine called (`Irq_user_routine` :
its palette, its sound).

## Setting the interrupt on a line

```asm
        jsr   IrqInit                  ; the monitor's TIMERPT : IrqManager
        ldd   #UserIRQ                 ; the game's routine, each frame
        std   Irq_user_routine
        lda   #255                     ; the line : 255, out of the display (VBL)
        ldx   #Irq_one_frame           ; the period : a frame, 312 lines of 64 cycles
        jsr   IrqSync
        jsr   IrqOn
```

`IrqSync` waits for that line, then loads the timer : the chip reloads it at
each expiry, so the interrupt keeps that line for good (the timer runs on
the CPU's clock, no prescaler : a period to the cycle).

## A second interrupt at a line : `IRQ_SPLIT`

A define, opt-in : a project that does not define it assembles the same
binary as before.

```asm
IRQ_SPLIT equ 1
        INCLUDE "./engine/irq/Irq.asm"
```

The game then asks, frame by frame, for a second interrupt at a line of the
display, to change the palette there (a water surface : Sonic 2's Chemical
Plant).

| Name | What |
|---|---|
| `Irq_split_routine` | the split's routine, a word the game sets : called with DP `$E7`, on the interrupt's own stack |
| `Irq_split_line` | the line of the display (0-199) where the next frames split, `$FF` none : the game's, any time |

What the split's interrupt does **not** do : count a frame, call
`Irq_user_routine`. So the music, the frame drop and every timing on the
frame counter keep the VBL's interrupt alone, exactly where it was.

### Why the VBL's interrupt keeps its phase

A latch written into the MC6846 restarts the counter when `TCR4` is clear :
the period would then start at the write, a few dozen cycles after the
expiry, and the VBL's interrupt would drift by that much at each split.
With `IRQ_SPLIT`, `IrqSync` sets `TCR4` after its own write (the sync itself
needs the restart) : a latch write no longer restarts the counter, the chip
loads the latch at the next expiry. So each period is written **one
interrupt ahead** :

| Interrupt | Counting now | It writes the latch for |
|---|---|---|
| the VBL's, the frame splits | VBL → split | split → next VBL : a frame less the first part |
| the VBL's, no split | VBL → next VBL | the next frame's first period |
| the split's | split → next VBL | the next frame's first period |

The two periods of a split frame sum to `Irq_one_frame` : the VBL's
interrupts stay a frame apart, to the cycle. The next frame's split is read
from `Irq_split_line` by the interrupt before its VBL : a line set during a
frame applies from the next one or the one after.

### Cost

- each frame : the scheduling, ~60 cycles ;
- a split frame : one more interrupt (the monitor's IRQ code first, some 90
  cycles on a TO8) and the split's routine ;
- the routine's writes land some lines after `Irq_split_line` : sixteen
  colours through `$E7DA` take some 370 cycles, near 6 lines, landing 2 to
  8 lines after the line asked. A game places its line accordingly (Sonic
  2 : 5 lines under its water's level, past its surface's sprite).

### Limits

- `Irq_split_line` counts from the line `IrqSync` set the VBL's interrupt
  on ; the split must stay inside the frame (any line of the display does
  with the VBL at 255).
- An interrupt masked by the game (a disk access, a `orcc #$50` section)
  comes late : the split's line moves for that frame, the VBL's period does
  not.
- The interrupt runs on its own stack : the split's routine may push.
