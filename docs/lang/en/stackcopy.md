# stackcopy — a block copied through the stack

`engine/graphics/draw/stackcopy.asm` copies a block of bytes from anywhere
to anywhere, 7 at a time : `pulu a,b,dp,x,y` reads them, `pshs a,b,dp,x,y`
writes them. It is the copy of a picture that is already in RAM, whole or
shifted by some rows : a page of the game copied into a screen buffer,
scrolled. `DrawFullscreenImage` does the same with a picture prepared for it
(`<png2bin buffer="fullscreen">`, its 7-byte blocks stored last to first) ;
`stackcopy` takes the bytes as they are.

## Use

Included on demand, nothing else to declare :

```
        INCLUDE "engine/graphics/draw/stackcopy.asm"
...
        ldu   #source                  ; the first byte
        ldy   #destination             ; the first byte
        ldd   #8000                    ; the bytes, 0 to 65535
        jsr   stackcopy.run            ; trashes a, b, x, y, u ; dp and cc kept
```

The copy runs from the last byte down : a destination above an overlapping
source is copied right (a picture moved down in its own buffer). A
destination below an overlapping source is not.

A 160x200 bitmap-16 picture is two 8 000-byte halves, `$C000` and `$A000` in
the data window ; rows shifted by `n` are the same two copies, `n * 40` bytes
further, `(200 - n) * 40` bytes each.

## The interrupts

S points into the destination while it pushes. An interrupt taken then
would push its frame there, and run its routine on that stack. So the
interrupts are masked for each block of 252 bytes (36 pulls and pushes,
about 1 100 cycles), and between two blocks S, DP and the masks are the
caller's again : the interrupts are taken there, late by at most a block. A
caller with the interrupts masked keeps them masked throughout.

The destination must not be where the caller's stack lives.

## Cost

Measured under toje (`ci/toje-bench/stackcopy_ut.py`, the jsr included, the
interrupts masked) :

| Bytes | Cycles | A byte |
|---|---|---|
| 0 | 211 | |
| 7 | 250 | |
| 252 | 1 314 | 5.21 |
| 8 000 | 35 520 | 4.44 |

A chunk of 7 bytes is 29 cycles (`pulu` 12, `pshs` 12, `leau -14,u` 5) : the
pulls climb and the pushes come down, so U steps back over the 7 bytes it
read and the 7 below. A block adds about 60 (S, DP and the masks given back,
the count). A copy by `pulu d,x` / `std ,y` / `stx 2,y` is about 5.4 cycles
a byte.

Code : 358 bytes and 5 of variables ; the routine writes its own code (the
caller's S, DP and masks, the entry into the block).

## Validation

`examples/stackcopy` copies blocks in a RAM page, the 50 Hz interrupt on :
lengths around the 7-byte chunks and the 252-byte blocks (0, 1, 6, 7, 8, 13,
251, 252, 253, 504, 505), a screen half 16 times, destinations above an
overlapping source (by 1 byte, 7 bytes and 13 rows), a block onto itself, then a copy
with the interrupts masked by the caller. Each copy is checked byte by
byte, with 16 bytes on either side. The bench stops at every interrupt
during the copies : the interrupted S is never in the data window. See its
[readme](../../../examples/stackcopy/readme.md).
