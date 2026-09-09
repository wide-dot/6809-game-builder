#!/usr/bin/env python3
"""Le cout d'un objet au compteur de cycles, par appel — pas au profileur.

    python3 tools/object_cost_probe.py dist/to8.fd <ids> <routine> [<routine>...]
    ex. gouger : 46,47,48,49 1 2     wick visible : 37 1

Generalisation de gouger_cost_probe.py (08/09/2026) : les identifiants et
les phases (l'octet routine de l'OST) viennent de la ligne de commande.

Le profileur toje ne connait pas les pages : deux routines a la meme adresse
dans deux pages cartouche se confondent sous un seul nom. Ici on mesure UN
appel a la fois : point d'arret a l'entree de gouger.Dive (ou Hidden),
lecture du compteur, puis course jusqu'a DisplaySprite — la sortie des trois
phases — et lecture du compteur. La page cartouche et l'id de l'objet en U
confirment que le point d'arret est bien le notre (une autre page peut
porter du code a la meme adresse). Meme geste pour un appel isole de
terrainCollision.do : course jusqu'a son adresse de retour, lue sur la pile.
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
CASTMAP = 'gen/enemies/build/stage2-cast.lwmap'
BSTAGE = equ('gen/stages/01/build/stage01-main.lwmap', 'bench.stage')
_, ENG = unit_base('common.engine')
WAIT = ENG + equ(ENGMAP, 'gfxlock.bufferSwap.wait')
DISPLAY = ENG + equ(ENGMAP, 'DisplaySprite')
TCDO = ENG + equ(ENGMAP, 'terrainCollision.do')
DROP = ENG + equ(ENGMAP, 'gfxlock.frameDrop.count')
CPAGE, CBASE = unit_base('stage2.cast')
DIVE = CBASE + equ(CASTMAP, 'gouger.Dive')
HIDDEN = CBASE + equ(CASTMAP, 'gouger.Hidden')
RUNOBJ = ENG + equ(ENGMAP, 'RunObjects')
POOL, NOBJ, OSZ, ROUTINE = 0x4000, 60, 63, 34
GOUGER_IDS = tuple(int(x) for x in sys.argv[2].split(','))
PHASES = [int(x) for x in sys.argv[3:]]

t = Toje()
for i in range(1, 9):
    for what in ('clear_watchpoint', 'clear_breakpoint'):
        try:
            t.call(what, {'id': i})
        except Exception:
            pass
t.boot_floppy(os.path.abspath(sys.argv[1]))
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
print('stage 2 en place', flush=True)


def regs():
    return t.call('read_registers')


def _find_cycles(o):
    if isinstance(o, dict):
        for k, v in o.items():
            if 'cycle' in k.lower() and isinstance(v, (int, float, str)):
                try:
                    return int(v)
                except ValueError:
                    pass
        for v in o.values():
            r = _find_cycles(v)
            if r is not None:
                return r
    return None


def cycles():
    for src in ('machine_state', 'read_registers'):
        c = _find_cycles(t.call(src))
        if c is not None:
            return c
    raise SystemExit('pas de compteur de cycles : %s' % t.call('machine_state'))


def gougers():
    raw = []
    for off in range(0, NOBJ * OSZ, 256):
        raw += t.read('%04X' % (POOL + off), min(256, NOBJ * OSZ - off))
    ph = {}
    for i in range(NOBJ):
        o = raw[i * OSZ:(i + 1) * OSZ]
        if o[0] in GOUGER_IDS:
            ph[o[ROUTINE]] = ph.get(o[ROUTINE], 0) + 1
    return ph


def dispatch_pc():
    """L'instruction `jsr [,x]` de RunObjects : l'entree de CHAQUE objet.
    Un point d'arret dans la page du cast serait touche par toutes les
    autres pages a la meme adresse (les tuiles compilees, des centaines de
    fois par trame) ; celui-ci l'est une fois par objet vivant."""
    d = t.call('disassemble', {'addr': '%04X' % RUNOBJ, 'lines': 24})
    for l in d['lines']:
        m = l['mnemonic'].lower().replace(' ', '')
        if m.startswith('jsr[,x]'):
            return int(l['addr'], 16)
    raise SystemExit('jsr [,x] introuvable dans RunObjects : %s' % d)


DISPATCH = None


def at_ours(phase):
    """Course jusqu'a l'entree d'UN gouger dans la phase voulue."""
    global DISPATCH
    if DISPATCH is None:
        DISPATCH = dispatch_pc()
        print('dispatch RunObjects a $%04X' % DISPATCH, flush=True)
    for _ in range(2000):
        t.call('set_breakpoint', {'pc': '%04X' % DISPATCH})
        t.call('run_to_breakpoint', {'timeout_ms': 60000})
        t.call('clear_breakpoint', {'id': 1})
        u = int(str(regs().get('u')), 16)
        o = t.read('%04X' % u, 40)
        if o[0] in GOUGER_IDS and o[ROUTINE] == phase:
            return u
        t.call('step')
    raise SystemExit('jamais un gouger en phase %d' % phase)


def bracket(run):
    """Cycles consommes par `run()` — le profileur sert de compteur."""
    t.call('profile_reset')
    t.call('profile_start')
    run()
    t.call('profile_stop')
    return int(t.call('profile_top', {'n': 1, 'by': 'cycles'})['total_cycles'])


def measure(phase, label, n):
    tot = []
    for _ in range(n):
        u = at_ours(phase)
        drop = t.read('%04X' % DROP, 1)[0] or 1

        res = {}

        def run():
            res.update(t.call('run_until_pc', {'pc': '%04X' % DISPLAY, 'max_instructions': 200000}))
        c = bracket(run)
        tot.append((c, drop, res.get('instructions'), res.get('reached')))
        t.call('run_frames', {'n': 3, 'fast': True, 'timeout_ms': 60000})
    for c, d, i, ok in tot:
        print('  %-8s %6d cycles, %s instructions pour %d trames de jeu = %5d cycles par trame %s'
              % (label, c, i, d, c // d, '' if ok else '(DisplaySprite non atteint)'))
    print('%s : moyenne %d cycles par trame de jeu' % (label, sum(c for c, _, _, _ in tot) // sum(d for _, d, _, _ in tot)))


def measure_probe(n):
    tot = []
    for _ in range(n):
        u = at_ours(2)
        # dans la plongee, la premiere sonde : course jusqu'a terrainCollision.do,
        # puis jusqu'a son adresse de retour
        t.call('set_breakpoint', {'pc': '%04X' % TCDO})
        t.call('run_to_breakpoint', {'timeout_ms': 60000})
        t.call('clear_breakpoint', {'id': 1})
        s = int(str(regs().get('s')), 16)
        ret = t.read('%04X' % s, 2)
        ret = (ret[0] << 8) | ret[1]
        res = {}
        c = bracket(lambda: res.update(t.call('run_until_pc', {'pc': '%04X' % ret, 'max_instructions': 100000})))
        tot.append((c, res.get('instructions')))
        t.call('run_frames', {'n': 3, 'fast': True, 'timeout_ms': 60000})
    print('terrainCollision.do (appel complet, page comprise) : %s (cycles, instructions), moyenne %d cycles'
          % (tot, sum(c for c, _ in tot) // len(tot)))


for phase in PHASES:
    for _ in range(400):
        t.call('run_frames', {'n': 25, 'fast': True, 'timeout_ms': 600000})
        if gougers().get(phase, 0) >= 1:
            break
    else:
        raise SystemExit('aucun objet en phase %d' % phase)
    print('objets par phase', gougers(), flush=True)
    measure(phase, 'phase %d' % phase, 6)
t.close()
