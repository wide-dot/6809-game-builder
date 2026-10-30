# Sprite streams (bm4s)

Status : toolchain and runtime written and validated under emulation against
a measured reference, October 2026, with a clip mode for boxes crossing the
screen's edges or a cut rectangle (opt-in, *Clipping*) ; bench
`examples/spritestream` (see *Validation*).

A compiled sprite ([sprites](sprites.md)) is code : fast, about six bytes a
drawn screen byte, one routine per variant. A **sprite stream** is data : the
picture's row segments with a mask and a data byte per screen byte (about
three bytes a drawn byte, records and deltas included), read at run time by
**walkers**, routines generated once for the whole set. It is the form for many large pictures that must be
drawn in several variants : a 320x200 4 colour (`bm4s`, `$41`) character set
of a few hundred pictures that would take tens of pages compiled fits in a
few as streams.

What the walkers do, per record :

- draw the segment, any pixel transparent or not (per pixel masks : a pair
  of pixels with one transparent pixel is drawn exactly) ;
- draw it in the stored facing, or **mirrored** (the bytes written right to
  left through a 256 byte reversal table) : one stream draws both facings ;
- **save** the screen bytes they mask on a stack (S), with a restore code :
  one restore walker puts a buffer back, last drawn first, so no rectangle is
  saved or copied.

- with the walkers' **clip mode**, draw only the part of a box inside a
  rectangle (*Clipping*).

## The pipeline

```
  indexed PNG ─┐
  (+ the same  ├─<spritestream>─▶ per sprite : record + streams  (data pages)
   2 px right) ┘                   one source each, adr_<name>
                                         │
  <spritestream genwalker> ─▶ walkers, restore, tables ─┐
                                                        ├─ one unit in the video
  engine/graphics/sprite/stream/spritestream.asm ───────┘  half page, a copy each half
```

The builder is generic : one picture in, one stream out. Anything that
depends on the game (which pictures, their padding, a second facing stored
for a picture drawn mirrored most of the time, the tables that tell the game
which record draws which image and how to anchor it) is prepared before the
build and handed over as pictures.

## Input pictures

An indexed PNG : index 0 transparent, 1 to 4 the mode's colours 0 to 3, one
PNG pixel a screen pixel, column 0 at pixel 0 of a screen byte (4 pixels a
byte, the two video planes alternating byte by byte). A width that is not a
multiple of 4 is completed with transparent pixels.

A **sprite** groups one picture and, optionally, the same picture moved right
by 2 pixels (2 transparent columns on its left, `shifted`) : drawn at a 2
pixel step of x, a sprite needs no shift at run time. A **mirrorable** picture
has an even width (pad an odd one with a transparent column on its right) :
its mirror then lands on the 2 pixel grid too. The builder checks both.

## Configuration

The shape set — what records the streams may hold, what routines the walkers
have — is the element's options. **The streams and the walkers must share
them** : set them once with `<default>` so both forms read the same values.

```xml
<default name="spritestream.segment" value="6"/>
<default name="spritestream.rows" value="2:2,3:2"/>

<!-- the sprites : an arena collection, each sprite a part the packer places -->
<file name="assets.chars" linkdata="LINK" arena="game" gendir="gen/chars">
    <spritestream gendir="gen/chars/streams" genreport="gen/chars/report.csv">
        <sprite name="hero_01" filename="art/hero/01.png" shifted="art/hero/01s.png"/>
        <sprite name="hero_02" filename="art/hero/02.png" shifted="art/hero/02s.png"/>
    </spritestream>
</file>

<!-- the manager : the walkers with the engine's runtime, one copy per half
     of the video half page -->
<file name="engine.sprites0" linkdata="LINK" region="sprites.half0">
    <lwasm gensource="gen/sprites/manager0.asm">
        <asm xml:space="preserve">spritestream.HALF equ 0</asm>
        <asm filename="src/sprites.head.asm"/>     <!-- equates, exports, SECTION code -->
        <spritestream genwalker="gen/sprites/walker.asm"/>
        <asm filename="engine/graphics/sprite/stream/spritestream.asm"/>
        <asm xml:space="preserve"> ENDSECTION</asm>
    </lwasm>
</file>
<!-- engine.sprites1 : the same with HALF 1, region sprites.half1 (no exports) -->
```

with the two halves as regions of the layout :

```xml
<region name="sprites.half0" page="$00" slice="0" address="$4000" size="$2000"/>
<region name="sprites.half1" page="$00" slice="1" address="$4000" size="$2000"/>
```

In an `<lwasm>` instead of a collection, `gensource` gives the INCLUDE lines
of the sprites inside a section, every record exported.

| attribute | default | |
|---|---|---|
| `videomode` | `bm4s` | the only one |
| `segment` | 6 | the longest record, in screen bytes |
| `rows` | `2:2,3:2` | multi-row records : `<bytes>:<rows>`, `none` for none |
| `mirrorable` | true | streams drawn in both facings (one byte more a record) |
| `save` | true | the walkers save what they mask ; `spritestream.restore` |
| `opaque` | false | whole bytes in segments of their own, data only |
| `mergepulls` | true | the restore pulls up to three saved groups at once |
| `clip` | false | the walkers' clip mode, for `spritestream.drawClip` (walkers only) |
| `guard` | false | records carry what their draw saves, the runtime skips a draw the save stack cannot hold (*The guard* ; needs `save`) |
| `gendir`, `gensource`, `genreport` | | sprites : their sources, the INCLUDE file, a CSV of the sprites |
| `genwalker` | | the walkers' form |

Limits, refused at build time with their cause : 64 record codes (the stored
walk indexes its jump table with a signed byte), 128 restore routines, a box
of 79 screen bytes and 255 rows.

## Record and stream

Record, 8 bytes, at `adr_<name>` : stream of the picture, stream of the
shifted picture (the same when there is none), their box bytes N0 and N1,
the rows, the mirror flag — 1 when the picture's width is 2 mod 4 : the
mirror of each stream then lands on the other stream's 2 pixel step. With
`guard`, two words more (12 bytes) : what a whole draw of either stream
saves, exactly, and the most a draw cut by `drawClip` saves.

Stream : records `[mirrored delta] [code] [delta] [payload]`, the first byte
only in mirrorable streams. A delta is the change of the walker's Y,
`rows x 40 + columns`, on the segment's first byte's column (stored facing)
or on the column of that byte's mirrored place (mirrored facing) ; a delta
past a signed byte becomes `nop` records, a row each. Codes : 0 end, 2 nop,
then the shapes (`m<p>_<n>`, `m<p>_<n>r<rows>`, `o<p>_<n>` : masked or opaque,
the first byte on the box's first plane or the other, n bytes, rows).
Payload of a row : the even bytes then the odd ones (each a plane, adjacent
columns) ; pairs as mask, mask, data, data (one 16 bit access each), a last
single byte as mask, data.

Every stream is decoded back by the builder the way the walkers read it,
and compared with its picture, in both facings when mirrorable : a stream
that would not draw its picture stops the build.

## The runtime

`engine/graphics/sprite/stream/spritestream.asm`, assembled after the
generated walkers. The game declares `spritestream.HALF` (0 or 1, the copy's
half), `spritestream.dp` (8 bytes of the direct page : the two save stacks'
tops, then the clip rectangle, unused without the clip mode ;
`spritestream.const.asm` for a caller) and optionally `spritestream.STACK`
(default 768 : the most a buffer saves between two restores, plus what an
interrupt pushes on S while a walker runs), and `spritestream.DRAWAT` 0 to
leave `drawAt` out (105 bytes of the half page measured with the clip mode and the guard, for the save stack of a game
that does not call it). The walkers' temporaries use `dp_engine`.

| entry | input | |
|---|---|---|
| `spritestream.init` | | both save stacks emptied : after a cut, when both buffers are redrawn |
| `spritestream.restore` | | the buffer's saved bytes put back, last drawn first |
| `spritestream.draw` | A record page (`$E7E6` value), B facing (0 stored), X left edge x (0-318, even), Y top line (0-255), U record | |
| `spritestream.drawAt` | A page, B facing + 2 x step, Y screen address of the box's first byte on its top line, U record | the caller has the address |
| `spritestream.drawClip` | as `draw`, X and Y signed ; the rectangle in `spritestream.clipLeft`, `clipRight` (screen bytes 0-80), `clipTop`, `clipBottom` (lines 0-200), right and bottom excluded | the clip mode : only the part inside the rectangle |

All give the caller's cart page back ; A, B, X, Y, U and CC are lost.

**Where it runs.** While a walker draws, the back buffer fills the data
window and the sprite's page the cart window : the manager lives in the video
half page `$4000-$5FFF`. gfxlock mounts there the half of the buffer it draws,
so each half holds a copy of the manager and that buffer's save stack ; the
two copies differ only by the direct page address of their stack's top.
A game whose sprite pack uses the half page (background erase mode) cannot
have both.

**The frame.** Inside the loop's single gfxlock section : `restore` first,
then the draws. The bytes a draw saves are put back by the next `restore` of
the same buffer, two images later. After a cut, `init`.

**Interrupts.** S is the save stack while a walker runs : an interrupt
pushes below its top, on free space. `STACK` must leave room for the
interrupt's own pushes below the deepest frame.

## The guard

The save stack has the size the game gives it (`STACK`), and nothing stops a
frame whose draws save more : the stack then grows down over the manager's
code, which sits just below it, and the next draw that runs that code
crashes the machine. A game that cannot bound what a frame draws (a crowd of
falling pieces, characters gathering) turns `guard` on, for the streams and
the walkers alike.

Each record then carries two words after its 8 bytes : W, what a whole draw
pushes (each record of the stream its n bytes a row, then its restore code
and Y : n x rows + 3), exactly, the larger of its two streams ; and C, the
most a draw cut by the clip mode pushes (each visible row of a cut record
its visible bytes then 3 or 4 : n x rows + 4 x rows a record). Before a
draw, the runtime checks that the stack holds it above
`spritestream.IRQ` bytes (default 12, an interrupt's pushes) :
`draw`, `drawAt` and a box `drawClip` draws whole against W, a box it cuts
against C. A draw that would not fit is not drawn — the screen is left as
it was, nothing saved — and `spritestream.skips` (a byte of each half,
wrapping) counts it. A frame that runs out of stack loses its last sprites
for that frame instead of the machine.

The builder computes both words from the stream it emits (`Decoder.saveBound`),
checked in JUnit against two counts that share no code with it : what the
generated walker routines push (equal to W, both facings) and what the clip
mode pushes on random windows (at most C). The walkers declare
`spritestream.GUARD` to the runtime, which assembles the checks only then.

What it costs : the records 4 bytes each ; the runtime 50 bytes (the three
checks, the skip, the counter) ; a draw 22 cycles (`drawAt` 34).

## Clipping

A box must lie inside the screen for `draw` : the walkers address its bytes
from the first one, and a byte past an edge lands on the line before or
after, or out of the buffer. `clip="true"` on the walkers
(`<spritestream genwalker="..." clip="true">`) adds the clip mode, which the
runtime's `spritestream.drawClip` uses. The streams are the same with or
without it : a game turns it on without re-encoding a sprite.

- A box inside the rectangle (with its wider stream) takes the draw path, 78
  cycles more than `draw` ; a box outside it returns.
- A crossing box is walked through a clip jump table (one per facing, the
  mirrored one at table number 5 after the reversal table) whose entries are
  handlers. Each record's row is tracked from Y (the visible rows are an
  address range), its box bytes come from a shape table (`p`, `n`, then rows
  and payload bytes a row 2 x CODES bytes before it). A record whose rows and
  bytes are visible is drawn by its own routine ; a hidden one is skipped ;
  the visible bytes of a cut one are drawn left to right by a tight loop (the
  two plane steps alternating, each byte's mask and data found through an
  offsets table, a pair a byte, read backwards when mirrored), saved as it
  draws them with one restore record a row ; the walk ends at the first
  record below the rectangle.
- The walk keeps its state in `dp_engine` (its 30 bytes) and a few bytes of
  the manager.

What it adds : the walkers 260 bytes (the clip tables, the shape and offsets
tables, two restore routines), the runtime 1 063 (`drawClip`, the handlers,
the cut loops) ; `STACK` must count, for the cut rows, a byte a byte and 3 or
4 more a row.

## Costs

Measured under toje (cycle exact) on the recommended set (`segment` 6, `rows`
2:2,3:2, mirrorable, save, merged pulls), on 216 character pictures
(mean box 231 screen bytes, 115 drawn, 36 rows), each in its 8 draws :

| | cycles |
|---|---|
| `draw`, mean of the stored and mirrored facings | 4 972 |
| `restore` of one picture | 1 386 |
| `drawAt` | 4 911 |
| `drawClip`, a box inside the rectangle | 5 050 |
| `drawClip`, each picture cut on each side, in the corners and through a window (6 048 draws) : draw + restore | 11 197 + 1 402 |

Bytes : the walkers and their tables 5 600, the runtime 217, each save stack
`STACK` + 3 (768 : 6 588 of the half page's 8 192 ; 1 024 : 6 844). With the
clip mode : 5 860 and 1 280 (`STACK` 1 024 : 8 167).

Clipped, on the same game's real frames (5 743, each image cut by its own
rectangle as the original draws it, 211 frames with a box crossing it) : 412
cycles a frame more on average than the same frames drawn without cuts, a
crossing image's draw about 11 000 cycles ; a standing character cut at the
screen's left edge 10 504 cycles (draw and restore), at its right edge
15 274.

An interrupt during a walk puts 12 bytes on the save stack (the 6809's own ;
the TO8 monitor jumps to the engine's handler, which switches stacks).
Measured on a game's real frames (2 096, up to five characters), a buffer
saves at most 747 bytes between two restores.
Streams : 2.9 bytes a drawn screen byte for that set (144 589 bytes, records
included, for 216 pictures at both 2 pixel steps), against 6.4 for the same
pictures compiled with gfxcomp's `draw`.

## Validation

The reference is the measured prototype the shape set was chosen with (a
game's bench, Python). The JUnit tests of `toolbox/graphics/spritestream`
compare the streams of 96 pictures (a seeded mire) and the walkers' routines
and jump tables with that prototype's, byte for byte, and assemble the
walkers of several shape sets with the runtime (the size model of the layout
checked against lwasm's addresses). For the clip mode, a model of the cut
path reads the tables the generator wrote and draws every stream of the
mire, both facings, through every column window and several row windows :
equal byte for byte to the decoder's whole walk inside the rectangle,
untouched outside it.

`examples/spritestream` is the bench of this repository : four test pictures
drawn on the machine in every entry, each result checked against a second
path (`draw`, `drawAt` and `drawClip` the same screen ; a cut against the
whole draw with the outside put back ; the mirrored walk against the stored
second facing ; a box across each screen edge against the same box cut
inside the screen), every restore checked, 42 tests replayed by
`ci/toje-bench/bench.py` against `bench.ref`. The runtime was run under toje on a
full character set loaded by the loader from a built disk : every picture in
every draw, exact against the expected screen and restored exactly, the
double buffer over 2 096 frames of real play, and the machine running
(interrupts on, gfxlock swapping) stopped at the end of its frames : every
buffer exact.
