#!/usr/bin/env python3
"""Generate the tile scroll example's decor animation, as a tile index .bin.

Same file shape as the map (16 bit big endian, column major) : it IS a map,
just a small one read by <tilepatch> instead of <tilemap>. The frames are laid
SIDE BY SIDE, so frame f is a contiguous run of cols*rows indexes — which is
what lets the builder slice by range rather than gather.

A measuring pattern, not artwork. Two things have to be checkable from memory,
and each is checked by a different property :

  the CELL ORDER   the four cells of a frame carry four DIFFERENT tiles, so a
                   row/column-major mix-up in the patch routine lands the wrong
                   tile in the wrong cell and shows up as a transposition ;

  the FRAME ORDER  the four tiles rotate by one position per frame, so the
                   sequence is readable from any single cell — and a sequencer
                   that skips, repeats or reverses a frame is visible without
                   comparing the whole rectangle.

Frame 0 lays tiles 1,2,3,4 column major over 2x2 :

    col 0        col 1
    +------+     +------+
    | 1    |     | 3    |   row 0
    +------+     +------+
    | 2    |     | 4    |   row 1
    +------+     +------+

and frame f rotates that list left by f.
"""
import struct
import os

COLS, ROWS, FRAMES = 2, 2, 4
TILES = [1, 2, 3, 4]          # the example's real tiles ; 0 stays the poison one

out = []
for f in range(FRAMES):
    rot = TILES[f:] + TILES[:f]
    # column major inside the frame, frames laid side by side : writing the
    # frames in order and each frame column major gives exactly the layout
    # <tilepatch> expects.
    for c in range(COLS):
        for r in range(ROWS):
            out.append(rot[c * ROWS + r])

path = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                    'src', 'assets', 'maps', 'patch.bin')
with open(path, 'wb') as fh:
    for v in out:
        fh.write(struct.pack('>H', v))

print('%s : %d frames of %dx%d, %d indexes'
      % (path, FRAMES, COLS, ROWS, len(out)))
for f in range(FRAMES):
    blk = out[f * COLS * ROWS:(f + 1) * COLS * ROWS]
    print('  frame %d  col0=(%d,%d)  col1=(%d,%d)' % (f, blk[0], blk[1], blk[2], blk[3]))
