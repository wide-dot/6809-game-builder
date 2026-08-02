# Generated draw code carries no absolute address

A v1 compiled sprite was sometimes hand-edited to hold the screen address it
paints into. In v2 the address is supplied by the caller, and the generated
file is never touched.

## Symptom

You open a v1 generated file to port it and find it starts with a literal
destination:

```asm
        ORG $A000
DRAW_Img_mask_0_0
        LDU #$DF40
        ...
        LDU #$BF40           ; second plane, 754 lines further down
```

and a note in the properties file confirming it was done by hand:

> if you replace the code, put `LDU #$DF40` and `LDU #$BF40` instead of LEAU
> and LDU/LEAU for initial U placement

Both the `ORG` and the literals are incompatible with a relocatable unit, and
editing a generated file by hand means the edit is lost the next time the
generator runs.

## The v1 idiom

The generator produced a *positioned* sprite — one that draws wherever the
caller points it. For a fixed full-screen overlay that indirection was pure
cost, so the two initial pointer loads were replaced with constants. It worked
because the game mode was one absolute image: `$DF40` and `$BF40` were as good
as any other way of naming the back buffer.

## The v2 model

The `draw` encoder emits a routine that takes its destination from the caller,
and there is nothing to patch:

- **`U` on entry** is the base of the first plane. The routine does
  `LEAU 8000,U` and pushes downward from there.
- **`glb_screen_location_1`** holds the base of the second plane; the routine
  reloads `U` from it between planes.

Both bases are fixed addresses — `$C000` for the form plane, `$A000` for the
colour plane. What alternates with double buffering is the **page behind the
`$A000-$DFFF` window**, not the address. That is why the v1 constants worked at
all, and why supplying them from the caller is exactly equivalent.

Note the arithmetic if you are checking a v1 file against a v2 one: `$C000 +
8000 = $DF40` and `$A000 + 8000 = $BF40`. The hand-patched literals were the
post-`LEAU` values.

## The fix

Declare the image in the direntry and let gfxcomp generate it:

```xml
<gfxcomp gendir="gen/overlay"
         gensource="gen/overlay/includes.asm"
         genindex="gen/overlay/index.asm"
         file="common.overlay">
    <image name="playfield_mask" filename="src/common/hud/mask/images/mask.png" index="0">
        <encoder name="draw" mirror="none" shift="0" position="top-left"/>
    </image>
</gfxcomp>
```

The entry is named `adr_<image name>_ND0` and exported by the generated index.
Then set the two bases and call:

```asm
        ldd   #$A000
        std   <glb_screen_location_1
        ldu   #$C000
        lda   #map.RAM_OVER_CART+overlay.page
        ldx   #adr_playfield_mask_ND0
        jsr   paged.call
```

Pick the encoder deliberately. `draw` pushes through `U` and leaves the stack
alone; `bdraw` blasts the stack (`STS glb_register_s` / `LEAS ,Y`) and expects
the sprite protocol with background save. A fixed overlay wants `draw`.

## Proof

Read the generated prologue and confirm there is no `ORG` and no literal
destination:

```asm
adr_playfield_mask_ND0
        LEAU 8000,U
```

Then check the direct-page reference actually assembled as direct, since
`setdp` is neutralised in the obj target and the generator emits a forced `<`:

```
0555 DEF0    LDU <glb_screen_location_1
```

`DE F0` is `LDU <$F0`, which with `DP = $9F` at runtime is `$9FF0` — the right
slot. If your caller runs with a different `DP`, this silently reads elsewhere.

## Met in

`games/r-type`, 2026-08-02, regenerating the playfield mask. The v1 file was
1510 hand-maintained lines; the v2 unit is 2736 bytes generated from
`mask.png`, with nothing to re-patch when the artwork changes.
