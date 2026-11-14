# Raycasting : textured walls by compiled scalers (BM16)

A first person view of a grid map on a TO8 : textured walls, a flat ceiling
and a flat floor, 6 to 16 frames a second.

- The **raycaster** casts a ray a screen column in the map and writes, per
  column, a descriptor : how tall the wall is, which texture column it
  shows.
- The **wall scalers** draw the descriptors : one compiled routine a wall
  height. A scaler writes the wall's rows only ; the ceiling and the floor
  stay in the buffer.

A column of the view is a screen byte : two BM16 pixels of the same colour,
80 columns for the whole screen.

Builder : `toolbox/graphics/raycast` (`<wallscaler>`, `<raycast>`).
Runtime : `engine/graphics/raycast/`. Example : `examples/wallscaler`.

## The view

Set once with `<default name="raycast.xxx">` : every `<wallscaler>` and
`<raycast>` reads the same settings.

| setting | default | |
|---|---|---|
| `cols` | 80 | byte columns (2 pixels each), even |
| `rows` | 200 | even, a multiple of the rows between two wall heights |
| `x`, `y` | 0, 0 | the view's top left : `x` in byte columns (even), `y` in rows |
| `lines` | 2 | screen rows a wall sample : 2 is a 2x2 pixel sample, 1 a texel a row, 4 coarser |
| `clipstep` | 8 | above `rows` (a wall clipped by the view), a scaler every `clipstep` rows of height |
| `maxheight` | 2.2 x `rows` | the tallest wall drawn : `rows` plus a multiple of `clipstep` |
| `fov` | 66 | horizontal field of view, degrees (10 to 110) |
| `wall` | 0.75 | a wall's height in map cells |
| `ceil`, `floor` | 1, 2 | colour indexes of the ceiling and the floor |

Outside the view the screen is the game's. A wall's height is even (a wall
is centred) and a multiple of `lines`. A setting the runtime cannot honour
is a build error that names it.

## Pictures

**Textures** : an indexed PNG 64 pixels high, a texture every 64 pixels of
its width, colours 0 to 15 of the game's palette. Texture 1 is the
leftmost.

**Map** : an indexed PNG, a pixel a cell — colour index 0 an empty cell, n
a wall of texture n. Up to 255 cells a side, walls all along its border.

## Configuration

```xml
<layout>
    <region name="columns.half0" page="$00" slice="0" address="$4000" size="$2000"/>
    <region name="columns.half1" page="$00" slice="1" address="$4000" size="$2000"/>
    <arena name="walls">
        <zone page="$05" address="$0000" size="$4000"/>
        <zone page="$06" address="$0000" size="$4000"/>
        <zone page="$07" address="$0000" size="$4000"/>
        <zone page="$08" address="$0000" size="$4000"/>
    </arena>
</layout>

<default name="raycast.ceil"  value="1"/>
<default name="raycast.floor" value="2"/>

<file name="walls.scalers" linkdata="LINK" arena="walls" gendir="gen/walls">
    <wallscaler form="scalers" gendir="gen/walls/scalers" gensource="gen/walls/scalers/includes.asm"/>
</file>

<file name="walls.raycast" linkdata="LINK" bake="all" page="$09" address="$0000">
    <lwasm gensource="gen/walls/raycast.asm">
        <raycast map="src/map.png" textures="src/textures.png" gensource="gen/walls/tables.asm"/>
        <asm filename="engine/graphics/raycast/raycast.unit.asm"/>
    </lwasm>
</file>
<file name="walls.angles" linkdata="LINK" page="$0A" address="$0000">
    <lwasm gensource="gen/walls/angles-file.asm">
        <raycast form="angles" gensource="gen/walls/angles.asm"/>
    </lwasm>
</file>

<file name="walls.textures" linkdata="LINK" page="$01" address="$7800">
    <lwasm gensource="gen/walls/textures-file.asm">
        <wallscaler form="textures" filename="src/textures.png" gensource="gen/walls/textures.asm"/>
    </lwasm>
</file>

<file name="walls.half0" linkdata="LINK" bake="auto" region="columns.half0">
    <lwasm gensource="gen/walls/half0.asm">
        <wallscaler form="columns" gensource="gen/walls/columns.asm"/>
        <asm filename="engine/graphics/raycast/wallscaler.columns.asm"/>
    </lwasm>
</file>
<!-- walls.half1 : the same, region="columns.half1" -->

<file name="game.main" linkdata="LINK" bake="auto" page="$01" address="$6100">
    <lwasm gensource="gen/main.asm">
        <wallscaler form="consts" gensource="gen/walls/consts.asm"/>
        <asm filename="src/main.asm"/>
    </lwasm>
</file>
```

In an `<lwasm>`, the generated element comes before the engine's file.

| file | where | why |
|---|---|---|
| scalers | an arena of pages under the cart window | the builder ranges the routines ; the zones are a budget (4 pages for the whole screen, 2 for 64 x 128) |
| raycaster's unit | an address `$xx00` of a cart page | its variables are in the direct page |
| angles | a cart page | 12 KB |
| textures | resident (`$6000-$9FFF`), at an address `$xx00` | read while a scaler's page fills the cart window |
| columns unit | the video half page, both halves | gfxlock mounts the half of the buffer being drawn |

`<raycast>` also takes `radius` (the nearest the camera comes to a wall, in
cells, default 0.3) and `pair` (default true : a ray for two columns, an
odd column whose neighbours hit the same face of the same cell takes their
mean ; false : a ray a column).

## Runtime

The game mode includes, after the generated constants :

```
        INCLUDE "engine/graphics/raycast/wallscaler.asm"
        INCLUDE "engine/graphics/raycast/raycast.asm"
```

The camera is the game's :

| | |
|---|---|
| `raycast.x`, `raycast.y` | position, 8.8 cells ; cell (0,0) is the map's top left |
| `raycast.angle` | 0-1023 a turn, 0 east (+x), 256 south (+y) |

Entries (A, B, X, Y, U and CC lost ; the cart page is given back) :

| entry | |
|---|---|
| `wallscaler.background` | the view of the buffer in the data window to the empty room. Both buffers, before the first frame |
| `raycast.cast` | the camera's view to the column descriptors |
| `wallscaler.draw` | the descriptors drawn in the back buffer |
| `raycast.move` | B = a step along the camera's direction, signed, in 1/256 cell : the camera moves where the map lets it and slides along a wall |

A frame, in the loop's gfxlock section :

```
loop    _gfxlock.on
        ; the game : raycast.angle, raycast.move
        jsr   raycast.cast
        jsr   wallscaler.draw
        _gfxlock.off
        _gfxlock.loop
        bra   loop
```

A frame takes 3 to 9 VBLs : move the camera by the VBLs gone since the
frame before, not by the frame.

A **column descriptor** is 6 bytes, left to right in
`wallscaler.descriptors` : the scaler's page (`$E7E6` value), the wall's
top row in the view, the texture column's address, the scaler's address.
`wallscaler.draw` runs with S on the descriptors and overwrites them : read
them between the cast and the draw. Any code that writes descriptors can
call `wallscaler.draw` without the raycaster ; a scaler is exported as
`wallscaler.h<rows>`.

## Costs

Under toje, `examples/wallscaler`, 16 cameras, the 50 Hz interrupt
included.

| | 80 x 200 | 64 x 128 | 64 x 128, `lines` 1, `pair` false, `fov` 90 |
|---|---|---|---|
| scalers | 64 472 bytes, 4 pages | 27 952, 2 pages | 38 374, 3 pages |
| raycaster's unit | 6 925 bytes | 6 605 | 7 021 |
| columns unit, a half | 2 853 bytes | 2 101 | 2 101 |
| `raycast.cast`, cycles | 44 400 (34 300 - 55 400) | 36 400 (27 700 - 46 200) | 50 500 (42 300 - 57 900) |
| `wallscaler.draw`, cycles | 53 500 (26 600 - 109 500) | 33 700 (17 300 - 58 600) | 37 100 (21 100 - 59 300) |
| frames a second | 9.3 (6.2 - 12.5) | 12.1 (10.0 - 16.5) | 10.0 (8.2 - 12.5) |

Whatever the view : the angles 12 288 bytes, a texture 4 096 bytes, the
resident part about 200 bytes plus 6 bytes a column.

A ray : about 700 cycles. A column : 41 cycles plus its scaler, 5 cycles a
row written. A wall that got shorter : about 125 cycles plus 16 a row
uncovered on each side.

## Limits

- BM16, byte columns.
- Textures of 64 x 64, 1 024 angles.
- Flat ceiling and floor ; no sprites, doors or walls of several heights.
- Not measured on a real TO8.

## Tests

- JUnit, `toolbox/graphics/raycast` : every scaler of four views run by an
  interpreter of its instructions ; the scalers' sizes against lwasm ;
  `RayModel`, the raycaster in fixed point, which the 6809 code follows.
- `python3 ci/toje-bench/bench.py examples/wallscaler` : 33 tests a disk,
  three views. `BenchReferenceTest` makes the bench's sums from `RayModel`.
