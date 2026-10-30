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
