#!/usr/bin/env python3
"""Le profil de la sequence de fin (stage 8) sous toje : la cadence de rendu
de la mort du Bydo au stage 1, et le cout de chaque etape de la boucle a
PLEINE CHARGE (huit lignes de generique a l'ecran, la flotte).

    TOJE_MCP=<toje>/scripts/toje-mcp.sh TOJE_FAST=1 OUT=<dir> \\
    python3 tools/ending_profile_probe.py          (depuis games/r-type)

LA CADENCE : frame_budget_watch sur stage.loop, budget 1 cycle — chaque
intervalle entre deux sommets de boucle (un rendu) est releve, avec son cycle
de fin. 19 968 cycles = une trame TO8 a 50 Hz.
LES ETAPES : au premier rendu ou huit lignes sont a l'ecran, run_until_pc de
frontiere en frontiere (les `jsr` de la boucle, offsets du listing
gen/stages/08/build/stage08-main.lst, a relever si stage-main.asm bouge) et
total_cycles de l'anneau de trace entre deux ; quatre rendus. Le cout d'une
etape inclut les IRQ 50 Hz tombees pendant elle (mesurees a part : de
l'entree de stage.userIRQ a son retour).
Sorties : OUT/fps.json (intervalles), OUT/steps.json (etapes).
ONE=1 : un seul rendu a pleine charge, sans le releve de cadence ni la suite.
"""
import os, re, sys, json
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..', 'ci', 'toje-bench'))
from mcp import Toje

OUT = os.environ['OUT']


def equ(mapfile, name):
    for l in open(mapfile):
        m = re.match(r'Symbol: %s \(.*\) = ([0-9A-Fa-f]+)' % re.escape(name), l)
        if m:
            return int(m.group(1), 16)
    raise SystemExit('symbole %s absent de %s' % (name, mapfile))


def layout(name):
    for l in open('gen/layout.asm'):
        m = re.match(r'%s equ \$?([0-9A-Fa-f]+)\s*$' % re.escape(name), l.strip())
        if m:
            return int(m.group(1), 16)
    raise SystemExit('equate %s absente' % name)


def unit_base(name):
    occ = open('dist/occupancy-fd.html').read()
    m = re.search(r'"name":"%s","container":"[^"]*","page":(\d+),"address":(\d+)' % re.escape(name), occ)
    return int(m.group(1)), int(m.group(2))


MAIN = 'gen/stages/08/build/stage08-main.lwmap'
BASE = layout('stage.address')
_, ENG = unit_base('common.engine')
ENGMAP = 'gen/common/build/engine.lwmap'
WAIT = ENG + equ(ENGMAP, 'gfxlock.bufferSwap.wait')
BSTAGE = equ(MAIN, 'bench.stage')
LOOP = BASE + equ(MAIN, 'stage.loop')
USERIRQ = BASE + equ(MAIN, 'stage.userIRQ')
ROWT = BASE + equ(MAIN, 'ending.rowText')
TY = BASE + equ(MAIN, 'ending.textY')
def loop_calls():
    """the jsr of the stage loop, in order, read from the main's listing
    (gen/stages/08/build/stage08-main.lst): [(offset, target)]"""
    out, on = [], False
    for l in open('gen/stages/08/build/stage08-main.lst'):
        m = re.match(r'^([0-9A-F]{4}) +[0-9A-F]+ +\(.*?\):\d+ \[\d+\] +\d+ +(?:!)? *(jsr|lbra) +(\S+)', l)
        if 'stage.state.running' in l and l.startswith('0'):
            on = True
        if not (on and m):
            continue
        off, op, target = int(m.group(1), 16), m.group(2), m.group(3)
        if op == 'lbra':
            break
        out.append((off, target))
    return out


def steps():
    """the frontiers of the ENDING's path: RunObjects without
    RunFrozenObjects, the bg tiles before the sprites (no drawShip, no second
    frame.tiles), then the credits and the side columns of
    stage.overlay.normal (IFDEF stage.ENDING) — the first two paged.call
    after BuildSprites"""
    calls = loop_calls()
    names = {'joypad.latch.read': 'joypad.latch.read', 'ScrollCols': 'ScrollCols',
             'tilemap.flush': 'tilemap.flush', 'ObjectWave': 'ObjectWave',
             'RunObjects': 'RunObjects (la fin, la flotte, le rendu)', 'gfxlock.on': 'gfxlock.on',
             'stage.frameBlit': 'stage.frameBlit', 'BuildSprites': 'BuildSprites (flotte, vaisseau)',
             'gfxlock.off': 'gfxlock.off', 'stage.endTick': 'stage.endTick (fin : directeur, musique)',
             'gfxlock.loop': 'gfxlock.loop (attente de l echange)'}
    out, paged, seen_tiles, after_bs = [], 0, False, 0
    for off, tg in calls:
        if tg in names:
            out.append((names[tg], off))
            if tg == 'BuildSprites':
                after_bs = 1
        elif tg == 'paged.call':
            paged += 1
            if paged == 1:
                out.append(('collisions (paged.call)', off))
            elif paged == 2:
                out.append(('effacement du champ', off))
            elif paged == 3:
                out.append(('etoiles (starfield.draw)', off))
            elif after_bs == 1:
                out.append(('generique (credits.Draw)', off)); after_bs = 2
            elif after_bs == 2:
                out.append(('colonnes (viewport)', off)); after_bs = 3
        elif tg == 'Obj_Run' and not any(n.startswith('fondu') for n, _ in out):
            out.append(('fondu, joueur, pod, bits (Obj_Run x5)', off))
        elif tg == 'stage.frame.tiles' and not seen_tiles:
            out.append(('decor derriere (frame.tiles)', off)); seen_tiles = True
    return out


STEPS = steps()

t = Toje()
for i in range(1, 9):
    for what in ('clear_watchpoint', 'clear_breakpoint'):
        try:
            t.call(what, {'id': i})
        except Exception:
            pass
t.boot_floppy(os.path.abspath('dist/to8.fd'))
t.call('run_frames', {'n': 1200})
occ = open('dist/occupancy-fd.html').read()
m = re.search(r'"name":"title.cheat","container":"title","page":(\d+),"address":(\d+)', occ)
page, base = int(m.group(1)), int(m.group(2))
pstage = equ('gen/title/build/cheat.lwmap', 'tct.pstage')
launch = equ('gen/title/build/cheat.lwmap', 'title.cheat.launch')
t.call('set_breakpoint', {'pc': '%04X' % WAIT})
t.call('run_to_breakpoint', {'timeout_ms': 120000})
t.call('clear_breakpoint', {'id': 1})
t.call('write_memory', {'addr': 'E7E6', 'bytes': ['%02X' % (0x60 + page)]})
t.call('write_memory', {'addr': hex(base + pstage), 'bytes': ['08', '01']})
t.call('set_register', {'reg': 'dp', 'value': '9F'})
t.call('set_register', {'reg': 'pc', 'value': '%04X' % (base + launch)})
dpage, dbase = unit_base('stage8.bydo')
death = dbase + equ('gen/enemies/build/stage8-bydo.lwmap', 'bydo.Death')
b = t.call('set_breakpoint', {'pc': '%04X' % death, 'page': dpage})
t.call('step')
for _ in range(400):
    if t.call('run_to_breakpoint', {'max_instructions': 5000000}).get('hit'):
        break
t.call('clear_breakpoint', {'id': b['id']})
t.call('step')
print('le noyau meurt : releve de cadence arme', flush=True)
ONE = os.environ.get('ONE') == '1'
if not ONE:
    t.call('frame_budget_watch', {'pc': '%04X' % LOOP, 'budget_cycles': 1, 'capacity': 65536})


def cyc():
    return t.call('dump_trace_ring', {'count': 1})['instructions'][-1]['total_cycles']


def pc():
    return int(t.call('read_registers')['pc'], 16)


def until(target, maxi=200000):
    t.call('run_until_pc', {'pc': '%04X' % target, 'max_instructions': maxi})
    return pc() == target


def visible():
    rows = t.read('%04X' % ROWT, 64)
    yb = t.read('%04X' % TY, 2)
    ty = yb[0] * 256 + yb[1]
    n = 0
    for r in range(16, 64):
        if rows[r]:
            d = ((r - 16) * 8 - ty) & 511
            if d <= 242 or d >= 512 - 9:
                n += 1
    return n


# jusqu'a la pleine charge
for k in range(3000):
    t.call('run_frames', {'n': 4})
    if visible() >= 8:
        break
print('pleine charge : %d lignes visibles' % visible(), flush=True)
t.call('screenshot', {'path': os.path.join(OUT, 'full_load.png')})
loops = []
for it in range(1 if ONE else 4):
    if not until(LOOP):
        print('stage.loop non atteint'); break
    c0 = cyc(); prev = c0; row = []
    for k, (name, off) in enumerate(STEPS):
        nxt = BASE + STEPS[k + 1][1] if k + 1 < len(STEPS) else LOOP
        ok = until(nxt)
        c = cyc()
        row.append((name, c - prev if ok else None)); prev = c
    loops.append((c - c0, row, visible()))
    print('rendu %d : %d cycles (%.2f trames)' % (it + 1, c - c0, (c - c0) / 19968), flush=True)
irqs = []
for k in range(8):
    if not until(USERIRQ):
        break
    c0 = cyc()
    sp = int(t.call('read_registers')['s'], 16)
    bb = t.read('%04X' % sp, 2); ret = (bb[0] << 8) | bb[1]
    ok1 = until(ret, 30000)
    irqs.append(cyc() - c0 if ok1 else None)
print('IRQ (stage.userIRQ) : %s' % irqs, flush=True)
json.dump({'loops': loops, 'irqs': irqs}, open(os.path.join(OUT, 'steps.json'), 'w'))
if ONE:
    t.close()
    sys.exit(0)
# la suite, jusqu'au stage 1
for k in range(400):
    t.call('run_frames', {'n': 250, 'timeout_ms': 600000})
    if t.read('%04X' % BSTAGE, 1)[0] == 1:
        break
fb = t.call('read_frame_budget', {'limit': 8192})
json.dump(fb, open(os.path.join(OUT, 'fps.json'), 'w'))
print('cadence : %s intervalles' % fb.get('count'), flush=True)
t.close()
