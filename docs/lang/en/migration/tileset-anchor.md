# A tile is anchored top-left — gfxcomp defaults to center

The v2 gfxcomp anchors an image at `POSITION_CENTER` unless the encoder says
otherwise. v1 tileset properties declared `TOP_LEFT` explicitly. Port that
declaration, or every tile in the map draws offset.

## Symptom

The whole scenery sits a few pixels up and to the left of where the engine
thinks it is — at identical camera positions, v2 content is shifted relative to
v1. The visible damage is at the edges: tiles emerge from under the right side
of the playfield mask a few pixels too early, which reads as "artefacts on the
right when tiles appear".

It cannot be a wrong start address: for a 12×12 tile the measured shift was
~5 pixels horizontally, and `DrawTiles` writes byte-aligned — a non-multiple-of
-4-pixels offset cannot come from `start_pos`. The offset is *inside the
compiled tile code*.

The measurement that pinned it, worth reusing: run v1 and v2 to the **same
camera position** (read `glb_camera_x_pos`, `$9FE6`), screenshot both under
toje, then 2D-correlate a scenery band (HUD excluded — it is screen-fixed and
must align at zero). Before the fix: best match at `(-5 px, -5 lines)`,
99.7 %. After: `(0, 0)`, 99.7 %.

## The v1 idiom

The tileset line in the object properties carried the anchor explicitly:

```properties
tileset.Tls_lvl01=./map/0/0.png;245,1,245,TOP_LEFT,./map/0/0.0.bin,16
```

## The v2 model

The anchor is per-encoder, and the default is `center`
(`GfxcompPlugin.java`: `Attribute.getString(child, ctx, "position",
Image.POSITION_CENTER)`). For a 12×12 tile, center rewinds the write origin by

```
coordinate = (ceil(12/2)-1)*40 + 12/8  =  5 lines + 1 byte
```

— exactly the measured shift. Center is the right default for *sprites*, whose
hotspot is their middle; a tile consumed by `DrawTiles` must be `top-left`.

Note the schema: `position` is an attribute of `<encoder>`, not `<image>` —
the validator refuses it on `<image>`.

## The fix

```xml
<image name="tilesEven" filename="src/stages/01/map/intro/even.png" grid="12x12">
    <encoder name="draw" mirror="none" shift="0" position="top-left"/>
</image>
```

One line per tileset encoder — even and odd planes, every stage.

## Proof

The camera-matched correlation above, back to `(0, 0)`. Visually: tiles are
born under the mask edge, as in v1.

## Met in

`games/r-type`, 2026-08-02. Found by comparing against the v1 build running
under the same emulator, after chasing it as a viewport-offset bug — the
viewport parameters were all correct.
