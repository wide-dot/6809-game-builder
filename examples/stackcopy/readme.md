# stackcopy — a block copied through the stack

The bench of `engine/graphics/draw/stackcopy.asm`
([manual](../../docs/lang/en/stackcopy.md)) : `stackcopy.run` copies D bytes
from U to Y, 7 at a time, pulled by U and pushed by S, the interrupts masked
for each 252 bytes.

The game mode (`src/main.asm`, its setup taken from examples/fullscreen,
nothing drawn) copies blocks in RAM page 5, mapped in the data window, the
50 Hz interrupt on :

| Tests | What |
|---|---|
| 1-11 | 0, 1, 6, 7, 8, 13, 251, 252, 253, 504 and 505 bytes : around the 7-byte chunks and the 252-byte blocks |
| 12 | 8 000 bytes (a screen half), 16 times : interrupts taken during the copies |
| 13-15 | a destination above an overlapping source : by 1 byte, 7 bytes, 13 rows of 40 |
| 16 | a block onto itself |
| 17 | 2 000 bytes, the interrupts masked by the caller : still masked after, none taken |

Before each copy the window (the source and the destination, 16 bytes on
either side) is filled with `$55`, the source with a pattern that never
repeats within 256 bytes (`a = 5a + 1` and the byte's high address). After
it, every byte of the window is checked : the destination holds the source's
pattern, the source what it held where the destination does not cover it,
the rest `$55`.

Witnesses at `$9C00` : `+0` `$CA` once running, `+1` `$0D` all passed or
`$E0+n` test n failed, `+2` the tests passed, `+3` (word) the interrupts taken
during a copy, `+5` 1 during a copy. Then the game mode copies 0, 7, 252 and
8 000 bytes in turn, the interrupts masked, for the bench to time.

## Build and check

From this directory (`engine` links to `../../engine`) :

```
java -Dbasedir=../.. -cp "../../repo/*" com.widedot.m6809.gamebuilder.MainCommand -f to8.config.xml
python3 ../../ci/toje-bench/stackcopy_ut.py dist/to8.fd
```

The bench stops at every interrupt during the tests (`IrqManager`) : the
interrupted S must never be in the data window, where the copy's S pushes.
Then it times the copies between `time.call` and `time.done` with toje's
profiler.

## Result (toje, 03/11/2026)

- 17/17 tests passed, 31 interrupts taken during the copies, none with S in
  the data window ;
- cycles, the jsr included : 0 bytes 211, 7 bytes 250, 252 bytes 1 314,
  8 000 bytes 35 520 (4.44 a byte).
