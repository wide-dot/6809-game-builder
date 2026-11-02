# Joypads and the DAC — one port for both (TO8)

The joypads and the 6-bit DAC share the music and games PIA (`$E7CC-$E7CF`) :

| Line | Joypad | DAC |
|---|---|---|
| `$E7CC` bits 0-3 / 4-7 | joypad 0 / 1 : up, down, left, right (0 = pressed) | — |
| `$E7CD` bits 6 / 7 | joypad 0 / 1 : button A (pin 6) | — |
| `$E7CD` bits 2 / 3 | joypad 0 / 1 : pin 7 — Thomson button B, Mega Drive SELECT | DAC bits 2 / 3 |
| `$E7CD` bits 0, 1, 4, 5 | — | DAC bits 0, 1, 4, 5 |

Bits 2 and 3 are both a DAC bit and pin 7 of a joypad port. What pin 7 does
depends on `$E7CD`'s direction register (DDRB) and on the pad plugged in.

## The three set-ups

| Routine | DDRB | Pin 7 | For |
|---|---|---|---|
| `joypad.init` (`joypad.asm`) | `$00` | an input : Thomson button B readable, the DAC silent | a game without DAC sound |
| `dac.enable` (`dac.enable.asm`) | `$3F` | an output : the DAC's bits 2 / 3 | DAC sound |
| `joypad.md6.init` (`joypad.md6.asm`, `joypad.md6.dac.asm`) | `$0C` / `$3F` | an output : SELECT, driven by `joypad.md6.read` | Mega Drive 3 / 6 button pads |

With DDRB at `$00` and nothing driving them, the DAC lines read 0 :
complemented, button B looks pressed. `joypad.init` seeds `held` with that
idle state so the first read makes no false press.

## The trap : a DAC at rest with bits 2-3 at 0

A Mega Drive pad with SELECT low reports **left and right pressed** at once
(its identification marker, which `joypad.md6.sync` tests). So when the DAC
lines are outputs and the DAC rests at a level with bit 2 (pad 0) or bit 3
(pad 1) at 0, the pad reads left + right while no one touches it. The game
sees whichever of the two it tests first, typically left. The phantom stops
when a later DAC write sets the bit again.

A plain DAC sound player is enough to cause it : a 1-bit speaker played on the
DAC as levels 0 / 63 rests at 0 after every even number of toggles. Emulators
don't model SELECT on the pins, so the bug appears **on a real machine only**.

The rule : while the DAC lines are outputs and a joypad is read, keep DAC
bits 2 and 3 at 1 whenever the game reads the joypad. Three ways :

- **levels that keep the bits** : a 1-bit speaker played as `$0C` / `$3F`
  (the toggle `eor #$33`), with `$0C` written right after the DAC is enabled.
  SELECT never moves, at a cost of 51 steps of swing instead of 63 (-1.8 dB) ;
- **a safe rest after each sound** : any level with bits 2-3 at 1, written
  when a blocking sound ends. A sound that toggles one step per frame in the
  main loop (a click) needs the first way ;
- **DDRB back to `$00` between sounds** (`joypad.init` again) : the lines
  float to the pad's own pull-up. The direction switch can click.

During a blocking sound (the game frozen), SELECT may toggle freely : nothing
reads the pad then. A 6-button pad's internal counter runs while SELECT
toggles ; it resets after about 1.5 ms of a steady SELECT.

## Thomson joypads

A Thomson joypad's buttons are contacts : DAC levels move none of its
directions. Its button B (pin 7) is readable only with DDRB bits 2 / 3 at 0,
so not while the DAC plays.
