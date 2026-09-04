# AABB screen projection: the whole box stays inside the byte

## Symptom

A shot fired out of one side of the screen kills enemies on the other side.
An enemy with a wide box gets hit by a shot at the far end of the screen.
Seen in `games/r-type` after the swept hitboxes of 31/08/2026; the
mechanism was latent since v1.

## The v1 idiom

Every object writes its hitbox centre, each tick, as the low byte of a
signed 16-bit screen offset, with a fixed radius:

```
        ldd   x_pos,u
        subd  glb_camera_x_pos
        stb   AABB_0+AABB.cx,u
```

`Collision_Do` compares centres **on one byte, modulo 256**:
`(cx_u − cx_x) + R ≤ 2R` unsigned. It is 34 cycles per axis and per pair in
an O(n·m) loop, and it is kept 1:1. It was reasonable in v1: nothing armed
ever travelled off-screen, and radii were small.

## The v2 model

Two centres 250 px apart have a distance of 6 and touch as soon as R ≥ 6.
The kernel *cannot* tell `x − camera = −20` from `+236`: the information is
lost at the projection. The v2 game breaks the v1 assumptions twice:

- the basic shot and the beam carry a **swept box** (rear edge at the
  previous frame's frontier, front edge at the current one), so the radius
  reaches 27 px at the frame-drop cap of 8;
- armed objects now leave the screen on both sides (rear-mounted force pod,
  rebound laser living 64 px past the left edge, enemies leaving to the
  right).

Clamping the *centre* into `[0,255]` is not enough — a centre pinned at 0
with a radius of 27 still puts the box's rear at −27, which the kernel reads
as 229. The invariant that matters is: **the whole box, `[cx − rx, cx + rx]`,
stays inside `[0,255]`.** For a swept box that means reasoning in **edges**,
clamping them, and only then converting to centre and radius.
Analysis: `games/r-type/doc/analyse-wrap-boites.md`.

## The fix

`AABB.spanX` (`engine/collision/aabb-span.asm`, resident, exported through
`api.asm`): D = front edge, X = rear edge (both signed 16-bit screen
offsets), Y = the box. Both edges are clamped into `[0,255]`, the box spans
between them, the front edge is kept exact and an odd length rounds inward
at the rear. Both directions are served — the front may be left of the rear
(a leftward shot); the register *roles* tell the routine which edge is the
front.

```
        ldd   weapon.sweepFrom         ; previous position (world)
        subd  glb_camera_x_pos
        addd  #3                       ; the previous frontier
        tfr   d,x                      ; X = rear edge
        ldd   x_pos,u
        subd  glb_camera_x_pos
        addd  #3                       ; D = front edge
        leay  AABB_0,u
        jsr   AABB.spanX               ; cx, rx written, inside the byte
```

Fixed-radius objects are the second half of the rule, still to convert: the
centre must be clamped into `[rx, 255 − rx]`, not `[0, 255]`. The kernel's
two copies (`wctk_overlap`, `gl.hitEnemies`) need no change once the boxes
they read obey the invariant.

## Proof

Assembled bytes of the routine and the r-type bench (`ci/toje-bench/
rtype_bench.py`, 7/7) after the conversion of the two swept shooters.

## Met in

`games/r-type`, 03–04/09/2026. Study commit `2e8787cb4`; a first attempt
clamped the centre through a macro (`0db6fccb0`) and was withdrawn the next
morning for the reason above.
