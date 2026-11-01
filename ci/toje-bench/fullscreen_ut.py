#!/usr/bin/env python3
"""Replay examples/fullscreen under toje, headless : a picture copied by DrawFullscreenImage."""

#     cd examples/fullscreen
#     python3 ../../ci/toje-bench/fullscreen_ut.py dist/to8.fd
#
# The game mode copies src/mire.png, converted by <png2bin buffer="fullscreen">,
# into both screen buffers with DrawFullscreenImage, then swaps them at every
# frame without drawing. The witnesses say when it runs ($9C00 = $CA) and when
# both buffers hold the picture ($9C01 = $0D).
#
# Two captures, two frames apart from each other by one (each buffer shown
# once), are compared with the picture, pixel by pixel : the picture index ->
# screen colour relation must be a function, and one to one (no two indexes on
# one colour) — a block copied to the wrong place, a swapped bank or a
# reversed block breaks it.
#
# toje's capture is 704x624 : the 320x200 screen at (32, 112), a BM16 pixel
# 4 capture pixels wide and 2 tall.
#
# Exit code : 0 pass, 1 fail, 2 no verdict.
import os
import signal
import sys

from PIL import Image

from mcp import Toje

WITNESS = '$9C00'


def check(png, mire):
    """The capture against the picture ; returns a list of faults."""
    cap = Image.open(png).convert('RGB')
    px = mire.load()
    rel, faults = {}, []
    for y in range(200):
        for x in range(160):
            c = cap.getpixel((32 + 4 * x + 1, 112 + 2 * y))
            i = px[x, y]
            if rel.setdefault(i, c) != c:
                faults.append('(%d,%d) : index %d shows %s, elsewhere %s' % (x, y, i, c, rel[i]))
                if len(faults) > 5:
                    return faults
    if len(set(rel.values())) != len(rel):
        faults.append('two indexes show the same colour : %s' % rel)
    return faults


def main(argv):
    disk = os.path.abspath(argv[0])
    mire = Image.open('src/mire.png')
    signal.alarm(600)                      # a toje call may never come back
    t = Toje()
    t.boot_floppy(disk, settle=1)        # the witnesses say when it runs
    for _ in range(2000):
        t.call('run_frames', {'n': 1})
        w = t.read(WITNESS, 2)
        if w[0] == 0xCA and w[1] == 0x0D:
            break
    else:
        print('no verdict : the pictures were never copied')
        return 2
    failed = 0
    for shot in range(2):                  # one buffer, then the other
        t.call('run_frames', {'n': 1})
        faults = check(t.call('screenshot')['path'], mire)
        print('buffer %d : %s' % (shot, 'FAIL' if faults else 'exact'))
        for f in faults:
            print('    ' + f)
        failed += bool(faults)
    t.close()
    return 0 if failed == 0 else 1


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
