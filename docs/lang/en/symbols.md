# Symbols across files

A v2 unit is assembled into an LWOBJ16 object and linked **at load time**, by
the loader, on the machine. That makes symbol visibility a runtime cost, not
just a build-time tidiness question, and it is worth knowing what each level
actually buys.

## The three levels

| in lwasm | what it means | where it is resolved |
|---|---|---|
| a plain label | local to the unit | by the assembler, at build time |
| `sym EXPORT` (also `.GLOBL`) | other units may reference it | offered to the loader |
| `sym EXTERNAL` (also `EXTERN`, `IMPORT`) | defined in another unit | by the loader, at scene load |

An object file carries three lists per section: local symbols, exported
symbols, and incomplete references. The local list only exists so the
assembler can express a reference it could not finish; **the v2 builder does
not emit it**. Only exports and references reach the disk.

`EXTDEP sym` forces a dependency on a symbol that is never referenced. We have
no use for it today; it is here so nobody reinvents it.

## What an export costs

**On disk: four bytes.** The builder assigns every exported name a numeric id
(`LinkSymbols`) and writes id and offset — the name itself never leaves the
build. An export is genuinely cheap to store.

**At load time: a linear search.** `linkData.symbol.search` walks every loaded
file, and inside each one every exported symbol, comparing ids, for **each**
reference it has to resolve. So linking a scene costs roughly

> references × exports in scope

Measured, from the boot keystroke to the game mode's first instruction:

| example | instructions | references |
|---|---|---|
| `loader-ut` | 741 929 | a few dozen |
| `sprites` | 796 240 | a few dozen |
| `tilescroll` | **883 096** | 768 |

That is about 113 instructions per reference resolved, at roughly thirty
exports in scope. Nothing alarming at this size, and quadratic all the same.

## The practices

**Export what crosses a direntry boundary, and nothing else.** Inside one
assembly unit the assembler resolves everything for free. `EXPORT` is a
statement that another *file* needs the symbol — not a statement that the
symbol is important. v2's engine modules get this right: `joypad.asm` exports
its seven API entry points and keeps its state private.

**A table of pointers into another unit is the expensive shape.** Not because
a pointer is dear, but because there are so many of them.
`examples/tilescroll` holds 768 — one per tile per map — and pays 5.3 KB of
link data and a measurable slice of its load for the privilege. v1 did not:
its maps were generated after placement with the addresses baked in. Anything
generated *by the builder, from data the builder already placed* should be
baked, not linked. That is the shape of roadmap item 7.

**Beware one-export-per-file generation.** `examples/mplus` produces 2667
single-symbol units for its PCM sample labels. Each is four bytes, which is
nothing, and each is also one more entry every resolution has to walk past.

**Do not turn on `undefextern`.** v1 assembled with `--pragma=undefextern`, so
any undefined symbol silently became an external. Combined with the loader
resolving a missing symbol to zero — which it does unless
`loader.CHECK_UNRESOLVED_SYMBOLS` is defined — a typo produces a program that
loads, runs and reads address zero. v2 does not pass the pragma: an unknown
symbol is an assembly error, at the line that used it. Keep it that way.

**`EXPORT` may precede the definition**, and may be written either as
`sym EXPORT` or `EXPORT sym`. The generated code uses the first form
consistently; there is no reason to mix.

## The `.static` sections

The answer to the bulk-table shape is implemented : a section whose name ends
with `.static` asks the builder to resolve its external references itself,
against the declared placement of their providers, and to emit **no link data
for them**. The source does not change — same `EXTERNAL`, same `fdb` — the
table is simply bracketed :

```asm
 SECTION map.static
map.even
        fcb   assets.tiles$PAGE+$60
        fdb   adr_tile2_ND0
 ENDSECTION
```

The rules :

- `extern16` and `externPg` references bake when their provider is loaded at
  **one single fixed destination** across every scene of the target (a region,
  or a literal page and address). Placements are collected from the whole
  configuration before the target runs, so scene declaration order does not
  matter — but **the provider's direntry must be declared before its
  consumer**, because a symbol's offset only exists once the provider is
  assembled.
- Anything else is a **build error** naming the section, offset, symbol and
  cause. A `.static` section is a promise ; there is no silent fallback.
- Internal references stay with the loader : the unit itself remains
  relocatable, only its providers are pinned. A unit with interns still needs
  `loadtimelink`.
- Same-name sections merge across the source, and the section named `code`
  always leads the unit's binary — the entry point convention — whatever
  order lwasm wrote the object in.

Measured on `examples/tilescroll` : 768 references baked, link data for the
map 4.6 KB → 0, the disk back to its standard layout, the memory pool back to
its normal size, and the load 883 096 → 547 790 instructions.

What it cannot see : a game loading a file at a run-time computed address
through the loader's API. The marker is the author's assertion that the
referenced content is scene-placed only ; the builder verifies it against
everything declared.

## Where this bites next

The audit that prompted this note: across the examples, 1948 symbols are
exported and 46 are imported. Most of the gap is `mplus`'s sample labels and
the imageset indexes, which export every variant address whether a game names
it or not. Neither is wrong today — an imageset cannot know which of its
images a game mode will use — but both are the same shape as the tilemap, and
the same answer applies: what the builder places, the builder can address.
