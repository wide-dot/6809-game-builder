# v1 RAM `fill`s become equates

v1 reserved RAM by emitting it inside a section `ORG`'d onto `dp`. A v2 unit is
relocatable, so reserved RAM becomes **equates** — no bytes emitted — and the
object pool goes to a fixed address the game chooses.

## Symptom

Two ways, depending on what you carried over.

Reserve with a fill and the unit grows by the size of the reservation, the
entry point is pushed away from offset zero (see
[unit-entry-point](unit-entry-point.md)), and the "RAM" lands wherever the
linker put the section — which is not where the rest of the game expects it.

Reserve with nothing at all and every access goes to address zero.

## The v1 idiom

```asm
        ORG dp
player1     rmb  object_size
...
```

Legitimate there: the image was absolute, so an `ORG` onto the direct page both
reserved the space and named it at the right address.

## The v2 model

A relocatable unit cannot own an absolute RAM address by emitting into it. So
the two jobs separate:

- **naming** the address is an equate, evaluated at assembly time, shared
  through a header both sides include;
- **reserving** it is a declaration to the builder, so nothing else is loaded
  on top.

The builder's `<reserved>` elements do the second job. It cannot infer them —
they are equates in the code, invisible to the configuration — so they are
declared:

```xml
<reserved name="objects.pool" page="$01" address="$90B0" size="$0750"/>
<reserved name="globals"      page="$01" address="$9E84" size="$007C"/>
<reserved name="stack"        page="$01" address="$9F00" size="$0100"/>
```

## The fix

Turn every `rmb` under an `ORG` into an equate chain anchored on a fixed base,
and declare the corresponding `<reserved>` range. Nothing is emitted.

Beware the consequence for the stack: once its range is declared it has a
**fixed budget**, and there is no guard. In r-type the stack has 124 bytes
between the globals at `$9E84` and the direct page at `$9F00`; an unbounded
recursion walked straight through the object pool below it (see
[equates-link-boundary](equates-link-boundary.md) for that story).

## Proof

The unit's size does not include the reservation, and the map shows the entry
at offset zero. The builder refuses to place anything in a `<reserved>` range,
so a collision is a build error rather than a runtime mystery.

## Met in

Recorded from the `sound/to8` pilot, 2026-07-31. The `<reserved>` declarations
were added for `games/r-type` on 2026-08-01 — the builder checked overlaps
*between loads*, but knew nothing of what the game occupies without loading
anything.

## The corollary, met much later

Turning a `fill` into an equate plus a `<reserved>` block keeps the *address*
and drops the *content*. A v1 `fill` is data of the game mode binary : it
arrives from disk zeroed. A `<reserved>` block is a promise the builder makes to
the loader, and nothing writes it.

Whatever a v1 game got for free from that `fill` — zeroed bytes, an object id
laid down by an `fcb` — needs an explicit initialisation in v2. See
[a v1 `fill` is loaded data, a v2 `<reserved>` block is not](reserved-ram-is-not-zeroed.md),
which is the same case caught the hard way, three weeks and one memory map
later.
