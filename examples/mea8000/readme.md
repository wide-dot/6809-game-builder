# mea8000 — speech playback, nothing else

The smallest program that should talk on a TO8 fitted with the Cedic-Nathan speech
synthesizer (MEA8000 at `$E7FE`/`$E7FF`), real or emulated. It says one sentence over
and over with a pause between plays: no screen, no interrupt, no other sound chip.

What it proves: the engine's players for the period format. The sentence
(`src/fr-female.mea`, `samples/fr-female.mea` of the
[mea8000-encoder](https://github.com/wide-dot/mea8000-encoder): a Mozilla Common Voice
sentence, default `thomson` profile) is a stream of Philips speech files, one per word
group — the format of every Cedic-Nathan product. It is loaded as a block into its own
RAM page (5) and played by `mea8000.stream.read` through the cartridge window, the way a
stream longer than a page is played (`mea8000.files.md`, *Streams over several pages*);
`mea8000.file.read` plays each file the period way: STOP, pitch, every byte on REQ, no
STOP at the end, the chip stops by itself.

Build from this directory (needs the `engine` link to `../../engine`):

```
java -Dbasedir=../.. -cp "../../repo/*" com.widedot.m6809.gamebuilder.MainCommand -f to8.config.xml
```

Witnesses: `$9C00` = `$CA` once running, `$9C01` = plays completed. Bench, with toje's
speech card plugged (its default):

```
python3 ../../ci/toje-bench/mea8000_ut.py dist/to8.fd
```

PASS on 2026-11-08: two plays completed in the chip's own time (REQ paces every byte;
without the card the count stays at 0). On MAME (`mame to8 -extension speech -flop1
dist/to8.fd`) the same disk says the sentence, a pause, the sentence again.

Cost of the players (TO8, bytes): `mea8000.file.read` 53, `mea8000.rom.read` 13,
`mea8000.stream.read` 44.

Lesson of 2026-09-11, kept here because it cost an evening: an end-of-file test written
as `cmpx 2,s` compared X to the copy of U pushed by `pshs d,u` *before* U was computed —
the loop exited at once, every file sent only its pitch, and the emulator was silent.
The end address now goes on the stack after it is computed (`pshs u` / `cmpx ,s`).
