# Alignment arithmetic on the location counter does not survive relocation

## Symptom

The build stops on a message from the object reader, naming an offset and
nothing else :

```
expression with several constants is not supported at offset 695
```

Nothing in the source looks unusual, and the offset points at an ordinary
instruction — the reader reports where the *relocation* sits, which is not
where the expression was written.

## The v1 idiom

v1 aligns a cyclic buffer by doing arithmetic on the location counter :

```asm
                       fill 0,32   ; spare bytes for alignment (cycling buffer)
glb.diagonalUpBuffer   equ (*/32)*32
                       fill 0,32*3
glb.diagonalDownBuffer equ (*/32)*32
```

Divide by 32, multiply by 32 : round the current address **down** to a 32-byte
boundary. The `fill 0,32` ahead of it is the slack that rounding down eats
into. The buffer is walked with a pointer whose low bits are masked, so it has
to start on a boundary.

This works in v1 because a game mode is assembled **at an absolute address**.
`*` is a number, the expression folds at assembly time, and the label is a
constant.

## Why it cannot work in v2

A v2 unit is assembled into a relocatable section, so `*` is section-relative
and stays symbolic. The expression reaches the object file as a relocation with
two constants and a symbol — more than the link data format can express.

That limit is not the real problem, though. The real problem is that
**alignment is not a relocatable operation**. A relocation adds a base to a
value:

> `(base + offset) / 32 * 32` ≠ `base + (offset / 32 * 32)`

The two agree only when `base` is itself a multiple of 32. There is no way to
write "align me" as an addition, which is all a relocation can do. Even a
format that carried the whole expression could not resolve it without knowing
the load address.

## The v2 idiom

Say it to the assembler, which answers with a constant :

```asm
                       ALIGN 32
glb.diagonalUpBuffer   equ *
                       fill 0,32*3
glb.diagonalDownBuffer equ *
```

`ALIGN` works inside a relocatable section : lwasm pads to the next multiple
and the label becomes a plain section-relative constant, relocated by a simple
addition like any other.

Two things to check when doing this :

- **The receiving region must be aligned too.** `ALIGN 32` aligns relative to
  the section, so the absolute address is aligned only if the load address is.
  Say it where the region is declared — r-type's `reboundlaser` sits at
  `$1C:$0000`, and a comment in the layout says why it may not move to an
  arbitrary address.
- **`ALIGN` rounds up, the v1 trick rounded down.** Where every `fill` between
  two labels is already a multiple of the alignment, aligning the *first* label
  aligns them all and the two forms produce the same addresses — which is the
  case here. Where they are not, compare the resulting offsets before and
  after rather than assuming.

## The rule

**Any expression that is not "symbol plus constant" has to be resolved at
assembly time.** Relocation is addition ; division, masking, and alignment are
not. When a v1 source computes an address from `*`, it is relying on being
assembled absolutely, and the import has to replace the computation with a
directive the assembler can fold — or move the value into the configuration,
which is the other place that knows addresses.

## See also

- [`bake`, and what the builder can resolve](../symbols.md) — the same boundary
  seen from the link data side.
- [Met in](#) `games/r-type`, 2026-08-05, importing the force pod's rebound
  laser and its three cyclic buffers.
