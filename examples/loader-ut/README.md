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
| +8 | T8 `linkData.unload` of bb : success, deindexed (`getPageID == $FF`), not-found on 2nd call |
| +9 | T9 dedup : reloading scene "second" keeps `linkData.count` stable, cc content and link intact |
| +10/+11 | info : `#marker.cc.begin` **before** the second scene load (expected `$0000` — unresolved symbols silently resolve to 0) |
| +15 | `$00` running, `$0D` all passed, `$E0+n` n test(s) failed |

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

- `loader.file.linkData.unload` (T8) : frees the link data buffer, shifts the
  following slots, decrements `occupiedSlots`, returns `B=$00` / `$FF` not found.
- reload dedup in `linkData.load` (T9) : a reloaded disk/file reuses its
  existing index slot (old buffer freed) instead of appending a duplicate.
- `loader.file.linkData.count` : jump table entry added (index 30) so tests
  and diagnostics can observe the index size.

Possible next steps : `isLoaded` helper (trivial via `getPageID != $FF`),
index shrink on unload (optional), group-level load/unload (see
`dynamic-link-data.md`).
