#!/usr/bin/env python3
"""Relever les trajectoires d'objets (gougers par defaut), pour les controler.

    python3 tools/object_track_probe.py dist/to8.fd <sortie.txt> [trames] [ids]
    ex. wick visible : ... 900 54

Generalisation de gouger_track_probe.py (08/09/2026) : les identifiants
viennent de la ligne de commande, et les onze octets ext_variables+9..19
sont releves en hexadecimal a la fin de chaque ligne (le controleur y lit
ce qu'il veut : phase d'ondulation du wick, compteur d'animation...).

Entree directe au stage 2 (le geste de stage2_video.py), puis a chaque
trame rendue le pool est lu et chaque gouger vivant (parent, ids 46..49)
note « trame horloge slot id routine profil x y anim ». L'horloge de jeu
(gfxlock.frame.gameCount) est la cle : deux builds au debit different
n'echantillonnent pas les memes trames, mais aux trames communes les
positions doivent etre egales — et surtout egales a la SIMULATION de
tools/gen_gouger_profiles.py, ce que verifie tools/gouger_track_check.py.
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
RUNOBJ = ENG + equ(ENGMAP, 'RunObjects')
GAMECOUNT = ENG + equ(ENGMAP, 'gfxlock.frame.gameCount')
POOL, NOBJ, OSZ, ROUTINE, XPOS, YPOS, EXT = 0x4000, 60, 63, 34, 18, 21, 38
GOUGER_IDS = tuple(int(x) for x in sys.argv[4].split(',')) if len(sys.argv) > 4 else (46, 47, 48, 49)

image = os.path.abspath(sys.argv[1])
out = sys.argv[2]
budget = int(sys.argv[3]) if len(sys.argv) > 3 else 1500

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

lines = []
last = None
for f in range(budget):
    # une trame rendue a la fois : RunObjects, que chaque rendu traverse —
    # l'attente de bascule, elle, est sautee par un rendu en retard, et deux
    # tours passaient alors entre deux releves (vecu sur la nuee de wicks)
    t.call('set_breakpoint', {'pc': '%04X' % RUNOBJ})
    t.call('run_to_breakpoint', {'timeout_ms': 60000})
    t.call('clear_breakpoint', {'id': 1})
    t.call('step')
    gc = t.read('%04X' % GAMECOUNT, 2)
    gc = (gc[0] << 8) | gc[1]
    raw = []
    for off in range(0, NOBJ * OSZ, 256):
        raw += t.read('%04X' % (POOL + off), min(256, NOBJ * OSZ - off))
    for i in range(NOBJ):
        o = raw[i * OSZ:(i + 1) * OSZ]
        if o[0] in GOUGER_IDS:
            x = (o[XPOS] << 8) | o[XPOS + 1]
            y = (o[YPOS] << 8) | o[YPOS + 1]
            lines.append('%5d t %5d slot %2d id %d rt %d sub %2d x %5d.%02X y %5d.%02X anim %3d ext %s'
                         % (f, gc, i, o[0], o[ROUTINE], o[1], x, o[XPOS + 2], y, o[YPOS + 2], o[EXT + 13],
                            ''.join('%02X' % b for b in o[EXT + 9:EXT + 20])))
open(out, 'w').write('\n'.join(lines) + '\n')
print('%s : %d lignes sur %d trames rendues' % (out, len(lines), budget))
t.close()
