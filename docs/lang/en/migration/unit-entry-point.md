# A unit begins at its entry point

A scene loads a direntry at its region's address and jumps to the **first
byte**. Anything that emits bytes — tables, object indexes, data — must come
after the entry code.

## Symptom

The unit loads and the machine runs off into whatever the first table happens
to decode as. Nothing reports an error: the loader did its job, the jump landed
where it was told.

## The v1 idiom

A v1 game mode was assembled at a fixed address and entered through a known
label. Where the tables sat relative to that label did not matter, because the
entry address was written down rather than implied.

## The v2 model

The scene knows a region's address, not a symbol inside the unit. "Where do I
jump?" is answered by convention: offset zero. That makes the layout of the
unit's first bytes part of its contract.

## The fix

Order the includes so that the entry code is emitted first, and the data after.
In an object unit this usually means the object's code include precedes its
index and imageset includes.

## What the builder guarantees

With several sections, "first byte" would otherwise depend on the order lwasm
happened to write them. It does not: the builder places the `code` section at
the **head of the binary** whatever that order. So the constraint is entirely
about include order *within* your code section, not about section layout.

(That guarantee was added on 2026-08-01, alongside a fix for section bases
being lost by cross-section internal references.)

## Proof

Check the map, not the source:

```
Symbol: main = 0000
```

The symbol you intend as the entry must be at offset zero. Any other value
means something is emitting bytes ahead of it.

## Met in

Recorded from the `sound/to8` pilot, 2026-07-31. Confirmed again on
`games/r-type`, where `enemy.asm` carries the constraint as a comment: *"the
entry must be the first byte of the unit: code first, tables after — hence the
order of the includes."*
