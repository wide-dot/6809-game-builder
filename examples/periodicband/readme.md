# periodicband — a band that repeats along x, drawn at any phase

The bench of `<periodicband>` and of its runtime,
`engine/graphics/tilemap/periodicband/periodicband.asm` (manual :
[tilemaps](../../docs/lang/en/tilemaps.md), *A periodic band*).

The band is a test pattern, period 48 px, two periods wide (96 x 40), drawn
by `tools/gen_band.py` (authoring : the build never runs it ; `--check` tells
whether the committed `src/band.png` is what it draws) :

- lines 0-7 and 32-39 are FULL (no transparent pixel) : the runtime's writer
  draws them from per-line tables ;
- lines 8-15 and 24-31 are STEMS (diagonal strokes, transparent between
  them, half bytes included) : the six compiled strips of 16 px ;
- lines 16-23 are empty.

Two neighbours on a full line never share a colour, and the colours' period
(15) is not the band's : a pixel pair taken one pixel off, a swapped plane or
a wrong rotation shows a wrong colour, not a plausible picture.

The game mode (`src/main.asm`, its setup taken from examples/hscroll) fills
the screen with colour 15, which the band never uses, draws the band at x 8,
line 60, 144 px wide, in both buffers, phase after phase (0 to 47), and holds
each one ; the witnesses at `$9C00` say which phase is on screen. Under the
bench script, which arms it, it holds each phase until the script has
checked its capture.

## Build and check

From this directory (`engine` links to `../../engine`) :

```
java -Dbasedir=../.. -cp "../../repo/*" com.widedot.m6809.gamebuilder.MainCommand -f to8.config.xml
python3 ../../ci/toje-bench/periodicband_ut.py dist/to8.fd
```

For every phase the capture is compared with the picture at that phase : in
the window, every pixel shows the picture's pixel `(x + phase) mod 48`, the
background where the picture is transparent (the index to colour relation a
function, one to one) ; outside it, the background everywhere but the side
margins of the band's lines and of the two lines around it, where the strips
may spill (a playfield mask covers them in a game).

## Result (toje, 30/10/2026)

- 48/48 phases exact : the full lines, the strips with their transparency,
  nothing outside the window and its margins ;
- cost (lwasm listing) : 305 cycles per full line, both planes ; the strips
  of this pattern 24 lines high. The JUnit tests of `PeriodicbandPlugin`
  check the same at every phase through a model of the runtime's reads.
