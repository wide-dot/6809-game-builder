#!/usr/bin/env python3
"""Trajectoire de la couche battleship (stage 3) : mesurée vs attendue.

    TOJE_MCP=<toje>/scripts/toje-mcp.sh \
    python3 tools/warship_traj.py dist/to8.fd [frames]

Boote l'image, force le cheat de sélection de stage (pstage=3, invincible)
par poke dans l'unité title.cheat, démarre, attend le seed du stage 3, puis
échantillonne mscroll.camera.x/y à intervalle fixe. La référence est
l'intégrale du script caméra lue DANS LE ROM arcade (mêmes conversions que
l'exporteur re.arcade : axes vérifiés au code, x*6, y*12).

L'écart affiché par échantillon permet de juger : forme identique = pilote
fidèle ; dérive proportionnelle = bug d'horloge ; divergence de forme = bug
d'axe ou de signe.
"""
import os, re, sys, json

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                '..', '..', '..', 'ci', 'toje-bench'))
from mcp import Toje

ROM = os.path.expanduser(
    '~/Documents/Claude/Projects/re.arcade.r-type/out/rom/maincpu.bin')
INNER = 0x16F8A
MAP_H = 384
STEP = 750

# --- adresses du build courant -------------------------------------------
def mscroll_sym(name):
    for l in open('gen/common/build/mscroll.lwmap'):
        m = re.match(r'Symbol: %s \(.*\) = ([0-9A-Fa-f]+)' % re.escape(name), l)
        if m:
            return 0x8850 + int(m.group(1), 16)
    raise SystemExit('symbol %s absent de mscroll.lwmap' % name)

def cheat_state_addr():
    """(page, adresse CPU fenetre cartouche) de tct.pstage."""
    occ = open('dist/occupancy-fd.html').read()
    m = re.search(r'"name":"title.cheat","container":"title","page":(\d+),"address":(\d+)', occ)
    page, addr = int(m.group(1)), int(m.group(2))
    for l in open('gen/title/build/cheat.lwmap'):
        m2 = re.match(r'Symbol: tct\.pstage \(.*\) = ([0-9A-Fa-f]+)', l)
        if m2:
            return page, addr + int(m2.group(1), 16)
    raise SystemExit('tct.pstage absent de cheat.lwmap')

CAMX = mscroll_sym('mscroll.camera.x')
CAMY = mscroll_sym('mscroll.camera.y')

# --- la reference : autoscroll du checkpoint + integrale du script ROM ---
# L'entree de stage arcade (checkpoint 0x1000:87FA, cp6) seme la vitesse bg
# a $0080 (0.5 px/trame) : la camera avance AVANT le spawn du master a
# ts $2000 (= 256 trames v2 apres l'entree), et le script prolonge cette
# vitesse (premier segment 8/16 = 0.5). v2 : $0030 8.8/trame (main.asm).
SPAWN = 256
PRE_SPEED = 0x30
rom = open(ROM, 'rb').read()
def s8(b): return b - 256 if b >= 128 else b
segs, off = [], INNER
while rom[off + 2] != 0x80:
    segs.append((s8(rom[off + 1]) * 6, s8(rom[off]) * 12, rom[off + 2]))
    off += 3

def expected(t):
    x = PRE_SPEED * min(t, SPAWN)
    y = 0
    tt = SPAWN
    if t > SPAWN:
        for sx, sy, fr in segs:
            if tt + fr >= t:
                r = t - tt
                x += sx * r; y += sy * r
                break
            x += sx * fr; y += sy * fr; tt += fr
    return (x >> 8, (y >> 8) % MAP_H)

# --- la machine ----------------------------------------------------------
budget = int(sys.argv[2]) if len(sys.argv) > 2 else 9000

t = Toje()
t.boot_floppy(os.path.abspath(sys.argv[1]))

def witnesses():
    b = t.read('0x87DB', 3)
    return b[0], b[1]

# le title : lui laisser son chargement complet AVANT tout poke — relire ses
# propres octets dans la RAM nue est un faux positif, le title charge ensuite
# PAR-DESSUS (vecu : un start partait avec l'etat vierge, direction stage 1)
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

# le poke doit SURVIVRE a du temps qui passe : c'est la preuve que le title
# est charge et n'ecrira plus par-dessus
for _ in range(40):
    poke_cheat()
    t.call('run_frames', {'n': 60})
    if cheat_holds():
        break
else:
    raise SystemExit('title jamais pret (le poke cheat ne tient pas)')

# marteler start jusqu'au seed du stage 3 (le start ne s'arme que sur le
# logo) ; un depart stage 1 = le cheat a saute, on abandonne explicitement
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

print('stage 3 en place — echantillonnage')
print('   t_reel   x_mesure y_mesure   x_attendu y_attendu')
worst = 0
for tt in range(0, budget + 1, STEP):
    x = t.read(hex(CAMX), 2); x = (x[0] << 8) | x[1]
    y = t.read(hex(CAMY), 2); y = (y[0] << 8) | y[1]
    ex, ey = expected(tt)
    dx = x - ex
    dy = min((y - ey) % MAP_H, (ey - y) % MAP_H)
    worst = max(worst, abs(dx), dy)
    print('  %6d     %4d %4d        %4d %4d   (dx %+d, dy %d)'
          % (tt, x, y, ex, ey, dx, dy))
    t.call('run_frames', {'n': STEP})
print('ecart max observe : %d px' % worst)
