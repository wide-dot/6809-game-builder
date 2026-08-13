# Migrating a game from v1 to v2 — the casebook

The v1 engine ([thomson-to8-game-engine][v1]) and this one differ in one
decisive way: a v1 game mode is **one absolute image**, assembled at fixed
addresses and burned into a disk layout; a v2 unit is **relocatable**, loaded
by a scene into a region, and linked on the machine at load time.

Almost every difficulty in a migration follows from that single change. This
directory records those difficulties, one file per case, so that the second
project to hit one does not have to rediscover it.

[v1]: https://github.com/wide-dot/thomson-to8-game-engine

## How this fits with the rest

Four artefacts share the migration; each has one job.

| Artefact | Job |
|---|---|
| `docs/migration-inventaire.csv` | the backlog — what is still to import |
| `engine/v1-manifest.csv` | the ledger — which v1 file, from which commit, with which deviation |
| `.claude/skills/v1-migration/SKILL.md` | the procedure — how to import a file, drift-check, validate |
| **this directory** | the casebook — how a v1 idiom becomes a v2 one |

The reference manual next door (`docs/lang/en/*.md`) describes the v2 model to
someone who has never seen v1. A case file here always starts from a v1 idiom
and ends at its v2 counterpart. When in doubt: if you can state it without
mentioning v1, it belongs in the manual.

## The rule

> Every migration case you resolve gets a file here, **in the commit that
> resolves it**. Code that carries the trace of the case cites the file in a
> comment. A migration fix without its case written down is not finished.

The cost of skipping it is not theoretical. Three of the cases below were paid
for twice before they were written: once when they bit, and once again when a
later session re-derived them from scratch.

## The order to work in

Numbering lives here and nowhere else — the files are named by case, so that a
comment in the code, a `deviations` cell in the manifest, or a commit message
can point at one and still be right a year later. Cases are met out of order in
practice; this is a reading order, not a schedule.

**The link boundary** — where relocation and load-time linking change the rules.

1. [Absolute equates never cross the link boundary](equates-link-boundary.md) —
   the first thing to get wrong, and the hardest to see, because it fails
   silently and long after the fact.
2. [Export only what crosses a direntry boundary](what-to-export.md)
3. [A unit begins at its entry point](unit-entry-point.md)
4. [A v1 main loop is jumped to; a v2 stage body is fallen into](loop-fallthrough.md) —
   the corollary: data on a fall-through path is executed.
5. [v1 RAM `fill`s become equates](ram-fill-to-equates.md) — and its corollary,
   the one that bites much later :
   [a v1 `fill` is loaded data, a v2 `<reserved>` block is not](reserved-ram-is-not-zeroed.md).
   The block a v1 game got zeroed from disk has to be zeroed by hand, and the
   omission hides until the memory map moves.
6. [A page is a register value, not a page number](page-register-value.md)
7. [A global read from several pages is an address, not a label](shared-globals.md)
8. [A v1 game has no link data; a v2 unit pays for every pointer it
   holds](static-link-bake.md) — the one that fails as a dead machine mid-load,
   and sends you to the disk image instead of the link.

**Assembly and includes** — what the obj target refuses, and where files go.

9. [`setdp` is refused by the obj target](setdp-obj-target.md)
9b. [Alignment arithmetic on the location counter does not survive
    relocation](relocatable-alignment.md) — `equ (*/32)*32` folds in a v1 game
    mode assembled absolutely, and cannot be relocated at all.
10. [Where to include a v1 file that has no `SECTION`](v1-file-sections.md)
11. [The `irq.on` / `irq.off` bridge](irq-bridge.md)
12. [A KEPT-V2 module imposes its API on imported objects](kept-v2-api.md)

**Getting a picture** — in the order that a wrong one is worth investigating.

13. [The video mode is not set for you](video-mode.md) — check this before
    judging anything on screen.
14. [Screen coordinates are offset](screen-coordinates.md)
15. [The opening pre-scroll paints the viewport — port it](init-prescroll.md) —
    the one whose absence a screenshot will not reveal. It turned out to be
    half of a v1 routine, hence :
    [import a v1 routine whole, or you will ship two of it](checkpoint-is-one-routine.md).
15b. [A v1 relative toggle assumes v1 owned the register](relative-toggles-on-shared-registers.md) —
    read-modify-write on `$E7E5` &co. In v2 the loader and the resident engine
    share those registers ; anchor absolutely instead of inheriting.
16. [Calling a routine that lives in a paged unit](paged-routine.md) — replaces
    the v1 habit of declaring it an object just to get it placed.
17. [Generated draw code carries no absolute address](generated-code-addresses.md)
18. [A tile is anchored top-left — gfxcomp defaults to center](tileset-anchor.md)
19. [Every v1 sprite variant becomes an `<encoder>` — losing one is silent](sprite-variants.md)
20. [A palette comes from the game mode, not from the artwork](game-mode-palette.md)
20b. [Generated code pasted into a v1 file goes back through the
    pipeline](pasted-generated-code.md) — and the measurement that says whether
    the PNGs or the pasted code are the stale ones.
21. [An imageset bigger than a page is spread, and its index carries a page per
    image](imageset-pages.md) — the one that stops the build dead, with nothing
    wrong in the game.
21b. [A hand edit of a generated map is data — declare it, or regeneration
    loses it](checkpoint-refresh-cells.md) — the checkpoint refresh cells,
    and the general rule for every committed generated file the build
    absorbs.

**Reading a v1 main loop** — what to port, and what existed only for v1.

22. [A v1 object that only existed to get code out of the resident page becomes
    a resident routine](main-private-object.md)


## Not cases, but next door

Some v1→v2 differences have no case file because the v2 manual already states
the contract in full, and a case would only duplicate it:

- **The direct page.** v1 owned `DP` outright; in v2 the loader hands it over,
  and hands it back when you call into the loader. Both directions, plus the
  map of the monitor page, are in [`direct-page.md`](../direct-page.md).
- **What a symbol costs.** [`symbols.md`](../symbols.md) carries the model, the
  three mechanisms and every measurement; [what-to-export](what-to-export.md)
  only holds the part that differs from v1.

## The shape of a case file

Keep it to the six headings below. The point of a fixed shape is that someone
reading under pressure can jump straight to **Symptom** and know in ten seconds
whether they are in the right file.

```markdown
# <the case, stated as a rule>

## Symptom
What it looks like when it bites — the actual error text, or the actual
observed behaviour. No theory.

## The v1 idiom
What the v1 code did, and why it was reasonable there.

## The v2 model
What replaces it, and *why the difference exists* — usually relocation or
load-time linking.

## The fix
The concrete edit.

## Proof
How you know it worked: the listing line, the measurement, the screen.

## Met in
Project, date, and the commit if there is one.
```

The **Proof** heading is not decoration. Several of these cases produce code
that assembles cleanly and runs wrong; the only honest way to close one is to
show the emitted bytes or the observed behaviour.
