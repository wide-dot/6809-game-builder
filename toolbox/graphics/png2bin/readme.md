/[index]/[toolbox]/png2bin

[index]: ../../../readme.md
[toolbox]: ../../../docs/toolbox.md

# png2bin
## Description

Converts an indexed PNG to video memory data. In a `config.xml`, the
`<png2bin>` element yields **one plane** (declare it once per plane) ; its
attributes are declared in `Handlers.java` and in
`docs/schema/gamebuilder.xsd`.

## Keeping a plane compressed : `codec`

`codec="none"` (the default) stores the plane's bytes as they are.
`codec="zx0"` stores them as one zx0 stream that **stays compressed in RAM** :
the file is loaded as is, and the game decompresses it where and when it
wants the picture (a title card into the back buffer, for instance). The
stream is the loader's classic format, forward, without the in-place byte
the loader prepends to its own entries, so any of `engine/compression/zx0/`
reads it :

```xml
<png2bin filename="card.png" videomode="bm4s" plane="0" codec="zx0"/>
<png2bin filename="card.png" videomode="bm4s" plane="1" codec="zx0"/>
```

```asm
        ldx   #card                 ; the first plane's stream
        ldu   #$C000                ; where it goes
        jsr   zx0_decompress        ; X ends on the second plane's stream
        ldu   #$A000
        jsr   zx0_decompress
```

What it buys is RAM : a 320x200 title card of two 8 000-byte planes is
about a third of that compressed. What it costs is the decompression at
show time. An unknown codec is a named build error. The compression is
cached (`.builder-cache`, domain `png2bin-zx0`) like the loader's entries.

## A full screen picture : `buffer="fullscreen"`

`buffer="fullscreen"` turns a 160x200 BM16 picture into the 16 000 bytes
`engine/graphics/draw/DrawFullscreenImage.asm` copies into the data window.
The routine pulls 7 bytes with `PULU` and pushes them with `PSHS`, from the
end of a bank down to its start : the data holds each bank's 7-byte blocks
from the last to the first, the `$C000` bank (pixels 0-1 of each four) first,
then the `$A000` bank. Both planes are in it, so it is declared once, plane 0 ;
another size or video mode is a named build error. v1 wrote the same bytes
(`PngToBottomUpB16Bin`, an act's `backgroundImage`).

```xml
<file name="assets.image" page="$05" address="$0000">
    <png2bin filename="src/picture.png" gendir="gen/assets/picture"
             videomode="bm16" buffer="fullscreen" plane="0"/>
</file>
```

```asm
image   fcb   map.RAM_OVER_CART+assets.image.page
        fdb   assets.image.address

        _ram.data.set #2            ; the buffer written
        orcc  #$50                  ; the copy pushes through S
        ldx   #image
        jsr   DrawFullscreenImage
        andcc #$AF
```

The copy costs about 58 000 cycles (lwasm listing : 152 cycles per 42 bytes,
two banks), nearly three frames. The bench : `examples/fullscreen`.
