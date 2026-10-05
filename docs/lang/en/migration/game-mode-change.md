# A game mode that loads the next one drops itself first, and returns into it

## Symptom

Sonic 2's title asking for Emerald Hill through v1's `LoadGameMode` turned
into a plain scene load : the machine freezes about fifty frames into the
load, on `log.halt`, with `log.code` = `$8101` — `log.tlsf.ERROR`, A = 3, the
loader's pool out of memory. The pool is sized for one RAM state at a time,
and the title's files were still indexed when Emerald Hill's arrived. With
room to spare, the next guard is `log.scene.LOAD_OVERLAP` : the new game mode
lands at `$6100` over the title's main, still indexed.

At build time, the two game modes on one disk :

```
the memory layout overlaps itself:
  region 'gm' [$6100-$9B33] runs into the reserved range 'ehz.tile_buffer' [$9000-$97FF]
```

## The v1 idiom

A v1 game mode is a whole absolute image with its own copy of the engine. An
object sets `GameMode` (the mode asked for) and `ChangeGameMode` ; the main
loop's `LoadGameMode` jumps into the RAM loader (page 4, at `$0000`) with A =
the mode asked for and B = the current one, and the builder had worked out,
pair by pair, what to reload. Nothing outlives the swap but a few globals at
`$6000`. The RAM a game mode kept at a fixed address above its code
(Emerald Hill's tile buffer at `$9000`) was its own business : the next game
mode used page 1 its own way.

## The v2 model

The loader indexes every file that carries link data, and that index is what
the global re-link patches : loading over a still indexed file is refused
(`LOAD_OVERLAP`), and the pool is sized for the link data of one state. **The
scene that ends declares what it drops.**

With a resident engine doing the switching (r-type), that declaration is
`loader.composition.load` : the loader converges from the state it remembers.
A self-contained game mode cannot use it. The loader remembers the current
state as a pointer to its table, and without a resident part the only place
for that table is the game mode the convergence overwrites. So the game mode
does the two steps v1's pair stood for : `loader.scene.unload` of its own
scene, then `loader.scene.load` of the next one.

Loading over the caller has two consequences :

- **the caller does not come back** : the new game mode's entry point is
  pushed as the return address and the load is jumped to, so the loader's
  `rts` lands at `$6100` ;
- **the interrupt goes off first** : its routine lives in the game mode being
  overwritten.

And page 1 is carved differently by each game mode. A `<reserved>` holds for
the whole layout : it would forbid the title the RAM Emerald Hill only needs
while it runs. So there is one region per game mode, all at `$6100`, and the
one that keeps RAM above its unit bounds itself with `size`. One
`<composition>` per game mode tells the builder those regions are never in
memory together, and has each state checked, even though nothing at run time
reads the tables.

## The fix

```asm
LoadGameModeNow
        ldb   GameMode                 ; the mode asked for (v1's A)
        bsr   GameModeScene            ; X = its scene, $FFFF : not on this disk
        cmpx  #$FFFF
        bne   @load
        clr   ChangeGameMode
        rts
@load
        stx   @scene
        jsr   IrqOff
        _ram.data.set #loader.PAGE
        ldb   glb_Cur_Game_Mode        ; the current one (v1's B) : drop it
        bsr   GameModeScene
        jsr   loader.ADDRESS+loader.scene.unload.IDX
        ldx   #0                       ; (dynamic) the new game mode's scene
@scene  equ   *-2
        ldd   #$6100                   ; its entry point : the load's return
        pshs  d
        jmp   loader.ADDRESS+loader.scene.load.IDX
```

`GameModeScenes`, the scene of each game mode by `GmID`, is generated with the
configuration. Keep the two variables straight : `GameMode` is the target,
`glb_Cur_Game_Mode` the mode running. Sonic 2's first port picked the scene by
the latter and reloaded the title.

```xml
<layout>
    <region name="gm.title" page="$01" address="$6100"/>
    <!-- EHZ keeps TilemapBuffer's buffers at $9000-$9D6A -->
    <region name="gm.ehz" page="$01" address="$6100" size="$2F00"/>
    ...
    <composition name="title"><scene name="scenes.title"/></composition>
    <composition name="ehz"><scene name="scenes.ehz"/></composition>
</layout>
```

A game mode that keeps RAM at a fixed address outside its unit also clears it
before use : the previous game mode's code is still there
([`reserved-ram-is-not-zeroed.md`](reserved-ram-is-not-zeroed.md)).

## Proof

- The chain under toje, v1 and v2 side by side : Start pressed at the title's
  game frame 1400, the title asks for Emerald Hill at frame 1469 in both ;
  Emerald Hill played after it with the same joystick script gives 667/667
  samples identical to v1 (Sonic, camera, rings, loop count) over 5 335 game
  frames (wide-dot/sonic-2, `tools/ehz_bench.py`, docs/migration.md §9).
- The title is still identical to v1 on the shared disk : 11/11 screenshots.
- The pool report (`pool-map-fd.txt`) : the states are `title` (810 bytes,
  5 files) and `ehz` (396 bytes, 11 files), peak 810 of 4 096.
- Without the `scene.unload` : the freeze of the Symptom.
- From the title's request to Emerald Hill's first frame under toje : 1 875
  frames (37.5 s), against 4 784 (95.7 s) for v1's RAM loader.

## Met in

wide-dot/sonic-2, title → Emerald Hill (M4), 05/10/2026.
