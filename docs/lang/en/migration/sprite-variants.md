# Every v1 sprite variant becomes an `<encoder>` — losing one is silent

A v1 `sprite.` line lists variants after the semicolon: `NB0,NB1`, `XB0`,
`ND0`. Each one maps to its own `<encoder>` element in the v2 `<image>`.
Port the list, not just the first entry — **and read it from the properties
of the TARGET** (`*.d7.properties` for the floppy build): the same object can
declare different variants per target, and the generic `.properties` is a
different contract.

## Symptom

None you will notice on a screenshot — that is the trap. The game runs, the
sprite draws, animations play. What is silently degraded depends on the
variant lost:

- **`NB1` missing** (the 1-pixel pre-shift): the sprite can only be drawn at
  even BM16 x positions. Movement loses its fine grain — a 2-pixel horizontal
  stutter that only shows when watching motion, never on a still.
- **`XB0` missing** (the x-mirror): whatever selects the mirrored image gets
  a hole in the imageset.

It was caught by the author reading the v1 properties against the v2 config,
not by any test.

## The v1 idiom

```properties
sprite.Img_Player=./objects/player1/images/rship_2.png;NB0,NB1
sprite.Img_Player_explode_0=./objects/player1/images/player1explosion_0.png;NB0
```

The variant list is per sprite and deliberate: the ship moves 1 px at a time,
so it carries both shifts; the explosion is transient, one shift is enough.
The letters encode encoder and parameters — `N`/`X` normal or x-mirrored,
`B`/`D` bdraw or draw, the digit the shift.

## The v2 model

`<image>` accepts **several `<encoder>` children**, one per variant. All of
them join the same imageset entry, and the engine picks by x parity and
mirror flags at draw time (`rsv_mapping_frame`), exactly as in v1:

```xml
<image name="rship_2" filename="src/common/player/images/rship_2.png" index="2">
    <encoder name="bdraw" mirror="none" shift="0"/>
    <encoder name="bdraw" mirror="none" shift="1"/>
</image>
```

The generated index then exports both `adr_rship_2_NB0` and `adr_rship_2_NB1`
(plus their `_erase` twins). The variant naming carries straight over from v1,
so checking is mechanical: grep the generated `index.asm` for `NB1` and
compare counts with the properties file.

## The fix

Translate each v1 variant to one encoder line. The mapping:

| v1 suffix | v2 encoder |
|---|---|
| `NB0` | `name="bdraw" mirror="none" shift="0"` |
| `NB1` | `name="bdraw" mirror="none" shift="1"` |
| `XB0` | `name="bdraw" mirror="x" shift="0"` |
| `ND0` | `name="draw" mirror="none" shift="0"` |

Budget note: each variant is a full compiled sprite. Adding `NB1` to the five
ship poses and eight pata-pata frames grew their units by 2.3 KB and 3.4 KB —
check the region budgets after.

## Why it happened — twice — and the rule

The player's config was written by copying the pata-pata block as a template
instead of reading the v1 properties: the ship lost its `NB1`. Then the fix
audit read the WRONG properties file (`obj.properties` instead of
`obj.d7.properties`) and **invented** an `NB1` for pata-pata that the floppy
target never had — caught by the author again. Same root cause both ways:
not reading the original contract for the target being built.

**The v1 properties of the target are the contract** — not the previous v2
config, not another target's properties. Inventing a variant is as wrong as
losing one: it costs bytes in the page and misstates the 1:1 baseline.

## The guard

`tools/check_variants.py` mechanises the check: it walks the v1
`*.d7.properties`, unions the variants per image (one png often carries
several `sprite.` lines, e.g. emitter-flash in `NB0` then `XB0`), matches
against the v2 `<image>`/`<encoder>` declarations by three-segment path
suffix (`<object>/images/<png>` survives the tree move and separates
homonyms — the shell's `mask.png` is not the playfield's), and exits non-zero
on any divergence on a ported image. Run it after any image declaration
change; it is part of the migration workflow (see the skill).

## Proof

The guard's `variantes conformes` on a clean run, and the region sizes
moving by the expected amount when a variant is added.

## Met in

`games/r-type`, 2026-08-03, both directions caught by the author: the lost
`NB1` on the ship, then the invented `NB1` on pata-pata.
