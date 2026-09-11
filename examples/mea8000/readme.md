# mea8000 — speech playback, nothing else

The smallest program that should talk on a TO8 fitted with the Cedic-Nathan speech
synthesizer (MEA8000 at `$E7FE`/`$E7FF`), real or emulated. It says one sentence over
and over with a pause between plays: no screen, no interrupt, no other sound chip, no
engine routine — the player is written out in `src/main.asm` so the whole program can be
read on one page.

The data and the player are those of the period. The sentence (`src/fr-female.mea`) is a
sequence of Philips speech files, one per word group — the format of every Cedic-Nathan
product — produced by the [mea8000-encoder](https://github.com/wide-dot/mea8000-encoder)
(its `samples/fr-female.mea`: a Mozilla Common Voice sentence, default `thomson` profile).
The player has the shape of the one published with the Cedic-Nathan demonstrations: STOP
`$1A`, the starting pitch, then every byte after a REQ poll, and no STOP at the end — the
file's last frame has amplitude 0 and the chip stops by itself.

Build from this directory (needs the `engine` link to `../../engine`):

```
java -Dbasedir=../.. -cp "../../repo/*" com.widedot.m6809.gamebuilder.MainCommand -f to8.config.xml
```

`dist/to8.fd` and `dist/to8.sd` are the images to play. Checked on MAME (`mame to8
-extension speech -flop1 dist/to8.fd`): the sentence, a pause, again. Under toje, which
has no synthesizer, the status register reads as always ready: the program runs through
the data at once and idles in its pause loop — it proves the boot and the loader, not the
protocol.

Lesson of 2026-09-11, kept here because it cost an evening: an end-of-file test written
as `cmpx 2,s` compared X to the copy of U pushed by `pshs d,u` *before* U was computed —
the loop exited at once, every file sent only its pitch, and the emulator was silent.
The end address now goes on the stack after it is computed (`pshs u` / `cmpx ,s`).
