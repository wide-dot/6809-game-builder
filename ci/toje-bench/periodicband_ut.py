#!/usr/bin/env python3
"""
Replay examples/periodicband under toje, headless : the periodic band bench.

    cd examples/periodicband
    python3 ../../ci/toje-bench/periodicband_ut.py dist/to8.fd

The game mode draws the band (src/band.png, period 48) at each of its 48
phases in turn, on a screen filled with colour 15 (a colour the band never
uses). The script arms the bench ($A5 at $9C05) : the game mode then holds
each phase until the script, its capture checked, writes the counter back
($9C02 -> $9C04). The witnesses say which phase is on screen (+1) and when
both buffers hold it (+2 moves).

For every phase, the capture is compared with the picture at that phase :

1. inside the window (x 8-151, lines 60-99) each pixel shows the picture's
   pixel (x - 8 + phase) mod 48, the background where the picture is
   transparent : the picture index -> screen colour relation must be a
   function, and one to one (no two indexes on one colour) ;
2. outside the window, everything is the background, but for the side
   margins (x 0-7 and 152-159) of the band's lines and of the lines just
   above and below : the strips may spill there (the runtime's contract, a
   playfield mask covers them in a game).

toje's capture is 704x624 : the 320x200 screen at (32, 112), a BM16 pixel
4 capture pixels wide and 2 tall.

Exit code : 0 pass, 1 fail, 2 no verdict.
"""
import os
import signal
import sys

from PIL import Image

from mcp import Toje

P, X0, Y0, WIDTH = 48, 8, 60, 144
WITNESS = '$9C00'


def check(png, band, phase):
    """The capture against the picture at the phase ; returns a list of faults."""
    cap = Image.open(png).convert('RGB')

    def screen(x, y):
        return cap.getpixel((32 + 4 * x + 1, 112 + 2 * y))

    h = band.size[1]
    px = band.load()
    bg = screen(80, 10)
    rel, faults = {'bg': bg}, []
    for y in range(h):
        for x in range(WIDTH):
            i = px[(x + phase) % P, y] or 'bg'
            c = screen(X0 + x, Y0 + y)
            if rel.setdefault(i, c) != c:
                faults.append('window (%d,%d) : index %s shows %s, elsewhere %s'
                              % (x, y, i, c, rel[i]))
                if len(faults) > 5:
                    return faults
    if len(set(rel.values())) != len(rel):
        faults.append('two indexes show the same colour : %s' % rel)
    for y in range(200):
        for x in range(160):
            inside = X0 <= x < X0 + WIDTH and Y0 <= y < Y0 + h
            margin = (x < X0 or x >= X0 + WIDTH) and Y0 - 1 <= y <= Y0 + h
            if not inside and not margin and screen(x, y) != bg:
                faults.append('outside (%d,%d) : %s, not the background' % (x, y, screen(x, y)))
                if len(faults) > 5:
                    return faults
    return faults


def main(argv):
    disk = os.path.abspath(argv[0])
    band = Image.open('src/band.png')
    signal.alarm(1200)                     # a toje call may never come back
    t = Toje()
    t.boot_floppy(disk, settle=1)        # the witnesses say when it runs
    for _ in range(2000):
        t.call('run_frames', {'n': 1})
        if t.read(WITNESS, 1)[0] == 0xCA:
            break
    else:
        print('no verdict : the game mode never ran')
        return 2
    t.call('write_memory', {'addr': '9C05', 'bytes': ['A5']})   # armed
    failed, last = 0, 0                 # the counter starts at 0, phase 0 makes it 1
    for phase in range(P):
        for _ in range(100):
            w = t.read(WITNESS, 3)
            if w[1] == phase and w[2] != last:
                break
            t.call('run_frames', {'n': 1})
        else:
            print('no verdict : phase %d never shown' % phase)
            return 2
        last = w[2]
        faults = check(t.call('screenshot')['path'], band, phase)
        t.call('write_memory', {'addr': '9C04', 'bytes': ['%02X' % last]})   # checked
        if faults:
            failed += 1
            print('phase %2d : FAIL' % phase)
            for f in faults:
                print('    ' + f)
    t.close()
    print('%d/%d phases exact' % (P - failed, P))
    return 0 if failed == 0 else 1


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
