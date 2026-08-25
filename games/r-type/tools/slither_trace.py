#!/usr/bin/env python3
"""Trace complete d'UN serpent, de son init a sa destruction.

    TOJE_FAST=1 python3 tools/slither_trace.py dist/to8.fd out.csv [--loops N]

On attend la naissance d'un maitre, on retient SON OST, et on l'echantillonne
a chaque tour de sa boucle (le point ou MasterLive lit anim.end) jusqu'a ce
qu'il meure. Les autres serpents qui passent au meme point sont ignores.

A chaque tour on releve, en plus de l'etat du maitre, les QUINZE records et
les QUINZE slots publies — c'est ce qui dit si la chaine existe vraiment et
si elle est etalee ou groupee. Le direntry du cast est deja monte : on est
arrete DANS son code.

Colonnes : t, mFrames, mState, mActive, anim, sub, xpos, ypos, frame,
nvivants (records a l'etat 1), npublies (slots allumes), xs (les x publies).
"""
import argparse, csv, os, re, sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                '..', '..', '..', 'ci', 'toje-bench'))
from mcp import Toje

ap = argparse.ArgumentParser()
ap.add_argument('image')
ap.add_argument('out')
ap.add_argument('--loops', type=int, default=1200)
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


CASTPAGE, CASTADDR = unit('stage5.cast')
_, ENG = unit('common.engine')
SAFE = sym('gen/common/build/engine.lwmap', 'gfxlock.bufferSwap.wait', ENG)
FRAME = sym('gen/common/build/engine.lwmap', 'gfxlock.frame.count', ENG)
M = 'gen/enemies/build/stage5-cast.lwmap'
INIT = sym(M, 'slither.MasterInit') + CASTADDR
RECS = sym(M, 'slither.Recs') + CASTADDR
SLOTS = sym(M, 'slither.Slots') + CASTADDR
NREC, RECSZ, SLOTSZ = 15, 2, 5
# le tour de boucle : la lecture d'anim.end DANS MasterLive (la seconde du
# listing ; la premiere est celle du callback Push)
hits = [int(m.group(1), 16) for l in open('gen/enemies/build/stage5-cast.lst')
        if 'lda   moveByScript.anim.end' in l
        for m in [re.match(r'([0-9A-F]{4}) ', l)] if m]
LOOP = hits[1] + CASTADDR
print('init %04X, tour %04X, recs %04X, slots %04X (page %d)'
      % (INIT, LOOP, RECS, SLOTS, CASTPAGE), flush=True)

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

bp = t.call('set_breakpoint', {'pc': '%04X' % INIT, 'page': CASTPAGE})
r = t.call('run_to_breakpoint', {'max_instructions': 4000000})
if not (isinstance(r, dict) and r.get('hit')):
    raise SystemExit('aucune naissance')
reg = t.call('read_registers', {})
U = int(reg['u'], 16)
sub = t.read('%04X' % (U + 1), 2)
print('maitre suivi : OST %04X, subtype %02X/%02X (variante %d, script %d)'
      % (U, sub[0], sub[1], sub[0] & 3, sub[1] >> 4), flush=True)
t.call('clear_breakpoint', {'id': bp['id']})
t.call('set_breakpoint', {'pc': '%04X' % LOOP, 'page': CASTPAGE})

EXT = 38
rows = []
for i in range(a.loops):
    t.call('step', {'count': 1})
    r = t.call('run_to_breakpoint', {'max_instructions': 2000000})
    if not (isinstance(r, dict) and r.get('hit')):
        print('plus de tour a la %de boucle' % i, flush=True)
        break
    reg = t.call('read_registers', {})
    if int(reg['u'], 16) != U:
        continue                          # un autre serpent : on l'ignore
    ost = t.read('%04X' % U, 48)
    if ost[0] == 0:
        print('le maitre est mort a la %de boucle' % i, flush=True)
        break
    recs = t.read('%04X' % RECS, NREC * RECSZ)
    slots = t.read('%04X' % SLOTS, NREC * SLOTSZ)
    fr = t.read('%04X' % FRAME, 2)
    lit = [k for k in range(NREC) if slots[k * SLOTSZ]]
    rows.append(dict(
        t=(fr[0] << 8) | fr[1],
        mFrames=(ost[EXT] << 8) | ost[EXT + 1],
        mState=ost[EXT + 5], mActive=ost[EXT + 4],
        anim='%04X' % ((ost[8] << 8) | ost[9]),
        sub='%04X' % ((ost[10] << 8) | ost[11]),
        xpos=(ost[18] << 8) | ost[19], ypos=(ost[22] << 8) | ost[23],
        frame=ost[12],
        nvivants=sum(1 for k in range(NREC) if recs[k * RECSZ] == 1),
        npublies=len(lit),
        xs=' '.join(str(slots[k * SLOTSZ + 1]) for k in lit)))
    if i and i % 200 == 0:
        print('  %d tours, mFrames=%d' % (i, rows[-1]['mFrames']), flush=True)

with open(a.out, 'w', newline='') as fh:
    w = csv.DictWriter(fh, fieldnames=list(rows[0].keys()))
    w.writeheader()
    w.writerows(rows)
print('%s : %d tours traces' % (a.out, len(rows)), flush=True)
