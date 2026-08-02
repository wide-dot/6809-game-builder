# Calling a routine that lives in a paged unit

Drawing code that has no state and no object structure is **a routine**, called
through `paged.call`. Do not make it an object.

## Symptom

You are porting something that v1 ran with `_Obj_Run ObjID_Mask`, and you go
looking for the object identifier to give it. There is none — the wave never
names it, so `gen_objid.py` never numbered it — and inventing one means finding
it a page, an index entry and a slot for something that has no state at all.

That friction is the signal. The object was never an object.

## The v1 idiom

```asm
@overlayNormal
        _Obj_Run ObjID_Mask
        _Obj_RunB ObjID_hud,#hud.NORMAL
```

Declaring the mask as an object was a **build hack**, and the v1 properties
file admits as much. It bought two things the v1 pipeline offered no other way
to get:

1. the compiled draw code was placed in a RAM bank rather than in the game
   mode's own image, which had no room for three kilobytes of `PSHU`;
2. the page was mounted before the call, because that is what the object
   runner does.

Neither has anything to do with the mask being an object. It has no OST, no
state, no routine index — one entry, one `RTS`.

## The v2 model

Both of those come for free now, and without the indirection.

**The page is an assembly-time constant.** A `<region>` in the layout produces
the equate `<region>.page`; a `<direntry>` exports `<name>$PAGE`, resolved at
load time. Either way the caller writes it as an immediate.

**The address is a link symbol.** The unit exports its entry, and the scene
load re-points it.

An object goes through `Obj_Index_*` because the **wave** names it by
identifier at runtime — the index is a dynamic lookup, and a drawing overlay
does not need one. It is known at assembly time.

Note also that the two paging windows are independent: code is banked at
`$0000-$3FFF` through `$E7E6`, video memory sits at `$A000-$DFFF` through
`$E7E5`. Mounting a draw routine's page does not disturb the buffer it paints
into.

## The fix

The engine side, `engine/system/paged-call.asm`:

```asm
* Entry : A = page to mount, i.e. map.RAM_OVER_CART+<region>.page
*         X = entry address of the routine
* Exit  : B clobbered. Everything else belongs to the callee.

paged.call
        _GetCartPageB                  ; the caller's page, to be given back
        pshs  b
        _SetCartPageA                  ; mount the routine's page
        jsr   ,x
        puls  b
        _SetCartPageB                  ; give the caller its page back
        rts
```

Add `_api paged.call` to the interface list — it is a routine, so it may cross
the boundary (see [equates-link-boundary](equates-link-boundary.md) for what
may not).

The call site, in the stage's draw phase:

```asm
        lda   #map.RAM_OVER_CART+overlay.page
        ldx   #adr_playfield_mask_ND0
        jsr   paged.call
```

and the consuming unit declares the entry:

```asm
adr_playfield_mask_ND0 EXTERNAL
```

Two units share a `stage-main.asm`? Both declare it. The `interface="true"`
region requires the same export list from every alternative, and a missing
`EXTERNAL` in the second one fails the build for the first.

## Why not `RunPgSubRoutine`

It exists, it does the same job, and it is the v1 idiom. It uses
self-modifying operands (`PSR_Page`, `PSR_Address`, `PSR_Param`), so it costs
three stores at the call site and **is not re-entrant**. `paged.call` keeps the
caller's page on the stack instead. Prefer it for new code; `RunPgSubRoutine`
stays for the fire chain that already depends on it.

## Choosing the call shape

Three shapes were costed before settling on the register-passing one. For N
overlay routines:

| N | inline macro | registers (`paged.call`) | table walked by the engine |
|---|---|---|---|
| 1 | 18 B | 24 B | 39 B |
| 2 | 36 B | 32 B | 42 B |
| 4 | 72 B | 48 B | 48 B |
| 6 | 108 B | 64 B | 54 B |

v1 ran mask + hud in its overlay phase, and starfield, erasers and messages are
coming, so N lands between 2 and 4 — where the register form is at least as
compact as a table and has nothing to keep in sync. Move to a table only past
five or so entries; converting is mechanical, each call site becoming a row.

## Proof

The overlay draws every frame, over everything else, and the rest of the frame
is unchanged. Where a v1 comparison exists, the overlay is the last thing to
paint — after `DrawSprites` — so check that sprites are not painted over it.

## Met in

`games/r-type`, 2026-08-02, wiring the playfield mask. The region is
`overlay` (page 16), shared with the hud and messages when they land, so that
one page mount covers the whole overlay phase.
