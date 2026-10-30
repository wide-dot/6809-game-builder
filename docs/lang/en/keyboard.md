# Keyboard — keyboard.fast, the 6804's frames (TO8)

The TO8 keyboard is scanned by its own microcontroller, a 6804, which sends
the CPU one 9-bit frame per key press and per repeat of a held key :

| Bit | Content |
|---|---|
| 8 | CNT held |
| 7 | Shift held |
| 6-0 | the key number, `$00`-`$4F` (`scancode.const.asm`) |

The monitor reads each frame under its CP1 interrupt and keeps **the
character alone** : through it, Shift + an arrow is the arrow, CNT + J is
the down arrow, and a key with no character is lost. `keyboard.fast` turns
that interrupt off and reads the frame itself, with the monitor's own timed
instructions (bank 1 `$F08E-$F0F4`) : the game gets the key number, Shift
and CNT. Shift and CNT alone send no frame, and the 6804 sends one key at a
time.

`keyboard.read` (`keyboard.asm`) stays the monitor's way : GETC's character,
for text entry.

## API

`engine/system/to8/controller/keyboard.fast.asm`, opt-in : a game mode
includes it. `std.asm` brings the macros and `scancode.const.asm`, which
cost nothing.

| Entry | In | Out | Destroys |
|---|---|---|---|
| `keyboard.fast.init` | — | the CP1 interrupt off, caps lock off | A, B, X |
| `keyboard.fast.read` | — | C = 1, D = the frame read since the last call ; C = 0, D = `$FFFF` : none | X |
| `keyboard.fast.poll` | — | C = 1 : the waiting frame was read now | A, B, X |

D holds the frame as a number : A bit 0 is CNT (`scancode.CNT`), B bit 7
Shift (`scancode.SHIFT`), B bits 6-0 the key. `read` returns every frame :
a press and each of the 6804's repeats. It also sets, from the same pass :

| Variable | Content |
|---|---|
| `keyboard.fast.pressed` | the frame, when it is not the key held (a press) ; `$FFFF` otherwise |
| `keyboard.fast.held` | the last frame while KTEST says a key is down ; `$FFFF` once none is |
| `keyboard.fast.frame` | the last frame read, whoever read it |
| `keyboard.fast.count` | frames read, modulo 256 |

A key released and pressed again between two reads looks like a repeat :
`pressed` needs one read with no key down in between.

Macros (`keyboard.fast.macro.asm`) : `_keyboard.fast.init`,
`_keyboard.fast.read`, `_keyboard.fast.waitKey` (waits for a press, its
frame in D) and `_keyboard.fast.ktst` (C = 1 while a key is down : KTEST,
system PIA `$E7C8` bit 0).

```
        _keyboard.fast.init              ; once, in the game mode's init
        ...
mainLoop
        _keyboard.fast.read              ; once a pass
        bcc   @noKey
        andb  #$FF-scancode.SHIFT        ; the key number
        cmpb  #scancode.LEFT
        ...
        ldd   keyboard.fast.held         ; a key held : $FFFF none
```

## Cost

269 bytes. Measured under toje (`ci/toje-bench/keyboard_ut.py --cycles`),
`jsr` included :

| Call | Cycles |
|---|---|
| `read`, no frame waiting | 115 (109 with a key down) |
| `poll` in the IRQ routine, no frame waiting | 41 |
| `read` with a frame | 1 516 (LEFT, `$00D`) to 1 556 (CNT + Shift + A, `$1AA`) : the 6804 sends for ~1.4 ms, a 1 bit is 18 µs longer than a 0 |
| `read` with a CAPS LOCK frame, the caps lock request sent | 3 909 |
| `init` | 2 492, the caps lock request |

The frame is read with interrupts masked, about 1.4 ms : the timing of the
pulses is the measure. A game that cannot spend it in a given pass does not
call `read` in that pass ; the 6804 keeps its frame waiting.

## Where to call it

`read` in the main loop, once a pass, is enough when nothing clears the
6846's CP1 flag between the 6804's call and the read. On the 6846, a read of
the CSR followed by an access to the port C data register (`$E7C3`) clears
that flag (the monitor's receiver reads `$E7C3` after each edge for that) ;
the monitor's interrupt entry reads the CSR at every interrupt, and `$E7C3`
is written all the time (gfxlock's half page, the monitor's cursor). The
6804 keeps its call up until the CPU answers (TO8 technical manual) : a
frame whose flag was cleared would wait unseen.

`poll` closes that window : called **first thing in the IRQ routine**,
before anything touches `$E7C3`, it reads a waiting frame at each interrupt
and `read` in the main loop returns it. The interrupt then spends ~1.4 ms on
the interrupts where a frame arrives, delaying what follows it (a buffer
swap) on those. `examples/keyboard` runs both placements.

## Caps lock is kept off

The 6804 sets the frame's Shift bit for Shift held **or caps lock engaged**
(TO8 technical manual, keyboard interfacing). `init` sends the 6804 its
caps-lock-off request, as the monitor sends it (ACK low for three units of
645 cycles once the 6804 answers ; the monitor's lower case flag, `$E7C3`
bit 3, set as it does) ; `poll` sends it again after every CAPS LOCK frame.
The Shift bit is then the Shift key alone. The CAPS LOCK key is still
reported, as key `$40`.

## Living with the monitor

GETC (`keyboard.read`, `_monitor.jsr.getc`) reads a waiting frame itself
when its interrupt is off, and its receiver turns the interrupt back on
(`$F0ED-$F0F4`) : after any monitor keyboard call, call `keyboard.fast.init`
again. The loader's disk prompts only test KTEST : a key pressed there waits
as a frame for the next `read`.

## Validated, and what is left to the machine

`examples/keyboard`, replayed by `ci/toje-bench/keyboard_ut.py` under toje :
every key of the TO8, Shift + arrows, CNT + letters, CNT + Shift, CAPS LOCK
kept off, a held key's repeats, 20 keys in a row, a key pressed while the
game is busy, read in the main loop and polled in the IRQ routine. It needs
a toje whose 6804 leaves CRC bit 0 to the CPU and whose 6846 drops its IRQ
line for a CP1 flag with CRC bit 0 off (wide-dot/toje#64).

To check on a real TO8 :

- the read itself (the monitor's instructions, so its timing) ;
- whether the CP1 flag survives the monitor's interrupt and the `$E7C3`
  writes until a main loop `read` (if not, `poll` in the IRQ routine is the
  placement) ;
- the 6804's repeat, and whether it keeps a call up after the key is released
  (toje drops it) ;
- caps lock : the Shift bit with caps lock engaged, and the request turning
  it off (the TO8D's LED goes out).

The MO6 has no 6804 : its `keyboard.fast` macros test the key matrix, and
nothing here applies to it.
