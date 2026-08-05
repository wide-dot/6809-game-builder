# Import a v1 routine whole, or you will ship two of it

## Symptom

A v1 routine gets imported in **two halves, months apart**, under two names,
and the two copies drift. Concretely, in the R-Type port:

- the stage init cleared both buffers to `$0000`, through two paged calls to an
  interlaced-clear routine, then called a locally-invented `preScroll` ;
- the death path called `checkpointLoad`, which cleared to `$0000` **again**,
  by the same two paged calls, then called that same `preScroll`.

Both were halves of **one** v1 routine, which clears to `$FFFF`, once, and then
pre-scrolls. Symptoms observed before anyone noticed: the starfield stopped
drawing after the first death (the sky was cleared to nibble 0 instead of
nibble 15, and stars only draw on nibble-15 "virgin sky"), and stage graphics
stayed visible behind the READY message (the whole-window clear lived in the
half that was never imported).

## How it happens

Not by carelessness — by a reasonable-sounding decision taken twice.

The first import needed only the pre-scroll: checkpoints were not on the
schedule yet. So the pre-scroll half was lifted out of the middle of the v1
file, given a name of its own, and given a parameter it never had (an entry
position in `U`, because `paged.call` had taken `X` and `A`). The v1 routine's
own name went unused.

Months later the checkpoint *was* scheduled. The importer opened the v1 file at
`checkpoint.load`, read forward, and imported what it saw — landing squarely on
the half already ported. The bits **above** the reading point (the whole-window
clear) and the constant that had been changed (`$FFFF` → `$0000`) went
unnoticed, because at no point did anyone diff the finished v2 routine against
the whole v1 file.

## The v1 shape

One routine, no parameter, two callers:

```asm
Level01_Start                          ; stage opening
        ...
        jsr   InitScroll
        _Obj_Run ObjID_checkpoint      ; <- here

mainloop.routine.checkpoint            ; after a death
        ...
        _Obj_Run ObjID_checkpoint      ; <- and here
```

It takes no argument because it derives one: it scans `checkpoint.positions`
for the last entry `<=` `scroll_tile_pos`. At stage opening `scroll_tile_pos`
is zero, so the scan yields the first checkpoint and the routine pre-scrolls
from the start. **That is how v1 gets its opening pre-scroll without a line of
dedicated code** — and it is exactly what a hand-written `preScroll(position)`
throws away.

## The rule

**Port a v1 routine from its first byte to its last, even when you only need
part of it today.** If only part is wanted, import the whole thing and call it
from one place; do not lift the middle out.

Two checks make the failure impossible:

1. **Read the whole v1 file before writing any v2 line.** Not from the label
   you were looking for — from the top. The clear that was missing sat eleven
   lines above the label the importer opened on.
2. **Before declaring a routine ported, diff it against the v1 source as a
   whole**, constants included. `$FFFF` versus `$0000` was one nibble in a
   comment-free line, and it cost the starfield.

When a v2 constraint genuinely forces a split (here: `paged.call` owns `X` and
`A`, so a mounted entry cannot take a register argument), the split belongs
**inside** the imported unit, as a documented `V2-DEVIATION` shim in front of
the intact routine — never as a second routine at the call site.

## See also

- [Relative toggles on shared registers](relative-toggles-on-shared-registers.md)
  — the bug that unifying this routine exposed.
- `engine/v1-manifest.csv` — the ledger where each imported file records its
  v1 origin and its deviations. An entry per *file*, not per fragment, is what
  makes a half-import visible.
