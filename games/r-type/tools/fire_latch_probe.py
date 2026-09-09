#!/usr/bin/env python3
"""Mesurer la prise en compte des appuis brefs sur le bouton de tir.

    python3 tools/fire_latch_probe.py dist/to8.fd [appuis] [trames d'appui]

Entre au stage 2 (invincible, sans manette), puis presse le bouton A pendant
DEUX trames video (40 ms, le plus court que l'IRQ voie : un appui d'une
trame tombe entre deux echantillons sous toje) a des instants quelconques,
`appuis` fois, et compte les tirs (ObjID_Weapon) apparus dans le pool. Un
premier appui de chauffe est ignore : le premier press_joystick de toje
branche la manette (le bit 2 de $E7CD bascule) sans front sur le bouton. Avant le verrou sous IRQ
(09/09/2026), le bouton n'etait lu qu'une fois par trame rendue : un appui
de 20 ms n'etait vu que s'il tombait sur l'instant de lecture — un sur
cinq environ a 9 img/s. Avec le verrou, chaque appui fait un tir.

Le compte se fait sur les APPARITIONS : le pool est relu apres chaque appui,
un slot qui prend l'identifiant du tir alors qu'il ne l'avait pas compte
une fois.
"""
import os
import random
import re
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                '..', '..', '..', 'ci', 'toje-bench'))
from mcp import Toje

os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def equ(mapfile, name):
    for l in open(mapfile):
        m = re.match(r'Symbol: %s \(.*\) = ([0-9A-Fa-f]+)' % re.escape(name), l)
        if m:
            return int(m.group(1), 16)
    raise SystemExit('symbole %s absent de %s' % (name, mapfile))


def unit_base(name):
    occ = open('dist/occupancy-fd.html').read()
    m = re.search(r'"name":"%s","container":"[^"]*","page":(\d+),"address":(\d+)'
                  % re.escape(name), occ)
    return int(m.group(1)), int(m.group(2))


ENGMAP = 'gen/common/build/engine.lwmap'
BSTAGE = equ('gen/stages/01/build/stage01-main.lwmap', 'bench.stage')
_, ENG = unit_base('common.engine')
WAIT = ENG + equ(ENGMAP, 'gfxlock.bufferSwap.wait')
POOL, NOBJ, OSZ = 0x4000, 60, 63
ID_WEAPON = 5                        # ObjID_Weapon (objid-common.const.asm)

image = os.path.abspath(sys.argv[1])
taps = int(sys.argv[2]) if len(sys.argv) > 2 else 30
hold = int(sys.argv[3]) if len(sys.argv) > 3 else 2

t = Toje()
for i in range(1, 9):
    for what in ('clear_watchpoint', 'clear_breakpoint'):
        try:
            t.call(what, {'id': i})
        except Exception:
            pass
t.boot_floppy(image)
t.call('set_pointer_device', {'device': 'none'})
t.call('run_frames', {'n': 1200, 'fast': True, 'timeout_ms': 600000})
occ = open('dist/occupancy-fd.html').read()
m = re.search(r'"name":"title.cheat","container":"title","page":(\d+),"address":(\d+)', occ)
page, base = int(m.group(1)), int(m.group(2))
pstage = equ('gen/title/build/cheat.lwmap', 'tct.pstage')
launch = equ('gen/title/build/cheat.lwmap', 'title.cheat.launch')
t.call('set_breakpoint', {'pc': '%04X' % WAIT})
t.call('run_to_breakpoint', {'timeout_ms': 120000})
t.call('clear_breakpoint', {'id': 1})
t.call('write_memory', {'addr': 'E7E6', 'bytes': ['%02X' % (0x60 + page)]})
t.call('write_memory', {'addr': hex(base + pstage), 'bytes': ['02', '01']})
t.call('set_register', {'reg': 'dp', 'value': '9F'})
t.call('set_register', {'reg': 'pc', 'value': '%04X' % (base + launch)})
t.call('step')
for _ in range(40):
    t.call('run_frames', {'n': 100, 'fast': True, 'timeout_ms': 600000})
    if t.read('%04X' % BSTAGE, 1)[0] == 2:
        break
else:
    raise SystemExit('le stage 2 n\'a jamais pris la main')
t.call('run_frames', {'n': 100, 'fast': True, 'timeout_ms': 600000})


def weapons():
    raw = []
    for off in range(0, NOBJ * OSZ, 256):
        raw += t.read('%04X' % (POOL + off), min(256, NOBJ * OSZ - off))
    return set(i for i in range(NOBJ) if raw[i * OSZ] == ID_WEAPON)


random.seed(1)
t.call('press_joystick', {'joystick': 0, 'button_a': True, 'hold_frames': 3})   # la chauffe
t.call('run_frames', {'n': 40, 'fast': True, 'timeout_ms': 600000})
seen = 0
for i in range(taps):
    # attendre que le pool n'ait plus aucun tir : un tir vit ~40 trames, et
    # compter les slots nouveaux ratait un tir ne dans le slot qu'un tir
    # precedent venait de liberer
    for _ in range(12):
        if not weapons():
            break
        t.call('run_frames', {'n': 15, 'fast': True, 'timeout_ms': 600000})
    t.call('run_frames', {'n': random.randint(1, 9), 'fast': True, 'timeout_ms': 600000})
    t.call('press_joystick', {'joystick': 0, 'button_a': True, 'hold_frames': hold})
    # le tir nait au rendu qui suit et peut sortir du cadre vite : on
    # scrute le pool toutes les deux trames pendant seize trames
    hit = False
    for _ in range(8):
        if weapons():
            hit = True
            break
        t.call('run_frames', {'n': 2, 'fast': True, 'timeout_ms': 600000})
    seen += hit
    if not hit and os.environ.get('VERBOSE'):
        p = t.read('9F00', 40)
        print('appui %d rate : player subtype %d routine %d x %d y %d' % (
            i, p[1] if p[1] < 128 else p[1] - 256, p[34], (p[18] << 8) | p[19], (p[21] << 8) | p[22]), flush=True)
print('%d appuis de %d trame(s) video : %d tirs apparus (%d %%)' % (taps, hold, seen, 100 * seen // taps))
t.close()
