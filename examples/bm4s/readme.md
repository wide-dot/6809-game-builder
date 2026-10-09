# bm4s — 320x200 in 4 colours through the BM16 chain

The bench of the `$41` display mode (bitmap 4 "special", TO8 / TO8D / TO9+
only), section 3 of `docs/lang/fr/analyse-modes-graphiques-2026-10.md`.

In `$41` a screen byte holds four 2-bit pixels, leftmost in bits 7-6, and
the RAMA byte of an address shows the four pixels to the left of its RAMB
byte : the byte layout of BM16 with 2-bit pixels. A BM16 pixel covers two
`$41` pixels, so a 320 pixel wide 4 colour picture is byte for byte the 160
pixel wide BM16 picture whose pixel is `(left << 2) | right`.

What the bench uses, and nothing more than examples/sprites, which its game
mode is copied from :

- `<gfxcomp videomode="bm4s">` : the PNGs are drawn at 320 in 4 colours
  (`src/assets/sprites/`), gfxcomp packs them by pixel pairs ; the encoders,
  the imageset index and the BM16 sprite runtime run unchanged ;
- `<png2pal>` : the palette, read from the same PNGs ;
- `_gfxmode.setBM4S` : the mode.

`x_pixel` keeps its 0..159 range : one unit is two screen pixels, and the
pre-shifted variant is a 2 pixel shift. Transparency goes by pixel pairs
(gfxcomp refuses a half transparent pair).

The pictures are test patterns drawn by `tools/gen_bm4s.py` (authoring : the
build never runs it ; `--check` tells whether the committed PNGs are what it
draws).

## Build and check

From this directory (`engine` links to `../../engine`) :

```
java -Dbasedir=../.. -cp "../../repo/*" com.widedot.m6809.gamebuilder.MainCommand -f to8.config.xml
python3 ../../ci/toje-bench/bm4s_ut.py dist/to8.fd
```

The bench reads the witnesses at `$9C00` (main.asm) and compares twelve
captures against the 320 pixel sources : the band exact, the moving sprite
(glyph or marker) exact where it is found, no pixel lit elsewhere, and the
glyph seen through both pre-shifted variants.

## Result (toje, 09/10/2026)

- witnesses : `$CA`, then `$01` everywhere, the frame counter moving, the
  free cell list head holding still ;
- 12 captures : the band (320x24, 1 pixel columns, 8 pixel colour blocks,
  1 pixel ticks) exact, the glyph (24x24, 1 pixel diagonal, a transparent
  hole) and the marker exact, the glyph at screen x 0 and 2 modulo 4 (both
  variants), no trail ;
- the compiled sprite unit is byte for byte the one the earlier Python
  recoding produced (02/10/2026).
