# A relative branch cannot reach another unit

## Symptom

The discovery pass of the build stops :

```
discovery pass stopped early: expression with several constants is not supported at offset 2059
```

The offset is in the unit being linked, here a Sonic 2 object : offset
`$080B` of its code section is the operand of

```asm
        lblo  DisplaySprite
```

## The v1 idiom

v1 assembled each object with the game mode's whole symbol table : every
engine routine had an absolute address, and a long branch to one assembled
to a plain displacement. Tail-calling the engine with a conditional long
branch was free, and v1 code does it.

## The v2 model

`DisplaySprite` lives in another unit, so the displacement is a relocation :
`DisplaySprite - (* + 4)`, a symbol minus a place. The v2 link data carries
one symbol plus a constant (`extern16`) ; a PC-relative reference to an
import is not expressible, and the linker says so.

## The fix

Branch around an absolute jump :

```asm
        ; V2-DEVIATION: was lblo DisplaySprite ; the v2 linker does not
        ; relocate a relative branch to another unit's symbol
        bhs   >
        jmp   DisplaySprite
!       inc   routine_secondary,u
```

Before rewriting, measure : in Sonic 2's 28 objects (title and Emerald Hill)
this was the only one — a grep of `b`/`lb` mnemonics whose target is not
defined in the object's own files gives the list.

## Proof

The unit links ; the listing shows `24 03 7E 00 00` (`bhs`, then `jmp` with
its `extern16`), and the title screen it belongs to is pixel-identical to v1.

## Met in

wide-dot/sonic-2, `objects/level/title-screen/title-screen/title-screen.asm`,
05/10/2026.
