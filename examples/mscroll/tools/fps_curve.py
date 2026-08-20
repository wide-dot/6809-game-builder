#!/usr/bin/env python3
"""Frame-rate survey of the mscroll example, machine frame by machine frame.

    TOJE_MCP=<toje>/scripts/toje-mcp.sh \
    python3 tools/fps_curve.py dist/to8.fd releve.csv [options]

The game mode already counts its rendered frames (`inc $9C00` once per main
loop) : the emulator reads that byte without costing the measured program a
cycle. The camera is driven DIAGONALLY by poking the two speed words after
boot — the diagonal is the worst steady case (both feeds run).

CSV output, one line per machine frame, the exact format of
ci/toje-bench/fps_plot.py :
  machine_frame,rendered,delta,camera
    rendered   unrolled rendered-frame counter ($9C00 wraps at 256)
    delta      renders on this machine frame (0 or 1)
    camera     camera.x (the bottom band of the plot)

Symbol addresses are read from the build's lwmap : rebuild before measuring.
"""
import argparse
import os
import re
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                '..', '..', '..', 'ci', 'toje-bench'))
from mcp import Toje

LWMAP = 'gen/assets/game-modes/to8/main/build/main.lwmap'
GM_BASE = 0x6100
COUNTER = '0x9C00'


def symbol(name):
    for line in open(LWMAP):
        m = re.match(r'Symbol: %s \(.*\) = ([0-9A-Fa-f]+)' % re.escape(name),
                     line)
        if m:
            return '0x%X' % (GM_BASE + int(m.group(1), 16))
    raise SystemExit('symbol %s not found in %s' % (name, LWMAP))


p = argparse.ArgumentParser()
p.add_argument('image')
p.add_argument('out')
p.add_argument('--frames', type=int, default=500,
               help='machine frames to survey (500 = 10 emulated seconds)')
p.add_argument('--speed', default='0100',
               help='diagonal speed, signed 8.8 hex px/frame on both axes')
p.add_argument('--settle', type=int, default=100,
               help='machine frames left to run before the survey starts')
p.add_argument('--bounce', action='store_true',
               help='flip the horizontal speed at the clamps, so the column '
                    'feeds stay active over the whole survey even on a '
                    'narrow map (the mire has 96 px of x travel)')
args = p.parse_args()

speeds = symbol('mscroll.camera.speed')       # y then x, 4 contiguous bytes
camx = symbol('mscroll.camera.x')
camxmax = symbol('mscroll.camera.x.max')
v = int(args.speed, 16)
sp = [(v >> 8) & 0xFF, v & 0xFF]
spn = [(-v >> 8) & 0xFF, (-v) & 0xFF]         # the mirrored x speed

t = Toje()
t.boot_floppy(os.path.abspath(args.image))

# wait for the game mode (the rendered-frame counter starts moving)
base = t.read(COUNTER, 1)[0]
for _ in range(60):
    t.call('run_frames', {'n': 10})
    if t.read(COUNTER, 1)[0] != base:
        break
else:
    raise SystemExit('the game mode never started (counter still)')

# diagonal drive : down-right at the requested speed on both axes
t.call('write_memory', {'addr': speeds,
        'bytes': ['%02X' % b for b in sp + sp]})
t.call('run_frames', {'n': args.settle})

xm = t.read(camxmax, 2)
xm = (xm[0] << 8) | xm[1]
going = 1

rows = []
rendered = 0
prev = t.read(COUNTER, 1)[0]
for i in range(args.frames):
    t.call('run_frames', {'n': 1})
    cur = t.read(COUNTER, 1)[0]
    delta = (cur - prev) & 0xFF
    prev = cur
    rendered += delta
    cx = t.read(camx, 2)
    cx = (cx[0] << 8) | cx[1]
    rows.append((i, rendered, delta, cx))
    if args.bounce:
        if going > 0 and cx >= xm:
            going = -1
            t.call('write_memory', {'addr': hex(int(speeds, 16) + 2),
                    'bytes': ['%02X' % b for b in spn]})
        elif going < 0 and cx == 0:
            going = 1
            t.call('write_memory', {'addr': hex(int(speeds, 16) + 2),
                    'bytes': ['%02X' % b for b in sp]})

with open(args.out, 'w') as f:
    f.write('machine_frame,rendered,delta,camera\n')
    for r in rows:
        f.write('%d,%d,%d,%d\n' % r)

total = rows[-1][1]
secs = args.frames / 50.0
print('%d rendered frames over %d machine frames (%.1fs) : %.2f fps mean'
      % (total, args.frames, secs, total / secs))
print('camera.x %d -> %d' % (rows[0][3], rows[-1][3]))
print('wrote %s' % args.out)
