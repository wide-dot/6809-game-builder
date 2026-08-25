#!/usr/bin/env python3
"""Journal long du serpent du stage 5, pour analyse APRES coup.

    TOJE_FAST=1 python3 tools/slither_log.py dist/to8.fd out.csv [--hits N]

Deux points d'arret, et une ligne de CSV par passage :

  `read` — le maitre lit `moveByScript.anim.end` a la fin de son tour
           d'interprete (obj.asm, juste apres runByFrameDrop). C'est LA
           decision : ce drapeau est ce qui doit faire basculer mState.
  `end`  — le moteur resident pose `anim.end = 1` (moveByScript, chemin de
           fin de script). C'est la CAUSE : si aucune ligne `end` ne porte
           l'OST d'un maitre, alors leurs scripts ne terminent jamais.

Colonnes : t (trame video), kind, u (l'OST), id, anim, sub, frame, dur,
mFrames, mState, mActive, flag ($9F98 au moment du passage).

Les adresses ne sont PAS codees en dur : elles sortent de l'occupancy et des
.lwmap, comme dans les autres sondes.
"""
import argparse, csv, os, re, sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                '..', '..', '..', 'ci', 'toje-bench'))
from mcp import Toje

ap = argparse.ArgumentParser()
ap.add_argument('image')
ap.add_argument('out')
ap.add_argument('--hits', type=int, default=4000)
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


def lst_addr(lstfile, needle):
    """L'offset d'une instruction reperee par son texte dans le listing."""
    for l in open(lstfile):
        if needle in l:
            m = re.match(r'([0-9A-F]{4}) ', l)
            if m:
                return int(m.group(1), 16)
    raise SystemExit('instruction absente du listing : ' + needle)


_, ENG = unit('common.engine')
SAFE = sym('gen/common/build/engine.lwmap', 'gfxlock.bufferSwap.wait', ENG)
FRAME = sym('gen/common/build/engine.lwmap', 'gfxlock.frame.count', ENG)
FLAG = sym('gen/common/build/engine.lwmap', 'glb_d0_b')   # global, adresse absolue
CASTPAGE, _ = unit('stage5.cast')
READ = lst_addr('gen/enemies/build/stage5-cast.lst', 'lda   moveByScript.anim.end')
END = ENG + lst_addr('gen/common/build/engine.lst', 'sta   moveByScript.anim.end')
print('point read %04X (page %d), point end %04X, flag %04X'
      % (READ, CASTPAGE, END, FLAG), flush=True)

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
else:
    raise SystemExit('stage 5 jamais seme')
print('stage 5 en place, enregistrement de %d passages' % a.hits, flush=True)

t.call('set_breakpoint', {'pc': '%04X' % READ, 'page': CASTPAGE})
t.call('set_breakpoint', {'pc': '%04X' % END})

EXT = 38
rows = []
for i in range(a.hits):
    # Sortir du point d'arret AVANT de relancer : run_to_breakpoint teste
    # l'arret sur le PC courant et rendrait la main sans rien executer — le
    # premier journal tenait 4 000 lignes rigoureusement identiques.
    if i:
        t.call('step', {'count': 1})
    r = t.call('run_to_breakpoint', {'max_instructions': 2000000})
    if not (isinstance(r, dict) and r.get('hit')):
        print('plus de passage a la %de iteration' % i, flush=True)
        break
    pc = int(r['hit_pc'], 16)
    reg = t.call('read_registers', {})
    u = int(reg['u'], 16)
    fr = t.read('%04X' % FRAME, 2)
    ost = t.read('%04X' % u, 48) if 0x4000 <= u < 0x5000 else [0] * 48
    rows.append(dict(
        t=(fr[0] << 8) | fr[1],
        kind='read' if pc == READ else 'end',
        u='%04X' % u, id=ost[0],
        anim='%04X' % ((ost[8] << 8) | ost[9]),
        sub='%04X' % ((ost[10] << 8) | ost[11]),
        frame=ost[12], dur=ost[13],
        mFrames=(ost[EXT] << 8) | ost[EXT + 1],
        mState=ost[EXT + 5], mActive=ost[EXT + 4],
        flag=t.read('%04X' % FLAG, 1)[0]))
    if i and i % 500 == 0:
        print('  %d passages' % i, flush=True)

with open(a.out, 'w', newline='') as fh:
    w = csv.DictWriter(fh, fieldnames=list(rows[0].keys()))
    w.writeheader()
    w.writerows(rows)
print('%s : %d lignes' % (a.out, len(rows)), flush=True)
