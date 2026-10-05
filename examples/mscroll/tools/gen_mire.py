#!/usr/bin/env python3
"""examples/mscroll test pattern.

Two styles, 8x16 tiles :

  ids (default) — 1024x240 px, wide enough for the camera to cross the
  ribbon's map-fixed seams (every 160 px) both ways. Every tile shows its
  own id (0-255) as two colour patches (high nibble above, low nibble
  below the orange ruler), and the ids are laid out pseudo-randomly : a
  wrong tile, a column fed into the wrong slot or a row read from the wrong
  place shows up as a different code. Readable by a human too : long
  horizontal rulers cross the whole map (white on every tile's line 0,
  orange on line 8 — a one-pixel vertical offset breaks them with a visible
  step), a cyan vertical ruler on every tile's column 0, and a 45-degree
  hatch. At most 256 distinct tiles.

  --coded — 256x240 px, the original forensic pattern : every pixel line of
  every tile encodes its own (column, row, line) as nibbles, so a single
  byte read from the code buffer names exactly what was written there.
  Noisy to look at, unbeatable for post-mortem decoding. It never crosses a
  seam (the camera stops at x = 96).

The byte-exact check (tools/diag_check.py) compares the screen against the
pixel source written next to the PNG, and reads the geometry from the
<mscroll> element's .equ.

Outputs :
  mire.png — indexed PNG (colours 1..16 hold hardware 0..15), the builder's
             <mscroll> element consumes it at build time
  mire.pix — the same pixels as raw bytes (one hardware colour per byte,
             row-major), read by tools/diag_check.py

usage : python3 tools/gen_mire.py [--coded]   (from examples/mscroll)
"""
import sys
from PIL import Image

CODED = '--coded' in sys.argv

COLS, ROWS = (32, 15) if CODED else (128, 15)
TILE_W, TILE_H = 8, 16
W, H = COLS * TILE_W, ROWS * TILE_H

# 16 visually distinct colours for hardware values 0..15
PALETTE = [
    (0, 0, 0), (85, 85, 85), (170, 170, 170), (255, 255, 255),
    (200, 30, 30), (255, 140, 0), (255, 230, 0), (60, 180, 40),
    (0, 200, 180), (40, 90, 220), (150, 60, 200), (255, 100, 170),
    (120, 70, 20), (170, 200, 90), (90, 130, 130), (255, 200, 150),
]

if CODED:
    def f(x, y):
        col, i = divmod(x, TILE_W)
        row, l = divmod(y, TILE_H)
        return (l & 15, col & 15, col >> 4, row,
                (col + row + l) & 15, 15 - l,
                (col * 3 + row * 5) & 15, 10)[i]
else:
    def tile_id(col, row):
        return (col * 37 + row * 101 + (col * row) % 7) & 255

    def f(x, y):
        col, i = divmod(x, TILE_W)
        row, l = divmod(y, TILE_H)
        if l == 0:
            return 3                  # white ruler, full width
        if l == 8:
            return 5                  # orange ruler, full width
        if i == 0:
            return 8                  # cyan vertical ruler
        t = tile_id(col, row)
        if 2 <= i <= 5 and 3 <= l <= 5:
            return t >> 4             # the id, high nibble
        if 2 <= i <= 5 and 11 <= l <= 13:
            return t & 15             # the id, low nibble
        if (x + y) % 8 == 4:
            return 2                  # 45-degree hatch
        return 0

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
      % (W, H, 'coded' if CODED else 'ids'))
