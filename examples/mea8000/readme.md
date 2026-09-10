# mea8000 — speech playback, nothing else

The smallest program that should talk on a TO8 fitted with the Cedic-Nathan speech
synthesizer (MEA8000 at `$E7FE`/`$E7FF`), real or emulated. It plays one speech stream
over and over with a pause between plays: no screen, no interrupt, no other sound chip,
no engine routine — the player is written out in `src/main.asm` so the whole program
can be read on one page.

The stream (`src/goldorak-01.mea`) is a sequence of Philips / Cedic-Nathan speech files,
one per utterance, produced by the [mea8000](https://github.com/wide-dot/mea8000) encoder
from the Goldorak line of the v1 engine, without frame merging. The protocol is the one
of Philips TP101 (fig. 19-20 and 28): STOP `$1A`, starting pitch, every frame on REQ,
then STOP once the dummy frame has started; see
[`mea8000.files.md`](../../engine/system/thomson/sound/mea8000.files.md).

Build from this directory (needs the `engine` link to `../../engine`):

```
java -Dbasedir=../.. -cp "../../repo/*" com.widedot.m6809.gamebuilder.MainCommand -f to8.config.xml
```

Under toje (no synthesizer) the program stops at the first REQ poll: `PC = play@wait`,
`X` on the first frame, `U` on the end of the first file — a way to check that the data
and the protocol are in place without hearing anything.
