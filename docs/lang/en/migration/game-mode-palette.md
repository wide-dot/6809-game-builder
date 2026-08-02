# A palette comes from the game mode, not from the artwork

v1 declared palettes explicitly in the game mode's properties. Port those
declarations. Do not point `png2pal` at a tile or map image and assume the
colours are the same.

## Symptom

The game runs, the artwork is recognisable, and the colours are wrong — often
spectacularly, because an unused index in the tile image becomes the background
and paints the screen magenta or cyan.

It is easy to miss for the opposite reason too: a tile palette usually contains
*most* of the right colours, so the screen looks plausible and only the entries
no tile happened to use are wrong. Those are exactly the entries used by
sprites, the hud and the border.

## The v1 idiom

Palettes were named resources of the game mode, each from its own PNG:

```properties
palette.Pal_game=./game-mode/01/images/pal.png
palette.Pal_tunnel=./game-mode/01/images/pal-inside.png
palette.Pal_black=../../engine/palette/color/Pal_black.png
palette.Pal_messages=./objects/messages/images/messages.png
```

`pal.png` is not artwork. It is a 16-entry swatch, authored as the level's
palette, and the tiles were drawn against it. The distinction matters: the
tiles are a *consumer* of the palette, not its definition.

## The v2 model

`<png2pal symbol="…" filename="…"/>` inside the direntry that needs it. The
mechanism is equivalent; only the declaration site moved. The trap is purely
that the config asks for a filename and any PNG will produce *a* palette.

## The fix

Point it at the swatch:

```xml
<!-- The GAME palette, not the tiles' : this is v1's palette.Pal_game
     (game-mode/01/images). The map PNG only carried a subset. -->
<png2pal symbol="Pal_stage" filename="src/stages/01/palette/pal.png"/>
```

Check the v1 project for the swatches before assuming they are missing — in
r-type all five had already been copied to `src/stages/01/palette/` during an
earlier import and simply were not referenced.

A stage with no swatch of its own keeps whatever it was given; say so in a
comment rather than silently pointing it at artwork.

## Proof

Compare a screenshot against the v1 emulator, or against reference footage.
The background is the fastest tell: r-type level 1 is black, and the tile
palette produced magenta.

Do this **after** fixing anything that affects timing or scrolling, not before.
A wrong palette and a desynchronised scroll look alike at a glance, and fixing
one while the other is outstanding gives no clean signal — see
[what the bench distorts](#a-warning-about-benches) below.

## A warning about benches

A test bench may deliberately run the game off its real values, and a comment
saying so is easy to skim past. r-type's stage-exchange bench scrolled at
`$0200` instead of the game's `$0030` — sixteen times too fast — to cross a
level within its frame budget.

That is defensible for what the bench measures, and ruinous for anything else:
wave timestamps are arcade frame counts calibrated against the real scroll
speed, so at bench speed enemies appear against the wrong scenery, and no
observation of an enemy means anything.

When you start judging *gameplay* rather than the bench's own witnesses, put
the real values back.

## Met in

`games/r-type`, 2026-08-02. `Pal_stage` had been pointed at
`src/stages/01/map/intro/even.png`, the tile image.
