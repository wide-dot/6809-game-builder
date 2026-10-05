#!/usr/bin/env python3
"""Byte-exact screen check of the mscroll1 example.

    python3 tools/check.py dist/to8.fd [--quick | --random N]

Boots the image under toje, then drives the camera along a scripted path
(writing mscroll1.camera.speed/speedx, the demo mode leaves them alone),
stopping and comparing the visible screen with the map after each leg. The
expected image comes from tools/gen_mire.py's own pixel function : screen
row s, column p shows map pixel (xr + p, camera.y + s), xr being camera.x
rounded down to a multiple of 8 (the 8 px step).

mscroll1.mask blacks the two zones the blast cannot get right : byte 39 of
every line (the overlap slot's wrong half, when x mod 16 >= 8) and the top
line (the hole the S byte offset leaves at the start of the band). Both
must read zero, and the 312 x 199 px left must match the map exactly.
Prints the first mismatching bytes and a per-byte-column count, exits
non-zero on any mismatch.
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, '..', '..', '..', 'ci', 'toje-bench'))
import gen_mire  # noqa: E402
from mcp import Toje  # noqa: E402

LWMAP = 'gen/assets/build/gm.lwmap'
GM_BASE = 0x6100
COUNTER = '0x9C00'


def symbol(name):
    for line in open(LWMAP):
        m = re.match(r'Symbol: %s \(.*\) = ([0-9A-Fa-f]+)' % re.escape(name), line)
        if m:
            return GM_BASE + int(m.group(1), 16)
    raise SystemExit('symbol %s not found in %s' % (name, LWMAP))


SPEEDS = symbol('mscroll1.camera.speed')   # y then x, 4 contiguous bytes
CAMX = symbol('mscroll1.camera.x')
CAMY = symbol('mscroll1.camera.y')
MAINLOOP = symbol('mainLoop')


def word(t, addr):
    b = t.read(hex(addr), 2)
    return (b[0] << 8) | b[1]


def drive(t, sy, sx, frames):
    b = ['%02X' % v for v in ((sy >> 8) & 0xFF, sy & 0xFF, (sx >> 8) & 0xFF, sx & 0xFF)]
    t.call('write_memory', {'addr': hex(SPEEDS), 'bytes': b})
    t.call('run_frames', {'n': frames})
    t.call('write_memory', {'addr': hex(SPEEDS), 'bytes': ['00'] * 4})
    t.call('run_frames', {'n': 40})   # let both screen buffers settle


def expected_byte(x, y):
    v = 0
    for i in range(8):
        v = (v << 1) | gen_mire.map_pixel(x + i, y)
    return v


def screens(t):
    """Both screen buffers (pages 2 and 3, RAMA), read at the top of the
    main loop : there both hold a finished frame (anywhere else the back
    buffer may be half drawn — blasted but not yet masked). The data window
    is switched to read them, then given back."""
    t.call('run_until_pc', {'pc': '%04X' % MAINLOOP, 'max_instructions': 2000000})
    page = t.call('read_page_map')['data_page']
    out = []
    for p in (2, 3):
        t.call('write_memory', {'addr': '0xE7E5', 'bytes': ['%02X' % p]})
        data = []
        for off in range(0, 8000, 1000):
            data += t.read(hex(0xC000 + off), 1000)
        out.append(data)
    t.call('write_memory', {'addr': '0xE7E5', 'bytes': ['%02X' % page]})
    return out


def check(t, tag):
    cx, cy = word(t, CAMX), word(t, CAMY)
    xr = cx & ~7
    bad = 0
    percol = {}
    for buf, data in enumerate(screens(t)):
        for s in range(200):
            y = cy + s
            for col in range(40):
                got = data[s * 40 + col]
                masked = s == 0 or col == 39
                want = 0 if masked else expected_byte(xr + col * 8, y)
                if got != want:
                    percol[col] = percol.get(col, 0) + 1
                    bad += 1
                    if bad <= 8:
                        print('%s : buffer %d line %3d byte %2d : got %02X want %02X%s'
                              % (tag, buf, s, col, got, want, ' (mask)' if masked else ''))
    cols = ' '.join('%d:%d' % (c, n) for c, n in sorted(percol.items()))
    print('%s : camera=(%d,%d) %s%s'
          % (tag, cx, cy, 'OK' if bad == 0 else '%d BAD' % bad,
             (' [' + cols + ']') if percol else ''))
    return bad


def main():
    t = Toje()
    t.boot_floppy(os.path.abspath(sys.argv[1]))
    base = t.read(COUNTER, 1)[0]
    for _ in range(60):
        t.call('run_frames', {'n': 10})
        if t.read(COUNTER, 1)[0] != base:
            break
    else:
        raise SystemExit('the game mode never started (counter still)')
    # stop the demo drift and look at where it left the camera
    t.call('write_memory', {'addr': hex(SPEEDS), 'bytes': ['00'] * 4})
    t.call('run_frames', {'n': 40})
    bad = check(t, 'start')
    legs = [
        ('right', 0, 0x0300, 120),          # 3 px/frame : crosses seams at 320, 640...
        ('down-right', 0x0200, 0x0200, 100),
        ('down-left', 0x0180, -0x0280, 100),
        ('up-right', -0x0080, 0x0100, 200),  # half a line per frame : fraction paths
        ('up-left', -0x0200, -0x0200, 80),
        ('fast right', 0, 0x1000, 120),      # 16 px/frame : one feed per frame or more
        ('fast down', 0x0C00, 0, 60),
        ('fast left', -0x0100, -0x1000, 60),
    ]
    if '--quick' in sys.argv:
        legs = legs[:2]
    if '--random' in sys.argv:
        # a seeded random walk : speeds up to 16 px/frame across, 12 lines
        # down or up, short and long legs — seams crossed both ways at
        # every phase, the vertical wrap, the clamps
        import random
        rnd = random.Random(0x6809)
        n = int(sys.argv[sys.argv.index('--random') + 1])
        legs = []
        for i in range(n):
            sx = rnd.choice([0, 1, -1]) * rnd.randrange(0, 0x1000, 0x40)
            sy = rnd.choice([0, 1, -1]) * rnd.randrange(0, 0x0C00, 0x40)
            legs.append(('walk %d' % i, sy, sx, rnd.randrange(3, 80)))
    for tag, sy, sx, n in legs:
        drive(t, sy, sx, n)
        bad += check(t, tag)
    print('RESULT', 'OK' if bad == 0 else 'FAIL (%d bytes)' % bad)
    sys.exit(1 if bad else 0)


if __name__ == '__main__':
    main()
