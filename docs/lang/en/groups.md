# Groups, layers and regions — loading model

Status : **design decision, current model**. This document supersedes the
group runtime design sketched in [dynamic-link-data.md](dynamic-link-data.md)
(loaded-group state machine, load/unload by group id, delta loading) : after
working through the real use cases, no new runtime mechanism is needed. The
existing per-file lifecycle **is** the group lifecycle, and the differential
loading problem is solved by authoring, not by the engine.

## 1. Core decisions

**A group is a multi-asm direntry.** The builder already provides everything
the media side of the original design asked for :

- lwasm concatenates the members' `code` sections in declaration order into
  one binary ("on concatène les fichiers d'un group avant compilation") ;
- the direntry codec (zx0) compresses the whole group as one stream ;
- the members' link data is emitted merged, relative to the group base — the
  runtime never needs to know the members ;
- the direntry name is the group alias, exported as `<alias> equ <file id>`
  in the generated `entries.asm`.

**The differential is authored, not computed.** An 8-bit game always knows
what changes ("entering level 2", "next track") ; the engine does not diff
anything at runtime. There is no dynamic placement, hence **no fragmentation
problem** : every group's destination is fixed at build time.

**No runtime allocator for game content.** The TLSF pool only holds loader
metadata (directory, link data index and blobs, transient scene tables).
Game content is written at fixed destinations, over whatever was there.

## 2. Layers and regions

Organize a game's memory as layers of decreasing stability :

- **resident** : engine + always-alive code/data. Loaded once, never touched.
- **common** : per-game-family content shared by several states (player
  sprites, HUD, common sounds). Loaded at family entry.
- **regions** : named address ranges (a set of pages, or arbitrary chunks
  including resident RAM and video half-pages) that hold **one variant at a
  time**. All variants of a region are authored at the *same destinations*.

A **scene** is the variant loader of a region : a placement script listing
`(destination page, destination address, group id)`. Switching variants =
`loader.scene.load` of the new variant's scene. Only that region's content
is read from disk ; every other layer is untouched. The trailing full
re-link then re-resolves cross-layer references (e.g. resident code
referencing the current variant's exports — symbols of unloaded variants
resolve to 0, symbols of the loaded one to their real address).

Use-case mapping :

- *R-Type* : resident (engine, player, force pod, HUD, soundFX) + common
  (shared sounds/tables) + region "level" (tilemap, compiled tiles, enemy
  set, boss, music) — one scene per level, all levels sharing the same
  destinations.
- *Lotus-class* : region "circuit" made of heterogeneous chunks (resident
  RAM ranges + video half-pages 0) — one scene per circuit. Scene
  destinations may target any space : cartridge window, resident, video
  half-page (handled by `ram.set`).

## 3. Runtime lifecycle (implemented, stress-tested)

| Need | Feature |
|---|---|
| state of loaded groups | `loader.file.linkDataIdx` (one slot per group) |
| load a variant | `loader.scene.load` (or the individual `file.*` entries) |
| is a group loaded ? | `_loader.file.isLoaded` (`getPageID != $ff`) |
| unload by request | `loader.file.linkData.unload` |
| reload without duplicate | dedup in `linkData.load` |
| replacement at same destination | implicit unload (`linkData.slot.findByDest`) |
| observability | `loader.file.linkData.count` |

Invariants after any load/unload (validated by `examples/loader-ut`,
including a 128-cycle swap/relink stress inside the 4 KB pool) :

1. every indexed slot describes a group whose binary is intact at its
   destination ;
2. no two slots share the same (diskId, fileId) ;
3. no two slots of *non-empty* groups share the same destination ;
4. the global re-link only patches memory belonging to live groups.

## 4. Authoring rules and conventions

- a group must fit one 16 KB page (`direntry.maxsize`) ; bigger content is
  split into several groups listed by the same scene ;
- the group is the smallest unit of reload — content with different
  lifetimes belongs to different groups ;
- groups tracked by the lifecycle must be `loadtimelink="LINK"` ; non-LINK
  files are fire-and-forget (always reloaded, never indexed) ;
- **export-only groups** (constants/interfaces, empty binary flag `$ff00`)
  are loaded at the (0,0) pseudo-destination ; several of them share it and
  they are exempt from destination-based implicit unload ;
- variants of a region must share exact destinations — the implicit unload
  only matches identical (page, address). A variant loaded at a *different*
  address partially overlapping a live group is not detected (sizes are not
  tracked) : this is an authoring error ;
- unresolved symbols silently resolve to 0 (define
  `loader.CHECK_UNRESOLVED_SYMBOLS` to trap instead) — forward references
  across regions rely on this and converge at the next scene load ;
- alias convention : `group.<domain>.<name>` for groups,
  `scenes.<region>.<variant>` for scenes.

## 5. Deferred

- **build-time verifier** : check that all variants of a region fit it, that
  regions do not overlap other layers, and that no variant covers live
  resident code. Declarative region descriptions would live in the config ;
  this replaces the "placement optimizer" idea — no flow graph is needed
  once content is layered ;
- paginated groups (automatic splitting of oversized groups, per-page
  `builder.pageOffset.*` equates) and RAM-map packing tools ;
- group interfaces / multiple instances (identical sorted export lists) ;
- size tracking in the index (partial-overlap detection) ;
- index shrink on unload ;
- GUI replacing manual XML configuration (long-term goal).
