# AABB screen projection: clamp the centre, never let it wrap

**v1 idiom.** Every object writes its own hitbox centre, each tick, as the
low byte of a signed 16-bit screen offset:

```
        ldd   x_pos,u
        subd  glb_camera_x_pos
        stb   AABB_0+AABB.cx,u
        ldb   y_pos+1,u
        stb   AABB_0+AABB.cy,u
```

`Collision_Do` then compares centres **on one byte, modulo 256**:
`(cx_u − cx_x) + R ≤ 2R` unsigned. Two centres 250 px apart have a distance
of 6 and touch as soon as R ≥ 6. Any armed box left of the screen
(`x − camera = −20`) is indistinguishable from one at `+236`, sixteen pixels
inside the right edge. The kernel is 34 cycles per axis and per pair, in an
O(n·m) loop; it is kept as is (the v1 file is 1:1), and it *cannot* tell the
two cases apart — the information is lost at the projection.

The v1 game never tripped over it because nothing armed travelled left. The
v2 game does (rear-mounted force pod, rebound laser living 64 px past the
left edge, enemies leaving to the right past 255): shots fired out of one
side killed enemies on the other. Analysis:
`games/r-type/doc/analyse-wrap-boites.md`.

**v2 idiom.** Compute the centre in 16 bits and clamp it into `[0, 255]`
at the very end, with the macros from `engine/collision/macros.asm`:

```
        ldd   x_pos,u
        subd  glb_camera_x_pos         ; D = signed screen offset
        _AABB.setCx AABB_0             ; cx = D clamped into [0,255]
        ldd   y_pos,u
        _AABB.setCy AABB_0
```

A centre below 0 is pinned to 0, above 255 to 255: an object gone left stays
left, far from everything on screen, and real adjacencies (an enemy at −3
against a shot at +2) are still contacts. The common case costs ten cycles
(`tsta`, `beq`, `stb`). When a site derives the centre from other quantities
(a swept segment: back + half length), keep every intermediate on 16 bits
too — pushing `d`, not `b` — so the clamp sees the true value.

The macro is the *only* sanctioned way to write `AABB.cx`/`AABB.cy`. Sites
are converted progressively; the first two were the basic shot and the beam
(`games/r-type/src/common/weapons/{weapon/obj,beam/beam}.asm`, 03/09/2026).
The remaining raw sites (`grep 'stb.*AABB\.c[xy]'`) are the backlog.

**Not a fix for the kernel's two copies.** `wctk_overlap`
(`src/common/lib/weaponcollide.asm`) and `gl.hitEnemies`
(`obj_groundlaser.asm`) reuse the same byte-wide test; they are covered by
the same rule as soon as the boxes they read are projected through the
macro.
