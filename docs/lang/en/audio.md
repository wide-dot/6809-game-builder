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

The MPLUS expansion card benches (`examples/mplus`) additionally exercise
PCM playback (`pcm` converter), MEA8000 speech synthesis and MIDI over the
EF6850 ACIA — experimental, not required by any game port.
