#!/usr/bin/env python3
"""Frame rate of the mscroll1 example at a few camera speeds.

    python3 tools/fps.py dist/to8.fd

The example's main loop increments $9C00 once per rendered frame ; toje
runs 50 Hz video frames. For each speed (pixels per 50 Hz frame, the unit
mscroll1 integrates with the frame drop), the camera runs 500 video frames
(10 s) and the loops are counted.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import check as C  # noqa: E402

SPEEDS = [
    ('still', 0, 0),
    ('x 1 px', 0, 0x0100),
    ('x 4 px', 0, 0x0400),
    ('x 8 px', 0, 0x0800),
    ('x 16 px', 0, 0x1000),
    ('y 2 lines', 0x0200, 0),
    ('y 6 lines', 0x0600, 0),
    ('diag 6/3', 0x0300, 0x0600),
]


def main():
    t = C.Toje()
    t.boot_floppy(os.path.abspath(sys.argv[1]))
    t.call('run_frames', {'n': 20})
    frames = 500
    for tag, sy, sx in SPEEDS:
        b = ['%02X' % v for v in ((sy >> 8) & 0xFF, sy & 0xFF, (sx >> 8) & 0xFF, sx & 0xFF)]
        t.call('write_memory', {'addr': hex(C.SPEEDS), 'bytes': b})
        t.call('run_frames', {'n': 20})
        loops = 0
        last = t.read(C.COUNTER, 1)[0]
        for _ in range(frames // 10):
            t.call('run_frames', {'n': 10})
            v = t.read(C.COUNTER, 1)[0]
            loops += (v - last) & 0xFF
            last = v
        print('%-10s %5.1f fps (%.2f video frames per loop)' % (tag, loops * 50 / frames, frames / max(loops, 1)))
        # back near the map's left edge for the next speed
        t.call('write_memory', {'addr': hex(C.SPEEDS), 'bytes': ['00', '00', 'F0', '00']})
        t.call('run_frames', {'n': 60})


if __name__ == '__main__':
    main()
