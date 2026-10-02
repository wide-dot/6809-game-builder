# bm4s — 320x200 in 4 colours through the BM16 chain

The proof of section 3 of `docs/lang/fr/analyse-modes-graphiques-2026-10.md`.

In the `$41` display mode (bitmap 4 "special", TO8 / TO8D / TO9+ only) a screen
byte holds four 2-bit pixels, leftmost in bits 7-6, and the RAMA byte of an
address shows the four pixels to the left of its RAMB byte : the byte layout of
BM16 with 2-bit pixels. A BM16 nibble covers two `$41` pixels, so a 320 pixel
wide 4 colour picture is byte for byte the 160 pixel wide BM16 picture whose
pixel is `(left << 2) | right`.

`tools/gen_bm4s.py` draws the test pictures at 320x200 in 4 colours
(`src/assets/sprites/src320/`, the reference) and writes their recoding
(`src/assets/sprites/*.png`). From there everything is examples/sprites
unchanged — gfxcomp, the imageset index, the BM16 sprite runtime — except the
mode register (`$41`) and a hand-written 4 colour palette. `x_pixel` keeps its
0..159 range : one unit is two screen pixels, and the pre-shifted variant is a
2 pixel shift.

The one constraint : transparency goes by pixel pairs (a BM16 nibble is
transparent or not). The generator refuses a half-transparent pair.

## Result (toje, 02/10/2026)

- witnesses `$9C00` : `$CA`, then `$01` everywhere ;
- the band (320x24, 1 pixel columns, 8 pixel colour blocks, 1 pixel ticks) :
  0 differences out of 7 680 pixels against its reference ;
- the glyph (24x24, 1 pixel diagonal, a transparent hole) : exact at unit 32
  (even) and 37 (odd), i.e. through both pre-shifted variants, the hole showing
  the background ;
- the marker : exact at every position sampled ;
- no stray pixel outside the sprites and the band over 7 captures : the erase
  path leaves no trail.

Build, from this directory (`engine` links to `../../engine`) :

```
python3 tools/gen_bm4s.py
java -Dbasedir=../.. -cp "../../repo/*" com.widedot.m6809.gamebuilder.MainCommand -f to8.config.xml
```
