# fullscreen — a picture copied by DrawFullscreenImage

The bench of `<png2bin buffer="fullscreen">` and of
`engine/graphics/draw/DrawFullscreenImage.asm` (manual :
[png2bin](../../toolbox/graphics/png2bin/readme.md), *A full screen picture*).

The picture is a test pattern, 160 x 200, drawn by `tools/gen_mire.py`
(authoring : the build never runs it ; `--check` tells whether the committed
`src/mire.png` is what it draws). Every pixel is opaque, the 16 colours on
every pixel phase, two neighbours on a line never the same colour, no
symmetry : a 7-byte block copied to the wrong place, a swapped bank or a
reversed block shows a wrong colour, not a plausible picture.

The game mode (`src/main.asm`, its setup taken from examples/hscroll) copies
the picture into both screen buffers, then swaps them every frame without
drawing. Witnesses at `$9C00` : `$CA` once running, `$0D` at `+1` once both
buffers hold the picture.

## Build and check

From this directory (`engine` links to `../../engine`) :

```
java -Dbasedir=../.. -cp "../../repo/*" com.widedot.m6809.gamebuilder.MainCommand -f to8.config.xml
python3 ../../ci/toje-bench/fullscreen_ut.py dist/to8.fd
```

Two captures, one per buffer, are compared with the picture pixel by pixel :
the picture index to screen colour relation must be a function, and one to
one.

## Result (toje, 01/11/2026)

- both buffers exact ;
- cost (lwasm listing) : about 58 000 cycles a copy, 152 cycles per 42 bytes.
  The JUnit test `FullscreenTest` checks the bytes against v1's conversion
  loop on the same pixels.
