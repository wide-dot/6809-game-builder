#!/usr/bin/env python3
"""Releve la cadence d'un stage, trame par trame, en entrant SANS manette.

    TOJE_MCP=<toje>/scripts/toje-mcp.sh \
    python3 tools/fps_stages.py dist/to8.fd 1 releve.csv [max_frames]

Meme mesure et MEME FORMAT CSV que ci/toje-bench/fps_curve.py — la sortie se
trace telle quelle avec ci/toje-bench/fps_plot.py. La seule difference est
l'ENTREE dans le stage.

Pourquoi ne pas reprendre --cheat de fps_curve : il joue la combinaison du
title a la manette (haut/bas/gauche/droite puis bas, puis N fois haut). Cette
saisie ne se prend pas de facon fiable ici — le title reste au title et le
releve abandonne. On fait donc ce que fait deja tools/stage1_video.py : poser
tct.pstage / tct.pinv et sauter dans title.cheat.launch, ce qui produit
exactement l'etat que le cheat aurait produit, invincibilite comprise.

L'invincibilite n'est pas un confort : sans elle le vaisseau, qui ne pilote ni
ne tire, meurt et la boucle part en DEAD/CHECKPOINT — le releve s'arreterait
la. Elle est verifiee apres l'entree, et le releve refuse de continuer sans.

Le jeu ne porte aucune sonde : bench.frames s'incremente une fois par tour de
stage.loop, l'emulateur le lit sans couter un cycle au programme mesure.
"""
import os
import re
import sys
import time

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                '..', '..', '..', 'ci', 'toje-bench'))
from mcp import Toje, bench_block, globals_block          # noqa: E402

os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

image = os.path.abspath(sys.argv[1])
stage = int(sys.argv[2])
out = os.path.abspath(sys.argv[3])
max_frames = int(sys.argv[4]) if len(sys.argv) > 4 else 30000
WEDGE = 1200


def equ(mapfile, name):
    for line in open(mapfile):
        m = re.match(r'Symbol: %s \(.*\) = ([0-9A-Fa-f]+)' % re.escape(name), line)
        if m:
            return int(m.group(1), 16)
    raise SystemExit('symbole %s absent de %s' % (name, mapfile))


def unit_base(name):
    occ = open('dist/occupancy-fd.html').read()
    m = re.search(r'"name":"%s","container":"[^"]*","page":(\d+),"address":(\d+)'
                  % re.escape(name), occ)
    return int(m.group(1)), int(m.group(2))


BENCH = bench_block(image)
LIVES = globals_block(image) + 4
_, ENG = unit_base('common.engine')
WAIT = ENG + equ('gen/common/build/engine.lwmap', 'gfxlock.bufferSwap.wait')
INV = ENG + equ('gen/common/build/engine.lwmap', 'cheat.invincible')
print('temoins : bench=$%04X lives=$%04X invincible=$%04X' % (BENCH, LIVES, INV),
      flush=True)

t = Toje()
for i in range(1, 9):                       # un point d'arret oublie fige les
    for what in ('clear_watchpoint', 'clear_breakpoint'):   # run_frames suivants
        try:
            t.call(what, {'id': i})
        except Exception:
            pass
t.boot_floppy(image)
t.call('run_frames', {'n': 1200})


def wit():
    b = t.read('0x%04X' % BENCH, 8)
    return {'magic': b[0], 'stage': b[1], 'frames': b[2],
            'camera': (b[3] << 8) | b[4]}


# --- entrer dans le stage, par la routine du cheat elle-meme ------------------
page, base = unit_base('title.cheat')
pstage = equ('gen/title/build/cheat.lwmap', 'tct.pstage')
launch = equ('gen/title/build/cheat.lwmap', 'title.cheat.launch')

# le poke de $E7E6 passe par un point sur : hors de lui, on tue le jeu qu'on mesure
t.call('set_breakpoint', {'pc': '%04X' % WAIT})
t.call('run_to_breakpoint', {'timeout_ms': 120000})
t.call('clear_breakpoint', {'id': 1})
t.call('write_memory', {'addr': 'E7E6', 'bytes': ['%02X' % (0x60 + page)]})
t.call('write_memory', {'addr': hex(base + pstage),
                        'bytes': ['%02X' % stage, '01']})    # stage N + invincible
t.call('set_register', {'reg': 'dp', 'value': '9F'})
t.call('set_register', {'reg': 'pc', 'value': '%04X' % (base + launch)})

machine = 0
for _ in range(200):
    t.call('run_frames', {'n': 60})
    machine += 60
    if wit()['stage'] == stage:
        break
else:
    raise SystemExit('jamais entre dans le stage %d : %s' % (stage, wit()))

inv = t.read(hex(INV), 1)[0]
print('stage %d atteint a la trame %d — invincible = %d %s'
      % (stage, machine, inv, 'OK' if inv else '*** NON ARME ***'), flush=True)
if not inv:
    raise SystemExit('invincible non arme : le releve serait fausse par la mort')

# --- le releve ----------------------------------------------------------------
start = machine
rows = []
prev = wit()['frames']
rendered = 0
dry = 0
t0 = time.time()
status = 'complet'

while machine - start < max_frames:
    t.call('run_frames', {'n': 1})
    machine += 1
    w = wit()
    d = (w['frames'] - prev) & 0xFF
    prev = w['frames']
    rendered += d
    rows.append((machine - start, rendered, d, w['camera'], w['stage']))

    if w['stage'] != stage:
        status = 'sortie du stage (stage=%d)' % w['stage']
        break

    dry = 0 if d else dry + 1
    if dry >= WEDGE:
        status = 'BLOCAGE : %d trames sans un rendu' % dry
        break

    if len(rows) % 2000 == 0:
        el = time.time() - t0
        print('  trame %6d  camera %5d  rendus %6d  (%.0f trames/s reelles)'
              % (machine - start, w['camera'], rendered, (machine - start) / el),
              flush=True)
else:
    status = 'garde-fou max_frames atteint'

with open(out, 'w') as f:
    f.write('machine_frame,rendered,delta,camera,stage,lives\n')
    lv = t.read('0x%04X' % LIVES, 1)[0]
    for r in rows:
        f.write(','.join(str(x) for x in r) + ',%d\n' % lv)

span = rows[-1][0] if rows else 0
fps = 50.0 * rendered / span if span else 0
print('%s — %d trames machine, %d rendus, moyenne %.1f img/s, camera %d'
      % (status, span, rendered, fps, rows[-1][3] if rows else 0), flush=True)
print('ecrit %s' % out, flush=True)
t.close()
