#!/usr/bin/env python3
"""Replay examples/overlay under toje, headless : the overlay sprite pack's bench.

    cd examples/overlay
    python3 ../../ci/toje-bench/overlay_ut.py dist/to8.fd [witnesses.txt]

The bench runs once and writes its witnesses at $9C00 (see the game mode's
main.asm) : +$00 magic $CA, +$01..+$19 $01 per passing test (t01..t25),
+$1F $0D once the sequence completed, +$20.. one word per test, the VRAM
checksum it recorded. The verdict is every test at $01.

The checksums are the differential handle : two builds differing only by
BuildSprites must write the same block. Given a file, the script writes the
block there (one line per test : rank, result, checksum), to diff two builds.

Exit code: 0 pass, 1 fail, 2 no verdict.
"""
import sys

from mcp import Toje

TESTS = 25


def main():
    disk = sys.argv[1]
    out = sys.argv[2] if len(sys.argv) > 2 else None

    t = Toje()
    t.boot_floppy(disk)
    for _ in range(40):
        t.call('run_frames', {'n': 25, 'timeout_ms': 20000})
        b = t.read('9C00', 0x20 + 2 * (TESTS + 1))
        if b[0] == 0xCA and b[0x1F] == 0x0D:
            break
    else:
        print('OVERLAY-UT NO VERDICT : the sequence never completed')
        t.dump()
        t.close()
        sys.exit(2)
    t.close()

    lines, failed = [], []
    for n in range(1, TESTS + 1):
        ok = b[n] == 0x01
        s = b[0x20 + 2 * (n - 1)] << 8 | b[0x21 + 2 * (n - 1)]
        lines.append('t%02d %s %04X' % (n, 'pass' if ok else 'FAIL', s))
        if not ok:
            failed.append('t%02d' % n)
    if out:
        with open(out, 'w') as f:
            f.write('\n'.join(lines) + '\n')
    print('\n'.join(lines))
    if failed:
        print('OVERLAY-UT FAIL : %s' % ' '.join(failed))
        sys.exit(1)
    print('OVERLAY-UT PASS : %d/%d' % (TESTS, TESTS))
    sys.exit(0)


if __name__ == '__main__':
    main()
