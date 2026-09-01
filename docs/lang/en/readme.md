# 6809-game-builder
## Description
The wide-dot 6809 game builder is a multiplatform (Windows, macOS, Linux) toolset and game engine for 6809 computers.

**Status** : this is the next generation of the builder and game engine.
The toolchain is mature — every change is proven against an identity corpus
(15 configurations, 63 disk images compared byte for byte) and replayed
headless under an emulator. The game runtime is being migrated 1:1 from the
[first generation](https://github.com/wide-dot/thomson-to8-game-engine),
which remains the complete-game reference (it runs R-Type level 1 in full,
boss included) ; the R-Type port on this generation already runs its stages
1 and 2 end to end.

[![CodeFactor](https://www.codefactor.io/repository/github/wide-dot/6809-game-builder/badge?s=8289592f61057a9492abfadaf23c94fe1bb4e60b)](https://www.codefactor.io/repository/github/wide-dot/6809-game-builder) [![Codacy Badge](https://app.codacy.com/project/badge/Grade/e77ba840d36c43bf8c4e839bac1bde06)](https://www.codacy.com/gh/wide-dot/6809-game-builder/dashboard?utm_source=github.com&amp;utm_medium=referral&amp;utm_content=wide-dot/6809-game-builder&amp;utm_campaign=Badge_Grade)

### Currently supported computers

- Thomson TO8 (primary target)
- Thomson MO6 / Olivetti Prodest PC128

### Candidates for future releases

- Thomson MO5
- Tandy Color Computer 3 (CoCo 3)

### Demos

(from the first generation of the engine)

![sonic2][sonic2] ![dott][dott]

### Main features

#### Tools

- build bootable floppy disk images (`.fd`, `.sd`, `.sap`, `.hfe`)
- declarative memory model : zones, arenas, attributed places — the
  builder measures, places and publishes, the runtime places nothing
- generate compiled sprites from png files (four encoders, mirror and
  pre-shift variants) and their image-set indexes
- generate tile maps and the whole level-map chain (leanscroll)
- convert pcm, vgm audio data (`vgm2ymm`, `vgm2vgc`, `vgm2sfx`)
- compress code and data (zx0)
- validate the configuration against a generated XSD, and report RAM
  occupancy per scene, link cost and disk seeks

#### Engine
- boot loader, file and scene loader, hot scene swap from disk
- load time linker on files, with a full lifecycle : reload dedup,
  explicit unload, overlap trap, multi-disk
- zx0 decompression in place
- dynamic memory allocator (16-bit TLSF)
- manage objects, animate sprites, move scripts
- manage collisions (AABB and terrain)
- display sprites by priority (compiled sprites, background erase)
- display tilemaps : 1 px scroll on pre-buffered maps, looping band scroll
- camera / autoscroll, enemy waves
- play audio with the ymm (YM2413) and vgc (SN76489) formats, sound FX
  under IRQ
- MEA8000 speech synthesis and MIDI (EF6850 ACIA) test benches

## Building the 6809-game-builder

Download the latest release if you don't want to build the project.

You need to have Java 11 (or newer) and Maven installed first.

To produce the packager which contains all the tools and all their dependencies, including the asm engine and the bundled third-party binaries (lwasm, etc.) :

```bash
$ mvn clean package
```

Platform distributions are then generated in `package/target` :

- `gamebuilder-package.exe` (for Windows, obviously)
- `gamebuilder-package` (for Linux and macOS)

## Documentation

[unpack tools][unpack-tools]

[setup a new project][project-setup]

[build a project][project-build]

[pages, windows and places][memory]

[the memory and scene model][scenes]

[symbols and link cost][symbols]

[groups and loading model][groups]

[objects][objects]

[sprites][sprites]

[tilemaps][tilemaps]

[audio][audio]

[migrating from the first generation — the casebook][migration]

## Toolbox

[toolbox reference guide][toolbox-reference]

## Credits

[third-party libraries and tools][credits]

[6809-game-projects]: https://github.com/wide-dot/6809-game-projects
[sonic2]: demo.gif
[dott]: demo2.gif
[unpack-tools]: unpack-tools.md
[project-setup]: project-setup.md
[project-build]: project-build.md
[memory]: memory.md
[scenes]: scenes.md
[symbols]: symbols.md
[groups]: groups.md
[objects]: objects.md
[sprites]: sprites.md
[tilemaps]: tilemaps.md
[audio]: audio.md
[migration]: migration/README.md
[toolbox-reference]: toolbox.md
[credits]: credits.md
