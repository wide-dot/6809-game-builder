#!/usr/bin/env python3
"""Autopsie ciblee du gel stage 7 (camera ~61, boucles ~88).

    TOJE_MCP=<toje>/scripts/toje-mcp.sh TOJE_FAST=1 \
    python3 tools/bug_autopsy.py dist/to8.fd

Amorce calquee sur bug_debug.py (cheat au point sur). Ensuite :
  - trace serree (5 trames) de [boucles, camera, etat scroll, log 9EF0]
    jusqu'au gel — la TRANSITION est ce qui manque aux autopsies passees ;
  - au gel : log engine, etat scroll complet, histogramme de 200k pas.
"""
import os, re, sys, time

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                '..', '..', '..', 'ci', 'toje-bench'))
from mcp import Toje

def unit_base(name):
    occ = open('dist/occupancy-fd.html').read()
    m = re.search(r'"name":"%s","container":"[^"]*","page":(\d+),"address":(\d+)'
                  % re.escape(name), occ)
    return int(m.group(1)), int(m.group(2))

def sym(mapfile, name, base=0):
    for l in open(mapfile):
        m = re.match(r'Symbol: %s \(.*\) = ([0-9A-Fa-f]+)' % re.escape(name), l)
        if m:
            return base + int(m.group(1), 16)
    raise SystemExit('symbole %s absent' % name)

_, ENGINE = unit_base('common.engine')
SAFE  = sym('gen/common/build/engine.lwmap', 'gfxlock.bufferSwap.wait', ENGINE)
BENCH = 0x87DB

# l'etat scroll (resident, fixe)
S_TILEPOS = sym('gen/common/build/engine.lwmap', 'scroll_tile_pos', ENGINE)      # +0 pos, +1 offset, +2 offset24
S_MAPPOS  = sym('gen/common/build/engine.lwmap', 'scroll_map_pos', ENGINE)       # 2 o
S_CAMOLD  = sym('gen/common/build/engine.lwmap', 'glb_camera_x_pos_old', ENGINE) # 2 o
S_MAX     = sym('gen/common/build/engine.lwmap', 'scroll_max', ENGINE)           # 2 o
Q_COUNT   = sym('gen/common/build/engine.lwmap', 'tilemap.q.count', ENGINE)      # 1 o + lost 1 o

def cheat_state_addr():
    occ = open('dist/occupancy-fd.html').read()
    m = re.search(r'"name":"title.cheat","container":"title","page":(\d+),"address":(\d+)', occ)
    page, addr = int(m.group(1)), int(m.group(2))
    for l in open('gen/title/build/cheat.lwmap'):
        m2 = re.match(r'Symbol: tct\.pstage \(.*\) = ([0-9A-Fa-f]+)', l)
        if m2:
            return page, addr + int(m2.group(1), 16)
    raise SystemExit('tct.pstage absent')

t = Toje()
page, addr = cheat_state_addr()
print('emulateur pret', time.strftime('%H:%M:%S'), flush=True)

t.call('mount_disk', {'path': os.path.abspath(sys.argv[1])})
t.call('reset')
t.call('run_frames', {'n': 90})
t.call('press_key', {'scancode': '0F', 'down': True})
t.call('run_frames', {'n': 5})
t.call('press_key', {'scancode': '0F', 'down': False})
t.call('run_frames', {'n': 3000, 'timeout_ms': 600000})

def safe_point(tries=40):
    for _ in range(tries):
        r = t.call('run_until_pc', {'pc': '%04X' % SAFE, 'max_instructions': 400000})
        if isinstance(r, dict) and r.get('reached'):
            return
        t.call('run_frames', {'n': 60})
    raise SystemExit('point sur jamais atteint')

safe_point()
t.call('write_memory', {'addr': '0xE7E6', 'bytes': ['%02X' % (0x60 + page)]})
t.call('write_memory', {'addr': hex(addr), 'bytes': ['07', '01']})
ok = t.read(hex(addr), 2) == [7, 1]
t.call('write_memory', {'addr': '0xE7E6', 'bytes': ['78']})
if not ok:
    raise SystemExit('le cheat n a pas pris')
t.call('press_key', {'scancode': '0F', 'down': True})
t.call('run_frames', {'n': 10})
t.call('press_key', {'scancode': '0F', 'down': False})
# MEME rythme que bug_debug.py : tranches de 500 trames. Le gel est sensible
# au decoupage des run_frames (5 trames : pas de gel en 2000 trames).
for _ in range(12):
    t.call('run_frames', {'n': 500, 'timeout_ms': 600000})
    b = t.read(hex(BENCH), 2)
    if b[0] == 0xCA and b[1] == 7:
        break
else:
    raise SystemExit('stage 7 jamais seme')
print('stage 7 en place', time.strftime('%H:%M:%S'), flush=True)

def snap():
    b   = t.read(hex(BENCH), 5)
    tp  = t.read(hex(S_TILEPOS), 3)
    mp  = t.read(hex(S_MAPPOS), 2)
    co  = t.read(hex(S_CAMOLD), 2)
    mx  = t.read(hex(S_MAX), 2)
    q   = t.read(hex(Q_COUNT), 2)
    log = t.read('9EF0', 5)
    return dict(loop=b[2], cam=(b[3] << 8) | b[4],
                tile=tp, mappos=(mp[0] << 8) | mp[1],
                camold=(co[0] << 8) | co[1], smax=(mx[0] << 8) | mx[1],
                q=q, log=log)

# --- la trace serree jusqu'au gel ------------------------------------------
# Le compteur reste a 0 pendant l'intro (READY) : n'armer la detection
# qu'une fois la boucle en marche, sinon l'intro passe pour un gel.
last_loop, stall, hist, armed = None, 0, [], False
for i in range(200):
    t.call('run_frames', {'n': 25, 'timeout_ms': 900000})
    s = snap()
    hist.append(s)
    if not armed:
        if s['loop'] >= 5:
            armed = True
        last_loop = s['loop']
        continue
    if s['loop'] == last_loop:
        stall += 1
        if stall >= 3:                        # 75 trames sans un tour
            print('*** GEL : camera %d, boucles %d ***' % (s['cam'], s['loop']), flush=True)
            break
    else:
        stall = 0
    last_loop = s['loop']
else:
    print('pas de gel en %d trames' % (400 * 5), flush=True)
    sys.exit(0)

print('--- les 12 derniers instantanes (5 trames each) ---', flush=True)
for s in hist[-12:]:
    print('  loop %3d cam %4d  tile %02X/%02X/%02X map %04X camold %04X smax %04X '
          'q %02X/%02X  log %s' % (s['loop'], s['cam'], s['tile'][0], s['tile'][1],
          s['tile'][2], s['mappos'], s['camold'], s['smax'], s['q'][0], s['q'][1],
          ' '.join('%02X' % c for c in s['log'])), flush=True)

# --- echantillons PURS (sans step, qui perturbe : le jeu REPART sous step) --
print('--- 40 PC entre run_frames(1), sans stepping ---', flush=True)
pure = {}
for _ in range(40):
    t.call('run_frames', {'n': 1, 'timeout_ms': 900000})
    r = t.call('read_registers', {})
    pc = r['pc']
    pure[pc] = pure.get(pc, 0) + 1
for pc, n in sorted(pure.items(), key=lambda kv: -kv[1])[:10]:
    print('  %s : %d' % (pc, n), flush=True)
s = snap()
print('apres 40 trames de plus : loop %d cam %d' % (s['loop'], s['cam']), flush=True)

# --- l'histogramme : ou vont 200k pas --------------------------------------
buckets = {}
pages = {}
for _ in range(400):
    t.call('step', {'count': 500})
    r = t.call('read_registers', {})
    pc = int(r['pc'], 16)
    buckets[pc & 0xFF00] = buckets.get(pc & 0xFF00, 0) + 1
    pm = t.call('read_page_map', {})
    pages[pm.get('cart_ram_page')] = pages.get(pm.get('cart_ram_page'), 0) + 1
print('--- histogramme PC (200k pas, seaux de 256 o) ---', flush=True)
for a, n in sorted(buckets.items(), key=lambda kv: -kv[1])[:12]:
    print('  $%04Xxx : %3d' % (a >> 8, n), flush=True)
print('pages cartouche vues :', pages, flush=True)

# --- l'etat final ----------------------------------------------------------
s = snap()
print('final :', s, flush=True)
regs = t.call('read_registers', {})
print('registres :', regs, flush=True)
sp = int(regs['s'], 16)
print('pile @%04X :' % sp, ' '.join('%02X' % c for c in t.read(hex(sp), 32)), flush=True)
