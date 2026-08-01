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
| `rle`, `zx0` | compressed image, decompressed to the screen | backgrounds, anything static and large |

The three drawing encoders share one slot in the index. `draw`, `rle` and
`zx0` all answer to the same variant letter, `D`, because the runtime calls
them the same way and the index only ever looks up `B` and `D` — an encoder
with a letter of its own got compiled and then left out of the index entirely.
One image therefore takes at most one of the three, and declaring two is an
error rather than a silent drop.

#### Compressed images are backgrounds, not sprites

`rle` and `zx0` are not simply "smaller sprites". The encoder **discards
transparency** — every pixel gets a colour, index 0 included — and emits one
contiguous run of the plane buffer rather than per-line fragments. The
decompressor writes that run straight to the screen with `stb ,u+`, so it
covers **every byte of every line the image spans**, at the full 40 bytes per
plane, whatever the image's own width.

Declare them full width. A narrow compressed image assembles, links and draws
without complaining, and quietly wipes the whole lines it sits on.

A compressed image also has no erase routine, so the object carrying it must
set `render_overlay_mask`. That flag does both halves of the job: it sends
`CheckSpritesRefresh` to the `D` slot, the only one a compressed image is
filed under, and it tells `EraseSprites` there is nothing to call. Its
imageset entry is three bytes rather than seven for the same reason — the
erase fields are simply absent, and nothing reads them.

To draw one, the game mode has to include the decompressor before the sprite
pack, which ends on `ifndef` stubs for the extended encoders :

```asm
        INCLUDE "engine/graphics/codec/zx0_mega.asm"
        INCLUDE "engine/graphics/sprite/sprite-background-erase-ext-pack.asm"
```

A game with no compressed image leaves that line out and pays nothing.

`mirror` is `none`, `x`, `y` or `xy` ; `shift` pre-shifts the image by whole
pixels so odd positions cost nothing at run time — the runtime picks between
the plain and the pre-shifted variant on the parity of the position, so both
are usually compiled together. Each combination is a
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
        fcb  center_offset             ; width correction, see below
        ; then, per sub set, for each variant it holds :
        fcb  page                      ; cartridge window register value
        fdb  adr_<name>_<variant>      ; the drawing code
        fcb  page
        fdb  adr_<name>_<variant>_erase
        fcb  nb_cell                   ; background cells the erase needs
```

A mirror with no variant of its own falls back to one that exists, so the four
offsets are never zero once a single variant is compiled.

`center_offset` is a correction derived from the image width, `-1` through `3`
by `width % 8`. The runtime reads it twice — `CheckSpritesRefresh` xors it with
`x_pixel` to choose between the unshifted and the 1 pixel shifted variant, and
`DrawSprites` subtracts it before turning the position into a screen address —
so one off puts the sprite a pixel away, or selects a variant that was never
compiled and the sprite vanishes. The bench compares it against v1 for that
reason.

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

### Animation

`AnimateSprite` walks a table of a frame duration, one imageset address per
frame, and an end marker. `<animation>` generates it, next to the images it
points at :

```xml
<animation name="Ani_shell" duration="8">
    <frame image="shell"/>
    <frame image="launcher"/>
</animation>
```

Frames name **images**, not symbols : the element writes `set_<image>` itself,
so a game mode never spells out the generated naming. `end` picks the marker —
`reset` (the default, start over), `goback` with `frames`, `goto` with
`animation`, or `nextroutine` / `resetandsubroutine` / `nextsubroutine`, which
hand control back to the object. The values are written out rather than the
equates of `constants-animation.equ`, so the table assembles in whatever unit
it lands in.

Put it in the same `<lwasm>` unit as the `<gfxcomp>` whose images it uses, and
point `Ani_Page_Index` at **that** direntry's region — the index has to follow
wherever the build placed the table, which is not necessarily the game mode.

`anim,u` points straight at the label when it is positive. A negative value is
a signed offset into `Ani_Asd_Index`, a per object table of animations, which
lets an object switch animation by index rather than by address.

### What a game mode has to provide

The engine sizes nothing by itself. A game mode declares :

- `nb_graphical_objects`, `nb_dynamic_objects`, `ext_variables_size` — they
  size the object tables and the priority structure ;
- the object status tables themselves, at fixed addresses. In a v2 game mode
  these are **equates**, not `fill` directives : the direntry is relocatable
  and its first byte is the entry point, so nothing but code belongs there ;
- `Img_Page_Index`, `Obj_Index_Page`, `Obj_Index_Address`, and `Ani_Page_Index`
  with `Ani_Asd_Index` once it animates — per object id, the page holding its
  imageset, the page and entry point of its code, and the page of its
  animation table. v1
  generated these during its placement pass ; v2 has no object pipeline yet,
  so a game mode writes them by hand for now. They hold **register values**,
  cartridge window bits included (`map.RAM_OVER_CART+<region>.page`).

`examples/sprites` is the smallest complete case : two PNGs, one object, the
frame order above, and assertions at `$9C00`.

### Palette

The runtime reads the palette through a **pointer**, `Pal_current`, so nothing
is copied — installing one is three instructions, v1's:

```asm
        ldd   #Pal_sprites
        std   Pal_current
        clr   PalRefresh          ; $FF nothing to do, 0 push it
```

`Pal_buffer` is not on that path: it is the scratch the fade object
interpolates into, and it repoints `Pal_current` at itself while it works.

`<png2pal>` produces the table two ways, and they coexist because
`Pal_current` is only a pointer:

```xml
<!-- inside a <lwasm> unit : a linkable table, its label exported -->
<png2pal symbol="Pal_sprites" filename="src/assets/sprites/shell_0.png"/>

<!-- as direntry content : 32 loadable bytes, swappable per region -->
<direntry name="assets.palettes.level1">
    <png2pal mode="bin" filename="src/assets/level1/palette.png"/>
</direntry>
```

`offset` defaults to 1 and that matters : colour 0 of a PNG is the transparent
index, the drawing code stores `pixel - 1`, so palette entry 1 becomes hardware
colour 0 and the chain lines up.

**A palette reached through `Pal_current` has to sit in memory that is always
addressable.** `PalUpdateNow` runs under interrupt, and it will read the
pointer whatever page happens to be mounted — so generate it into the game
mode's unit, or copy it into `Pal_buffer` while its page is up.

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

An overlay sprite — a `draw` or compressed image — skips all of that. It is
never backed up and never erased, so it stays on screen until something else
paints over it. Note that `rsv_bgdata` is **not** a way to tell the two apart:
`DrawSprites` stores whatever the draw routine left in U there for every
sprite. The bit that decides is `rsv_prev_render_overlay_mask`, which is what
`EraseSprites` itself reads.

## Two spaces, two kinds of transform

An image goes through **mirror, then planing, then pre-shift**, and the order
is not a preference : the three steps do not live in the same space.

The mirror is a source transform — pixels in, pixels out — and the planing that
follows measures everything from its result. The pre-shift is a screen
transform : the two planes hold the even and the odd pixels of a line, so
moving the image across by one pixel means walking data out of one plane into
the other with a carry into the next byte, and wrapping what leaves the line.
It has no meaning on the source image.

The code says so. `ImageTransform` and `PlaneTransform` are separate
interfaces, typed by what they act on, so a screen transform cannot be applied
to a BufferedImage — it does not compile. They were one interface once, typed
over BufferedImage, and the pre-shift was written as a translate on the source
because nothing said it could not be.

The order also carries an invariant the imageset depends on: **a shifted
variant declares the geometry of the unshifted one**. The index keeps a single
x1/y1 per mirror group, shared by every variant in it, and lets the shifted one
write them — so a shift that moved the bounding box would corrupt the group.
Measuring during the planing, before the shift, makes that true by
construction rather than by care. A test pins it.

## Reproducible builds

Past a node size the search that orders instruction groups is random. Left
unseeded it made the same PNG give 542 bytes on one run and 544 on the next.
Both generators now seed it with the same fixed constant, so a sprite's code
depends on its pixels alone : not on the machine, not on the image's name, not
on where it sits in the build, not on the run.

That is a requirement, not a convenience. Region destinations are placed by
hand, against budgets someone computed once ; a size that drifts between
builds would eat into one of them silently. It is also what keeps the byte for
byte image comparison usable as this repository's validation method now that
generated sprite code is part of the corpus.

The `maxTries` knob v1 exposes does not substitute for this. It sets the node
size below which the search is exhaustive, capped by a factorial table that
stops at 9!, so raising it past 362880 changes nothing — measured, 100 million
tries still gives 542 against 541 bytes on two runs. Setting it to 0 does not
help either : v1's `draw` loop would indeed stop swapping, but its `bdraw` loop
was later changed to keep going "until a solution is found", which makes the
first swap unconditional.

## Parity with v1

The port is checked against the original generator, not against itself :
`toolbox/graphics/gfxcomp/bench/run.sh` runs the same PNG through both chains,
assembles both with the same lwasm and compares.

The two generators emit **byte identical** code on every case of the bench,
including the sprites large enough to reach the random branch — that is what
seeding both sides with the same constant buys. The bench still measures
whether v1 reproduces itself rather than assuming it, and falls back to
comparing sizes within 1% if it does not : that path is now a regression
detector for the seeding, not the normal outcome.

`checkindex.py` extends the comparison to the index : geometry must match the
v1 encoders exactly, and the cell count must follow the one deviation that is
deliberate — the erase margin is 12 bytes where v1 used 16, because the v2
interrupt manager switches S to its own buffer in its first instruction, so
only the hardware push reaches the user stack.

That check earned its place on its first run, catching a one pixel error in
the horizontal centring that had been in the port from the start.

## The decompressor no longer cares where it lands

`zx0_6809_mega.asm` used to pad itself onto a 256 byte boundary — up to 255
wasted bytes — so that a handful of self modified bytes would share one page
and could be reached through the direct page in two bytes each. That padding
is meaningless in a relocatable object: `*` is relative to the section, and
the page it names is not the page the code ends up in. It is the single reason
compiled sprites could never use a compressed image.

Deriving DP from the program counter at run time does work, but it only moves
the problem: the bytes must still share a page, and nothing in a relocatable
unit can promise that. The v2 decompressor reaches them **extended** instead,
which removes the constraint rather than checking it. Twelve accesses, so
twelve bytes and about 6% of decompression time, and `bsr zx0_reload` had to
become `lbsr` once the routine grew.

The two length registers moved out of the code and into the direct page, named
by `ZX0_DP` at the include site — see [direct-page.md](direct-page.md), which
also explains why the routine sets DP itself rather than inheriting it.
`zx0_offset` is the exception: it computes `Y = U + offset16`, which needs D,
and A carries the bit stream, so it stays self modified with extended writes —
extended reaches any address, so it constrains nothing either.

That price lands where it is cheapest. The two callers are the bootloader,
which decompresses while a scene loads and is in no hurry, and compiled sprite
drawing, which is relocatable and so never had the fast path to lose. What it
buys is that neither can be broken by where it was placed — including the
bootloader, whose own copy satisfied the constraint by luck and was checked by
nothing.
