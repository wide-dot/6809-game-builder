# keyboard — the 6804's frames, read by the game

The bench of `keyboard.fast` ([manual](../../docs/lang/en/keyboard.md)) : the
game turns the monitor's keyboard interrupt off and reads the 9-bit frame of
the keyboard's 6804 itself — the key number, Shift and CNT, which the
monitor's GETC throws away.

One resident game mode, the monitor's text screen (loaded at `$6300` : the
monitor's screen buffers sit below), the engine's 50 Hz IRQ on throughout.

## Build

```
ln -s ../../engine engine      # once
java -Dbasedir=<repo root> -cp "../../repo/*" \
     com.widedot.m6809.gamebuilder.MainCommand -f to8.config.xml
```

Output in `dist/` (`to8.fd`, `to8.sd`, `to8.sap`).

## On screen

```
FRAME    $1AA
KEY      $2A  A
SHIFT    YES
CNT      YES
STATE    PRESSED

FRAMES   012   ENGINE COUNT 012
IRQ READ 000

MODE     READ AT EVERY PASS
```

The last frame : its value, the key number and the key's name, Shift, CNT,
and whether `keyboard.fast.read` saw a press or the 6804's repeat of the key
held. FRAMES counts the frames the main loop got, ENGINE COUNT those the
engine read ; IRQ READ those the IRQ routine read (mode below). Printing
through the monitor takes ~68 000 cycles : the display lags a held key's
repeats, the frames are not lost (the 6804 waits).

## The witnesses

At `$9C00`, written by the game mode :

| Offset | Content |
|---|---|
| `+0` | `$CA` once running |
| `+1` | the mode, written by the bench : bit 0 polled in the IRQ routine and read once a frame (else read at every pass of the main loop), bit 7 nothing on screen |
| `+2` | frames `keyboard.fast.read` returned |
| `+3` | `keyboard.fast.count` with the last one |
| `+4` | the last frame returned (word) |
| `+6` | `keyboard.fast.pressed` with it (word) |
| `+8` | `keyboard.fast.held`, at every pass (word) |
| `+10` | frames the IRQ routine read |

At `$9D00` : every frame returned, a word each in a ring of 128, bit 15 set
for a press.

## The bench

```
TOJE_MCP=<toje>/scripts/toje-mcp.sh \
python3 ci/toje-bench/keyboard_ut.py examples/keyboard [--cycles]
```

It presses keys through toje's 6804 and checks the log, frame by frame :
every key of the TO8, CAPS LOCK then A (caps lock kept off : A without
Shift), Shift + the arrows and A, CNT + eleven letters, CNT + Shift + A, a
held key and five repeats (`held` while down, `$FFFF` after), the same key
twice, 20 keys in a row held one frame each ; then polled in the IRQ
routine : 20 keys, Shift + arrows, CNT + letters, each frame read in the
interrupt ; then on screen, and a key pressed while the game is busy
printing. `--cycles` times `keyboard.fast.read`.

It needs a toje whose 6804 leaves CRC bit 0 to the CPU and whose 6846 drops
its IRQ line for a CP1 flag with CRC bit 0 off (wide-dot/toje#64) : with the
released one (1.9.0), the monitor's interrupt takes every frame and the bench
fails.

**27/10/2026** : 13/13 pass (toje `fix/mc6804-crc-irq-enable` 3a546ed, the
6804 and 6846 fixes). The released toje 1.9.0 : 0/13 ; toje acdcf16 (the
6804 fix alone) : 12/13, the key pressed while the game is busy lost.
