#!/usr/bin/env python3
"""Replay examples/mea8000 under toje, headless : a sentence said by the speech synthesizer."""

#     cd examples/mea8000
#     python3 ../../ci/toje-bench/mea8000_ut.py dist/to8.fd
#
# The program says a sentence of eight speech files (3.7 s) over and over with a
# two-second pause, through mea8000.stream.read. The witnesses say when it runs
# ($9C00 = $CA) and how many plays completed ($9C01). With the speech card
# plugged (toje's default) a play takes the chip's real time : REQ paces every
# byte, so two completed plays within 20 s prove that the chip accepted the
# stream, frame after frame, and that the player came back from each file.
# Without the card REQ never comes and the count stays at 0.
#
# Exit code : 0 pass, 1 fail, 2 no verdict.
import os
import signal
import sys

from mcp import Toje

WITNESS = '$9C00'


def main(argv):
    disk = os.path.abspath(argv[0])
    signal.alarm(600)
    t = Toje()
    t.boot_floppy(disk, settle=1)
    frames = 0
    for _ in range(300):
        t.call('run_frames', {'n': 5})
        frames += 5
        w = t.read(WITNESS, 2)
        if w[0] == 0xCA:
            break
    else:
        print('no verdict : the program never ran ($9C00 != $CA)')
        return 2
    started = frames
    for _ in range(240):                         # 24 s at most
        t.call('run_frames', {'n': 5})
        frames += 5
        w = t.read(WITNESS, 2)
        if w[1] >= 2:
            break
    plays = w[1]
    secs = (frames - started) / 50.0
    print('mea8000 : %d play(s) completed in %.1f s' % (plays, secs))
    if plays < 2:
        print('FAIL : fewer than two plays in %.1f s' % secs)
        return 1
    if secs < 8.0:
        print('FAIL : two plays in %.1f s — the chip did not pace the stream' % secs)
        return 1
    print('PASS')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
