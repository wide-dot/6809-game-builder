# The render structures are resident in v2 — a mode entry must purge them

## Symptom

Small, silent, and it moves from one run to the next: **one glyph of the title
logo is missing** — the `R`, the dot, the `P` — but only on the title reached
*after* a game over. The title reached from boot is always complete, in the same
build and at the same point of the attract sequence.

Everything the eye would check is right. The six letters are allocated
(`addr_logo` holds six valid, regularly spaced OST pointers), chained, with the
right `image_set` and the right positions. It is not an allocation failure and
not a load failure.

The one asymmetry, in a single dump: five letters carry `render_flags = $88` and
the missing one carries `$08`. Bit 7 is `render_hide_mask` — and it reads
backwards from what the name suggests. `CheckSpritesRefresh` sets it on every
object it *reaches* (`CSR_SetHide` is the fall-through of `CSR_SetDrawTrue`), so
the missing letter is not hidden: it is **never visited**.

## The v1 idiom

In v1 the engine is assembled **into each game mode's binary**: the game mode's
`main.asm` INCLUDEs `sprite-background-erase-ext-pack.asm` alongside everything
else. The Display Priority Structure —

```asm
DPS_buffer_0
Tbl_Priority_First_Entry_0    fill  0,2+(nb_priority_levels*2)
Tbl_Priority_Last_Entry_0     fill  0,2+(nb_priority_levels*2)
Lst_Priority_Unset_0          fdb   Lst_Priority_Unset_0+2
```

— and the background-save cell free list are therefore **loaded data of the
game mode**, exactly like the static OST slots of
[`reserved-ram-is-not-zeroed.md`](reserved-ram-is-not-zeroed.md).
`LoadGameMode` reloads the binary, so both structures come back zeroed *for
free*, at every mode change. No v1 game mode contains the gesture — which is
why porting one does not reveal that the gesture is needed.

## The v2 model

In v2 the engine is **resident**. It is loaded once at boot and survives every
stage swap; only the mode unit in the `$8000` slot is exchanged. So the DPS and
the cell list survive the swap too, still naming the objects of the mode that
just ended — while `ManagedObjects_ClearAll` has just wiped the object pool.

The stage entry already knew half of this and says so: it purges the pool before
its priming frame, because "the v2 pool is RESIDENT — a stage swap arrives with
the outgoing stage's objects still alive". The other half was missing: the
structures that *name* those objects were left standing.

A stale entry does not merely add a dead object to a list. It **poisons its
priority level for good**:

```asm
DSP_CheckLastEntry
        tst   a,y                     ; Tbl_Priority_Last_Entry[prio]
        bne   DSP_addToExistingNode   ; <- taken forever after
DSP_addFirstNode
        stu   a,y                     ; last entry
        leay  buf_Tbl_Priority_First_Entry-buf_Tbl_Priority_Last_Entry,y
        stu   a,y                     ; first entry  <- the ONLY writer
```

`Tbl_Priority_First_Entry` is written **only** by `DSP_addFirstNode`, and
`DSP_addFirstNode` is unreachable while `Tbl_Priority_Last_Entry` is non-zero.
A new object at a stale level is therefore appended behind a corpse: `Last` is
updated to name it, `First` still names the corpse, and every reader —
`CheckSpritesRefresh`, `DrawSprites`, `EraseSprites` — walks from `First`.
Whether the new object is reached depends on what the corpse's
`rsv_priority_next_obj_*` field happens to hold now.

R-Type makes this vivid because **the player's OST lives in the direct page**
(`player1 equ dp`, `$9F00`) rather than in the pool. The player registers at
priority 3, and the logo's dot is the priority-3 letter. So the title inherits
`Tbl_Priority_First_Entry_0[3] = $9F00` from the stage, chains its dot behind
it, and the walk from `$9F00` reads a link field in a direct page the title has
since rewritten for its own use. The dot is never drawn.

Which glyph disappears varies from run to run because which priority levels were
occupied at the moment the player died varies — a level nobody occupied then is
still clean.

## The fix

Purge the render structures wherever the object pool is purged. The checkpoint
reload already had the full gesture and is the model to copy:

```asm
        jsr   InitStack
        jsr   ManagedObjects_ClearAll
        jsr   DisplaySprite_ClearAll     ; priority lists, both buffers
        jsr   EraseSprites_ClearAll      ; background-save cell free list
        jsr   InitDrawSprites
```

`EraseSprites_ClearAll` belongs in the same breath: the cell free list is
allocated per object and per buffer, so the dead objects of the outgoing mode
keep their cells booked. That one leaks rather than corrupts, which is why it
had not been noticed — but it is the same defect.

The general rule: **every engine structure that holds an object address is
invalidated by `ManagedObjects_ClearAll` and must be reset in the same
sequence.** In v1 the reload did it; in v2 nothing does it unless the mode entry
asks. The list to check: the priority lists (`DisplaySprite_ClearAll`), the cell
free list (`EraseSprites_ClearAll`), the collision lists
(`Collision_ClearLists`), the per-object direct page (`ObjectDp_Clear`). The
checkpoint path calls all four; a mode entry that calls fewer should be able to
say why.

## Proof

The measurement that settles this is one 42-byte read — **dump
`Tbl_Priority_First_Entry_*` and compare it to the object pointers the mode
holds**. A first entry that is not one of the mode's own objects is the whole
story. On R-Type (`common.engine` at `$6100`, so `DPS_buffer_0` at `$6ED6`):

| | `First_Entry[2..7]` |
|---|---|
| title from boot | `87DB 8850 88C5 893A 89AF 8A24` — the six letters |
| title after game over, before the fix | `87DB` **`9F00`** `88C5 893A 89AF 8A24` |

`$9F00` is `player1`, i.e. the direct page: the stage's priority-3 object, still
listed. `Tbl_Priority_Last_Entry_0[3]` correctly named the dot (`$8850`), which
is the signature of `DSP_addToExistingNode` having been taken.

Do **not** try to read this from `render_flags`: `render_hide_mask` is set on
the objects that were reached, so the broken one is the one *missing* the bit,
and the flag says nothing about why.

## Met in

R-Type, 18/08/2026, on the branch that added the CONTINUE screen. The defect
predates that work — the missing purge is as old as the resident engine — but
the CONTINUE screen changed which objects were alive when the player died, and
so turned a level that happened to be benign into one that was not.
