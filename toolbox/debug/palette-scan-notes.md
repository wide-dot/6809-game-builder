# Palette scan — notes & Windows tuning

wddebug does not read the palette from a build-dependent address. It **locates**
the palette at hook time by scanning DCMOTO's memory for the **TO8 system palette**
(present on the boot / home screen, exactly like the boot-logo signature that
anchors `ramAddress`). This keeps the tool compatible across DCMOTO versions,
which store the palette at different offsets **and** in different byte layouts.

See `Emulator.searchPaletteAddress()` and the two signatures
`PAL_BGRX_PATTERN` / `PAL_NIBBLE_PATTERN` in
[`Emulator.java`](src/main/java/com/widedot/toolbox/debug/Emulator.java).

## The two known layouts

| Format | Layout | Decode | Seen in |
|--------|--------|--------|---------|
| `PAL_NIBBLE` | 16 colours × **2 bytes** — even `= (green<<4)\|red`, odd low nibble `= blue` (high nibble = marking/M bit, ignored) | via `ThomsonRGB[nibble]` | legacy DCMOTO (historically at fixed offset `ramAddress + 0x805C0`) |
| `PAL_BGRX` | 16 colours × **4 bytes** — `B, G, R, 00` (already-decoded 8-bit RGB) | used directly | `dcmoto-64_20260114` (found at `ramAddress + 0x84300`, mirrored at `+0x84380`) |

The scan tries `PAL_BGRX` first, then `PAL_NIBBLE` (masked). Whichever matches
sets `Emulator.paletteAddress` + `Emulator.paletteFormat`; `VideoBufferImage`
decodes accordingly.

## ✅ The nibble signature is now VERIFIED under Windows

`PAL_NIBBLE_PATTERN` was originally **derived** by reversing `ThomsonRGB` on the
16 system colours read out of the `PAL_BGRX` table on macOS/Wine. On **2026-07-02**
it was verified against a real nibble-format DCMOTO (`dcmoto_20250515`, Windows):
`searchPaletteAddress()` found the system palette as `PAL_NIBBLE` at the legacy
`ram+0x805C0`, and the 32 captured bytes matched the pattern **exactly** on the
even bytes and on the blue low-nibble. The only difference was the odd-byte **high
nibble (M/marking bit)**, which is `1` on colours (`0` for black) — exactly what
`PAL_NIBBLE_MASK` masks out. `PAL_NIBBLE_PATTERN` now holds those authoritative
bytes; the mask is still required.

### How to (re)capture the authoritative nibble string (on Windows / old DCMOTO)

1. Boot DCMOTO to the **TO8 home screen** (system palette active).
2. Let wddebug find `ramAddress` via the boot-logo scan (`searchRamAddress`).
3. Read the **32 bytes** at `ramAddress + 0x805C0` (the legacy `x7da` location,
   kept as `Emulator.x7daAddress`). A quick way is a throwaway main that calls
   `OS.openProcess` + `Emulator.searchRamAddress()` then
   `OS.readMemory(Emulator.ramAddress + 0x805C0, 0x20)` and hex-dumps it.
4. Those 32 bytes **are** the real `PAL_NIBBLE` system palette. Replace
   `PAL_NIBBLE_PATTERN` with them.
5. If the odd-byte high nibble (M bit) is 0 in the captured bytes, you can drop
   `PAL_NIBBLE_MASK` (pass `null` for exact match); otherwise keep the mask.

### Reference system colours (R,G,B 8-bit), palette index 0..15

```
000000 FF0000 00FF00 FFFF00 0000FF FF00FF 00FFFF EBFAFA
C2FAFA DB8F8F 8FDB8F DBDB8F 007A9E DB8FDB CCFAE3 E3C200
```
(black, red, green, yellow, blue, magenta, cyan, white, then 8 medium colours.)

## If the scan fails to find the palette

- Make sure the **TO8 system palette is on screen** when hooking (home screen).
  A game overrides the palette, so hook first, then load the game — the palette
  at the found address updates in place.
- If a **new DCMOTO build** changes the layout again, capture the system palette
  bytes from memory (as above) and add a third signature + format branch.

## Robustness knobs

- `NativeProcess.findBytes(pattern, mask)` does the search (mask byte `0x0F` =
  match low nibble only, `0x00` = ignore byte, `null` mask = exact).
- To reduce false positives you can search on fewer colours (the 7 primaries —
  black + R,G,B,Y,M,C — are the most universal part of the TO8 palette); the
  full 16-colour signature is used here because it was available and specific.
