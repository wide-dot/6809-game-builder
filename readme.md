[EN](/docs/lang/en/readme.md)

# 6809 Game Builder
![](/docs/assets/images/banner.png)

---

## Description
[wide-dot](https://www.wide-dot.com)'s 6809 game builder is a multiplatform toolset and assembly game framework for 6809 computers.

Target machines : Thomson **TO8** (primary) and **MO6**. Candidates for future releases : Thomson MO5, Tandy CoCo 3.

[![CodeFactor](https://www.codefactor.io/repository/github/wide-dot/6809-game-builder/badge?s=8289592f61057a9492abfadaf23c94fe1bb4e60b)](https://www.codefactor.io/repository/github/wide-dot/6809-game-builder) [![Codacy Badge](https://app.codacy.com/project/badge/Grade/e77ba840d36c43bf8c4e839bac1bde06)](https://www.codacy.com/gh/wide-dot/6809-game-builder/dashboard?utm_source=github.com&amp;utm_medium=referral&amp;utm_content=wide-dot/6809-game-builder&amp;utm_campaign=Badge_Grade)

### Status

The toolchain is mature : every release of the build is proven against an
identity corpus (15 configurations, 63 disk images compared byte for byte)
and replayed headless under an emulator. The game runtime is being migrated
1:1 from the [first generation](https://github.com/wide-dot/thomson-to8-game-engine)
of this engine — which remains the complete-game reference (it runs R-Type
level 1 in full, boss included) ; the R-Type port on this generation
already runs its stages 1 and 2 end to end, level swap, checkpoint and
real artwork included.

### Main features

#### Builder
- declarative memory model : the author declares constraints (zones,
  arenas, budgets), the builder measures, places and publishes — the
  runtime places nothing
- scenes as load lists : a `<load>` is a name ; where a file lands is
  declared once, on the file
- collections : a file too big for a page flows into the free tails,
  cut between elements by the packer
- load-time linker data emission (intern / extern8 / extern16 / externPg),
  with baked-by-default references and a caused list of what stays linked
- floppy disk images : fd640 / fd320 / fd158 → `.fd`, `.sd`, `.sap`, `.hfe`
- lwasm assembly (raw, obj), zx0 compression, generated access tables
  (image sets, tile maps, level-map chain via leanscroll)
- audio converters (`vgm2ymm`, `vgm2vgc`, `vgm2sfx`), `pcm`, `png2pal`,
  `png2bin`, `stm2bin`, `phoneme`, `txt2bas`
- compiled sprites (`gfxcomp`) : four encoders, mirror and pre-shift
  variants
- an XML configuration validated by a generated XSD, and build reports :
  RAM occupancy per scene, link cost, disk seek map

#### Framework
##### file and data
- boot loader, file and scene loader, hot scene swap from disk
- load-time file linker with a full lifecycle : reload dedup, explicit
  unload, overlap trap, multi-disk support
- zx0 decompression in place
- dynamic memory allocator (16-bit TLSF, with realloc)
##### gfx
- optimized double buffering (50 Hz IRQ swap, frame-drop accounting)
- compiled sprite runtime (background erase, priority display)
- object manager, animation, move scripts
- tilemap scroll (1 px, pre-buffered maps) and looping band scroll
- AABB and terrain collisions, camera / autoscroll, enemy waves
- palette manager, video modes
##### sound
- YMM player (YM2413) and VGC player (SN76489), sound FX under IRQ
- MEA8000 speech synthesis and MIDI (EF6850) test benches
##### controllers
- keyboard and joystick manager
- six button megadrive control pad support (for Thomson)

## Building the 6809 Game Builder

Download the latest release if you want to skip this step !

You need to have Java 11 (or newer) and Maven installed first.

To produce the packager which contains all the tools and all their dependencies, including the asm engine and the bundled third-party binaries (lwasm, etc.) :

```bash
$ mvn clean package
```

Platform distributions are then generated in `package/target` :

- `gamebuilder-package.exe` (for Windows, obviously)
- `gamebuilder-package` (for Linux and macOS)
- `gamebuilder-package-*-tools-<os>-packaging.zip` (per-OS third-party binaries)

## Documentation

- [project examples](examples/)
- [setup a new project](docs/lang/en/project-setup.md)
- [build a project](docs/lang/en/project-build.md)
- [the memory and scene model](docs/lang/en/scenes.md)
- [symbols and link cost](docs/lang/en/symbols.md)
- [sprites](docs/lang/en/sprites.md) · [objects](docs/lang/en/objects.md) · [tilemaps](docs/lang/en/tilemaps.md)

## Credits
- [third-party tools](docs/lang/en/credits.md)
