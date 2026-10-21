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
  2 : 8 lines under its water's level, past its surface's sprite).

### Limits

- `Irq_split_line` counts from the line `IrqSync` set the VBL's interrupt
  on ; the split must stay inside the frame (any line of the display does
  with the VBL at 255).
- An interrupt masked by the game (a disk access, a `orcc #$50` section)
  comes late : the split's line moves for that frame, the VBL's period does
  not.
- The interrupt runs on its own stack : the split's routine may push.

## The buffer swap at the VBL : `DO_NOT_WAIT_VBL`

A define, opt-in : a project that does not define it assembles the same
binary as before (`WaitVBL` waits for the beam to leave the screen, then
swaps the two screen buffers).

A game whose loop takes several frames loses, waiting, half a frame a loop
on average ; swapping at once instead tears the screen (the page shown
changes in the middle of the display). With `DO_NOT_WAIT_VBL` the swap is
deferred to the interrupt, set on a line out of the display (`IrqSync`,
255) :

```asm
DO_NOT_WAIT_VBL equ 1

MainLoop
        jsr   WaitVBL                  ; the swap asked : no wait
        ...                            ; the objects : nothing written to the screen
        jsr   WaitVBL.done             ; the buffer drawn shown : this one mapped
        ...                            ; the drawing
        bra   MainLoop
```

- `WaitVBL` asks the swap and returns : it turns `gfxlock.backBuffer.id`
  (the buffer the objects display into), counts the frames since its last
  call (`gfxlock.frameDrop.count`), and leaves the display register's value
  in `WaitVBL.pending`.
- `IrqManager`, at the VBL's interrupt, writes it to `$E7DD` : the buffer
  drawn shows from the top of the next frame.
- `WaitVBL.done` waits for that write, then maps the other buffer to draw
  (the data window `$E7E5`, the screen window's half `$E7C3`). The
  interrupt off (`$6019`) or masked : it writes `$E7DD` itself.

Between `WaitVBL` and `WaitVBL.done` the data window still holds the
buffer just drawn : nothing there may write the screen (a game's objects
display into lists, the drawing comes after). Two calls of `WaitVBL`
without `WaitVBL.done` in between (an act's start clearing both buffers)
show the last buffer asked ; `WaitVBL.done` counts the swaps asked since
its last mapping and toggles the screen window's half when it is odd.

### Cost

- `WaitVBL` 61 bytes, some 110 cycles ; `WaitVBL.done` 62 bytes, some 100
  cycles and the wait, if the drawing comes before the VBL (+44 bytes
  against the waiting `WaitVBL`) ;
- the interrupt : 11 bytes, 8 cycles a frame, 20 when it swaps.

### Limits

- The interrupt must be set out of the display : the swap lands when it
  runs.
- A loop faster than a frame waits in `WaitVBL.done` : a frame a loop at
  most, as with the waiting `WaitVBL`.
