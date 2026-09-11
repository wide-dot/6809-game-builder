# A per-frame loop is a multiply

The v1 compensates the frame drop by **replaying** the frame's work once per
elapsed frame : a loop over `gfxlock.frameDrop.count`, and inside it the
per-frame arithmetic as it was written for 50 Hz. It reads naturally and it
is exact, but it costs the loop body times the drop, on every object, at
every render.

## Symptom

A stage that renders every nine frames pays nine times the per-frame work of
every mobile object and every enemy that can fire. Measured at the belly of
the R-Type stage 3 warship (2026-09-10, `games/r-type/doc/profil-boucle-stage3-2026-09.md`) :
a small turret's tick was 710 cycles, 243 of them in `tryFoeFire` — and the
fire decision itself is a dozen instructions. The rest was the loop that
advanced its fire clock one frame at a time.

## The v1 idiom

```
        ldx   gfxlock.frameDrop.count_w
@loop   ldd   x_pos+1,u
        addd  x_vel,u                  ; one frame of velocity
        std   x_pos+1,u
        ...
        leax  -1,x
        bne   @loop
```

and, for the fire clock :

```
        ldd   fireCounter,u
        ldx   gfxlock.frameDrop.count_w
!       addd  #1
        cmpd  #threshold
        beq   fire
        cmpd  fireReset,u
        bhs   fireAndReset
        leax  -1,x
        bne   <
        std   fireCounter,u
```

## The v2 rule

When the loop body has no per-frame side effect — no clamp, no collision, no
branch that depends on the intermediate value — the k iterations are one
operation :

- a **constant velocity** integrated over k frames is `velocity * k` : two
  unsigned `mul` per axis on the 8.8 velocity, the product truncated as a
  two's-complement 16-bit value (the calculation of `bullet.AddPos` and
  `layer.AddPos` in R-Type), added once. Same positions to the bit ; about a
  hundred cycles whatever the drop. `engine/object-management/ObjectMoveSync.asm`
  does this since 2026-09-10 (a recorded deviation of the 1:1 import).
- a **counter with a threshold** advances by k, and the tests become
  interval tests : the threshold fires if it lies in `(counter, counter + k]`
  — the counter stops there, the remaining frames of the tick are lost as
  they were in the loop — else the reset fires if `counter + k` reaches it.
  `tryFoeFireCommon` (`src/common/lib/projectile.asm`) and the Bug manager's
  fire clock do this.

When the body **does** have per-frame side effects (the force pod's tracking
clamps, `mscroll.move`'s clamped camera, a script stepped frame by frame),
the loop stays : it is the semantics, not a compensation.

## What it is worth

Every mobile object and every firing enemy of the game, at every render :
200 to 300 cycles each. The stage 3 belly, with fourteen turrets, gets
3 000 cycles back on the fire clocks alone.
