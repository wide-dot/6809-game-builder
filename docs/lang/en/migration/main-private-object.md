# A v1 object that only existed to get code out of the resident page becomes a resident routine

## Symptom

Nothing crashes — that is what makes this one easy to over-port. You read the
v1 main loop, find

```
        _Obj_RunB ObjID_mainext,#mainext.COLLISION
```

and start building the v2 counterpart: an object id, an entry in the stage's
object index, a page, a command register, a dispatcher. Half a day later you
have reproduced a mechanism that exists to solve a problem you do not have.

## The v1 idiom

`obj_mainext` is not a game object. It has no OST, no state, no life cycle; its
own header says so:

> *extension non graphique du code main du game-mode. Porte hors de la page
> résidente ($6100-$9EFF) le code "privé" du main.*

It is a **page eviction device**. v1's resident page was full, so code that only
the main loop called was pushed out into a mounted page, and the only way v1 had
to place and reach a lump of code was to declare it an object: give it an id,
let the object index carry its page and address, and dispatch on a command in
`B`.

The collision pass is the clearest case. `Collision_Do` is pure computation —
it walks two linked lists and writes potentials — so it is safe in a mounted
page, and it was moved there. Its *data* (the lists) stayed resident, because
the objects that register in them run in mounted pages themselves.

## The v2 model

Two things changed underneath.

A v2 stage is **loaded into the resident page** — R-Type's `stage` region is
page `$01`, address `$8300`. The stage body is not competing for room with the
engine; they are neighbours in the same page. The pressure that created
`obj_mainext` is gone.

And when code genuinely does live in another page, v2 reaches it **by name**:
`paged.call` takes a page and a symbol, with no id, no index entry and no
command register (see [paged-routine.md](paged-routine.md)). The starfield and
the playfield mask go that way.

So a v1 main-private object splits along what it actually was:

- code that is *pure computation over resident data* — put it with the data, in
  the resident unit, as a plain routine;
- code that is genuinely big and paged — `paged.call`;
- an id in the object index — only if it has an OST.

## The fix

`Collision_Do` and the four AABB lists already lived in the resident engine, so
the detection pass joined them there, next to `Collision_ClearLists` which was
resident for the same reason:

```asm
Collision_Run
        _Collision_Do AABB_list_friend,AABB_list_ennemy
        _Collision_Do AABB_list_player,AABB_list_bonus
        _Collision_Do AABB_list_player,AABB_list_ennemy_unkillable
        _Collision_Do AABB_list_player,AABB_list_ennemy
        rts
```

and the stage calls it where v1 ran its object, right after `ObjectWave`:

```asm
        jsr   Scroll
        jsr   ObjectWave
        jsr   Collision_Run
```

The interface gains **one** name instead of three: `_Collision_Do` is a macro
that writes into `Collision_Do_1` and `Collision_Do_2`, two self-modified
operands of the engine. Expanded in the stage, those two would have had to
cross the link as well; expanded in the engine, they stay private.

## Proof

The pass is what makes the AABB potentials move, and the two ends of it are
visible without instrumenting anything: a shot deletes a pata-pata, and flying
into one kills the ship — the player's death routine, its explosion and the
checkpoint reload all run. Neither happened before, with every object already
registering its box correctly: the pass was simply never called.

## Met in

R-Type v2, 2026-08-03, finishing the collision migration. The same reading
applies to the other v1 objects whose only reason to exist was placement —
check for an OST before giving one an id.
