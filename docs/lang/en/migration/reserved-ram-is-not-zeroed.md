# A v1 `fill` is loaded data ; a v2 `<reserved>` block is not

## Symptom

Loud and confusing. The palette turns to garbage — magenta border, wrong
colours everywhere — and the game crashes shortly after, at stage startup.

What makes it hard to place is that **nothing in the failing path changed**.
The palette data assembles correctly, the reference to it is baked to the right
address, and reading that address at runtime shows the right bytes. The only
edit was to a couple of equates and two `<reserved>` blocks in the layout.

The tell is that the failure moves with the memory map : the same code works at
one address and fails 351 bytes lower.

## The v1 idiom

v1 declares its out-of-pool object slots as **data of the game mode binary** :

```asm
palettefade                  fcb   ObjID_fade
                             fill  0,object_size-1
forcepodOST                  fcb   ObjID_forcepod
                             fill  0,object_size-1
```

That `fill` is not a reservation, it is **content**. It travels in `main.bin`,
so those slots arrive from disk zeroed, with their object id already in place.
No game mode ever has to initialise them, and no v1 source contains the gesture
— which is exactly why porting one does not reveal that the gesture is needed.

## What v2 does instead

A v2 unit is relocatable and its first byte is its entry point, so reserving
space with `fill` is not an option : it would push the entry point away from
offset zero. The project's answer is the `<reserved>` block —

```xml
<reserved name="objects.static" page="$01" address="$9CAC" size="$01D4"/>
```

— which tells the builder *nobody may load here*, and nothing more. **No file
covers it, so nothing writes it.** Its content at power-on is whatever the RAM
happened to hold.

## Why it hides for so long

A reserved block that happens to sit where something else has already been
writing reads as zero, and zero is what the missing initialisation would have
produced. The static OST block lived just under the system stack, which sweeps
that area at every deep call chain — so it *was* zeroed, by accident, for the
whole time it stayed there.

Move the block, and it lands on untouched RAM full of `$FF`. Then, for the
palette fade object :

- `o_fade_unload` reads `$FF` instead of 0, so `PaletteFade_Idle` calls
  `UnloadObject_u` on a slot that is **not in the pool** — the free list gains
  an address it never owned ;
- the fields the arming routine does write are correct, which is what sends you
  looking at the data, the section placement and the loader, all of them
  innocent.

## What to do

Zero the reserved block at stage entry, and seed the ids the v1 `fcb` carried :

```asm
        ldx   #palettefade
        ldd   #nb_static_objects*object_size
!       clr   ,x+
        subd  #1
        bne   <
        lda   #ObjID_fade
        sta   palettefade+id
```

This runs at **every** stage entry, not only the first, and that is faithful :
v1 reloads its game mode binary at every entry, so its slots are re-zeroed just
as often.

## The general rule

**Anything a v1 game mode obtained from a `fill` in its binary needs an
explicit initialisation in v2.** The two are not equivalent : one is loaded
content, the other is an address range the builder promises to leave alone.

The same reasoning applies to every `<reserved>` block. `globals` already had
its gesture for this reason — the inter-main variables are cleared in the stage
init, with a comment saying that their content at startup is whatever the
machine had. The static object slots simply had not been given theirs.

When adding a `<reserved>` block, the question to answer in the same breath is
**who writes it first**. If the answer is nobody, the block is a latent bug
waiting for the map to move.

## Debugging note

Two false trails cost real time here, both worth naming :

- reading an address *derived* from an OST field instead of reading the baked
  immediate in the code. `ldx #Pal_stage` assembles as `8E xx xx` once baked —
  read those two bytes, they are the truth. A field read from an OST that a
  later routine has already rewritten is not ;
- concluding "the section is not loaded" from that wrong address. The section
  was loaded, at the address the code pointed at, in both the working and the
  failing build.

The measurement that settles it is short : read the baked immediate, then read
the memory it names.
