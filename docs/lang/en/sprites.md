# Compiled sprites

Status : the toolchain and the drawing runtime are in place and validated
under emulation (August 2026). Survey that preceded the work :
[`sprites-etat-2026-07.md`](../fr/sprites-etat-2026-07.md).

A sprite is not data here, it is **code**. `gfxcomp` turns a PNG into 6809
instructions that write the pixels, and the runtime calls that code. There is
no blitter loop and no mask test at run time : transparency, addresses and
register allocation are all decided at build time.

## The pipeline

```
  PNG  ──gfxcomp──▶  drawing code + erase code + imageset index
                             │
                             ├── one <lwasm> unit, one direntry
                             │
                     load time linker ──▶ addresses and page resolved
                             │
                     the sprite runtime calls the code
```

Declare it in the configuration file :

```xml
<direntry name="assets.sprites" loadtimelink="LINK">
    <lwasm gensource="gen/assets/sprites/sprites.asm">
        <!-- entries.asm brings the file id equates the index needs -->
        <asm filename="gen/directories/disk0/entries.asm"/>
        <gfxcomp gendir="gen/assets/sprites"
                 gensource="gen/assets/sprites/includes.asm"
                 genindex="gen/assets/sprites/index.asm"
                 file="assets.sprites">
            <image name="shell" filename="src/assets/sprites/shell_0.png" index="0">
                <encoder name="bdraw" mirror="none" shift="0"/>
            </image>
            <image name="launcher" filename="src/assets/sprites/launcher.png" index="1">
                <encoder name="bdraw" mirror="none" shift="0"/>
                <encoder name="draw"  mirror="none" shift="0"/>
            </image>
        </gfxcomp>
    </lwasm>
</direntry>
```

`gfxcomp` compiles each `<image>`, writes one source per `<encoder>` into
`gendir`, and returns a `gensource` of INCLUDE lines wrapped in a section —
that is the unit `<lwasm>` assembles. `file` names the direntry the images end
up in : the index needs it to reference their page (see below).

Input PNGs are 8 bit indexed, colour index 0 transparent, 1 to 16 for the
palette.

### Encoders

| name | what it produces | when |
|---|---|---|
| `bdraw` | background backup + draw, plus a matching erase routine | moving sprites |
| `draw` | draw only | overlays, sprites whose background need not survive |
| `rle`, `zx0` | compressed image data | not used by the drawing runtime |

`mirror` is `none`, `x`, `y` or `xy` ; `shift` pre-shifts the image by whole
pixels so odd positions cost nothing at run time. Each combination is a
**variant**, named `<mirror><encoder><shift>` — `NB0` is unmirrored bdraw
unshifted. That name, v1's, is what the generated symbols carry :
`adr_shell_NB0`, `adr_shell_NB0_erase`.

## The imageset index

The index is the table the runtime reads to find out what to draw. Its layout
comes from v1 unchanged :

```
idx_<name>              equ <index>     ; the id, also emitted as a byte
set_<name>
        fcb  n, x, y, xy               ; offset of each mirror's sub set
        fcb  x_size, y_size            ; drawn area, transparent border trimmed
        fcb  center_offset             ; 0 or 1, parity of the image centre
        ; then, per sub set, for each variant it holds :
        fcb  page                      ; cartridge window register value
        fdb  adr_<name>_<variant>      ; the drawing code
        fcb  page
        fdb  adr_<name>_<variant>_erase
        fcb  nb_cell                   ; background cells the erase needs
```

A mirror with no variant of its own falls back to one that exists, so the four
offsets are never zero once a single variant is compiled.

**The page is a relocation.** v1 placed pages during a global build pass and
wrote the number in. v2 loads files into regions at run time, so the index
carries an `externPg` relocation on `<direntry>$PAGE`, resolved when the file
is loaded. The byte goes straight to the cartridge window register, so it also
carries the RAM over cartridge bits — the relocation's plus operand covers
that, which is why the generated source reads `assets.sprites$PAGE+$60`.

The unit must therefore include the directory's `entries.asm` : that is where
the file id equate the relocation resolves against is defined.

Exported for the rest of the game to link against : `set_<name>`,
`idx_<name>`, and every `adr_<name>_<variant>`.

## Drawing

The runtime is v1's, imported as is. A frame looks like this — the order is
the contract, not a suggestion :

```asm
        jsr   RunObjects              ; each object updates itself and calls
                                      ; DisplaySprite to register in the
                                      ; priority structure of the buffer
        jsr   CheckSpritesRefresh     ; per object : mirror, mapping frame,
                                      ; screen bounds, erase and draw decisions
        _gfxlock.on
        jsr   EraseSprites            ; restore the backgrounds, free the cells
        jsr   UnsetDisplayPriority    ; apply priority changes
        ; anything that must end up inside a background backup goes here
        jsr   DrawSprites             ; allocate cells, mount the page, draw
        ; anything that must not be captured goes here (HUD, starfield)
        _gfxlock.off
        _gfxlock.loop
```

`InitDrawSprites` runs once at start up : it sets the camera offsets, and
nothing draws without it.

`DisplaySprite` runs **every frame**, from the object's own routine. It
registers the object in the priority structure of the buffer being drawn, and
there is one structure per buffer.

### What a game mode has to provide

The engine sizes nothing by itself. A game mode declares :

- `nb_graphical_objects`, `nb_dynamic_objects`, `ext_variables_size` — they
  size the object tables and the priority structure ;
- the object status tables themselves, at fixed addresses. In a v2 game mode
  these are **equates**, not `fill` directives : the direntry is relocatable
  and its first byte is the entry point, so nothing but code belongs there ;
- `Img_Page_Index`, `Obj_Index_Page`, `Obj_Index_Address` — per object id, the
  page holding its imageset and the page and entry point of its code. v1
  generated these during its placement pass ; v2 has no object pipeline yet,
  so a game mode writes them by hand for now. They hold **register values**,
  cartridge window bits included (`map.RAM_OVER_CART+<region>.page`).

`examples/sprites` is the smallest complete case : two PNGs, one object, the
frame order above, and assertions at `$9C00`.

### Positions

`x_pixel` / `y_pixel` are screen coordinates in a **shifted frame** :
`screen_left`..`screen_right` by `screen_top`..`screen_bottom`, that is
48..207 by 28..227. The margin lets a position just off screen stay inside a
byte. A sprite whose bounding box leaves that frame is flagged out of range
and silently not drawn — the first thing to check when nothing appears.

Setting `render_playfieldcoord` in `render_flags` switches the object to
playfield coordinates (`x_pos` / `y_pos`), which the engine converts through
the camera offsets. Without that flag `x_pos` is never read.

### Backgrounds

A `bdraw` sprite saves what it covers before drawing, into cells allocated by
`BgBufferAlloc` (`nb_cell` of them, from the index). `EraseSprites` replays
the save in reverse and releases the cells. Allocation and release balance out
over a frame : the bench watches the head of the free cell list, which is what
a leak would move.

## Parity with v1

The port is checked against the original generator, not against itself :
`toolbox/graphics/gfxcomp/bench/run.sh` runs the same PNG through both chains,
assembles both with the same lwasm and compares.

Where the register allocation search is exhaustive, the two generators emit
**byte identical** code. Past that size both fall back to an unseeded random
walk, so v1 does not reproduce itself either — measured at 543 against 544
bytes on the same sprite between two runs. The bench detects which regime it
is in by sampling v1 several times, and in the stochastic one it requires
gfxcomp to land within 1% of v1's best sample.

`checkindex.py` extends the comparison to the index : geometry must match the
v1 encoders exactly, and the cell count must follow the one deviation that is
deliberate — the erase margin is 12 bytes where v1 used 16, because the v2
interrupt manager switches S to its own buffer in its first instruction, so
only the hardware push reaches the user stack.

That check earned its place on its first run, catching a one pixel error in
the horizontal centring that had been in the port from the start.
