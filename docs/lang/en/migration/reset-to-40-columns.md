# A reset goes back to 40 columns only if the monitor knows the mode changed

A game sets its video mode in the gate array (`$E7DC`), behind the monitor's
back. The monitor keeps its own idea of the mode in `SCRMOD` (`$605F`), still
0, 40 columns, as BASIC left it. On a reset it reprograms the gate array
only when the mode it wants differs from `SCRMOD` : 40 columns against 40
columns, it does nothing, and the menu comes up in the game's BM16.

## Symptom

Press reset during a game : the menu is unreadable, columns of coloured
blocks, because it is drawn in 40 columns and shown in 160×200×16.

## The v1 idiom

v1's boot sector set BM16 itself, and since commit `10b1d58c` (2026-07-31,
"Ensures reset reverts back to std 40 columns gfx mode") it also writes a
non-zero `SCRMOD` next to it : `sta <$605F` in `boot-fd.asm`, `stb $605F` in
`boot-t2.asm`, `$40` in `_system.reboot`.

## The v2 model

v2's boot sector does not set a mode : the game does, through
`_gfxmode.set*` (see [video-mode.md](video-mode.md)). The boot sector writes
`SCRMOD` once, before it reads the loader :

```asm
        lda   #$40               ; Display mode : not 40 columns, so that a
        sta   <map.SCRMOD        ; reset reprograms the gate array
```

Nothing writes `SCRMOD` afterwards : the loader talks to the monitor only
through `DKCONT` and `PUTC`, and sends no mode escape.

The value is v1's `$40`, and its bits matter : the monitor's `PUTC` reads
bit 7 and bit 2 of `SCRMOD` (to pick RAMA or RAMB and to draw a character).
With both clear, the loader's monitor text (the disk prompt without a loading
bar, the I/O error) is written exactly as in 40 columns.

The sector's first part had 3 bytes left under its `$6278` limit, so the
"Only for TO8/8D/9+" message moved to the second part, next to the others
(`ldx #mess1` instead of `leax <mess1,pcr`, same size).

## Proof

Boot a game that sets BM16, press reset on the machine : the menu is in 40
columns. Every TO8 image changes in its boot sector, and only there.

## Met in

Brought over from v1 on 2026-10-30, `engine/system/to8/bootloader/boot.asm`.
The MO6 boot is not touched : v1's commit is TO8 only.
