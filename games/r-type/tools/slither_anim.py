#!/usr/bin/env python3
"""Qui ecrit le pointeur de script d'un maitre de serpent, et quoi.

    TOJE_FAST=1 python3 tools/slither_anim.py dist/to8.fd [--writes N]

Le journal precedent (slither_log.py) a montre que `anim` d'un maitre est
DEJA hors de la zone des scripts au premier releve. Cette sonde prend le
probleme a la racine : elle attend la naissance d'un maitre, pose une
SURVEILLANCE MEMOIRE sur son champ `anim` (+8, deux octets) et journalise
chaque ecriture avec le PC qui l'a faite.

Trois ecrivains possibles dans moveByScript, et le PC les distingue :
  initialize      — la pose initiale
  avance normale  — fin de segment, on passe a la commande suivante
  enchainement    — terminateur $0000 : le mot QUI SUIT est installe comme
                    nouveau script. C'est le chemin suspect.
"""
import argparse, os, re, sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                '..', '..', '..', 'ci', 'toje-bench'))
from mcp import Toje

ap = argparse.ArgumentParser()
ap.add_argument('image')
ap.add_argument('--writes', type=int, default=200)
a = ap.parse_args()


def unit(n):
    occ = open('dist/occupancy-fd.html').read()
    m = re.search(r'"name":"%s","container":"[^"]*","page":(\d+),"address":(\d+)'
                  % re.escape(n), occ)
    return int(m.group(1)), int(m.group(2))


def sym(f, n, b=0):
    for l in open(f):
        m = re.match(r'Symbol: %s \(.*\) = ([0-9A-Fa-f]+)' % re.escape(n), l)
        if m:
            return b + int(m.group(1), 16)
    raise SystemExit('symbole absent : ' + n)


def lst(f, needle, nth=0):
    hits = [int(m.group(1), 16) for l in open(f)
            if needle in l for m in [re.match(r'([0-9A-F]{4}) ', l)] if m]
    return hits[nth]


_, ENG = unit('common.engine')
SAFE = sym('gen/common/build/engine.lwmap', 'gfxlock.bufferSwap.wait', ENG)
CAST, _ = unit('stage5.cast')
INITCALL = lst('gen/enemies/build/stage5-cast.lst', 'jsr   moveByScript.initialize')
W = {ENG + lst('gen/common/build/engine.lst', 'stx   anim,u', 0): 'initialize',
     ENG + lst('gen/common/build/engine.lst', 'stx   anim,u', 1): 'avance',
     ENG + lst('gen/common/build/engine.lst', 'stx   anim,u', 2): 'ENCHAINEMENT'}
TBL = sym('gen/enemies/build/stage5-cast.lwmap', 'slither.script.tbl')
print('ecrivains :', {'%04X' % k: v for k, v in W.items()},
      ' table de scripts a %04X' % TBL, flush=True)

t = Toje()
pg, ad = unit('title.cheat')
ad += sym('gen/title/build/cheat.lwmap', 'tct.pstage')
t.call('mount_disk', {'path': os.path.abspath(a.image)})
t.call('reset')
t.call('run_frames', {'n': 90})
t.press('0F')
t.call('run_frames', {'n': 3000, 'timeout_ms': 600000, 'fast': True})
for _ in range(40):
    r = t.call('run_until_pc', {'pc': '%04X' % SAFE, 'max_instructions': 400000})
    if isinstance(r, dict) and r.get('reached'):
        break
    t.call('run_frames', {'n': 60})
t.call('write_memory', {'addr': '0xE7E6', 'bytes': ['%02X' % (0x60 + pg)]})
t.call('write_memory', {'addr': hex(ad), 'bytes': ['05', '01']})
ok = t.read(hex(ad), 2) == [5, 1]
t.call('write_memory', {'addr': '0xE7E6', 'bytes': ['78']})
if not ok:
    raise SystemExit('le cheat n a pas pris')
t.press('0F')
for _ in range(12):
    t.call('run_frames', {'n': 500, 'timeout_ms': 600000, 'fast': True})
    b = t.read('87DB', 2)
    if b[0] == 0xCA and b[1] == 5:
        break
print('stage 5 en place', flush=True)

# attendre la naissance d'un maitre : le point d'arret sur son init
bp = t.call('set_breakpoint', {'pc': '%04X' % INITCALL, 'page': CAST})
r = t.call('run_to_breakpoint', {'max_instructions': 4000000})
if not (isinstance(r, dict) and r.get('hit')):
    raise SystemExit('aucun maitre ne nait')
reg = t.call('read_registers', {})
u = int(reg['u'], 16)
print('maitre ne : OST %04X, script initial X=%s' % (u, reg['x']), flush=True)
t.call('clear_breakpoint', {'id': bp['id']})
t.call('set_watchpoint', {'addr': '%04X' % (u + 8), 'len': 2, 'label': 'anim'})

prev = None
for i in range(a.writes):
    t.call('step', {'count': 1})
    r = t.call('run_to_breakpoint', {'max_instructions': 2000000})
    if not (isinstance(r, dict) and r.get('hit')):
        print('plus d ecriture apres %d' % i, flush=True)
        break
    reg = t.call('read_registers', {})
    pc = int(reg['pc'], 16)
    v = t.read('%04X' % (u + 8), 2)
    anim = (v[0] << 8) | v[1]
    who = W.get(pc, W.get(pc - 2, '?%04X' % pc))
    zone = 'script' if TBL <= anim < TBL + 0x400 else 'HORS ZONE'
    if anim != prev:
        print('  %-13s anim=%04X  %s' % (who, anim, zone), flush=True)
    prev = anim
