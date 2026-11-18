#!/usr/bin/env python3
"""Replay examples/stackcopy under toje, headless : stackcopy.run checked and timed."""

#     cd examples/stackcopy
#     python3 ../../ci/toje-bench/stackcopy_ut.py dist/to8.fd
#
# The game mode copies blocks in RAM page 5 with stackcopy.run, the 50 Hz
# interrupt on, and checks each copy byte by byte with 16 bytes on either side
# (witnesses at $9C00 : +1 $0D all passed or $E0+n test n failed, +2 the tests
# passed, +3 the interrupts taken during a copy, +5 1 during a copy).
#
# The bench stops at every interrupt (IrqManager) while the tests run : the
# interrupted S must never point into the data window ($A000-$DFFF), where
# the copy's S pushes — an interrupt taken there would push its frame into the
# destination.
#
# Then the timed copies : the cycles from time.call to time.done (the jsr
# included, toje's profiler), for each length, the interrupts masked.
#
# Exit code : 0 pass, 1 fail, 2 no verdict.
import os
import re
import signal
import sys

from mcp import Toje

WITNESS = 0x9C00
TESTS = 17


def symbols():
    """The game mode's symbols, at their address."""
    cfg = open('to8.config.xml').read()
    base = int(re.search(r'name="assets.gm.main"[^>]*address="\$([0-9A-Fa-f]+)"', cfg).group(1), 16)
    sym = {}
    for line in open('gen/assets/game-modes/to8/main/build/main.lwmap'):
        m = re.match(r'Symbol: (\S+) .* = ([0-9A-F]+)', line)
        if m:
            sym[m.group(1)] = base + int(m.group(2), 16)
    return sym


def main(argv):
    disk = os.path.abspath(argv[0])
    sym = symbols()
    signal.alarm(1200)                     # a toje call may never come back
    t = Toje()
    t.boot_floppy(disk, settle=1)

    hits = inside = 0
    status = 0
    for _ in range(20000):                 # every interrupt until the verdict
        r = t.call('run_until_pc', {'pc': '$%04X' % sym['IrqManager'], 'max_instructions': 400000})
        w = t.read('%04X' % WITNESS, 6)
        status = w[1] if w[0] == 0xCA else 0
        if status == 0x0D or status >= 0xE0:
            break
        if not r.get('reached'):
            continue
        if w[5]:                           # during a copy
            hits += 1
            s = t.call('read_registers')['s']
            s = int(s, 16) if isinstance(s, str) else s
            if 0xA000 <= s < 0xE000:
                inside += 1
                print('interrupt with S at $%04X, in the data window' % s)
        t.call('step', {'count': 1})
    else:
        print('no verdict : the tests never ended')
        return 2
    w = t.read('%04X' % WITNESS, 6)
    irqs = (w[3] << 8) | w[4]
    print('tests : %d/%d passed%s' % (w[2], TESTS, '' if status == 0x0D else ', test %d failed' % (status - 0xE0)))
    print('interrupts during the copies : %d (game mode count), %d stopped at, %d with S in the data window'
          % (irqs, hits, inside))

    lens = {}
    for _ in range(12):                    # the timed copies, a length at a time
        t.call('run_until_pc', {'pc': '$%04X' % sym['time.call'], 'max_instructions': 400000})
        n = t.read('%04X' % sym['t.len'], 2)
        t.call('profile_reset')
        t.call('profile_start')            # toje's profiler counts the cycles
        t.call('run_until_pc', {'pc': '$%04X' % sym['time.done'], 'max_instructions': 400000})
        t.call('profile_stop')
        c = t.call('profile_top', {'n': 1})['total_cycles']
        lens.setdefault((n[0] << 8) | n[1], set()).add(c)
    print('cycles of stackcopy.run, jsr included :')
    for n in sorted(lens):
        c = sorted(lens[n])
        print('  %5d bytes : %s%s' % (n, c, '  (%.2f a byte)' % (c[0] / n) if n else ''))
    t.close()
    failed = status != 0x0D or w[2] != TESTS or inside or hits == 0
    print('BENCH stackcopy %s' % ('FAIL' if failed else 'PASS'))
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
