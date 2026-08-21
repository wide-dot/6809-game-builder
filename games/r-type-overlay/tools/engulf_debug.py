#!/usr/bin/env python3
"""Traqueur de blocage du stage 2 : courir jusqu'au boss et vider l'etat.

    TOJE_MCP=<toje>/scripts/toje-mcp.sh TOJE_FAST=1 \
    python3 tools/engulf_debug.py dist/to8.fd

Amorce calquee sur warship_fps.py (elle est eprouvee, on n'y touche pas).
Ensuite on avance par blocs et on surveille bench.frames : s'il cesse de
bouger, on vide registres, page cartouche, pile d'appels et les temoins.
"""
import os, re, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                '..', '..', '..', 'ci', 'toje-bench'))
from mcp import Toje

def unit_base(name):
    occ = open('dist/occupancy-fd.html').read()
    m = re.search(r'"name":"%s","container":"[^"]*","page":(\d+),"address":(\d+)'
                  % re.escape(name), occ)
    return int(m.group(1)), int(m.group(2))

def sym(mapfile, name, base):
    for l in open(mapfile):
        m = re.match(r'Symbol: %s \(.*\) = ([0-9A-Fa-f]+)' % re.escape(name), l)
        if m: return base + int(m.group(1), 16)
    raise SystemExit('symbole %s absent' % name)

_, ENGINE = unit_base('common.engine')
SAFE = sym('gen/common/build/engine.lwmap', 'gfxlock.bufferSwap.wait', ENGINE)
INV  = sym('gen/common/build/engine.lwmap', 'cheat.invincible', ENGINE)
BENCH = 0x87DB
STAGE = 2

def cheat_state_addr():
    occ = open('dist/occupancy-fd.html').read()
    m = re.search(r'"name":"title.cheat","container":"title","page":(\d+),"address":(\d+)', occ)
    page, addr = int(m.group(1)), int(m.group(2))
    for l in open('gen/title/build/cheat.lwmap'):
        m2 = re.match(r'Symbol: tct\.pstage \(.*\) = ([0-9A-Fa-f]+)', l)
        if m2: return page, addr + int(m2.group(1), 16)
    raise SystemExit('tct.pstage absent')

t = Toje(); page, addr = cheat_state_addr()
t.call('mount_disk', {'path': os.path.abspath(sys.argv[1])})
t.call('reset'); t.call('run_frames', {'n': 90})
t.call('press_key', {'scancode': '0F', 'down': True}); t.call('run_frames', {'n': 5})
t.call('press_key', {'scancode': '0F', 'down': False})
t.call('run_frames', {'n': 3000, 'timeout_ms': 600000})

for _ in range(40):
    r = t.call('run_until_pc', {'pc': '%04X' % SAFE, 'max_instructions': 400000})
    if isinstance(r, dict) and r.get('reached'): break
    t.call('run_frames', {'n': 60})
else: raise SystemExit('point sur jamais atteint')

t.call('write_memory', {'addr': '0xE7E6', 'bytes': ['%02X' % (0x60 + page)]})
t.call('write_memory', {'addr': hex(addr), 'bytes': ['%02X' % STAGE, '01']})
ok = t.read(hex(addr), 2) == [STAGE, 1]
t.call('write_memory', {'addr': '0xE7E6', 'bytes': ['78']})
if not ok: raise SystemExit('le cheat n a pas pris')
t.call('press_key', {'scancode': '0F', 'down': True}); t.call('run_frames', {'n': 10})
t.call('press_key', {'scancode': '0F', 'down': False})

for _ in range(12):
    t.call('run_frames', {'n': 500, 'timeout_ms': 600000})
    b = t.read(hex(BENCH), 2)
    if b[0] == 0xCA and b[1] == STAGE: break
else: raise SystemExit('stage 2 jamais seme')
print('stage 2 en place, invincible=%d' % t.read(hex(INV), 1)[0], flush=True)

# --- sonde : le premier appel de tilemap.patch ------------------------------
if os.environ.get('PROBE'):
    PATCH = 0x6100 + 0x04F3
    P = {n: 0x6100 + int(v, 16) for n, v in
         (('col', '04E9'), ('row', '04EA'), ('cols', '04EB'), ('rows', '04EC'),
          ('plane', '04ED'), ('mapEven', '0310'), ('pageEven', '0314'),
          ('vrows', '030B'))}
    t.call('set_breakpoint', {'addr': '%04X' % PATCH})
    r = t.call('run_to_breakpoint', {'timeout_ms': 900000})
    print('arret :', r)
    print('registres :', t.call('read_registers', {}))
    for n, a in P.items():
        print('  %-9s @%04X = %s' % (n, a, t.read(hex(a), 2)))
    sys.exit(0)

# --- observer les cellules patchees pendant le combat -----------------------
if os.environ.get('WATCH'):
    MAPE = 0x6100 + 0x0310
    PAGE = 0x6100 + 0x0314
    VROWS = 0x6100 + 0x030B
    base = t.read(hex(MAPE), 2); base = (base[0] << 8) | base[1]
    page = t.read(hex(PAGE), 1)[0]
    vr = t.read(hex(VROWS), 1)[0]
    COL, ROW = 87, 7
    off = COL * vr * 3 + ROW * 3
    print('carte even @%04X page %02X, %d lignes ; cellule (%d,%d) a +%d = %04X'
          % (base, page, vr, COL, ROW, off, base + off), flush=True)
    # aller jusqu'au combat : le boss n'apparait qu'a la butee de camera
    while True:
        t.call('run_frames', {'n': 500, 'timeout_ms': 600000})
        b = t.read(hex(BENCH), 5)
        cam = (b[3] << 8) | b[4]
        if cam >= 980:
            print('combat atteint, camera %d' % cam, flush=True)
            break
    # LE TUBE 0 : rectangle (83,6). On echantillonne ses cellules et on releve
    # les SALVES — l'animation ne doit pas etre continue, chaque emission du
    # script ne vivant qu'environ 272 trames.
    # L'OBJET D'ANIMATION EST-IL SEULEMENT CREE ? Point d'arret sur son Init.
    if os.environ.get('SPAWN'):
        INIT = 0x08A5                  # tilemapanim.Init, page 13 (stage2.cast)
        print('bp :', t.call('set_breakpoint', {'pc': hex(INIT), 'page': 13}),
              flush=True)
        for i in range(8):
            r = t.call('run_to_breakpoint', {'max_instructions': 40000000})
            hit = isinstance(r, dict) and (r.get('hit') or r.get('reached'))
            if not hit:
                print('arret %d : %s' % (i, r), flush=True); break
            reg = t.call('read_registers', {})
            uu = int(reg['u'], 16)
            ext = uu + 38               # object_base_size
            v = t.read(hex(ext), 5)     # desc(0,1) phase(2) life(3,4)
            print('spawn %d : U=%04X  desc=%02X%02X  vie=%d'
                  % (i, uu, v[0], v[1], (v[3] << 8) | v[4]), flush=True)
            t.call('step', {'count': 1})   # sortir du point d'arret
        sys.exit(0)

    # QUELS RECTANGLES SONT REELLEMENT ECRITS ? Point d'arret sur tilemap.patch.
    if os.environ.get('PATCHLOG'):
        PATCH = sym('gen/common/build/engine.lwmap', 'tilemap.patch', ENGINE)
        P = {n: sym('gen/common/build/engine.lwmap', 'tilemap.patch.' + n, ENGINE)
             for n in ('col', 'row', 'cols', 'rows', 'plane')}
        LOST = sym('gen/common/build/engine.lwmap', 'tilemap.q.lost', ENGINE)
        t.call('set_breakpoint', {'pc': hex(PATCH)})
        vus = {}
        for i in range(60):
            r = t.call('run_to_breakpoint', {'max_instructions': 20000000})
            if not (isinstance(r, dict) and r.get('hit')):
                print('plus d arret : %s' % r, flush=True); break
            k = tuple(t.read(hex(P[n]), 1)[0] for n in ('col', 'row', 'cols', 'rows'))
            vus[k] = vus.get(k, 0) + 1
            t.call('step', {'count': 1})
        print('rectangles ecrits (col,row,cols,rows) -> nombre :')
        for k in sorted(vus): print('   %-16s %d' % (str(k), vus[k]))
        print('perdus (ring plein) : %d' % t.read(hex(LOST), 1)[0])
        sys.exit(0)

    if os.environ.get('TUBE'):
        # LE RECTANGLE ENTIER (4x4). Lire un seul coin ne suffit pas : le
        # pourtour est du rocher, identique dans les deux poses — seul le
        # centre s'ouvre.
        TC, TR, TW, TH = 83, 6, 4, 4
        def tubecells():
            out = []
            for c in range(TW):
                out += t.read(hex(base + (TC + c) * vr * 3 + TR * 3), TH * 3)
            return out
        last = None
        runs = []
        cur = None
        for i in range(240):
            t.call('run_frames', {'n': 25, 'timeout_ms': 600000})
            for _ in range(20):
                r = t.call('run_until_pc', {'pc': '%04X' % SAFE, 'max_instructions': 400000})
                if isinstance(r, dict) and r.get('reached'): break
            t.call('write_memory', {'addr': '0xE7E6', 'bytes': ['%02X' % page]})
            cells = tubecells()
            t.call('write_memory', {'addr': '0xE7E6', 'bytes': ['78']})
            changed = last is not None and cells != last
            last = cells
            if changed:
                if cur is None: cur = [i, i]
                else: cur[1] = i
            elif cur is not None and i - cur[1] > 2:
                runs.append(tuple(cur)); cur = None
        if cur is not None: runs.append(tuple(cur))
        print("salves d'animation du tube 0, en trames depuis le debut du combat :")
        for a, z in runs:
            print('   %5d .. %5d   (%d trames)' % (a * 25, z * 25, (z - a + 1) * 25))
        print('%d salves — une animation continue en donnerait UNE seule' % len(runs))
        sys.exit(0)

    seen = []
    shots = 0
    for i in range(200):
        t.call('run_frames', {'n': 25, 'timeout_ms': 600000})
        b = t.read(hex(BENCH), 5)
        cam = (b[3] << 8) | b[4]
        # lire la carte demande de monter sa page ; on le fait au point sur
        for _ in range(20):
            r = t.call('run_until_pc', {'pc': '%04X' % SAFE, 'max_instructions': 400000})
            if isinstance(r, dict) and r.get('reached'): break
        t.call('write_memory', {'addr': '0xE7E6', 'bytes': ['%02X' % page]})
        cells = t.read(hex(base + off), 6) + t.read(hex(base + off + vr * 3), 6)
        t.call('write_memory', {'addr': '0xE7E6', 'bytes': ['78']})
        key = tuple(cells)
        if key not in seen:
            seen.append(key)
            print('  camera %4d  cellules %s' % (cam, ' '.join('%02X' % c for c in cells)), flush=True)
            if 1 <= len(seen) <= 6:
                t.call('screenshot', {'path': os.path.abspath('dist/engulf-%d.png' % shots)})
                shots += 1
    print('%d etats distincts observes' % len(seen))
    sys.exit(0)

STEP = int(os.environ.get('STEP', '100'))
last, stuck, total = None, 0, 0
while total < int(os.environ.get('BUDGET', '16000')):
    t.call('run_frames', {'n': STEP, 'timeout_ms': 600000})
    total += STEP
    b = t.read(hex(BENCH), 5)
    cam = (b[3] << 8) | b[4]
    if b[2] == last:
        stuck += 1
        if stuck >= int(os.environ.get('STALL', '3')):
            print('\n*** BLOCAGE *** trame %d, boucles %d, camera %d' % (total, b[2], cam))
            print('registres :', t.call('read_registers', {}))
            print('page cart :', t.call('read_memory', {'addr': '0xE7E6', 'size': 1}))
            try: print('pile      :', t.call('read_call_stack', {}))
            except Exception as e: print('pile      : indisponible', e)
            print('temoins   :', t.read(hex(BENCH), 16))
            sys.exit(1)
    else:
        stuck = 0
        if total % 1000 == 0:
            print('  trame %5d  boucles %3d  camera %4d' % (total, b[2], cam), flush=True)
    last = b[2]
print('aucun blocage en %d trames' % total)
