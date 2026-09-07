# The v1 boot fade becomes a routine

The v1 boot sector fades the TO8 monitor palette to a colour before it loads
anything. In v2 that code has no sector to live in — the boot sector is 219
bytes out of 256 and the loader owns the rest of the boot — so the fade is
**a routine**, `palette.fade`, that a scene calls from wherever it wants.

## Symptom

At boot the monitor shows page 0 with its own palette. Everything a scene
writes into page 0 before the game's first buffer swap shows up as pixel
noise — in r-type, `common.ranking` lands there, and the title's init clears
the object pool there. The title does set `Pal_black` as its first
instruction, but that comes **after** the loads that produced the noise.

v1 never had this problem : its boot sector faded the palette to black
before reading a single sector of game code.

## The v1 idiom

`engine/boot/boot-fd.asm` (commit `10b1d58c`), `PalFade`/`PalRun`, at `$6200`
inside the boot sector :

- the monitor palette is **hard-coded** (`pal_from`), as six colours with the
  entry ranges each one covers (`pal_len`) — the sector had no room for
  sixteen entries ;
- every frame : poll `$E7E7` for the beam leaving the useful screen, then
  spin 40 lines to sit inside the invisible border (the EF9369 written
  mid-screen snows), then move each component one step toward the target
  (`boot_color_gr`, `boot_color_b`) and write the entries ;
- variables live in direct page `$62` ; `pal_cycles` = 16 frames.

## The v2 shape

`engine/palette/palette-fade.asm` :

```
        ldu   #palette.to8.monitor     ; the working palette, 16 entries, in RAM
        ldd   #$0000                   ; the target : black
        jsr   palette.fade
```

- **Sixteen entries, in place.** The grouping was a sector-size trick ;
  a routine takes any palette buffer in the EF9369 / `Pal_buffer` layout
  (`GGGGRRRR`, `0000BBBB`) and steps it where it is. `palette.to8.monitor`
  is the v1 table unfolded — the only thing the boot use needs.
- **Target in registers, memory on the stack.** No direct page, no global :
  the routine is callable from the boot relay, from a transition state with
  the IRQ off, or from a game mode. `A`/`B`/`X`/`Y`/`U` are clobbered, DP is
  untouched (extended addressing only).
- **Same timing.** VBL by polling, 40 border lines, one step per component
  per frame, exit when nothing moved — 15 frames at most, 300 ms.
- **Registers by name.** `map.EF9369.A`/`.D` and `map.CF74021.SYS1` come from
  the machine's `map.const.asm`, which the caller includes first.

## Proof

`examples/tilescroll`, with the routine called at the very top of the game
mode (before `_gfxmode.setBM16` and `Pal_tiles`) and a screenshot per frame
from boot under toje, mean luminance of the picture :

```
frame  81  181.3   the monitor menu, untouched
frame  82  172.1   first step
frame  88   69.9
frame  93   44.1   only the TO8 logo outline is left
frame  96    0.0   black, border included
frame  97   74.9   the game mode sets its own palette (its business)
```

Fifteen frames from the first step to black, PC inside `palette.fade`'s VBL
loop the whole way. The harness was a `FADE_TEST` define on the example and
is not kept ; the routine is.

Two things the measurement also shows, for whoever wires the boot :

- the fade must run **before** the loads that write page 0 — in r-type that
  means a scene loaded before `scenes.boot`, since `scenes.boot` itself
  carries `common.ranking` into page 0 ;
- a game mode that sets its palette before clearing and swapping (as
  tilescroll does at frame 97) flashes one frame of page 0. Keep the palette
  black until the target screen is drawn.

## Met in

r-type, 2026-09-07 — `games/r-type/doc/plan-ecran-loading-2026-09.md` §10.
Wired the same day as `scenes.fade`, the loader's default scene : a 191-byte
unit **in the engine's own region** (`$6100`), baked, no link data, alone in
its composition. It fades, then *jumps* into `scene.load(scenes.boot)` with
`boot.entry` pushed as the return address — it is never executed again, so
the engine may overwrite it. Measured from boot : the TO8 menu at frame 0,
black at frame 60, nothing but black until the title reveals itself at frame
2880. `rtype_bench` 7/7, title hand-over at the same frame as before.
