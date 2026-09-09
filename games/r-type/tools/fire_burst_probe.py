#!/usr/bin/env python3
"""Mesurer une rafale d'appuis dans UNE fenetre de rendu : autant de tirs,
espaces comme a la borne ?

    python3 tools/fire_burst_probe.py dist/to8.fd [rafales] [appuis] [hold] [repos]

Entre au stage 2 (invincible), pousse le vaisseau a gauche, puis, `rafales`
fois : attend que le pool n'ait plus de tir, presse A `appuis` fois de suite
(press_joystick hold_frames=`hold`, puis `repos` trames), et scrute le pool
chaque trame pendant quatorze trames. Compte les slots de tir vus et l'ecart
en x des tirs vivants ensemble.

PIEGE DE MESURE : sous toje, press_joystick hold_frames=N dure 2N trames
(N enfoncees, N relachees — mesure sur gfxlock.frame.count). Un appui
« hold 1 » toutes les 0 trames de repos fait donc un appui toutes les DEUX
trames, et deux tirs voisins doivent etre a 2 x 6 = 12 px l'un de l'autre.

Attendu avec la liste d'appuis (09/09/2026) : `appuis` tirs, ecartes de
(2 x hold + repos) trames x 6 px, plus le defilement d'un rendu s'ils sont
nes a des rendus differents (la position de naissance suit le vaisseau a la
trame de l'appui, et le retard est rattrape a 6 px la trame). Avant, avec le
bit : un seul tir par rendu, les appuis d'une meme fenetre fondus.
"""
import os
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
POOL, NOBJ, OSZ, XPOS = 0x4000, 60, 63, 18
ID_WEAPON = 5                        # ObjID_Weapon (objid-common.const.asm)

image = os.path.abspath(sys.argv[1])
bursts = int(sys.argv[2]) if len(sys.argv) > 2 else 8
per = int(sys.argv[3]) if len(sys.argv) > 3 else 3
hold = int(sys.argv[4]) if len(sys.argv) > 4 else 1
rest = int(sys.argv[5]) if len(sys.argv) > 5 else 0

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
    """{slot: x} des tirs vivants."""
    raw = []
    for off in range(0, NOBJ * OSZ, 256):
        raw += t.read('%04X' % (POOL + off), min(256, NOBJ * OSZ - off))
    return {i: (raw[i * OSZ + XPOS] << 8) | raw[i * OSZ + XPOS + 1]
            for i in range(NOBJ) if raw[i * OSZ] == ID_WEAPON}


def stage_sym(name):
    m = re.search(r'"name":"stage2","container":"stage","page":\d+,"address":(\d+)', occ)
    base = int(m.group(1))
    return base + equ('gen/stages/02/build/stage02-main.lwmap', name)


TAPCOUNT = stage_sym('joypad.latch.tapCount')
TAPS = stage_sym('joypad.taps')
TAPS_N = stage_sym('joypad.taps.count')

# le vaisseau a GAUCHE, que ses tirs vivent une vingtaine de trames a l'ecran
# (au point de ralliement, pres du bord droit, un tir sortait en deux trames
# et la lecture du pool le manquait)
t.call('press_joystick', {'joystick': 0, 'direction': 'left', 'hold_frames': 90})
t.call('run_frames', {'n': 20, 'fast': True, 'timeout_ms': 600000})


t.call('press_joystick', {'joystick': 0, 'button_a': True, 'hold_frames': 3})   # la chauffe
t.call('run_frames', {'n': 60, 'fast': True, 'timeout_ms': 600000})
total = 0
for b in range(bursts):
    for _ in range(12):
        if not weapons():
            break
        t.call('run_frames', {'n': 15, 'fast': True, 'timeout_ms': 600000})
    t.call('run_frames', {'n': 1 + b, 'fast': True, 'timeout_ms': 600000})
    for k in range(per):
        t.call('press_joystick', {'joystick': 0, 'button_a': True, 'hold_frames': hold})
        if k < per - 1 and rest:
            t.call('run_frames', {'n': rest, 'timeout_ms': 600000})
    latch = t.read('%04X' % TAPCOUNT, 1)[0]
    seen = {}
    best = {}
    for f in range(14):
        t.call('run_frames', {'n': 1, 'fast': True, 'timeout_ms': 600000})
        w = weapons()
        if os.environ.get('VERBOSE') and b < 2:
            lc = t.read('%04X' % (ENG + equ(ENGMAP, 'gfxlock.frame.lastCount') + 1), 1)[0]
            print('   +%2d : %s  taps.count %d  taps %s  lastCount %d' % (f, w, t.read('%04X' % TAPS_N, 1)[0], t.read('%04X' % TAPS, 4), lc), flush=True)
        seen.update(w)
        if len(w) > len(best):
            best = w
    xs = sorted(best.values())
    gaps = [xs[i + 1] - xs[i] for i in range(len(xs) - 1)]
    total += len(seen)
    print('rafale %d : %d slots de tir vus, %d vivants ensemble, x = %s, ecarts %s (verrou avant lecture : %d appuis)'
          % (b, len(seen), len(best), xs, gaps, latch), flush=True)
print('%d rafales de %d appuis (toutes les %d trames) : %d tirs sur %d attendus, ecart attendu %d px' % (bursts, per, 2 * hold + rest, total, bursts * per, 6 * (2 * hold + rest)))
t.close()
