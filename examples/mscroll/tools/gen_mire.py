#!/usr/bin/env python3
"""examples/mscroll test pattern.

Two styles, same geometry (256x240 px, 8x16 tiles, row stride 64) :

  visual (default) — readable by a HUMAN at a glance. Long horizontal ruler
  lines cross the whole map (white every 16 px, orange mid-tile), thin
  vertical rulers every 16 px, a calm 45-degree hatch, and a soft 4-shade
  patchwork behind. Any one-pixel vertical offset (the ribbon seam, a feed
  anchored wrong) breaks the horizontal rulers and the hatch with a visible
  step ; any horizontal offset breaks the vertical rulers. The byte-exact
  check does not rely on decoding cells any more : tools/diag_check.py
  compares the screen against the pixel source written next to the PNG.

  --coded — the original forensic pattern : every pixel line of every tile
  encodes its own (column, row, line) as nibbles, so a single byte read from
  the code buffer names exactly what was written there. Noisy to look at,
  unbeatable for post-mortem decoding. Keep it for deep debugging.

Outputs :
  mire.png — indexed PNG (colours 1..16 hold hardware 0..15), the builder's
             <mscroll> element consumes it at build time
  mire.pix — the same pixels as raw bytes (one hardware colour per byte,
             row-major 256x240), read by tools/diag_check.py

usage : python3 tools/gen_mire.py [--coded]   (from examples/mscroll)
"""
import sys
from PIL import Image

COLS, ROWS = 32, 15
TILE_W, TILE_H = 8, 16
W, H = COLS * TILE_W, ROWS * TILE_H

CODED = '--coded' in sys.argv

if CODED:
    # 16 visually distinct colours for hardware values 0..15
    PALETTE = [
        (0, 0, 0), (85, 85, 85), (170, 170, 170), (255, 255, 255),
        (200, 30, 30), (255, 140, 0), (255, 230, 0), (60, 180, 40),
        (0, 200, 180), (40, 90, 220), (150, 60, 200), (255, 100, 170),
        (120, 70, 20), (170, 200, 90), (90, 130, 130), (255, 200, 150),
    ]

    def f(x, y):
        col, i = divmod(x, TILE_W)
        row, l = divmod(y, TILE_H)
        return (l & 15, col & 15, col >> 4, row,
                (col + row + l) & 15, 15 - l,
                (col * 3 + row * 5) & 15, 10)[i]
else:
    # muted patchwork (1..4), hatch (8), rulers (7, 14, 15)
    PALETTE = [
        (0, 0, 0),        # 0  unused by the pattern
        (30, 40, 70),     # 1  patchwork, dark blue
        (35, 60, 45),     # 2  patchwork, dark green
        (55, 40, 60),     # 3  patchwork, dark purple
        (60, 55, 35),     # 4  patchwork, dark olive
        (90, 90, 90), (110, 110, 110),  # 5, 6 spare greys
        (230, 140, 30),   # 7  mid-tile ruler, orange
        (95, 115, 150),   # 8  45-degree hatch, blue-grey
        (60, 60, 60), (80, 80, 80), (100, 100, 100),  # 9..11 spare
        (130, 130, 130), (160, 160, 160),             # 12, 13 spare
        (60, 200, 210),   # 14 vertical ruler, cyan
        (255, 255, 255),  # 15 horizontal ruler, white
    ]

    def f(x, y):
        if y % 16 == 0:
            return 15                 # white line every 16 px, full width :
        if y % 16 == 8:               # a 1px vertical offset breaks it
            return 7
        if x % 16 == 0:
            return 14                 # thin vertical ruler
        if (x + y) % 8 == 4:
            return 8                  # calm 45-degree hatch
        return 1 + (x // 16 + y // 16) % 4

im = Image.new('P', (W, H))
flat = [255, 0, 255]                  # index 0 : unused magenta
for rgb in PALETTE:
    flat += list(rgb)
flat += [0, 0, 0] * (256 - 17)
im.putpalette(flat)
px = im.load()

pix = bytearray(W * H)
for y in range(H):
    for x in range(W):
        v = f(x, y)
        pix[y * W + x] = v
        px[x, y] = v + 1

im.save('mire.png')
with open('mire.pix', 'wb') as fh:
    fh.write(pix)
print('mire.png + mire.pix : %dx%d, style %s'
      % (W, H, 'coded' if CODED else 'visual'))
