# An imageset bigger than a page is spread, and its index carries a page per image

> **Update (2026-08-12).** The `<pageset>` element this case uses was retired
> with the single-sort placement (5c) : its behaviour — whole if it fits, cut
> between elements if it cannot — is now what any arena `<file>` gets by
> default, and the explosion's images are ordinary arena files. The account
> below is kept as written : the two-element split (compile vs index) and
> the page-per-image index are unchanged, only the spelling of the spread
> declaration moved. Current form : [sprites.md](../sprites.md) § When the
> code outgrows a page.

## Symptom

```
ERROR | DirEntryPlugin > data size 17881 is over maxsize: 16384
ERROR | Target > target fd failed : 1 output file(s) removed
```

The object is fine, the images are the ones v1 declares, and the build stops
dead. R-Type's explosion is 13 compiled sprites — five of them 24×48 — which
come to 17 881 bytes. No page holds that.

Trying to put the images in a `<pageset>` hits the next wall:

```
<gfxcomp genindex> cannot be packed into pages
```

## The v1 idiom

v1 had no such limit, and not because its sprites were smaller. Its imageset
descriptor carries **a page byte per image**, right before the address of the
drawing routine. `explosion_ImageSet.lst`, four consecutive frames:

```
Img_expFwk_3   fcb $07,$07,$07,$07,$0B,$15,$01,$06,$00,$00,$00,$FB,$F6,$75
Img_expFwk_5   fcb $07,$07,$07,$07,$0B,$14,$01,$06,$00,$00,$00,$FB,$F7,$72
Img_expFwk_1   fcb $07,$07,$07,$07,$09,$0D,$01,$06,$00,$00,$00,$FC,$FB,$6E
Img_expFwk_0   fcb $07,$07,$07,$07,$05,$0A,$01,$06,$00,$00,$00,$FF,$FC,$6C
```

`$75`, `$72`, `$6E`, `$6C` — four frames of one animation, four different
pages. v1's allocator placed the compiled code wherever it fitted and patched
the page into the descriptor, so the author never chose. Only the descriptors
themselves stayed together, in the object's own page.

That grouping is not an accident of v1's allocator, it is a runtime constraint
that v2 has too: `CheckSpritesRefresh` mounts `Img_Page_Index[id]` before
dereferencing `image_set,u`. **The index must fit in one page. The code must
not have to.**

## The v2 model

v2 had kept the first half of that and lost the second. `ImageSet` emitted one
relocation, `<file>$PAGE`, for the whole set — true only while every image is
compiled into the same unit — and the pageset guard said so out loud.

The road out was already built, for tilesets:

| Piece | Already used by |
|---|---|
| `<pageset>` — declare a page budget and a content, the builder measures, packs first-fit and emits one direntry per page | 244 even tiles over 3 pages, 303 odd over 5 |
| `StaticLink.pageOf(symbol)` — the page a given symbol landed on | every entry of both map tables |
| a `.static` section — references baked at build time, zero link data | `stage1.maps`, 1059 references |

`TilemapPlugin` already emitted exactly the shape an imageset needs, three
bytes per entry: `fcb map.RAM_OVER_CART+<page of this tile>` then
`fdb adr_<tile>`. The javadoc of `pageOf` even named the missing consumer —
"a generator that emits a page byte per entry — a tilemap, **an object
index**".

So compiling and indexing become **two elements**. `<gfxcomp imageset="...">`
compiles and hands over the geometry it measured; `<imageset>` writes the index
from it, asking the placement registry for each image's page, one by one. The
declaration is not duplicated: the second element names the first.

## The fix

```xml
<region name="explosion"        page="$14" address="$0000" size="$1000"/>
<region name="explosion.images" page="$15" address="$0000" size="$4000" pages="2"/>
...
<!-- the code : spread, the builder chooses -->
<pageset name="explosion.images" region="explosion.images"
         gendir="gen/fx/explosion-pages" loadtimelink="LINK">
    <gfxcomp gendir="gen/fx/explosion"
             gensource="gen/fx/explosion/includes.asm"
             imageset="explosion">
        <image name="expBig_0" filename="…/blast_big_0.png" index="8">
            <encoder name="bdraw" mirror="none" shift="0"/>
        </image>
        …
    </gfxcomp>
</pageset>

<!-- the object and its index : one page, the one Img_Page_Index mounts -->
<direntry name="common.explosion" loadtimelink="LINK">
    <lwasm gensource="gen/fx/explosion.asm">
        <asm filename="src/common/fx/explosion/explosion.asm"/>
        <imageset name="explosion" gensource="gen/fx/explosion/index.asm"/>
    </lwasm>
</direntry>
```

Order matters, and for the same reason it matters for a tilemap: the images
must be declared **before** the index that resolves their pages. Both `<load>`s
go in the scene, the pageset by its set name.

`<imageset>` joins the unit's `code` section ; with `bake="auto"` (or `all`)
on the direntry, the addresses are baked too
and the whole set costs no link data.

## Proof

The generated index, 26 page bytes for 13 images (draw + erase):

```
$ grep -oE 'fcb   \$7[0-9A-F]' gen/fx/explosion/index.asm | sort | uniq -c
  24 fcb   $75
   2 fcb   $76
```

which is exactly what the packing reported:

```
DirEntryPlugin > file explosion.images.0 | 14875 bytes
PageSetPlugin  > pageset explosion.images page 21 : 24 parts
DirEntryPlugin > file explosion.images.1 |  2501 bytes
PageSetPlugin  > pageset explosion.images page 22 : 2 parts
ImagesetPlugin > imageset explosion : index generated in section code.static
LwObject       > explosion.obj : 26 references resolved statically in section 'code.static'
DirEntryPlugin > file common.explosion |   505 bytes
```

Two frames of one animation on two different pages, each descriptor carrying
its own — the v1 shape, restored.

On the machine: a pata-pata's hit potential forced to zero under toje, the
explosion draws at its position and animates through its frames, and the object
deletes itself. The twelve example configs rebuild **byte for byte identical**,
the road outside `<imageset>` being untouched.

## Met in

R-Type v2, 2026-08-03, porting the explosion object. The alternative considered
and rejected was splitting the object in three — one per image family — which
would have fitted in pages without any builder work, at the cost of cutting
`exp.animations` in three and touching all twenty call sites that name
`ObjID_explosion`. The capability is reusable; the split would have been paid
again by the boss, whose sprites are larger still.
