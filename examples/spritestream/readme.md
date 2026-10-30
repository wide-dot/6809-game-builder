# spritestream — bm4s sprites as streams, and their clip mode

The bench of the sprite stream manager ([`spritestream.md`](../../docs/lang/en/spritestream.md)) :
the builder's `<spritestream>` (the sprites as records and streams, the
walkers with their clip mode, `clip="true"`) and the engine's runtime
(`engine/graphics/sprite/stream/spritestream.asm`), one copy of the manager
in each half of the video half page, as a game places it.

What it proves, every result checked on the machine against a second path
(screens compared by checksums, both planes) :

- `draw` of each picture, in both facings (the stored one, the mirrored walk)
  and both 2 pixel steps, from an even and an odd first byte : its `restore`
  gives the background back ; `drawAt` and `drawClip` (the rectangle the
  screen) draw the same screen ;
- `drawClip` through five cuts of each box (its first byte off, its last,
  its upper half, its lower half, a window one byte and one line in from
  each side) draws what `draw` draws with the bytes outside the cut put
  back, and restores ;
- the mirrored walk of `flag` draws what its second facing `flagm`, stored,
  draws, at both steps ;
- a box across each of the screen's four edges (`drawClip`, the rectangle
  the screen, a uniform background) draws the same visible part as the same
  box moved inside the screen and cut on the same bytes, changes nothing
  else, and restores ;
- the guard (`guard="true"` on the shape set) : with the save stack's top
  leaving `flag` its whole draw's bound less one byte, the draw is skipped
  (`spritestream.skips` one more, the screen the background, t43) ; with
  exactly its bound, it is drawn, the screen t01's, and restores (t44) ;
- after every test, nothing written past the screen in either plane.

The pictures are test patterns drawn by `tools/gen_spritestream.py`
(authoring : the build never runs it ; `--check` tells whether the committed
PNGs are what it draws) : `flag` (multi-row records, a gap of empty rows,
per pixel masks, a width of 2 mod 4 whose mirror swaps the 2 pixel steps),
`flagm` its mirror, `slab` (long rows cut into segments), `tall` (rows
repeated by two), each with its copy moved 2 pixels right.

## Build and check

From this directory (`engine` links to `../../engine`) :

```
java -Dbasedir=../.. -cp "../../repo/*" com.widedot.m6809.gamebuilder.MainCommand -f to8.config.xml
cd ../.. && python3 ci/toje-bench/bench.py examples/spritestream
```

The game mode writes its verdicts at `$9C00` (`docs/lang/en/benches.md` ;
the tests and their codes in `main.asm`) ; the words are the draws'
checksums, compared with `bench.ref` : a changed word is a changed picture.

## Result with the guard (toje, 27/10/2026)

44/44, identical to the reference : t01-t42 word for word as before the
guard (it changed no draw), t43 one skip, t44 t01's checksum. Broken on
purpose (the interrupt's margin dropped from the check) : t43 fails, and
nothing else.

## Result (toje 1.9.0, 27/10/2026)

42/42, identical to the reference (12 s of replay). Broken on purpose once
(the cut loop's mask applied after the data, stored facing only) : the eight
tests of the stored facing fail (t01, t02, t05, t06, t09, t10, t13, t14),
and nothing else.
