# Groups — minimal specification

Status : **specification, partially implemented**. This document narrows the
original group design (see [dynamic-link-data.md](dynamic-link-data.md)) down
to the minimal feature set required to port an R-Type-class game (game modes
reloaded by delta, as done by the v1 `RAMLoaderManager`). Everything else is
explicitly deferred (see last section).

Design decision that makes this minimal : **a group is not a new media or
runtime entity — it is a direntry**. The builder already provides everything
the media side of the original design asked for ; what is missing is only a
delta-loading routine on the runtime side.

## 1. Definition

A **group** is the unit of loading, linking and lifecycle :

- it has a unique **alias** (text, checked at build time) ;
- it is stored on the media as **one contiguous stream** (optionally
  zx0-compressed as a whole) ;
- it is loaded to **one destination** (page + address) in one call ;
- it has **one entry** in the runtime link data index ;
- it is the granularity of `isLoaded` / `unload`.

## 2. Authoring model (builder)

A group is declared as **one `<direntry>` containing the ordered list of its
asm units** :

```xml
<direntry name="group.level1.objects" codec="zx0" loadtimelink="LINK">
    <lwasm>
        <asm filename="src/objects/enemy-a.asm"/>
        <asm filename="src/objects/enemy-b.asm"/>
        <asm filename="src/objects/bullets.asm"/>
    </lwasm>
</direntry>
```

This gives, with the existing toolchain, all the media-side properties of the
original design :

- **concatenation** : lwasm merges the `code` sections of the members in
  declaration order into one binary (this is what the original notes meant by
  "on concatène les fichiers d'un group avant compilation") ;
- **single-stream compression** : the direntry codec compresses the whole
  group, no per-member loss ;
- **merged link data** : the member exports/interns/externs are emitted as one
  link data blob for the group, offsets already relative to the group base —
  the runtime never needs to know the members ;
- **alias and id** : the direntry name is the group alias ; the generated
  `entries.asm` exports `<alias> equ <file id>`, which fills the role of the
  planned `builder.group.<alias>` equates.

Rules :
- group alias convention : `group.<domain>.<name>` (recommended, not enforced) ;
- `ORG` is forbidden inside members (obj format, relocated at load time) ;
- a group must fit its destination page (`direntry.maxsize`, 16 KB) — a data
  set larger than one page is authored as several groups, one per page
  (manual "paginated groups" ; automatic splitting is deferred) ;
- members that must be individually reloadable do not belong in the same
  group — the group is the smallest unit of reload ;
- groups that should be tracked by the lifecycle (delta, isLoaded, unload)
  must be declared `loadtimelink="LINK"` : the link data index **is** the
  "loaded groups" state. A group without link data is loadable but invisible
  to the lifecycle.

## 3. Runtime model

The existing per-file machinery is the group machinery — no new structure :

| Design requirement | Runtime feature |
|---|---|
| "keeps a state of loaded groups" | `loader.file.linkDataIdx` slots (diskId, fileId, page, addr, link data ptr) |
| "load : group id, destination" | scene entries / `loader.file.load` + `linkData.load` + `link` |
| "is a particular group loaded ?" | `_loader.file.isLoaded` (`getPageID != $ff`) |
| "unloaded by user request" | `loader.file.linkData.unload` |
| observability | `loader.file.linkData.count` |
| reload without duplicate | dedup in `linkData.load` |
| overwrite at same destination | implicit unload (`linkData.slot.findByDest`) |

A **scene** remains what it is today : a placement script, i.e. an ordered
list of `(destination page, destination address, group id)`. A **game mode**
is authored as one scene listing all its groups.

## 4. Delta loading (the missing piece — to implement)

New jump table entry :

```
loader.scene.loadDelta          ; jump table index 33
input  REG : [X] scene file id
```

Semantics : make RAM converge to the target scene, touching the disk only for
what is missing. This is the v2 equivalent of the v1 `RAMLoaderManager` delta
reload between game modes.

Algorithm :

1. Load the target scene file into the memory pool (as `scene.load` does).
2. **Unload pass** : for each slot of the link data index, search the target
   scene for an entry with the same file id **and** the same destination
   (page + address). If none : `linkData.slot.remove` the slot. Iteration
   note : do not advance the slot cursor after a removal (slots shift down).
3. **Load passes** : for each scene entry, if a slot exists with the same
   file id and same destination, **skip** the file entirely (no disk read, no
   decompress, no link data reload). Otherwise run the three usual passes
   (load, decompress, linkData.load — the dedup and implicit-unload logic
   already handle any residual index conflicts).
4. **Re-link** : run the full `loader.file.link` over all indexed files, as
   today. Skipped files are re-linked too — this is required, because their
   extern references may point into groups that have just been (re)loaded,
   and it is what makes forward references converge.
5. Free the scene file buffer.

Edge cases :
- an entry whose destination changed (same group, new address) is NOT a
  match : the old slot is removed by the unload pass, the group is reloaded
  at the new destination — correct by construction ;
- export-only entries (empty file flag `$ff00`, e.g. constant interfaces)
  are indexed like any group and delta-skip like any group ;
- files not declared `loadtimelink="LINK"` are invisible to the index : they
  are (re)loaded unconditionally by the load passes and never unloaded —
  by design, keep them for fire-and-forget data ;
- `scene.load` keeps its current semantics (unconditional load) ; `loadDelta`
  is a separate entry point.

Cost : the unload pass is O(slots × scene entries) with 16-bit compares — a
few dozen entries at worst, negligible against a single sector read.

## 5. Lifecycle invariants

After any `scene.load` / `scene.loadDelta` / `linkData.unload` :

1. every indexed slot describes a group whose binary is intact in RAM at
   (filePage, fileAddr) ;
2. no two slots share the same (diskId, fileId) — dedup ;
3. no two slots share the same (filePage, fileAddr) — implicit unload ;
4. the global re-link is therefore always safe : it only patches memory that
   belongs to live groups.

Invariant 1 still relies on scene authoring for **partial overlaps** (a group
loaded across another group's range at a different start address is not
detected — sizes are not tracked in the index). With delta loading and
one-destination-per-group authoring this does not occur in practice ; a debug
build check (trap if a load intersects a live slot) would require adding the
size to the slot and is deferred.

## 6. Deferred (from the original design)

- builder `<group>` element grouping existing direntries (today : one
  direntry = one group, members are asm units) ;
- **paginated groups** : automatic splitting of an oversized group into
  per-page groups by a pre-build tool, `builder.pageOffset.<file>` equates ;
- RAM map / page-filling optimization tools ("reorder in place") ;
- **group interfaces / multiple instances** : identical alphabetically-sorted
  export lists between groups sharing an id ;
- interval (size-based) overlap detection in the runtime index ;
- index shrink on unload ;
- graphical editor concepts (Assets / Components / Objects / Packages).

## 7. Test plan (examples/loader-ut)

- T11 : `loadDelta` of a scene equal to the current state → zero disk reads
  (observable : `linkData.count` unchanged and marker contents untouched ;
  disk activity observable via the `pulse` callback counter) ;
- T12 : `loadDelta` of a scene that drops one group and adds another →
  dropped group deindexed, added group loaded and linked, kept group not
  reloaded (pulse counter only accounts for the added group + scene file) ;
- T13 : `loadDelta` with a destination change for a kept group → group
  reloaded at the new address, old slot removed, extern references to it
  re-patched (checked via the linked begin label).
