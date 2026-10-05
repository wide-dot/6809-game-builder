#!/usr/bin/env python3
"""Byte-exact screen check of the mscroll example.

    python3 tools/diag_check.py dist/to8.fd [--random N]

Boots the image under toje, takes the camera over (the example's demo
drift leaves mscroll.camera.speed/speedx alone until a joypad input, so
the probe writes them directly), and after each leg compares the visible
screen with the map.

The expected image comes from tools/gen_mire.py's pixel source (mire.pix,
one hardware colour per byte), the geometry from the <mscroll> element's
gen/mire/mire.mscroll.equ. The model is UNIFORM : screen row s, BM16
column x shows map pixel (xr + x, camera.y + s), xr = camera.x rounded
down to 2 px (the scroll's step) — the ribbon seam is compensated by the
engine, so a seam regression shows up as a whole region shifted by a line.

BM16 layout : for every 4 px group, RAMA holds pixels 0,1 and RAMB pixels
2,3 (two nibbles each). The 8 px of each side are the masked edges (the S
byte offset spills there) : they are reported apart, and only the 144 px
between them (groups 2 to 37) must match.

The scripted legs cross the map-fixed seams (every 160 px) both ways, at
2 px steps and faster, diagonally, and at the clamps ; --random N appends
a seeded random walk. Speeds stay at or under 4 px per 50 Hz frame : the
full-screen BM16 blast takes ~3 frames, and 8 px/frame makes the
frame-drop compensation run away (the 8.8 sum overflows). Exits non-zero
when a centre byte mismatches.
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

EQU = dict(re.findall(r'mire\.(\w+)\s+equ (\d+)', open('gen/mire/mire.mscroll.equ').read()))
MAP_W, MAP_H = int(EQU['MAP_WIDTH']), int(EQU['MAP_HEIGHT'])

with open('mire.pix', 'rb') as fh:
    PIX = fh.read()
assert len(PIX) == MAP_W * MAP_H, 'mire.pix does not match the geometry'


def symbol(name):
    for line in open(LWMAP):
        m = re.match(r'Symbol: %s \(.*\) = ([0-9A-Fa-f]+)' % re.escape(name), line)
        if m:
            return GM_BASE + int(m.group(1), 16)
    raise SystemExit('symbol %s not found in %s' % (name, LWMAP))


def group(x, y, plane):
    """The plane byte of the 4 px group at map pixel (x, y)."""
    y %= MAP_H
    o = x + 2 * plane
    return (PIX[y * MAP_W + o % MAP_W] << 4) | PIX[y * MAP_W + (o + 1) % MAP_W]


def word(t, addr):
    b = t.read(hex(addr), 2)
    return (b[0] << 8) | b[1]


def drive(t, sy, sx, frames):
    b = ['%02X' % v for v in ((sy >> 8) & 0xFF, sy & 0xFF, (sx >> 8) & 0xFF, sx & 0xFF)]
    t.call('write_memory', {'addr': hex(SPEEDS), 'bytes': b})
    t.call('run_frames', {'n': frames})
    t.call('write_memory', {'addr': hex(SPEEDS), 'bytes': ['00'] * 4})
    t.call('run_frames', {'n': 40})   # let both screen buffers settle


def check(t, tag):
    cx, cy = word(t, CAMX), word(t, CAMY)
    xr = cx & ~1
    # both buffers converged after the settle : read screen buffer 0
    t.call('write_memory', {'addr': '0xE7E5', 'bytes': ['02']})
    planes = []
    for base in (0xC000, 0xA000):     # RAMA half, RAMB half
        data = []
        for off in range(0, 8000, 1000):
            data += t.read(hex(base + off), 1000)
        planes.append(data)
    bad = edge = 0
    rows = {}
    for s in range(200):
        for g in range(40):
            for plane in (0, 1):
                got = planes[plane][s * 40 + g]
                want = group(xr + 4 * g, cy + s, plane)
                if got == want:
                    continue
                if not 2 <= g < 38:
                    edge += 1
                    continue
                bad += 1
                rows[s] = rows.get(s, 0) + 1
                if bad <= 6:
                    print('%s : line %3d group %2d plane %d : got %02X want %02X'
                          % (tag, s, g, plane, got, want))
    lines = ' lines %s' % sorted(rows)[:10] if rows else ''
    print('%-12s camera=(%3d,%3d) centre %s, %d edge bytes%s'
          % (tag, cx, cy, 'OK' if bad == 0 else '%d BAD' % bad, edge, lines))
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
drive(t, 0, 0, 1)                      # stop the demo drift
bad += check(t, 'start')
legs = [
    ('right 2px', 0, 0x0200, 100),     # across the 160 px seam at 2 px steps
    ('right 1px', 0, 0x0100, 150),     # across 320, odd positions on the way
    ('down-right', 0x0100, 0x0300, 100),
    ('left fast', 0, -0x0600, 60),     # back across two seams
    ('up-left', -0x0080, -0x0100, 200),  # half a line : the fraction paths
    ('right fast', 0x0200, 0x0400, 220),  # 4 px/frame up to the right clamp
    ('left clamp', -0x0100, -0x0400, 240),  # all the way back to x = 0
]
if '--random' in sys.argv:
    import random
    rnd = random.Random(0x6809)
    n = int(sys.argv[sys.argv.index('--random') + 1])
    for i in range(n):
        legs.append(('walk %d' % i,
                     rnd.choice([0, 1, -1]) * rnd.randrange(0, 0x0600, 0x40),
                     rnd.choice([0, 1, -1]) * rnd.randrange(0, 0x0400, 0x40),
                     rnd.randrange(3, 80)))
for tag, sy, sx, n in legs:
    drive(t, sy, sx, n)
    bad += check(t, tag)
print('RESULT', 'OK' if bad == 0 else 'FAIL (%d centre bytes)' % bad)
sys.exit(1 if bad else 0)
