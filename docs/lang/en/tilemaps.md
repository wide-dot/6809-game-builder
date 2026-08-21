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
