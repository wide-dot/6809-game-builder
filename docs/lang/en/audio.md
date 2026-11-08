# Audio

Two music formats are supported by the engine, both produced from VGM
captures by the bundled converters :

| format | chip | converter | player |
|---|---|---|---|
| **ymm** | YM2413 (OPLL) | `vgm2ymm` | `engine/sound/ym2413/` |
| **vgc** | SN76489 (PSG) | `vgm2vgc` | `engine/sound/sn76489/` |

Sound effects for the YM2413 are extracted with `vgm2sfx` and played under
IRQ next to the music (this is the exact combination the first-generation
R-Type uses : ymm music + YM sound FX).

Both players stream from RAM pages and run under the 50 Hz IRQ ; a music
is an ordinary loadable file — declare it, load it from a scene, call
`obj.play`. Hot swapping a music (title → level) is an ordinary scene
swap, exercised by `examples/sound` (TO8 and MO6), which is the reference
wiring : boot, double buffering, two musics, and the swap.

Two cautions, both learned on machine :

- the players resolve `irq.on` / `irq.off` at load time — a game mode
  must export a bridge that **preserves the registers** ; a bare
  `equ IrqOff` reuses a monitor routine that clobbers A and corrupts the
  player's page byte (see `irq-bridge.md` in the migration casebook) ;
- a stream interrupted mid-frame is reset by `obj.play` — the ring buffer
  is refilled with a neutral value and the decompressor's parity is
  cleared, so a swap can never leave the next music unfolding shifted by
  one byte.

The TO8's built-in 6-bit DAC (`$E7CD`) shares its bits 2 and 3 with pin 7
of the joypad ports : a DAC resting with them at 0 makes a Mega Drive pad
read left and right pressed. See [joypads and the DAC](joypad.md).

## Speech : the MEA8000

The Cedic-Nathan speech synthesizer (a Philips MEA8000 at `$E7FE`/`$E7FF`)
plays speech files in Philips' period format, which the
[mea8000-encoder](https://github.com/wide-dot/mea8000-encoder) produces
from a recording. Two polling players live in
`engine/system/thomson/sound/`, both opt-in (include the files you use) :

| routine | what | bytes |
|---|---|---|
| `mea8000.file.read` | one speech file : STOP, pitch, every byte once REQ allows it, no STOP at the end — the chip fades on the file's last frame and stops by itself, and the player waits for that | 53 |
| `mea8000.stream.read` | a stream longer than a page : 16 KB blocks cut at file boundaries, one per RAM page loaded through the cartridge window, mapped in turn from a 5-byte-per-block table (register byte `page \| map.RAM_OVER_CART`, address, length ; 0 ends) | 44 |

Formats, protocol and the table are in
`engine/system/thomson/sound/mea8000.files.md`. Why no STOP at the end : a
STOP sent as the last frame starts races the chip's own sample clock, and
the chip's state then depends on the CPU's timing ; letting it stop by
itself is deterministic (checked sample for sample against MAME). The
bench is `examples/mea8000` (`ci/toje-bench/mea8000_ut.py`, toje's speech
card plugged). The MPLUS expansion card benches (`examples/mplus`)
additionally exercise PCM playback (`pcm` converter), the MEA8000 and MIDI
over the EF6850 ACIA — experimental, not required by any game port.
