#!/usr/bin/env python3
"""Sondes du gestionnaire de chaine du bug (stage 7).

    TOJE_FAST=1 [CHAIN=1] python3 tools/bug_debug.py dist/to8.fd

L'amorce est CALQUEE sur warship_fps.py — un seul poke de cheat, fait au
point sur (safe_point), un seul appui, de gros blocs. Les variantes
« rapides » sans safe_point corrompent la page montee et figent le stage
tres tot (camera 67-89, vecu trois fois le 22/08).

CHAIN=1 : attendre la chaine longue (camera >= 640), puis relever records
vivants / slots allumes du gestionnaire toutes les 60 trames, prendre une
capture au pic, et verifier que la chaine s'eteint.
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
BUGPAGE, _ = unit_base('lib.bug')
RECSL  = sym('gen/enemies/build/bug.lwmap', 'bug.recsL')
RECSS  = sym('gen/enemies/build/bug.lwmap', 'bug.recsS')
SLOTSL = sym('gen/enemies/build/bug.lwmap', 'bug.slotsL')
SLOTSS = sym('gen/enemies/build/bug.lwmap', 'bug.slotsS')
NRECL, NRECS, RECSZ, SLOTSZ = 40, 12, 9, 5

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
print('menu passe', time.strftime('%H:%M:%S'), flush=True)

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
for _ in range(12):
    t.call('run_frames', {'n': 500, 'timeout_ms': 600000})
    b = t.read(hex(BENCH), 2)
    if b[0] == 0xCA and b[1] == 7:
        break
else:
    raise SystemExit('stage 7 jamais seme')
print('stage 7 en place', time.strftime('%H:%M:%S'), flush=True)

def mgr_state():
    """(vivants L, allumes L, vivants S, allumes S), page montee AU POINT SUR."""
    safe_point()
    t.call('write_memory', {'addr': '0xE7E6', 'bytes': ['%02X' % (0x60 + BUGPAGE)]})
    rcl = t.read(hex(RECSL), NRECL * RECSZ)
    sll = t.read(hex(SLOTSL), NRECL * SLOTSZ)
    rcs = t.read(hex(RECSS), NRECS * RECSZ)
    sls = t.read(hex(SLOTSS), NRECS * SLOTSZ)
    t.call('write_memory', {'addr': '0xE7E6', 'bytes': ['78']})
    return (sum(1 for k in range(NRECL) if rcl[k * RECSZ] == 1),
            sum(1 for k in range(NRECL) if sll[k * SLOTSZ] == 1),
            sum(1 for k in range(NRECS) if rcs[k * RECSZ] == 1),
            sum(1 for k in range(NRECS) if sls[k * SLOTSZ] == 1))

# CRASH=1 : cerner le blocage rapporte a la premiere chaine — surveiller le
# compteur de boucles des la camera 100, et faire l'autopsie au premier arret.
if os.environ.get('CRASH'):
    print('surveillance des boucles DES LA PREMIERE TRAME', flush=True)
    last = None
    stall = 0
    for i in range(200):
        t.call('run_frames', {'n': 25, 'timeout_ms': 900000})
        b = t.read(hex(BENCH), 5)
        cam = (b[3] << 8) | b[4]
        if b[2] == last:
            stall += 1
            if stall >= 3:
                print('*** BLOCAGE camera %d, boucles figees a %d ***' % (cam, b[2]),
                      flush=True)
                break
        else:
            stall = 0
        last = b[2]
        if i % 8 == 0:
            print('  camera %4d  boucles %3d' % (cam, b[2]), flush=True)
    else:
        print('aucun blocage observe (camera %d)' % cam, flush=True)
        sys.exit(0)
    print('registres :', t.call('read_registers', {}), flush=True)
    print('pages     :', t.call('read_page_map', {}), flush=True)
    pcs = {}
    for _ in range(40):
        t.call('step', {'count': 500})
        r = t.call('read_registers', {})
        pcs[r['pc']] = pcs.get(r['pc'], 0) + 1
    print('PC echantillonnes :', sorted(pcs.items(), key=lambda kv: -kv[1])[:10],
          flush=True)
    r = t.call('read_registers', {})
    sp = int(r['s'], 16)
    print('pile @%04X :' % sp, ' '.join('%02X' % c for c in t.read(hex(sp), 24)),
          flush=True)
    # LE POOL D'OBJETS : demi-page 0, lisible sans pagination — qui vit ?
    pool = t.read('0x4000', 60 * 63)
    vus = {}
    for k in range(60):
        i, r2 = pool[k * 63], pool[k * 63 + 34]
        if i:
            vus.setdefault((i, r2), 0)
            vus[(i, r2)] += 1
    print('pool : %d objets vivants' % sum(vus.values()), flush=True)
    for (i, r2), n in sorted(vus.items()):
        print('   id %3d routine %2d  x%d' % (i, r2, n), flush=True)
    # le profileur : 50 trames au point mort, les boucles les plus chaudes
    print('profil de 50 trames au point mort...', flush=True)
    t.call('profile_reset', {})
    t.call('profile_start', {})
    t.call('run_frames', {'n': 50, 'timeout_ms': 900000})
    t.call('profile_stop', {})
    print('TOP :', t.call('profile_top', {}), flush=True)
    print('LOOPS :', t.call('profile_loops', {}), flush=True)
    sys.exit(0)

if os.environ.get('CHAIN'):
    # --- 1) la chaine COURTE (camera ~146) doit prendre l'instance S --------
    while True:
        t.call('run_frames', {'n': 120, 'timeout_ms': 900000})
        b = t.read(hex(BENCH), 5)
        cam = (b[3] << 8) | b[4]
        if cam >= 138:
            break
    peakS = 0
    for i in range(10):
        t.call('run_frames', {'n': 60, 'timeout_ms': 900000})
        al, ll, as_, ls = mgr_state()
        b = t.read(hex(BENCH), 5)
        cam = (b[3] << 8) | b[4]
        print('  camera %4d  L %2d/%2d  S %2d/%2d' % (cam, al, ll, as_, ls),
              flush=True)
        peakS = max(peakS, as_)
        if peakS >= 8:
            t.call('screenshot', {'path': os.path.abspath('dist/stage7-chainS.png')})
            print('  capture courte : dist/stage7-chainS.png', flush=True)
            break
    print('chaine courte : pic %d records sur l instance S' % peakS, flush=True)
    # --- 2) la chaine LONGUE (camera ~643) sur l'instance L -----------------
    while True:
        t.call('run_frames', {'n': 250, 'timeout_ms': 900000})
        b = t.read(hex(BENCH), 5)
        cam = (b[3] << 8) | b[4]
        if cam >= 640:
            break
    print('la chaine longue approche, camera %d' % cam, flush=True)
    peak = 0
    shot = False
    zero = 0
    for i in range(60):
        t.call('run_frames', {'n': 60, 'timeout_ms': 900000})
        al, ll, as_, ls = mgr_state()
        b = t.read(hex(BENCH), 5)
        cam = (b[3] << 8) | b[4]
        print('  camera %4d  L %2d/%2d  S %2d/%2d' % (cam, al, ll, as_, ls),
              flush=True)
        peak = max(peak, al)
        if ll >= 8 and not shot:
            shot = True
            t.call('screenshot', {'path': os.path.abspath('dist/stage7-chain.png')})
            print('  capture longue : dist/stage7-chain.png', flush=True)
        if peak and al == 0:
            zero += 1
            if zero >= 3:
                break
    print('chaine longue : pic %d records ; extinction %s' %
          (peak, 'propre' if zero >= 3 else 'non observee'), flush=True)
