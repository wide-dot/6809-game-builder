#!/usr/bin/env python3
"""
Replay a bench example under toje, headless, against its committed reference.

    python3 ci/toje-bench/bench.py examples/overlay            # verdict
    python3 ci/toje-bench/bench.py examples/overlay --update   # new reference

The example describes its bench in bench.json (docs/lang/en/benches.md) :

    {"disk": "dist/to8.fd", "witnesses": "9C00", "tests": 30,
     "blocks": {"sweep": ["9D00", 256]}, "until": [["9DFE", "CB"]],
     "frames": 2000}

and writes its witnesses in RAM, loader-ut's convention : +$00 $CA once the
game mode runs, +$01.. $01 per passing test, +$1F $0D once the sequence
completed, +$20.. one word per test (a checksum the test recorded). The
named blocks are read whole, once every "until" byte holds its value (work
the bench does after its sequence).

The verdict : every test at $01, and the whole block (results, words,
blocks) identical to bench.ref, the reference committed next to bench.json.
A changed checksum is a changed picture : either a bug, or a change meant,
and then --update writes the new reference, to commit with it.

Exit code : 0 pass, 1 fail, 2 no verdict.
"""
import json, os, sys

from mcp import Toje


def witnesses(t, desc):
    """Run the bench until it completes ; return the reference lines, or None."""
    base = int(desc.get('witnesses', '9C00'), 16)
    tests = desc['tests']
    for _ in range(max(1, desc.get('frames', 2000) // 25)):
        t.call('run_frames', {'n': 25, 'timeout_ms': 20000})
        b = t.read('$%04X' % base, 0x20 + 2 * tests)
        if b[0] == 0xCA and b[0x1F] == 0x0D and all(
                t.read('$' + addr, 1)[0] == int(value, 16) for addr, value in desc.get('until', [])):
            break
    else:
        return None
    lines = ['t%02d %02X %04X' % (n, b[n], b[0x20 + 2 * (n - 1)] << 8 | b[0x21 + 2 * (n - 1)])
             for n in range(1, tests + 1)]
    for name, (addr, length) in sorted(desc.get('blocks', {}).items()):
        data = t.read('$' + addr, length)
        lines += ['%s %s+%03X %s' % (name, addr, k, bytes(data[k:k + 32]).hex().upper())
                  for k in range(0, length, 32)]
    return lines


def main(argv):
    """Replay the bench of the example directory argv[0]."""
    ex = argv[0]
    with open(os.path.join(ex, 'bench.json'), encoding='utf-8') as f:
        desc = json.load(f)
    ref_path = os.path.join(ex, 'bench.ref')
    t = Toje()
    t.boot_floppy(os.path.join(ex, desc.get('disk', 'dist/to8.fd')))
    lines = witnesses(t, desc)
    if lines is None:
        print('BENCH %s NO VERDICT : the sequence never completed' % ex)
        t.dump()
        t.close()
        sys.exit(2)
    t.close()
    failed = [l.split()[0] for l in lines if l.startswith('t') and l.split()[1] != '01']
    if '--update' in argv:
        with open(ref_path, 'w', encoding='utf-8') as f:
            f.write('\n'.join(lines) + '\n')
        print('BENCH %s : reference written (%d lines)' % (ex, len(lines)))
    ref = open(ref_path, encoding='utf-8').read().split('\n')[:-1] if os.path.exists(ref_path) else []
    moved = [(r, l) for r, l in zip(ref, lines) if r != l]
    if len(ref) != len(lines):
        moved.append(('%d reference lines' % len(ref), '%d now' % len(lines)))
    for r, l in moved:
        print('  reference : %s\n  now       : %s' % (r, l))
    if failed or moved:
        print('BENCH %s FAIL : %s%s' % (ex, ' '.join(failed) or 'all tests pass',
                                        ', %d line(s) off the reference' % len(moved) if moved else ''))
        sys.exit(1)
    print('BENCH %s PASS : %d/%d, identical to the reference' % (ex, desc['tests'], desc['tests']))
    sys.exit(0)


if __name__ == '__main__':
    main(sys.argv[1:])
