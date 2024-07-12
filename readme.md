[EN](/docs/lang/en/readme.md) | [FR](/docs/lang/fr/readme.md)

# 6809 Game Builder
![](/docs/assets/images/banner.png)

---

## Description
[wide-dot](https://www.wide-dot.com)'s 6809 game builder is a multiplatform toolset and assembly game framework for 6809 computers.

[![CodeFactor](https://www.codefactor.io/repository/github/wide-dot/6809-game-builder/badge?s=8289592f61057a9492abfadaf23c94fe1bb4e60b)](https://www.codefactor.io/repository/github/wide-dot/6809-game-builder) [![Codacy Badge](https://app.codacy.com/project/badge/Grade/e77ba840d36c43bf8c4e839bac1bde06)](https://www.codacy.com/gh/wide-dot/6809-game-builder/dashboard?utm_source=github.com&amp;utm_medium=referral&amp;utm_content=wide-dot/6809-game-builder&amp;utm_campaign=Badge_Grade)

### Main features
Many plugins and asm libraries are being migrated from the early version of this game builder ... more to come !

#### Plugin based builder
- floppy disk image generator
- custom file directory generator
- lwasm assembler (raw, obj, ...)
- zx0 encoder
- sound converter (vgm, midi)
- image converter (compilated, raw)
- tilemap converter (stm)

#### Framework
##### file and data
- boot loader
- zx0 file loader
- load time file linker
- file and scene loader
- dynamic memory allocator
##### gfx
- optimized double buffering
- palette manager
##### sound
- vgm player (YM2413, SN76489)
- midi file player (EF6850)
##### controllers
- joystick and keyboard manager
- six button megadrive control pad support (for Thomson)



## Building the 6809 Game Builder

Download the latest release if you want to skip this step !

You need to have Java 8 (or newer) and Maven to be installed first.

To produce the packager which contains all the tools and all their dependencies, including engine (asm) and plugins (lwasm, etc.) :

```bash
$ mvn clean package
```

Then plateform distrubutions are generated in .\package\target :

- gamebuilder-package.exe (for windows, obviously)
- gamebuilder-package (for Linux and MacOS)

## Documentation

- [project examples]()
- [setup a new project]()
- [builder plugin reference]()
- [assembly framework reference]()

## Credits
- [third-party tools](docs/lang/en/credits.md)
