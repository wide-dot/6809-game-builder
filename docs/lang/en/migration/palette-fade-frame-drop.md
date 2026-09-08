# The palette fade counts rendered frames, not time

**v1 idiom.** `PaletteFade` (`engine/objects/palette/fade/fade.asm`) steps
every colour one unit toward its target each time its wait counter
(`o_fade_wait`, in frames) runs out, and the counter is decremented **once
per call** — once per main-loop iteration, that is once per *rendered*
frame. On a level that renders every frame the two are the same thing.

**What breaks in v2.** R-Type's stages render at 8 to 12 images per second
under frame drop. A fade armed with a wait of 15 then steps every 15
*rendered* frames, about 90 video frames, and a 16-step fade to black
takes ~1 400 video frames instead of 240. Any fade meant to match a
timed sequence — here the Gomander's death, where the arcade blacks out its
tile palette in 31 steps every 8 frames while the death countdown runs —
lands far too late, long after the sequence it was supposed to dress.

The fades already in the game (stage entry, wait 4 ; checkpoint reload,
wait 1) have the same bias, but nothing waits on them, so nobody noticed.

**v2 resolution.** An opt-in *compensated* mode. A new OST byte,
`o_fade_drop` (`ext_variables+16`): when non-zero, each call consumes
`gfxlock.frameDrop.count` video frames (one when the count is zero) and
performs as many steps as the wait allows within them — the same
compensation as every other timed thing in the loop. When zero, the code is
strictly the v1 behaviour; the static `palettefade` OST is born zeroed and
the stage's own fade-in/out helpers clear the byte explicitly, so existing
callers are unchanged.

Callers that time a fade against the game clock set the byte
(`stage.deathFadeOut`, `endlevel`'s `ReadoutFadeIn`). The wait is then in
video frames: 15 gives 16 × 15 = 240 frames for the arcade's 248, 8 gives
128 for its 124.

**How to recognise it elsewhere.** Any v1 object whose timing is a plain
`dec counter` per call is a per-rendered-frame timer. It only matters when
something else — an arcade countdown, a music cue, another object — expects
the effect to land at a given frame.
