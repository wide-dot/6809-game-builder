#!/usr/bin/env python3
"""Generate pre-shifted 1bpp sprite variants."""
#
# The 1bpp compiled sprites are byte-aligned : one variant can only draw at
# x positions that are multiples of 8, so a byte-stepping sprite jumps 8
# pixels per move. Eight pre-shifted variants (shift 0..7 inside a canvas
# padded by 8 on the right, zero-filled so nothing clips) let the game draw
# at any pixel : variant s = (X - x1_0) & 7, byte column = (X - x1_s) >> 3,
# with x1_s = x1_0 + s exactly (same canvas, same trim, ink only moved).
#
# Each variant is a standalone shift-0 bdraw1 image : the engine, the
# imageset layout and CSR/Draw/Erase are untouched. A mapping_frame change
# (byte crossing) is already an erase+draw refresh by construction.
#
# usage : python3 tools/mk_shifts.py  (from examples/layers)
import os

from PIL import Image

SRC = 'src/assets/sprites'
NAMES = ('knight', 'ghost', 'dragon')
PAD = 8


def main():
    """Write the eight pre-shifted variants of each source sprite."""
    os.makedirs(SRC, exist_ok=True)
    for name in NAMES:
        src = Image.open(os.path.join(SRC, name + '.png'))
        assert src.mode == 'P', src.mode
        w, h = src.size
        data = list(src.getdata())
        ink = [x for y in range(h) for x in range(w) if data[y * w + x] == 1]
        assert ink, name
        assert max(ink) + (PAD - 1) < w + PAD, (name, max(ink))
        for s in range(8):
            out = Image.new('P', (w + PAD, h), 0)
            out.putpalette(src.getpalette())
            px = out.load()
            for y in range(h):
                for x in range(w):
                    v = data[y * w + x]
                    if v:
                        px[x + s, y] = v
            out.save(os.path.join(SRC, f'{name}_s{s}.png'))
        print(f'{name} : 8 variants, canvas {w + PAD}x{h}')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
