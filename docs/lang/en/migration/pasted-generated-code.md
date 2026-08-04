# Generated code pasted into a v1 file goes back through the pipeline

## Symptom

A v1 object carries hundreds of lines of sprite drawing code, and its
`.properties` has the matching `sprite.` lines **commented out**, with a note :

```properties
# temporary image (used to generate code, should be commented because replaced by the code, see above)
#sprite.Img_hud_0=./objects/levels/hud/images/0.png;ND0
```

The PNGs are still there. Nothing regenerates them. Retouching a digit means
re-running a generator by hand, pasting the output back, and hoping nobody
notices the two got out of step — which, in R-Type's HUD, is exactly what had
happened : `images/0.asm` on disk wrote colour `$04`, while the pasted copy
wrote `$01`.

## The v1 idiom

This is not laziness, it is a missing option. The generator's drawing code
reaches the second video plane through `glb_screen_location_1` and **consumes
U** walking the first :

```asm
	STA ,U
	LDU <glb_screen_location_1     ; U is now the other plane, and gone
	...
	RTS
```

That is right for a sprite drawn once at a computed position. It is wrong for a
HUD, which draws a **row** — twelve digits, advancing one byte between them :

```asm
	jsr   DRAW_Img_hud_b
	leau  1,u                      ; the caller's cursor over the row
```

With U consumed, the caller would have to reload the plane pointer twelve times
per frame. So the author generated the sprites once, hand-edited them to switch
planes by a constant offset and give U back, and pasted the result in. The
`.properties` lines were commented so the pipeline would not overwrite the
edit.

## The v2 model

The v2 encoder takes the calling convention as a parameter, so the hand edit
becomes a declaration :

```xml
<encoder name="draw" mirror="none" shift="0" planes="offset"/>
```

| `planes` | second plane | U on exit |
|---|---|---|
| `pointer` *(default)* | `glb_screen_location_1` | consumed |
| `offset` | `U − planedistance` | **given back** |

`planedistance` is a `<gfxcomp>` attribute defaulting to 8192 — the distance
between the two halves of the TO8 video window. It is a machine constant, not a
property of the image, and not derivable from the geometry the compiler already
knows, so it is declared rather than guessed.

An imageset is **not** required : `genindex` is optional, and a HUD indexes
nothing — it calls its sprites by name. The unit bridges the naming, as it does
elsewhere for `Img_` → `set_` :

```asm
DRAW_Img_hud_0 equ adr_hud_0_ND0
```

## The fix

Delete the pasted routines, declare the images, bridge the names. For R-Type's
HUD that removed 306 lines from `hud.asm` and eleven stale `.asm` files.

## Proof

Measure before deleting — that is the whole method here. Compile each PNG with
the new option and compare against what is pasted :

```
  DRAW_Img_hud_0         IDENTIQUE (20 inst.)
  DRAW_Img_hud_4         meme multiensemble, ordre different (21 inst.)
  ...
8 identiques, 4 a l'ordre pres, sur 12
```

Eight sprites byte for byte ; four differing only in the order of *disjoint*
write groups — the encoder's ordering search, which is seeded and reproducible
but has no reason to match a hand-pasted output. None diverged, which also
settled the question the measurement was really there to answer : **the PNGs
were not stale**. The stale files were the generated `.asm` next to them.

On the machine, the two builds render the same screen — compared pixel by
pixel, `getbbox()` on the difference returns `None`. The unit came out at
exactly 5 184 bytes both ways.

## A trap worth naming

The attribute plumbing is not covered by a unit test that calls the encoder
directly. The first build after the feature silently used the default : the
`planes` attribute had never been read, because the edit that wired it into the
plugin did not apply. Every test still passed — they construct the encoder
themselves and never go through the configuration.

What caught it was the generated file : `grep LEAU gen/…/hud_0_ND0.asm` showed
`LDU <glb_screen_location_1`. When an option changes emitted code, **read the
emitted code once** before believing the option arrived.

## Met in

R-Type v2, 2026-08-04, porting the HUD.
