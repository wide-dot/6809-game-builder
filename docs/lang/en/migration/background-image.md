# A v1 act's `backgroundImage` becomes `<png2bin buffer="fullscreen">`

v1 converted an act's background picture into the 16 000 bytes
`DrawFullscreenImage` copies, inside its builder. v2 has the routine (imported
1:1, `engine/graphics/draw/DrawFullscreenImage.asm`) and the conversion as a
`png2bin` buffer. Port the declaration ; do not write the bytes with a script.

## The v1 idiom

An act names its picture in the game mode's properties :

```properties
act.default.backgroundImage=./game-mode/00/image/nebuleuse.png
```

and the builder (`PngToBottomUpB16Bin`) writes the picture's bytes, places
them, and generates `Bgi_<act>` : the page and address the game mode hands to
`DrawFullscreenImage` in X.

## The v2 model

The picture is a file of its own, the conversion a `png2bin` element :

```xml
<file name="assets.image" page="$05" address="$0000">
    <png2bin filename="src/picture.png" gendir="gen/assets/picture"
             videomode="bm16" buffer="fullscreen" plane="0"/>
</file>
```

and the game mode writes the parameter itself, from the file's generated
symbols :

```asm
image   fcb   map.RAM_OVER_CART+assets.image.page
        fdb   assets.image.address

        ldx   #image
        jsr   DrawFullscreenImage
```

The bytes are v1's, byte for byte (`FullscreenTest` runs v1's conversion loop
on the same pixels). `buffer="fullscreen"` holds both planes : it is declared
once, with plane 0.

## What happened before this case

Sonic 2's special stage (`wide-dot/sonic-2`) needed the v1 bytes before the
buffer existed, and wrote them with a Python port of `PngToBottomUpB16Bin` in
its generator. That is the trap this case closes : a transformation between a
committed source and what the game loads belongs to the builder (the review
grid's first point), not to a script run before the build.
