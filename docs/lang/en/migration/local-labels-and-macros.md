# Local labels do not survive a macro call

**Symptom.** `lwasm` reports `Undefined symbol @foo` on a branch whose target
is defined a few lines below, in what looks like the same scope.

**Cause.** A `@local` label belongs to the scope of the enclosing non-local
label — but a **macro invocation between the reference and the definition
closes that scope**. The branch then looks for `@foo` in a scope where it was
never defined.

```asm
Live
        beq   @dead                  ; <- ERROR : Undefined symbol @dead
        _Collision_RemoveAABB AABB_0,AABB_list_ennemy   ; <- the macro
@dead   rts                          ; defined here, but in another scope
```

**What it looks like when it bites.** Nothing about the message points at the
macro, and the code reads exactly like the v1 original that assembles fine —
because in the original nothing sat between. It cost two diagnoses on the same
day (23/08/2026): `cytron/obj.asm`, where `_Collision_RemoveAABB` and `_ldd`
sit between the branches and the death labels, and `pellet-grow.asm`, which
mounts a page (`_SetCartPageA`) in the middle of its own error path.

**The fix.** Name the label explicitly — `cytron.dead` rather than `@dead`.
It costs a prefix and it is immune. Prefer this in any routine that mounts a
page, adds a hitbox, or otherwise calls a macro between a test and its target.

**Do not** move the macro instead: the order of a routine should follow what it
does, not what the assembler tolerates.
