# Objects

An object is a slot of RAM plus a routine. The slot holds everything the
engine reads about it — position, velocity, image, render flags, and a
per-object extension area whose shape the game defines. The routine is what
runs once a frame.

The two are joined by an **id**. The object stores its id in the first byte of
its slot, and the engine looks that id up in two tables the game provides:

```asm
Obj_Index_Page                          ; where the object's code lives
        fcb   $00                       ; id 0 : a booked but empty slot
        fcb   map.RAM_OVER_CART+gamemode.page
        fcb   map.RAM_OVER_CART+objects.page

Obj_Index_Address                       ; and its entry point
        fdb   $0000
        fdb   obj.tracer
        fdb   obj.paged.run
```

That indirection is the whole point. `RunObjects` mounts the page named by the
first table before calling the address in the second, so **an object's code
does not have to be resident**. R-Type's level 1 leans on this hard: it pushes
even its collision pass and its end-of-stage sequence out into paged objects
to keep the resident page free.

> v2 has no builder-side object pipeline yet (roadmap item 7): a game mode
> writes these two tables by hand. What has changed from v1 is that the
> addresses can be `EXTERNAL` symbols resolved by the load time linker, and
> the pages come from the declared `<layout>` — so neither is a hardcoded
> number any more.

## The pool

Slots are fixed size and pre-allocated. The game declares how many:

```asm
nb_dynamic_objects           equ 4
ext_variables_size           equ 20     ; per object, the game's own space
Dynamic_Object_RAM           equ $9800
Dynamic_Object_RAM_End       equ Dynamic_Object_RAM+nb_dynamic_objects*object_size
```

`InitStack` fills a stack of free slot addresses, top slot pushed first, so
the bottom slot is handed out first. `LoadObject_u` (or `_x`) pops one and
links it at the end of the run list; it returns with Z set when the pool is
empty, and a game that ignores that gets memory it does not own.

`UnloadObject_u` / `_x` do the reverse: unlink, push the address back, and
**clear the whole slot**. The clearing is not tidiness — slots are recycled,
and a stale id or render flag would make the next occupant inherit a life it
never had.

`ManagedObjects_ClearAll` wipes the pool and both list heads. It does not
reset the free stack, so it is followed by `InitStack`.

## The run list

`RunObjects` walks a doubly linked list from `object_list_first`. Two things
happen inside that walk that the list has to survive.

**An object can delete itself.** The slot it is running from is cleared under
its feet, so the walk cannot read the next pointer out of it afterwards.
`RunObjects` saves that pointer into `object_list_next` *before* each call,
and `UnloadObject_*` updates that saved copy when the object being removed is
the one queued next.

**An object can spawn another.** A child is linked at the end of the list, so
if the parent is anywhere before the end the child runs **in the same pass**.
That is deliberate — it is how a spawner gets its spawn moving on the frame it
appears — but it also means an object that unconditionally spawns never lets
the walk end.

An object whose id is 0 is skipped rather than dispatched: it is a booked
slot, reserved now and given an identity later.

## Calling an object outside the walk

Three ways, in increasing order of what they cost and what they allow:

| what | when |
|---|---|
| `_MountObject` / `_RunObject` macros | from the **resident** page. They expand inline and leave the cartridge page changed. |
| `_Obj_Run*` macros + `Obj_Run.asm` | the same thing as a call rather than an expansion. A site becomes a couple of register loads and a `jsr`, which is why R-Type stage 1 uses them — the resident page is the scarce resource. |
| `RunPgSubRoutine` | from a **mounted** object. It saves the caller's page, mounts the callee's, calls, and puts the caller's page back. Without it, an object calling another one pulls its own code out from under itself. |

## Movement

`ObjectMoveSync` adds the s8.8 velocity to the position **once per elapsed
frame**, reading `gfxlock.frameDrop.count`. A dropped frame is compensated,
not lost. Keep that coupling: R-Type's waves, boss and end-of-stage timings
are calibrated against the arcade original through this counter.

`ObjectDp_Clear` wipes the user direct page up to `dp_extreg`, which it shares
with the engine and therefore leaves alone.

## The bench

`examples/objects` exercises all of the above and writes its verdict to
`$9C00`, loader-ut style. It draws nothing on purpose: an object deleting
itself mid-walk, or spawning a child mid-walk, leaves nothing on screen to
look at, so the only way to assert it is to trace it and read the trace back.

Twelve checks, including both list edge cases, a paged object that reports a
byte existing only in its own unit (so a missing mount cannot pass by
accident, and neither can a stale one), and the subpixel arithmetic of
`ObjectMoveSync`.

It earned its place on its first run: **`UnloadObject_x` did not work at
all.** A missing branch target marker sent its "not the queued object" path
twenty instructions past the unlink, straight into `stu object_list_last` —
leaving the list pointing at a cleared slot, and `object_list_last` holding
the free stack pointer, so the next load would link onto it. Only the
self-deletion case took the correct path. Nothing in v1 has ever called that
routine, which is why nothing had ever run it. Fixed in both repositories.
