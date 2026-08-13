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

**Export what crosses a file boundary, and nothing else.** Inside one
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

## The `bake` attribute

The answer to the bulk-table shape — and, since 2026-08-05, to every fixed
reference — is the file's `bake` attribute. The source does not change at
all : same `EXTERNAL`, same `fdb`, plain `SECTION code`. The configuration,
which is what places everything, decides how references resolve :

```xml
<file name="stage1.maps" linkdata="LINK" bake="all">
<file name="common.player" linkdata="LINK" bake="auto">
```

- `bake="none"` (default) — everything through the load-time linker.
- `bake="auto"` — each reference is **classified** : baked when its provider
  sits at one fixed destination the consumer can see (interns, when the unit
  itself does), left load-time linked otherwise. References into run-time
  alternatives stay linked by construction. An optimiser, not a promise.
- `bake="all"` — the strict promise : every reference must bake, a failure is
  a build error naming the symbol and the cause. For generated tables and
  fully fixed units, where a silent fallback would hide a regression.

(The earlier vehicle — sections named `*.static` — is gone : it forced the
placement decision into the source, could not express a mixed unit like the
engine, and complicated the entry-point convention. `bake="all"` carries the
same promise from the configuration side.)

The rules :

- `extern16`, `extern8` and `externPg` references bake when their provider is
  loaded at **one single fixed destination** across every scene of the target
  (a region, or a literal page and address), and 8/16 bit references to an
  **absolute export** (a `SECTION constant` value) bake without any placement
  at all. An 8 bit reference to a placed symbol bakes to the low byte of its
  address — exactly what the run-time linker would store.
- **Declaration order does not matter.** The discovery pass the build already
  runs harvests every export offset, every placement and every cut
  membership, and the real pass resolves against the harvest — a consumer
  declared before its provider builds identically. (If the discovery pass
  itself stops early on an unrelated error, declaring providers first is the
  workaround the message suggests.)
- A symbol exported by **several files** refuses a build-time value,
  whoever asks : naked provider counting, no reachability or co-location
  analysis (author's arbitration, 2026-08-10 — the consumer election that
  used to disambiguate per scene composition is gone). The reference stays
  load-time linked and the loader's first-match scan decides at run time —
  whichever alternative is loaded wins. The one multi-provider case that
  resolves is several exports of the same absolute value : one answer,
  whoever provides it. Sharing a name is therefore the author's way of
  saying "the loaded one wins" — a table's main entry (`map.even`,
  `stage.wave`, the five engine tables) does exactly that, and generated
  per-set labels are made unique by the generator (a tile is
  `adr_<host>_<id>_<variant>`) so they never collide by accident.
- Under `all`, anything else is a **build error** naming the section, offset,
  symbol and cause ; under `auto` it stays load-time linked — a routing, not
  a failure, and it is recorded : the caused list (below) says why each named
  reference still goes through the loader, the pool map and link report say
  what the residual costs.
- Internal references bake as well — see the next section.
- Same-name sections merge across the source, and the section named `code`
  always leads the unit's binary — the entry point convention, whatever order
  lwasm wrote the object in.

Measured on `examples/tilescroll` : 768 references baked, link data for the
map 4.6 KB → 0, the disk back to its standard layout, the memory pool back to
its normal size, and the load 883 096 → 547 790 instructions.

What it cannot see : a game loading a file at a run-time computed address
through the loader's API. The marker is the author's assertion that the
referenced content is scene-placed only ; the builder verifies it against
everything declared.

## The same for a unit's own references

A `.static` section resolves its **internal** references too, and for the same
reason : an intern's value is relative to where its unit lands, and a
scene-placed file lands somewhere the builder already knows. Baking it
costs nothing the build was not already doing.

It matters everywhere a unit is fixed, not only where a table is big.
R-type's animation scripts are ~2900 pointers into themselves — 8 KB of pool,
a stage exchange did not survive it — but the engine's 455 interns and the
mounted objects' cost the same per entry. Under `bake="auto"` the whole game
went from 9 104 to 552 bytes of link data (and 6 files instead of 30, the
empty blocks dropping with their index slots) ; what remains is exactly the
exchange boundary : the engine's references into the stage's interface region,
and the stages' nine interface exports.

A tempting shortcut does not work, and was measured rather than assumed :
leaving the interns unresolved because the unit loads at address zero. lwasm
writes zeros at relocation sites, not the section-relative value, so the
pointers would all read zero.

## The policy

The two mechanisms above are not optimisations to reach for once a build gets
tight. They are the default, and `linkdata` is the exception :

> Every file declares `bake="auto"`, and the classification does the rest :
> what is fixed bakes, what is exchangeable stays linked. `bake="all"` replaces
> `auto` where silence would hide a regression — generated tables, fully fixed
> units. `bake="none"` is for what the builder cannot know : content loaded at
> an address computed at run time.

Three corollaries, each of which has been got wrong :

**The criterion is a fixed destination, not shared content.** "Common to every
stage" is a symptom of the rule, not the rule. A stage's own tile map, its
collision data, its wave table sit in a declared region just as firmly as the
engine does, and their pointer tables are exactly the bulk that fills a pool.
A habit limited to inter-stage commons leaves the largest tables paying.

**References bake, resources do not.** The marker goes on the *consumer's*
section, and the provider's file must be declared before it. "Bake this
asset" means nothing; "bake the table that points into it" means something.

**An empty block drops itself.** A block costs 12 bytes before it holds
anything — six two-byte counters — then four per export and four to six per
reference. When the bake resolves every reference and the pruning removes
every export, the builder no longer writes the link file at all : the
descriptor keeps its reserved size (file ids derive from the attributes), the
flag stays down, and the loader neither indexes the file nor allocates
anything. `linkdata` can stay declared ; it only costs when it carries.
An export still imported keeps its counter above zero, so a block the loader
needs can never be dropped — `stage1` keeps its frontier exports,
because the engine relinks against them at every scene load.

**A reference *into* a swappable unit must stay linked — this one is
correctness, not size.** The stage exchange is nothing but the loader
re-resolving the engine's `EXTERNAL`s at each `scene.load` : the moment stage 2
lands, `ldx #Obj_Index_Page` points at stage 2's table. Bake that and the engine
is frozen on whichever alternative the builder happened to resolve. The rule is
directional, and it is the reverse of the intuition : a **consumer** of a fixed
single provider bakes; a consumer of a multi-provider name does not. In r-type this is
what keeps `common.engine` and `common.player` linked — the engine reads the
stage's five tables, the player writes the stage's `mainloop.state` — while
`stage1` and `stage2`, which only ever consume fixed providers, bake whole.

The build refuses the mistake deterministically : the export table is keyed
per provider, and any multi-provider name refuses a build-time value —
whatever the declaration order, whoever asks. The old refusal was accidental
(it held only while alternatives were declared after the resident units that
read them, and `registerExport` was last-one-wins) ; it is now the naked
provider counting described above.

What happens when the policy is not applied is a load that stops with no
message at all — see
[A v1 game has no link data](migration/static-link-bake.md).

## The link report

Arbitration needs numbers, so the build prints them. After each target, every
file that still carries link data is listed, largest first :

```
link data: 30 files, 5278 bytes (pool cost while indexed), 4603 references baked
  bytes  intern  x8  x16  page  expA  expR   baked  file
   2138     473   0   13     0     0    39       0  common.engine
    896     122   0   30    36     0     0       0  common.player
     36       0   0    0     0     0     6     280  stage1
```

`bytes` is what that file adds to the loader's memory pool while it is indexed;
the total is what the pool must hold if every one of them is indexed at once.
A large `bytes` with `baked` at zero is a unit the policy has not reached yet.

The same table is written to `<dist.dir>/link-report-<target>.csv`, one row per
file, so a sweep can be sorted and diffed between builds.

## The caused list

The link report says what link data costs ; the caused list says **why each
named reference still goes through the loader**. After each target, every
load-time resolution the bake classified is printed with its cause, and the
full list — classified and declared alike — is written to
`<dist.dir>/linked-refs-<target>.csv` :

```
file,symbol,sites,mode,cause
common.engine,Obj_Index_Page,5,auto,"'Obj_Index_Page' is exported by [stage1, stage2], run-time alternatives that 'common.engine' could see either of — the reference must stay load-time linked"
ut.gm,data.value,1,declared,"the file declares bake=""none"""
```

This list exists because the link is **derived** : a name with a single fixed
provider bakes, a name several reachable alternatives export stays load-time
linked, automatically. The price of that routing is that an export duplicated
by mistake no longer stops the build — it becomes one more silent link. The
caused list is where it is caught : once baking is the default the list is
short, and it is meant to be re-read. Every line should be a boundary the
author recognises — an exchangeable provider (the engine reading a stage's
tables), a declared `bake="none"` (a bench exercising the linker). **A
surprising line is a name exported twice by error.**

Internal relocations carry no name to review ; the link report counts them
per file. When nothing is load-time linked, no file is written — an absent
`linked-refs` csv is itself the report.

## Export pruning

The other half is implemented too : an export **nothing imports** is left out
of the link data. The discovery pass the build already runs to stabilise
symbol ids now also collects which symbols are referenced as `EXTERNAL` ; the
real pass emits only those. There is nothing to author — dead exports simply
stop costing their four bytes and, more importantly, stop being one more
entry every resolution walks past.

The uniqueness check still runs for pruned exports : two files exporting the
same dead name is still an error. And a symbol consumed **only** through a
`.static` section counts as unimported — the bake does not go through the
loader — so the two mechanisms compound : `tilescroll`'s link data now
carries no exports and no externals at all, only interns.

What pruning does *not* do is shrink the corpus much on its own : most bulk
exports turn out to be genuinely imported (a sample table importing 2667
labels is the `.static` shape, not the dead-export shape), and units without
`linkdata` never put their exports on disk in the first place. It removed
19 dead exports from `loader-ut` and every export from the two `.static`
consumers. Its real value is keeping the search tables honest as the corpus
grows.

## Shared export names

Export names MAY be shared between files : the loader resolves a symbol by
scanning the loaded files and taking the first match, so whichever
alternative is loaded wins. No uniqueness rule and no co-loadability
analysis exist any more (author's arbitration, 2026-08-10) — sharing a name
IS the mechanism of swappable content : each stage exports `Obj_Index_Page`,
`map.even`, `stage.wave` — the same names, by design, because the engine's
`EXTERNAL` references must find whichever stage is in, and the global
re-link repoints them at every `scene.load`.

The guarantee that two stages stay drop-in replacements does not live in
the builder : it lives in the source (`api.asm` — one file, `EXPORT` or
`EXTERNAL` depending on `ENGINE_RESIDENT`, drift impossible) and in the
benches. What the builder gives is **visibility** : every reference left to
the loader appears in the caused list with its providers named — a name
duplicated by accident reads as a surprising line there — and the dangling
check still refuses a linked reference whose export no file emits.

## The single-list contract

An interface between a resident engine and swappable content is a LIST of
names — and the way to keep its two sides from drifting is to have only one
list. The idiom, from `games/r-type/src/common/engine/api.asm` :

```
_api    macro
  ifdef ENGINE_RESIDENT
\1 EXPORT
  else
\1 EXTERNAL
  endif
        endm

        _api InitGlobals
        _api Scroll
        …
```

The engine unit defines `ENGINE_RESIDENT` before including the file and
gets the EXPORT lines ; every stage includes the same file and gets the
EXTERNAL lines for the same names. Drift is impossible because there is
nothing to keep in sync. The reverse direction — the tables the engine
reads back from the stage — is the same idiom inverted (`stage-tables.asm`).

The list itself is AUTHORED, deliberately : each name costs four bytes of
link data and a linear search per reference at load time, so what crosses
the boundary is a design decision, not an inventory. A builder-generated
`.external.asm` emitted from the export registry was considered and
REJECTED (7a, 2026-08) : the export list IS the contract — generating it
from "what the engine exports" would invert the causality, since this very
file is what decides the engine's exports. The single-list macro delivers
the no-drift property with zero machinery.

## Where this bites next

The audit that prompted this note: across the examples, 1948 symbols are
exported and 46 are imported. Most of the gap is `mplus`'s sample labels and
the imageset indexes, which export every variant address whether a game names
it or not. Neither is wrong today — an imageset cannot know which of its
images a game mode will use — but both are the same shape as the tilemap, and
the same answer applies: what the builder places, the builder can address.
