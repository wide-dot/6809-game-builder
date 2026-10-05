#!/usr/bin/env python3
"""Where the cycles go in the mscroll1 example, per routine.

    python3 tools/profile.py dist/to8.fd [speed_y speed_x frames]

Runs the camera at a constant speed (8.8, pixels per 50 Hz frame ; default
3 lines down, 6 px right) and profiles toje's PCs, folded on the game
mode's symbols (gen/assets/build/gm.lwmap, loaded at $6100) : the code
buffer ($0000-$3FFF, the blast) and the other pages are reported apart.
Cycles are given per rendered frame (the example's loop counter at $9C00).
"""
import bisect
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import check as C  # noqa: E402


def routines():
    syms = []
    for line in open(C.LWMAP):
        m = re.match(r'Symbol: (\S+) \(.*\) = ([0-9A-Fa-f]+)', line)
        if m and not m.group(1).startswith('@'):
            syms.append((C.GM_BASE + int(m.group(2), 16), m.group(1)))
    syms.sort()
    return syms


def main():
    sy = int(sys.argv[2], 0) if len(sys.argv) > 2 else 0x0300
    sx = int(sys.argv[3], 0) if len(sys.argv) > 3 else 0x0600
    frames = int(sys.argv[4]) if len(sys.argv) > 4 else 250
    syms = routines()
    keys = [a for a, _ in syms]
    t = C.Toje()
    t.boot_floppy(os.path.abspath(sys.argv[1]))
    b = ['%02X' % v for v in ((sy >> 8) & 0xFF, sy & 0xFF, (sx >> 8) & 0xFF, sx & 0xFF)]
    t.call('write_memory', {'addr': hex(C.SPEEDS), 'bytes': b})
    t.call('run_frames', {'n': 20})
    c0 = t.read(C.COUNTER, 1)[0]
    t.call('profile_reset')
    t.call('profile_start')
    t.call('run_frames', {'n': frames})
    t.call('profile_stop')
    loops = (t.read(C.COUNTER, 1)[0] - c0) & 0xFF
    top = t.call('profile_top', {'n': 1000})
    total = top['total_cycles']
    fold = {}
    for row in top['rows']:
        pc = int(row['pc'], 16)
        if pc < 0x4000:
            name = '(code buffer : blast)'
        elif pc >= 0xE000:
            name = '(monitor / ROM)'
        elif pc < 0x6100 or pc >= 0xA000:
            name = '(outside the game mode $%04X)' % (pc & 0xF000)
        else:
            i = bisect.bisect_right(keys, pc) - 1
            name = syms[i][1] if i >= 0 else '?'
        fold[name] = fold.get(name, 0) + row['cycles']
    print('%d video frames, %d loops (%.1f fps), %d cycles profiled (top 1000 PCs : %d)'
          % (frames, loops, loops * 50 / frames, total, sum(fold.values())))
    for name, cyc in sorted(fold.items(), key=lambda kv: -kv[1])[:20]:
        print('  %-40s %6.1f%%  %7d cycles/loop' % (name, 100 * cyc / total, cyc / max(loops, 1)))


if __name__ == '__main__':
    main()
