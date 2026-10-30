#!/usr/bin/env python3
"""Replay examples/keyboard under toje, headless : keyboard.fast, the 6804's
frames read by the game.

    TOJE_MCP=<toje with the 6804 fix>/scripts/toje-mcp.sh \\
    python3 ci/toje-bench/keyboard_ut.py examples/keyboard [--cycles]

The script presses keys through toje's 6804 (press_key) and checks what the
game mode logged : each frame keyboard.fast.read returned, in order, with
its "pressed" flag (examples/keyboard/readme.md has the witness layout).
Every key of the TO8, Shift + arrows, CNT + letters, CAPS LOCK kept off, a
held key's repeats, 20 keys in a row ; read in the main loop, then polled in
the IRQ routine. --cycles times keyboard.fast.read in toje's cycle counter.

Needs a toje whose 6804 leaves CRC bit 0 to the CPU (wide-dot/toje#64) and
whose 6846 drops its IRQ line for a CP1 flag with CRC bit 0 off : with an
older one the monitor's interrupt takes the frames, and the bench fails.

Exit code : 0 pass, 1 fail, 2 no verdict.
"""
import os, re, sys

from mcp import Toje

BENCH = 0x9C00
LOG = 0x9D00
MODE_IRQ, MODE_QUIET = 0x01, 0x80
SHIFT, CNT = '51', '53'
NO_KEY = (0x38, 0x48)
CAPS = 0x40
ARROWS = (0x04, 0x05, 0x0D, 0x3D)                      # up right left down
LETTERS = {c: k for c, k in zip(
    'ABCDEFGHIJKLMNOPQRSTUVWXYZ',
    (0x2A, 0x0F, 0x1F, 0x1B, 0x1A, 0x13, 0x0B, 0x03, 0x3A, 0x33, 0x3B, 0x43, 0x4B,
     0x07, 0x42, 0x4A, 0x2B, 0x12, 0x23, 0x0A, 0x32, 0x17, 0x2F, 0x27, 0x02, 0x22))}

t = None
failed = []
ran = [0]


def state():
    b = t.read('$%04X' % BENCH, 11)
    return {'magic': b[0], 'mode': b[1], 'logged': b[2], 'count': b[3],
            'frame': b[4] << 8 | b[5], 'pressed': b[6] << 8 | b[7],
            'held': b[8] << 8 | b[9], 'irq': b[10]}


def log_since(n0, n1):
    """Return the log entries n0..n1-1 : (frame, pressed)."""
    out = []
    for n in range(n0, n1):
        b = t.read('$%04X' % (LOG + 2 * (n % 128)), 2)
        w = b[0] << 8 | b[1]
        out.append((w & 0x1FF, bool(w & 0x8000)))
    return out


def run(n):
    if n:
        t.call('run_frames', {'n': n, 'timeout_ms': 20000})


def key(code, mods=(), hold=3, gap=3, repeats=0):
    """Hold mods, press the key for hold frames, then release it.

    Repeats adds that many more 'down' events (the 6804's repeat), hold frames
    apart ; gap frames follow the release.
    """
    for m in mods:
        t.call('press_key', {'scancode': m, 'down': True})
    t.call('press_key', {'scancode': '%02X' % code, 'down': True})
    run(hold)
    for _ in range(repeats):
        t.call('press_key', {'scancode': '%02X' % code, 'down': True})
        run(hold)
    t.call('press_key', {'scancode': '%02X' % code, 'down': False})
    for m in reversed(mods):
        t.call('press_key', {'scancode': m, 'down': False})
    run(gap)


def check(name, presses, expected, extra=None):
    """Press the keys, compare the new log entries with expected."""
    ran[0] += 1
    s0 = state()
    for p in presses:
        if isinstance(p, tuple):
            key(*p)
        else:
            key(p)
    s1 = state()
    got = log_since(s0['logged'], s1['logged'])
    ok = got == expected and (s1['count'] - s0['count']) % 256 == len(expected)
    why = ''
    if extra:
        e = extra(s0, s1)
        ok, why = ok and e[0], e[1]
    print('%s %-34s %d frames%s' % ('PASS' if ok else 'FAIL', name, len(got), why))
    if not ok:
        failed.append(name)
        fmt = lambda l: ' '.join('%03X%s' % (f, 'p' if p else 'r') for f, p in l)
        print('     expected %s\n     got      %s' % (fmt(expected), fmt(got)))
    return s1


def held_check():
    """Check a held key : pressed once, then repeats ; held while down, none after."""
    ran[0] += 1
    s0 = state()
    t.call('press_key', {'scancode': '3D', 'down': True})
    run(4)
    during = [state()['held']]
    for _ in range(5):
        t.call('press_key', {'scancode': '3D', 'down': True})      # the 6804's repeat
        run(4)
        during.append(state()['held'])
    t.call('press_key', {'scancode': '3D', 'down': False})
    run(3)
    after = state()['held']
    got = log_since(s0['logged'], state()['logged'])
    expected = [(0x03D, True)] + [(0x03D, False)] * 5
    ok = got == expected and all(h == 0x03D for h in during) and after == 0xFFFF
    print('%s %-34s %d frames, held %s then %04X' % ('PASS' if ok else 'FAIL', 'held key : 5 repeats',
          len(got), '/'.join('%03X' % h for h in sorted(set(during))), after))
    if not ok:
        failed.append('held key')
        print('     got %s' % got)


def symbols(example):
    """Return the game mode's symbols, at their address."""
    cfg = open(os.path.join(example, 'to8.config.xml')).read()
    base = int(re.search(r'name="gm.keyboard"[^>]*address="\$([0-9A-Fa-f]+)"', cfg).group(1), 16)
    sym = {}
    for line in open(os.path.join(example, 'gen/gm/build/keyboard.lwmap')):
        m = re.match(r'Symbol: (\S+) .* = ([0-9A-F]+)', line)
        if m:
            sym[m.group(1)] = base + int(m.group(2), 16)
    return sym


def clk():
    return t.call('machine_state')['clocks']['cpu_cycles']


def span(sym, start, end, limit=300000):
    t.call('run_until_pc', {'pc': '$%04X' % sym[start], 'max_instructions': limit})
    c0 = clk()
    t.call('run_until_pc', {'pc': '$%04X' % sym[end], 'max_instructions': 300000})
    return clk() - c0


def cycles(example):
    """Time keyboard.fast.read between read.call and read.done."""
    sym = symbols(example)
    span_read = lambda: span(sym, 'read.call', 'read.done')
    print('cycles of keyboard.fast.read, jsr included :')
    print('  no frame, no key down   %s' % sorted({span_read() for _ in range(8)}))
    for name, keys in (('LEFT', ['0D']), ('CNT+SHIFT+A', [CNT, SHIFT, '2A']), ('CAPS LOCK', ['40'])):
        t.call('run_until_pc', {'pc': '$%04X' % sym['read.done'], 'max_instructions': 300000})
        for k in keys:                                          # pressed between two reads
            t.call('press_key', {'scancode': k, 'down': True})
        for _ in range(50):                                     # the reads before the call
            with_frame = span_read()
            if with_frame > 500:
                break
        idle = span_read()
        print('  %-12s frame read %5d, then a key down, no frame %d' % (name, with_frame, idle))
        for k in reversed(keys):
            t.call('press_key', {'scancode': k, 'down': False})
        run(3)
    t.call('write_memory', {'addr': '$%04X' % (BENCH + 1), 'bytes': ['%02X' % (MODE_QUIET | MODE_IRQ)]})
    run(2)
    print('cycles of keyboard.fast.poll in the IRQ routine, no frame, jsr included : %s'
          % sorted({span(sym, 'poll.call', 'poll.done') for _ in range(4)}))


def main(argv):
    global t
    example = argv[0]
    t = Toje()
    t.boot_floppy(os.path.join(example, 'dist/to8.fd'), settle=1)
    if '--cycles' in argv:
        print('cycles of keyboard.fast.init, jsr included : %d'
              % span(symbols(example), 'init.call', 'init.done', 5000000))
    for _ in range(40):
        run(25)
        if state()['magic'] == 0xCA:
            break
    else:
        print('BENCH keyboard NO VERDICT : the game mode never ran')
        t.dump()
        sys.exit(2)

    t.call('write_memory', {'addr': '$%04X' % (BENCH + 1), 'bytes': ['%02X' % MODE_QUIET]})
    print('-- read in the main loop, at every pass')
    keys = [k for k in range(0x50) if k not in NO_KEY + (CAPS,)]
    check('every key alone', keys, [(k, True) for k in keys])
    check('CAPS LOCK, then A : caps kept off', [CAPS, LETTERS['A'], CAPS, LETTERS['A']],
          [(0x0C0, True), (0x02A, True), (0x0C0, True), (0x02A, True)])
    check('Shift + arrows, Shift + A', [(k, (SHIFT,)) for k in ARROWS + (LETTERS['A'],)],
          [(0x080 | k, True) for k in ARROWS + (LETTERS['A'],)])
    ctl = [LETTERS[c] for c in 'ARSNGLVJKXY']
    check('CNT + letters', [(k, (CNT,)) for k in ctl], [(0x100 | k, True) for k in ctl])
    check('CNT + Shift + A', [(LETTERS['A'], (CNT, SHIFT))], [(0x1AA, True)])
    held_check()
    check('the same key twice', [LETTERS['Z'], LETTERS['Z']], [(0x022, True), (0x022, True)])
    burst = [LETTERS[c] for c in 'THEQUICKBROWNFOXJUMP']
    check('20 keys in a row (1 frame each)', [(k, (), 1, 1) for k in burst], [(k, True) for k in burst])

    t.call('write_memory', {'addr': '$%04X' % (BENCH + 1), 'bytes': ['%02X' % (MODE_QUIET | MODE_IRQ)]})
    run(2)
    print('-- polled first thing in the IRQ routine, read once a frame')
    irq_reads = lambda s0, s1: ((s1['irq'] - s0['irq']) % 256 > 0,
                                ', %d read in the IRQ' % ((s1['irq'] - s0['irq']) % 256))
    check('20 keys in a row', [(k, (), 2, 2) for k in burst], [(k, True) for k in burst], irq_reads)
    check('Shift + arrows', [(k, (SHIFT,)) for k in ARROWS], [(0x080 | k, True) for k in ARROWS], irq_reads)
    check('CNT + letters', [(k, (CNT,)) for k in ctl], [(0x100 | k, True) for k in ctl], irq_reads)

    t.call('write_memory', {'addr': '$%04X' % (BENCH + 1), 'bytes': ['00']})
    run(2)
    print('-- on screen')
    shot = [(LETTERS['A'], (), 10, 10), (0x0D, (SHIFT,), 10, 10), (LETTERS['R'], (CNT,), 10, 10)]
    check('A, Shift + LEFT, CNT + R', shot, [(0x02A, True), (0x08D, True), (0x112, True)])
    # B pressed while A's frame is still being printed (~3.5 frames) : the
    # 6804's call waits for the read, the game busy meanwhile
    check('a key while the game is busy', [(LETTERS['A'], (), 1, 0), (LETTERS['B'], (), 10, 10)],
          [(0x02A, True), (0x00F, True)])
    png = os.path.abspath(os.path.join(example, 'dist', 'keyboard.png'))
    t.call('screenshot', {'path': png})
    print('screen : %s' % png)

    if '--cycles' in argv:
        t.call('write_memory', {'addr': '$%04X' % (BENCH + 1), 'bytes': ['%02X' % MODE_QUIET]})
        run(2)
        cycles(example)
    t.close()
    if failed:
        print('BENCH keyboard FAIL %d/%d : %s' % (ran[0] - len(failed), ran[0], ', '.join(failed)))
        sys.exit(1)
    print('BENCH keyboard PASS : %d/%d' % (ran[0], ran[0]))
    sys.exit(0)


if __name__ == '__main__':
    main(sys.argv[1:])
