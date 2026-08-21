# Tilemaps and the horizontal scroll

How a scrolling level is built and drawn : the runtime that walks a tilemap,
the table it walks, and the build chain that generates that table. The
reference implementation is r-type level 1 ; the working example is
`examples/tilescroll`.

## The runtime

`engine/graphics/tilemap/horizontal-scroll/scroll-map-buffered-even.asm`
(imported 1:1 from v1) scrolls one pixel at a time over a map of **compiled
tiles**. Two routines share the work :

- `Scroll` — outside the gfx lock : advances the camera, decides which
  columns changed, computes where in the map to read ;
- `DrawTiles` — inside the gfx lock : calls the compiled tile routines that
  repaint the changed cells of the hidden buffer.

The trick that makes a 1 px scroll affordable is the **pair of maps** : the
even one points at tiles compiled as-is, the odd one at the same tiles
pre-shifted by one pixel. An odd camera position costs nothing more than
reading the other table.

This is not `hscroll` : that one loops a fixed-width band on itself for
repeating backgrounds. The tilemap scroll is the playable terrain, on a map
as long as the level.

## The table

Column major, three bytes per cell :

```
fcb   page          the page holding the compiled tile routine (+$60, RAM
                    over cartridge window)
fdb   address       its entry point
```

There is no tile index at run time — each cell points **straight at code**.
Index 0 in the source map means *draw nothing* : the cell becomes three zero
bytes and the scroll skips it. Real levels lean on this hard : 60–75 % of
r-type's cells are empty, the initial viewport image carries what never
changes.

## The build chain

The same chain v1 used — its map cutter is a v2 tool, and its tiles were
compiled by the sprite encoder :

1. **Draw the level as one PNG** (`in.png`, one row of tiles = 12 px).
2. **`<leanscroll>`** runs the cut as part of the build — no hand-run tool,
   no committed intermediate :

   ```xml
   <leanscroll image="src/stages/01/map/in.png" gendir="gen/stages/01/map"
               gensymbols="gen/stages/01/map/map.const.asm"/>
   ```

   From the level picture it derives both scroll planes (the odd one
   pre-shifted a pixel), each as a strip of unique tiles plus the tile index
   map (16 bit big endian, transposed to column major, index 0 reserved for
   "nothing to draw"), then windows and renumbers them — `columns=`/`first=`
   select an opening section, the whole level when omitted — into
   `even.png / even.bin / odd.png / odd.bin` under `gendir`. The geometry
   comes out as equates (`map.COLS`, `map.ROWS`) in `gensymbols`. Results
   are cached on the picture and the parameters, so the chain runs once per
   art change, not once per build pass. The module itself stays callable by
   hand (`toolbox/graphics/tilemap/leanscroll`).

   **`lean="false"`** drops the lean pass and tiles the picture AS IT IS.
   Everything else is unchanged — both planes, dedup, window, maps, equates.
   The pass only pays when the engine SCROLLS the playfield : it removes the
   pixels a sweep is going to repaint anyway, and `scrollstep=`/`nbsteps=`
   are the vector it sweeps along (declaring either alongside `lean="false"`
   is an error, they would mean nothing). A renderer that clears the field
   and repaints every tile every frame has nothing to spare, and the pass
   would only mask what the art says — there, transparency comes from the
   picture, not from a scroll model.
3. **`<gfxcomp>` with `grid`** slices the strip and compiles every tile :

   ```xml
   <gfxcomp gendir="gen/tiles" gensource="gen/tiles/includes.asm">
       <image name="tiles" filename="src/tiles/tiles.png" grid="12x12">
           <encoder name="draw" shift="0"/>
           <encoder name="draw" shift="1"/>
       </image>
   </gfxcomp>
   ```

   Tiles are named `<name>_<id>` in reading order — leanscroll's numbering —
   and their entry points (`adr_<name>_<id>_<variant>`) are exported by a
   generated block, since a tileset has no imageset index. Nothing imports
   them through the loader, so pruning keeps them out of the link data.

   Two ways to get the odd map's tiles : compile the normal strip twice
   (`shift="1"` for the second encoder, variant `ND1`), or compile
   leanscroll's pre-shifted strip as its own `<image>` (v1's way — its `_s`
   tilesets are shifted pixels compiled unshifted, so both variants are
   `ND0`). The `<tilemap>` element takes the variant as a plain string, so
   either naming works.

4. **`<tilemap>`** turns the index map into the run-time table :

   ```xml
   <tilemap map="src/maps/map.bin" label="map.even"
            tiles="tiles" variant="ND0" file="assets.tiles"
            gensource="gen/maps/map_even.asm"/>
   ```

   Each index becomes `fcb <file>$PAGE+$60` + `fdb adr_<tiles>_<id>_<variant>`,
   in a **`.static` section** : the builder bakes every reference against the
   declared placement of the tiles' direntry, so a 1980-cell level costs no
   load-time link data and no run-time symbol search (v1 paid the same price —
   zero — by generating after placement). The generated file declares its own
   `EXTERNAL`s ; nobody hand-writes hundreds of them.

## What the game mode still owns

The geometry (columns, rows, viewport) is the game's business : equates in
its source, `scroll_map_even/odd` and the map page set at init. The tiles'
direntry must be declared **before** the consumer of its addresses — a
provider consumed statically is built first.

## Validation

`examples/tilescroll` runs this exact chain on generated test patterns (a
poison tile 0 that must never appear, a diagonal that breaks visibly on any
1 px error), plus the terrain collision unit on top ; validated under toje.
The real-data shape is confirmed against r-type : level 1 maps decode to
132×15 entries over 245/304 tiles, level 2 to 96×15 over 191/230, empties
dominating both.

## Animating the decor : `tilemap.patch`

A map cell is a pointer, not an id, so animating scenery is rewriting those
pointers in place — the next `DrawTiles` paints the result. This is what the
arcade does : R-Type repaints a rectangle of its background tilemap to swallow
the Outslay into Gomander's tube (`gomander_helper_blit_recipe` at 0x40:A578,
6×4 cells of `(tile_id, attr)`), and the Warship's wrecks work the same way.

It is also the *only* way to put moving art behind a sprite : the decor is
painted after the sprites, so a tilemap animation covers them, where a sprite
never could.

### The runtime

`engine/graphics/tilemap/patch/tilemap-patch.asm` holds two layers.

`tilemap.patch` writes one rectangle into one plane. Because the map is column
major, a column of the rectangle is contiguous on **both** sides, so each
column is a straight block copy — that is what keeps the routine short. It
mounts the map's page and restores the caller's, so the source block must be
directly addressable : resident, or a page already mounted. That costs
nothing, since a block is three bytes per cell — eight frames of 2×2 weigh 96
bytes, while the *tiles* they name weigh kilobytes.

`tilemap.anim.start` / `.step` / `.apply` play a sequence over that primitive.
The clock advances by `gfxlock.frameDrop.count` and the rectangle is written
only when the frame actually changes ; a late loop catches up by frames and
paints once, on the frame it lands on.

**One animation, two planes, one clock.** The scroll reads `map.even` or
`map.odd` by camera parity and the two point at different tiles, so an
animation carries a descriptor for each — stepping two states would run the
clock twice. A boss that stops the scroll freezes the parity and can declare
the odd descriptor as 0.

Where the arcade keeps a forward table and a reverse table over the same
payloads, the engine keeps one table and a direction flag : the reading order
is a property of the reading, not of the data.

### The build chain

Draw the frames **side by side** in one picture, cut it with `<leanscroll>`
exactly like a level — the frames then land as a contiguous run per frame in
the column-major index map, which is what lets the builder slice by range.
Compile the strip with `<gfxcomp grid>`, then :

```xml
<tilepatch map="gen/engulf/even.bin" label="engulf.even"
           tiles="stage2.engulf.tiles.even" variant="ND0"
           cols="2" rows="2" frames="8" col="47" row="5" hold="2"
           gensource="gen/engulf/even.asm"/>
```

One invocation per plane, like `<tilemap>` and for the same reason. Each index
becomes the same three-byte entry, baked against the tiles' declared
placement, so an animation costs no load-time link data. Index 0 keeps its
meaning — the cell draws nothing — which on a patch is a usable effect : it
erases.

**Use a tileset of its own.** Measured on the arcade's engulf : 161 distinct
tile ids over 192 cells, and only 4 cells frozen across the eight frames. A
decor animation is bespoke pixels, not a recombination of the level's tiles,
so it shares almost nothing with the level and a common pool would save
nothing while coupling the animation's art to the level's tile numbering.

### Deferred requests — why object code never writes the map

Object code does not touch the map. It **pushes a request** — a descriptor and
a frame number, three bytes — and that is all. Once per frame the game loop
calls `tilemap.flush`, which mounts the map's page **once** and applies
whatever accumulated.

That is not a convenience, it is what makes the thing safe. Three parts live
in three places : the module is resident ; an animation's **state** lives in
the OST of the object driving it, hence in half-page 0 — outside the cartridge
window, which ends at `$4000`, and pinned by `_gfxlock.init` under overlay, so
always addressable ; the **descriptor and blocks** live in the map's direntry,
which is paged. Pushing a pointer does not dereference it, so object code has
no page to know about, and the only place that mounts one is the drain.

The sequencer that read both sides produced three defects, each the same
mistake — a read taken on the wrong side of a mount does not fail loudly, it
returns whatever bytes live there : `cols`/`rows` as zero and 64 KB
overwritten, the frame index wrong and cells blanked, the hold as zero and the
catch-up loop spinning. With deferred requests those are not expressible.

**No allocator.** An animation belongs to an object, and that object's OST is
its storage — on the bytes the sprite animator already reserves there
(`tanim.frame` / `tanim.timer` / `tanim.flags`, aliases over indices 12-14).
Instantiation, lifetime and release are the object's.

One caveat worth knowing : `tanim.timer` shares byte 13 with `wave_frame_drop`,
which ObjectWave deposits at creation. An object born from a wave must read its
lateness **before** arming its animation.

**Stamps need none of this.** `tilemap.stamp` pushes one request for frame 0 —
no clock, no direction, no lifetime. The battleship's 31 wrecks are one call
each.

`tilemap.patch`, the leaf that writes a rectangle, refuses a zero `cols` or
`rows` rather than trusting it : an unresolved symbol reads as a silent zero in
this project, and here that zero would run 256 columns of 256 bytes.

### Validation

`examples/tilescroll` runs a 2×2 rectangle of four frames over the scrolling
test map, both planes, bouncing forward and back. The pattern is built so both
properties are readable : the four cells of a frame carry four *different*
tiles, so a row/column mix-up shows as a transposition, and the four rotate by
one per frame, so the sequence can be read from any single cell.
