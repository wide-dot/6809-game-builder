# 6809-game-builder
## Description
The wide-dot 6809 game builder is a multiplatform (Windows, macOS, Linux) toolset and game engine for 6809 computers.

### Currently supported computers

- Thomson TO8
- Thomson TO8D
- Thomson TO9+

### Candidates for future releases

- Thomson MO5
- Thomson MO6 / Olivetti Prodest PC128
- Tandy Color Computer 3 (CoCo 3)

### Demos

Demonstrations are available in a dedicated repository : [6809-game-projects]

![sonic2][sonic2] ![dott][dott] 

### Main features

#### Tools

- build bootable cartridge or floppy disk
- define packages of code and data to be loaded in RAM pages
- compress your code and data
- generate compilated images from png files or tilesets
- pre-process your images
- convert Tiled tmx tilemaps in asm data
- convert pcm, vgm, midi, smps audio data

#### Engine
- load packages of asm binary and data in subset of RAM pages
- manage objects
- display sprites by priority
- animate your sprites
- display tilemaps (tile groups, animation, buffering, ...)
- play audio with dpcm, svgm, smid, smps, psg audio formats
- use ym2413 and sn76489 sound chips
- play midi files (EF6850 ACIA)

## Building the project an Running
Download the latest release or build the project.

To produce the JAR and all its dependencies, including engine (asm) and tools (lwasm, exo, etc.) :

```bash
$ mvn clean package
```

Then the different plateform distrubution are generated in .\package\target :

- gamebuilder-package.exe (for windows, obviously)
- gamebuilder-package (for Linux and MacOS)

## Tutorials

[unpack tools][unpack-tools]

[setup a game][setup-a-game]

[build a game][build-a-game]

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
[setup-a-game]: doc/setup-a-game.md
[build-a-game]: doc/build-a-game.md
[objects]: doc/objects.md
[sprites]: doc/sprites.md
[tilemaps]: doc/tilemaps.md
[audio]: doc/audio.md
[toolbox-reference]: doc/toolbox.md
[credits]: doc/credits.md
