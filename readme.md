# 6809-game-builder
## Description
The wide-dot 6809 game builder is a multiplatform (Windows, macOS, Linux) toolset and game engine for 6809 computers.

**WARNING**: This is the next generation of the builder and game engine. However, this version is still under development and should not be used.
Please use [this repository](https://github.com/wide-dot/thomson-to8-game-engine) instead.

[![CodeFactor](https://www.codefactor.io/repository/github/wide-dot/6809-game-builder/badge?s=8289592f61057a9492abfadaf23c94fe1bb4e60b)](https://www.codefactor.io/repository/github/wide-dot/6809-game-builder) [![Codacy Badge](https://app.codacy.com/project/badge/Grade/e77ba840d36c43bf8c4e839bac1bde06)](https://www.codacy.com/gh/wide-dot/6809-game-builder/dashboard?utm_source=github.com&amp;utm_medium=referral&amp;utm_content=wide-dot/6809-game-builder&amp;utm_campaign=Badge_Grade)

### Currently supported computers

- Thomson TO8
- Thomson TO8D
- Thomson TO9+

### Candidates for future releases

- Thomson MO5
- Thomson MO6 / Olivetti Prodest PC128
- Tandy Color Computer 3 (CoCo 3)

### Demos

![sonic2][sonic2] ![dott][dott] 

### Main features

#### Tools

- generate compilated images from png files or tilesets
- convert Tiled tmx tilemaps in asm data
- convert pcm, vgm, midi, smps audio data
- compress code and data
- build bootable cartridge or floppy disk

#### Engine
- load code and data to RAM pages
- link at load time
- manage objects
- manage collisions
- display sprites by priority
- animate sprites
- display tilemaps (tile groups, animation, buffering, ...)
- use multiple software scroll engines
- play audio with dpcm, svgm, smid, smps, psg audio formats
- use ym2413 and sn76489 sound chips
- play midi files (EF6850 ACIA)

## Building the project an Running

Download the latest release or build the project.

You need to have Java 8 (or newer) and Maven to be installed first.

To produce the packager which contains all the tools and all their dependencies, including engine (asm) and tools (lwasm, etc.) :

```bash
$ mvn clean package
```

Then plateform distrubutions are generated in .\package\target :

- gamebuilder-package.exe (for windows, obviously)
- gamebuilder-package (for Linux and MacOS)

## Tutorials

[unpack tools][unpack-tools]

[setup a new project][project-setup]

[build a project][project-build]

[objects][objects]

[sprites][sprites]

[tilemaps][tilemaps]

[audio][audio]


## Toolbox

[toolbox reference guide][toolbox-reference]

## Credits

[third-party libraries and tools][credits]

[6809-game-projects]: https://github.com/wide-dot/6809-game-projects
[sonic2]: doc/demo.gif
[dott]: doc/demo2.gif
[unpack-tools]: doc/unpack-tools.md
[project-setup]: doc/project-setup.md
[build-a-game]: doc/build-a-game.md
[objects]: doc/objects.md
[sprites]: doc/sprites.md
[tilemaps]: doc/tilemaps.md
[audio]: doc/audio.md
[toolbox-reference]: doc/toolbox.md
[credits]: doc/credits.md
