# A hand edit of a generated map is data — declare it, or regeneration loses it

## Symptom

The build chain regenerates a level's tilemaps from the level picture
(`<leanscroll>`), and the produced map differs from the shipped v1 map by a
few cells : stage 1's maps read `0` (draw nothing) at column 48, rows 6-8,
where the v1 maps read `1`. The level picture offers no way to tell — those
cells are plain background there, the same palette index as every other
empty cell.

## The v1 idiom

v1 ran the map cutter by hand and committed its outputs. That made the
generated map EDITABLE : when a data fix was needed, the author patched the
committed `.bin` directly. Stage 1 carries exactly one such fix — the
horizontal band at screen centre is not refreshed by the scroll from the
same blocks as at stage start, and a checkpoint restart repaints the
playfield from the map ; without the fix the whole stage would have to be
scrolled through again. So three cells were hand-bound to tile 1 (a drawn,
mostly-transparent tile) to keep the scroll repainting them.

Nothing marks the edit : it lives only in the committed binary, invisible
next to the picture it was generated from. The regeneration is *correct*
against the picture — and silently drops the fix.

## The v2 shape

The fix is authored DATA, so it is declared where the chain runs :

```xml
<leanscroll image="src/stages/01/map/in.png" gendir="gen/stages/01/map"
            gensymbols="gen/stages/01/map/map.const.asm"
            refresh="48:6-8"/>
```

`refresh=` lists cells (as `<col>:<row>` or `<col>:<rowFirst>-<rowLast>`)
that must stay DRAWN although the lean would empty them : each is bound to
the set's first tile, exactly what the v1 hand edit did. The declaration is
visible, survives every regeneration, and the reader learns WHY from the
comment beside it — three things the binary patch could not offer.

## How it was found

The 7c chain replaced the committed maps with regenerated ones ; the
identity harness flagged a 6-byte residue on stage 1. A rendering of the
divergent zone showed the source picture carries nothing distinctive there
(background, borders and the divergent cells are all one palette index),
which ruled out an art marker and pointed at a direct map edit — confirmed
by the author, with the checkpoint rationale. With `refresh=` declared, the
whole disk image returns byte-for-byte to the shipped hash.

## The general rule

A committed generated file invites hand fixes that regeneration destroys.
When a chain is absorbed by the build, every difference between the
committed output and the regenerated one must be adjudicated : an artifact
of an old tool version can be dropped, but an unexplained residue may be an
UNDECLARED authored decision — surface it to the author before adopting
either side. The fix, once understood, becomes a declared input.
