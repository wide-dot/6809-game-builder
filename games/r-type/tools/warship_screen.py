#!/usr/bin/env python3
"""Le banc ECRAN de la couche battleship (stage 3).

    TOJE_MCP=<toje>/scripts/toje-mcp.sh TOJE_FAST=1 \
    python3 tools/warship_screen.py dist/to8.fd [out_dir]

Meme amorce que warship_traj.py (boot, cheat pstage=3, start, attente du
seed du stage 3) mais la mesure ne s'arrete pas a la VARIABLE : a chaque
point d'echantillonnage il lit l'etat du module (camera x/y, cursor,
stretch, reliquats de vitesse) ET prend une capture d'ecran.

C'est le discriminant des deux hypotheses du handoff : si camera.y suit la
reference et que l'ecran, lui, ne suit pas, le defaut est dans le RENDU
(cursor/couture/updategfx), pas dans le pilote.
"""
import os, re, sys, json

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                '..', '..', '..', 'ci', 'toje-bench'))
from mcp import Toje

ROM = os.path.expanduser(
    '~/Documents/Claude/Projects/re.arcade.r-type/out/rom/maincpu.bin')
INNER = 0x16F8A
MAP_H = 384

# --- adresses du build courant -------------------------------------------
def mscroll_sym(name):
    for l in open('gen/common/build/mscroll.lwmap'):
        m = re.match(r'Symbol: %s \(.*\) = ([0-9A-Fa-f]+)' % re.escape(name), l)
        if m:
            return 0x8850 + int(m.group(1), 16)
    raise SystemExit('symbol %s absent de mscroll.lwmap' % name)

def cheat_state_addr():
    occ = open('dist/occupancy-fd.html').read()
    m = re.search(r'"name":"title.cheat","container":"title","page":(\d+),"address":(\d+)', occ)
    page, addr = int(m.group(1)), int(m.group(2))
    for l in open('gen/title/build/cheat.lwmap'):
        m2 = re.match(r'Symbol: tct\.pstage \(.*\) = ([0-9A-Fa-f]+)', l)
        if m2:
            return page, addr + int(m2.group(1), 16)
    raise SystemExit('tct.pstage absent de cheat.lwmap')

SYM = {n: mscroll_sym(n) for n in
       ('mscroll.camera.x', 'mscroll.camera.y', 'mscroll.cursor.w',
        'mscroll.stretch', 'mscroll.speed', 'mscroll.speedx',
        'mscroll.camera.speed', 'mscroll.camera.speedx')}
for k, v in sorted(SYM.items()):
    print('%-24s $%04X' % (k, v))

# --- la reference ---------------------------------------------------------
SPAWN = 256
PRE_SPEED = 0x30
rom = open(ROM, 'rb').read()
def s8(b): return b - 256 if b >= 128 else b
segs, off = [], INNER
while rom[off + 2] != 0x80:
    segs.append((s8(rom[off + 1]) * 6, s8(rom[off]) * 12, rom[off + 2]))
    off += 3

def expected(t):
    """(x, y_signe, index de segment) a t trames apres le seed du stage."""
    x = PRE_SPEED * min(t, SPAWN)
    y = 0
    tt = SPAWN
    idx = -1
    if t > SPAWN:
        for i, (sx, sy, fr) in enumerate(segs):
            if tt + fr >= t:
                r = t - tt
                x += sx * r; y += sy * r; idx = i
                break
            x += sx * fr; y += sy * fr; tt += fr
    return (x >> 8, y >> 8, idx)

# --- la machine ----------------------------------------------------------
out = sys.argv[2] if len(sys.argv) > 2 else 'dist/warship-screen'
os.makedirs(out, exist_ok=True)

t = Toje()
t.boot_floppy(os.path.abspath(sys.argv[1]))

def witnesses():
    b = t.read('0x87DB', 3)
    return b[0], b[1]

page, addr = cheat_state_addr()
t.call('run_frames', {'n': 2700})

def poke_cheat():
    t.call('write_memory', {'addr': '0xE7E6', 'bytes': ['%02X' % (0x60 + page)]})
    t.call('write_memory', {'addr': hex(addr), 'bytes': ['03', '01']})
    t.call('write_memory', {'addr': '0xE7E6', 'bytes': ['78']})

def cheat_holds():
    t.call('write_memory', {'addr': '0xE7E6', 'bytes': ['%02X' % (0x60 + page)]})
    ok = t.read(hex(addr), 2) == [3, 1]
    t.call('write_memory', {'addr': '0xE7E6', 'bytes': ['78']})
    return ok

for _ in range(40):
    poke_cheat()
    t.call('run_frames', {'n': 60})
    if cheat_holds():
        break
else:
    raise SystemExit('title jamais pret (le poke cheat ne tient pas)')

for _ in range(40):
    poke_cheat()
    t.press(hold=8)
    t.call('run_frames', {'n': 250})
    magic, stage = witnesses()
    if magic == 0xCA and stage == 3:
        break
    if magic == 0xCA and stage not in (0, 3):
        raise SystemExit('parti au stage %d — le cheat n a pas tenu' % stage)
else:
    raise SystemExit('le stage 3 n a jamais seme son bloc')

def w(name):
    b = t.read(hex(SYM[name]), 2)
    v = (b[0] << 8) | b[1]
    return v - 65536 if v >= 32768 else v

# points d'echantillonnage : le contexte tot, puis la fenetre du symptome
POINTS = [900, 1500, 1900, 2400, 2900, 3300, 3700, 4100, 4500, 4900,
          5300, 5700, 6100, 6500, 6900, 7300, 7700, 8100, 8500, 8900, 9300]

print('stage 3 en place — releve ecran')
rows = []
cur = 0
fast = os.environ.get('TOJE_FAST') == '1'
for p in POINTS:
    # courir jusqu'a 4 trames avant le point en turbo, la fin en rendu
    if p - 4 > cur:
        t.call('run_frames', {'n': p - 4 - cur, 'timeout_ms': 600000})
        cur = p - 4
    if p > cur:
        # rendu reel : l'ecran doit etre a jour pour la capture
        old = os.environ.pop('TOJE_FAST', None)
        t.call('run_frames', {'n': p - cur})
        if old: os.environ['TOJE_FAST'] = old
        cur = p
    x, y = w('mscroll.camera.x'), w('mscroll.camera.y')
    cw = t.read(hex(SYM['mscroll.cursor.w']), 2)
    st = t.read(hex(SYM['mscroll.stretch']), 1)[0]
    sp, spx = w('mscroll.speed'), w('mscroll.speedx')
    csp, cspx = w('mscroll.camera.speed'), w('mscroll.camera.speedx')
    ex, ey, seg = expected(p)
    dy = min((y - ey) % MAP_H, (ey - y) % MAP_H)
    shot = os.path.abspath(os.path.join(out, 't%05d.png' % p))
    t.call('screenshot', {'path': shot})
    row = dict(t=p, x=x, y=y, cursor=cw[1], stretch=st, speed=sp, speedx=spx,
               cspeed=csp, cspeedx=cspx, ex=ex, ey=ey % MAP_H, eysig=ey,
               dx=x - ex, dy=dy, seg=seg, shot=shot)
    rows.append(row)
    print('t=%5d  x=%4d(%+d)  y=%4d ref %4d (d%2d)  cur=%3d str=%d '
          'sp=%+6d spx=%+6d csp=%+d cspx=%+d seg=%d'
          % (p, x, row['dx'], y, row['ey'], dy, cw[1], st, sp, spx,
             csp, cspx, seg), flush=True)

json.dump(rows, open(os.path.join(out, 'samples.json'), 'w'), indent=1)
print('captures + samples.json dans', out)
