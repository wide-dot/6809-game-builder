# A frame-drop timer carries its overshoot

A Mega Drive or arcade timer counts down once per frame and reloads when it
goes past zero. Compensated for the frame drop, it counts down by the frames
elapsed ; the frames it went past zero belong to the next period, and the
reload has to keep them — exactly them.

## Symptom

Animations run fast, by a margin that grows with the frame drop : at one
frame per loop an image of a five-frame period lasts four ; at three frames
per loop, one. Where an image needs more than one loop, the counter drifts
down, loop after loop, until the byte wraps positive and the animation
freezes for a hundred loops — Sonic 2's legs stopped at full speed, then
ran again, then stopped.

## The v1 idiom

`AnimateSpriteSync` (v1 `engine/graphics/animation/AnimateSpriteSync.asm`) :

```
@Anim_Run
        ldb   anim_frame_duration,u
        subb  gfxlock.frameDrop.count       ; c' = duration - n
        stb   anim_frame_duration,u
        bpl   @Anim_Rts
@b      ldb   -1,x                          ; D, the script's duration
        addb  anim_frame_duration,u         ; D + c'
        subb  gfxlock.frameDrop.count       ; D + c' - n : n taken twice
        stb   anim_frame_duration,u
        bpl   @Anim_Reload
        clr   anim_frame_duration,u
```

and its load, `bra @b` after a change of animation : D plus the duration the
previous animation left, minus the drop.

The same `D + c'` was written by hand in Sonic 2's own timers (`SAnim_*`,
`Obj08_SkidDust`), one frame short.

## The v2 rule

The original reloads D on reaching -1 : an image lasts D+1 frames. With c'
the counter after the drop is taken (negative, the frames past -1 being
`-1 - c'`), the next period starts with

```
        D + 1 + c'
```

clamped at 0 : one image per call at most, since one image is displayed per
loop — beyond that the timer stays between 0 and D instead of drifting.

A newly loaded animation starts on the current frame, whatever the drop :
the frames before the call belonged to the previous animation. Its first
image lasts D+1 frames counting this one : the duration is D, the original's
reset to 0 then decrement.

At one frame per call `AnimateSpriteSync` is then `AnimateSprite`, the
original's routine ; at n frames per call it is n calls of it, as long as a
loop is no longer than an image (`examples/objects`, T13 and T19).

## Met in

Sonic 2, 05/10/2026 : the review of Emerald Hill against s2disasm found the
game's timers one frame short and drifting ; fixed in the game's code, then
in `AnimateSpriteSync` (V2-DEVIATION). r-type's animations run on it : each
image now lasts its script's duration plus one frame, where v1 played it n+1
frames short — at a typical drop of 2 to 3, an image of duration 3 goes from
1 frame to 4. A script tuned by eye against v1 shows it.
