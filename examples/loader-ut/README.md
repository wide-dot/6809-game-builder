# loader-ut — unit test game mode for the file/scene loader

Test harness for `engine/system/thomson/bootloader/loader.asm`. It boots a
minimal game mode that exercises the loader and writes its results to a fixed
RAM table, readable from an emulator or debugger (toje, wddebug, DCMOTO).

This is the base for implementing and testing the **missing loader features**
(`loader.file.linkData.unload`, reload dedup, `isLoaded` query — see the
loader analysis in the repository `CLAUDE.md`).

## Layout

- `src/assets/game-modes/to8/main.asm` — the test program, loaded at `$6100`.
- `src/assets/markers/marker-{aa,bb,cc}.asm` — marker data files (`$0400`
  bytes each) : body filled with a unique id byte (`$A1`/`$B2`/`$C3`), tail
  `$F0,$F1,$F2,$F3,$F4,id` (the 6-byte tail specifically exercises the
  loader's `cdataz` uncompressed-tail handling for zx0 files). Each exports a
  `marker.xx.begin` symbol to exercise the load-time linker.
- `src/scenes/to8/main/scene.asm` — boot scene : game mode + marker aa
  (page 6/`$0000`, zx0) + marker bb (page 6/`$0800`, raw).
- `src/scenes/to8/second/scene.asm` — loaded at runtime by the test :
  marker cc (zx0) **over** marker bb at page 6/`$0800`.

## Result table (`$9C00`)

| offset | meaning |
|---|---|
| +0 | `$CA` magic — test program is running |
| +1 | T1 marker aa content (zx0 decompress + cdataz tail) |
| +2 | T2 marker bb content (raw load) |
| +3 | T3 extern16 link of `marker.aa.begin` / `marker.bb.begin` |
| +4 | T4 `loader.file.getPageID` for aa and bb |
| +5 | T5 runtime `loader.scene.load` of scene "second", cc content |
| +6 | T6 full re-link patched `#marker.cc.begin` (forward reference) |
| +7 | T7 `loader.file.getPageID` for cc |
| +8 | T8 implicit unload : loading cc at bb's destination deindexed bb (`isLoaded` false, explicit unload reports not found) |
| +9 | T9 dedup : reloading scene "second" keeps `linkData.count` stable, cc content and link intact |
| +10 | T10 explicit `linkData.unload` of aa : success, `isLoaded` false, count drops by one |
| +11 | T11 stress : 128 load/unload/relink cycles of the dd/ee variants over one destination — fresh extern fixups ($F1), content ($F2), symbol flips in the gm ($F3) and in the stable hub file ($F4), index steady at 4 ($F5) ; explicit unload every 16th cycle ; the whole loop must live within the 4 KB pool |
| +12 | T12 index growth : +6 export-only files push the index past 8 slots (realloc), values resolved ($F7), mass unload ($F8), count restored ($F9) |
| +14 | T11 progress : remaining iterations |
| +15 | `$00` running, `$0D` all passed, `$E0+n` n test(s) failed |
| +16/+17 | info : `#marker.cc.begin` **before** the second scene load (expected `$0000` — unresolved symbols silently resolve to 0) |

Each test slot : `$00` not run, `$01` pass, `$FF` fail.

## Build & run

Needs `lwasm` >= 4.22 available as `lwasm.exe` in the PATH (macro-local `@`
labels used by the engine are broken in the 4.18 binaries shipped in
`toolbox/third-party/bin/macos`), an `engine` symlink/copy at the example
root, and the gamebuilder jars in `repo/` (built by `mvn -pl
toolbox/gamebuilder/core -am package`).

```
cd examples/loader-ut
ln -s ../../engine engine
java -cp "../../repo/*" com.widedot.m6809.gamebuilder.MainCommand -f to8.config.xml
```

Boot `dist/to8.fd` on a TO8 (press `B` at the monitor menu), let it run a few
seconds, then read 16 bytes at `$9C00`.

## Covered loader lifecycle features

- `loader.file.linkData.unload` (T10) : frees the link data buffer, shifts the
  following slots, decrements `occupiedSlots`, returns `B=$00` / `$FF` not found.
- reload dedup in `linkData.load` (T9) : a reloaded disk/file reuses its
  existing index slot (old buffer freed) instead of appending a duplicate.
- implicit unload (T8) : registering a **different** file at the exact
  destination (page+address) of an indexed file removes the stale entry, so
  the global re-link cannot patch stale offsets over the new binary.
- `loader.file.linkData.count` : jump table entry (index 30) so tests and
  diagnostics can observe the index size.
- `_loader.file.isLoaded` macro : `getPageID != $FF`, result in CC (ne=loaded).

Limitation : implicit unload only matches the exact same destination ;
loading a file that *partially overlaps* an indexed file's memory (different
start address) still leaves a stale entry — sizes are not tracked in the
index. Use explicit `linkData.unload` in that case.

Convention : export-only files (empty binary, link data only) are loaded at
the (0,0) pseudo-destination ; several of them share it, so they are exempt
from destination-based implicit unload.

## Bugs caught by the stress additions

- `loader.dir.load` never stored the malloc'd buffer into `map.DK.BUF` when
  the directory spans more than one sector : sector 2+ was read over the
  loader's own variables and code at `ptsec+256`. Dormant since the origin —
  no previous project had a directory larger than one sector.
- the destination-based implicit unload evicted export-only files from the
  index one after the other (they all share destination (0,0)) — a
  regression introduced with the implicit unload itself, now fixed by the
  empty-file exemption above.
