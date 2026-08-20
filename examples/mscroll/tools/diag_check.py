#!/usr/bin/env python3
"""Byte-exact screen check of the mscroll example after diagonal motion.

    TOJE_MCP=<toje>/scripts/toje-mcp.sh \
    python3 tools/diag_check.py dist/to8.fd

Drives the camera through the four diagonals (down to both horizontal
clamps, then up at the joypad's slow speed and back), stopping and
verifying the WHOLE visible screen after each leg. Both clamps are
multiples of 8 px, which keeps the decode byte-aligned.

The expected image is computed from tools/gen_mire.py's pixel source
(mire.pix, one hardware colour per byte), so the check works for any
pattern style. The model is UNIFORM : screen row s, column x shows map
pixel (camera.x+x, camera.y+s) — the ribbon seam is compensated by the
engine (map-fixed shear, see engine mscroll.asm), so no seam term belongs
here ; a seam regression shows up as one-pixel-shifted columns.

Prints mismatching 8px cells (capped) and a per-column bad count, exits
non-zero if any cell mismatches.
"""
import os
import re
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                '..', '..', '..', 'ci', 'toje-bench'))
from mcp import Toje

LWMAP = 'gen/assets/game-modes/to8/main/build/main.lwmap'
GM_BASE = 0x6100
COUNTER = '0x9C00'

MAP_W, MAP_H = 256, 240               # tools/gen_mire.py geometry

with open('mire.pix', 'rb') as fh:
    PIX = fh.read()
assert len(PIX) == MAP_W * MAP_H, 'mire.pix does not match the geometry'


def symbol(name):
    for line in open(LWMAP):
        m = re.match(r'Symbol: %s \(.*\) = ([0-9A-Fa-f]+)' % re.escape(name),
                     line)
        if m:
            return GM_BASE + int(m.group(1), 16)
    raise SystemExit('symbol %s not found in %s' % (name, LWMAP))


def cell_bytes(mx, my, plane):
    """The two plane bytes of the 8px cell at map pixel (mx, my).
    Byte interleave : plane A holds pixel pairs (0,1) and (4,5) of the
    cell, plane B pairs (2,3) and (6,7)."""
    p = PIX[my * MAP_W + mx:my * MAP_W + mx + 8]
    if plane == 0:
        return ((p[0] << 4) | p[1], (p[4] << 4) | p[5])
    return ((p[2] << 4) | p[3], (p[6] << 4) | p[7])


def drive(t, sy, sx, frames):
    b = ['%02X' % v for v in ((sy >> 8) & 0xFF, sy & 0xFF,
                              (sx >> 8) & 0xFF, sx & 0xFF)]
    t.call('write_memory', {'addr': hex(SPEEDS), 'bytes': b})
    t.call('run_frames', {'n': frames})
    t.call('write_memory', {'addr': hex(SPEEDS), 'bytes': ['00'] * 4})
    t.call('run_frames', {'n': 40})   # let both screen buffers settle


def check(t, tag):
    cx = t.read(hex(CAMX), 2)
    cx = (cx[0] << 8) | cx[1]
    cy = t.read(hex(CAMY), 2)
    cy = (cy[0] << 8) | cy[1]
    if cx % 8:
        raise SystemExit('%s : camera.x=%d is not 8px aligned, adjust the '
                         'drive lengths' % (tag, cx))
    # both buffers converged after the settle : read screen buffer 0
    t.call('write_memory', {'addr': '0xE7E5', 'bytes': ['02']})
    planes = []
    for base in (0xC000, 0xA000):     # RAMA half, RAMB half
        data = []
        for off in range(0, 8000, 1000):
            data += t.read(hex(base + off), 1000)
        planes.append(data)
    bad = 0
    percol = {}
    for s in range(200):
        my = (cy + s) % MAP_H
        for cell in range(20):
            mx = cx + cell * 8
            for plane in (0, 1):
                got = (planes[plane][s * 40 + cell * 2],
                       planes[plane][s * 40 + cell * 2 + 1])
                want = cell_bytes(mx, my, plane)
                if got != want:
                    bad += 1
                    percol[mx // 8] = percol.get(mx // 8, 0) + 1
                    if bad <= 12:
                        print('%s : line %3d col %2d plane %d : '
                              'got %02X %02X want %02X %02X'
                              % (tag, s, mx // 8, plane,
                                 got[0], got[1], want[0], want[1]))
    for c in sorted(percol):
        print('%s : col %2d : %d bad cells' % (tag, c, percol[c]))
    print('%s : camera=(%d,%d) %s' % (tag, cx, cy,
          'OK' if bad == 0 else '%d bad cells' % bad))
    return bad


SPEEDS = symbol('mscroll.camera.speed')   # y then x, 4 contiguous bytes
CAMX = symbol('mscroll.camera.x')
CAMY = symbol('mscroll.camera.y')

t = Toje()
t.boot_floppy(os.path.abspath(sys.argv[1]))

base = t.read(COUNTER, 1)[0]
for _ in range(60):
    t.call('run_frames', {'n': 10})
    if t.read(COUNTER, 1)[0] != base:
        break
else:
    raise SystemExit('the game mode never started (counter still)')

bad = 0
# down-right to the x=96 clamp, then down-left back to the x=0 clamp :
# every 8px column crosses the feed in both directions, rows keep feeding.
# Then the same going UP (the other updategfx direction), at the joypad's
# slow half-pixel speed so the 8.8 fraction paths run too.
drive(t, 0x0100, 0x0100, 150)
bad += check(t, 'down-right')
drive(t, 0x0100, -0x0100, 150)
bad += check(t, 'down-left')
drive(t, -0x0080, 0x0080, 300)
bad += check(t, 'up-right')
drive(t, -0x0100, -0x0100, 150)
bad += check(t, 'up-left')

sys.exit(1 if bad else 0)
