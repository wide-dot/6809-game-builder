# Export only what crosses a direntry boundary

v1 had no boundaries: one image, every name visible. In v2 an export is
resolved on the machine, by a linear search, once per reference. Exporting
generously is not tidy — it is a load-time cost paid every scene.

## Symptom

Nothing fails. Scene loading is just slow, and the disk carries link data it
did not need.

The measurement that makes it concrete: from the boot keystroke to the game
mode's first instruction, `examples/tilescroll` took **883 096** instructions
against **796 240** for `examples/sprites`. The difference is 768 references —
one per tile per map — at roughly 113 instructions each.

## The v1 idiom

Two habits carry over badly.

**Everything was visible.** A v1 game mode and its engine were assembled
together, so referring to a symbol in "another file" cost nothing at all. There
was no reason to think about which names were public.

**Unknown symbols were tolerated.** v1 assembled with `--pragma=undefextern`,
which turned an unknown name into an external resolved to zero. That made
forward references painless and typos invisible.

## The v2 model

A reference is resolved by `linkData.symbol.search`, which walks every loaded
file and, inside each, every exported symbol, comparing ids. So a scene's link
cost is roughly

> references × exports in scope

An export itself is cheap to *store* — four bytes, the name never leaves the
build — but it enlarges the corpus every reference is searched against.

**Do not enable `undefextern` in v2.** v2 makes an unknown symbol an assembly
error, which is the better bargain: an unresolved external is zero at runtime,
and `jsr $0000` has no diagnostic. Two other cases in this directory are that
same silent zero seen from different angles — see
[irq-bridge](irq-bridge.md) for a missing symbol and
[equates-link-boundary](equates-link-boundary.md) for one that resolved when it
should not have.

## The fix

Export a name only when it genuinely crosses a direntry boundary. In
particular, a table of pointers into another unit is the expensive shape —
and usually the avoidable one: **what the builder places, the builder can
address**. Declaring the direntry `bake="all"` (formerly a `.static`
section) has the builder resolve the
references itself, at build time, and they disappear from the link data
entirely.

The full mechanism, its guarantees and its failure modes are in the manual:
[`symbols.md`](../symbols.md).

## Proof

Count instructions from boot to the game mode's first instruction, and look at
the link data size on disk. On `tilescroll`, moving the map table to `.static`
took 768 references to zero: link data 4.6 KB → 0, load 883 096 → 547 790
instructions.

## Met in

Measured on `examples/tilescroll` and `examples/sprites`, 2026-08-01. The
`undefextern` difference was recorded during the engine import.
