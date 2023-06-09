/[readme]/build-a-game

Build a game
=

## Description

Building a game is the process of assembling all source code of a game and encode the result in a storage media for a dedicated system.

## Systems

The game builder support the following 6809 systems :

system|clock|manufacturer|year
-|-|-|-
to8|1 MHz|Thomson|1986
to8d|1 MHz|Thomson|1987
to9+|1 MHz|Thomson|1986

## Storage media

The builder handle several media types, all are specific to a system or a system familly.

system|storage media|max. size|file extension
-|-|-|-
to8, to8d, to9+|floppy disk|640 KiB|.fd, .hfe
to8, to8d, to9+|[SDDRIVE] (sd card)|16 GiB|.sd
to8, to8d, to9+|[Megarom T.2] (rom)|2 MiB|.rom (loader in .sd)

## Usage

... TODO ...

[SDDRIVE]: http://dcmoto.free.fr/bricolage/sddrive/index.html
[Megarom T.2]: https://megarom.forler.ch/fr/

[readme]: ../readme.md
[build-a-game]: build-a-game.md