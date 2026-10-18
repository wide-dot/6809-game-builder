#!/usr/bin/env python3
"""
Replay a bench example under toje, headless, against its committed reference.

    python3 ci/toje-bench/bench.py examples/overlay            # verdict
    python3 ci/toje-bench/bench.py examples/overlay --update   # new reference

The example describes its bench in bench.json (docs/lang/en/benches.md) :

    {"disk": "dist/to8.fd", "witnesses": "9C00", "tests": 30,
     "blocks": {"sweep": ["9D00", 256]}, "until": [["9DFE", "CB"]],
     "frames": 2000}

"disk" may be a list : the same tests on each disk (an example's targets,
one per set of options), each line of the reference prefixed with its disk's
name.

The bench writes its witnesses in RAM : +0 $CA once the game mode runs, +1 N its
number of tests, +2 $0D once the sequence completed, +3.. one byte per test
($01 : pass), then one word per test (a value the test recorded, a VRAM
checksum ; 0 if none). The named blocks are read whole, once every "until"
byte holds its value (work the bench does after its sequence).

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
        h = t.read('$%04X' % base, 3)
        if h[0] == 0xCA and h[2] == 0x0D and all(
                t.read('$' + addr, 1)[0] == int(value, 16) for addr, value in desc.get('until', [])):
            break
    else:
        return None
    if h[1] != tests:
        return ['count %d, bench.json says %d' % (h[1], tests)]
    b = t.read('$%04X' % (base + 3), 3 * tests)
    lines = ['t%02d %02X %04X' % (n, b[n - 1], b[tests + 2 * (n - 1)] << 8 | b[tests + 2 * n - 1])
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
    disks = desc.get('disk', 'dist/to8.fd')
    disks = disks if isinstance(disks, list) else [disks]
    lines, failed = [], []
    for disk in disks:
        t = Toje()
        t.boot_floppy(os.path.join(ex, disk))
        some = witnesses(t, desc)
        if some is None:
            print('BENCH %s NO VERDICT : the sequence never completed on %s' % (ex, disk))
            t.dump()
            t.close()
            sys.exit(2)
        t.close()
        name = os.path.splitext(os.path.basename(disk))[0] + ' ' if len(disks) > 1 else ''
        failed += [name + l.split()[0] for l in some if l.startswith('t') and l.split()[1] != '01']
        lines += [name + l for l in some]
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
    print('BENCH %s PASS : %d/%d%s, identical to the reference'
          % (ex, desc['tests'], desc['tests'], ' on %d disks' % len(disks) if len(disks) > 1 else ''))
    sys.exit(0)


if __name__ == '__main__':
    main(sys.argv[1:])
