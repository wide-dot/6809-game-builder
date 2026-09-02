#!/usr/bin/env python3
"""Capture video+son du stage 1 complet, en mode INVINCIBLE.

    TOJE_MCP=<toje>/scripts/toje-mcp.sh TOJE_FAST=1 \
    python3 tools/stage1_video.py dist/to8.fd [dist/stage1.avi]

Meme methode que warship_video.py, dont il reprend les pieges :

  - un point d'arret laisse par une sonde fige les run_frames suivants en
    silence : on purge avant de commencer ;
  - tout poke de $E7E6 passe par le point sur gfxlock.bufferSwap.wait, sinon
    la sonde tue le jeu qu'elle filme ;
  - le declencheur de capture est un PC et non une trame : un declencheur
    frame/seconds coupe le turbo des l'armement, un declencheur pc le laisse
    disponible pour tout le rodage et ne le coupe qu'a l'instant voulu ;
  - le temoin ne s'ecrit pas en dur, il vient des .lwmap et de layout.asm.

Le declencheur est l'entree de la REGION stage : le loader y saute quand le
stage 1 prend la main, et le title — qui vit a la meme adresse — a rendu la
sienne bien avant.
"""
import os, re, sys

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


def layout(name):
    for l in open('gen/layout.asm'):
        m = re.match(r'%s equ \$?([0-9A-Fa-f]+)\s*$' % re.escape(name), l.strip())
        if m:
            return int(m.group(1), 16)
    raise SystemExit('equate %s absente de gen/layout.asm' % name)


def unit_base(name):
    occ = open('dist/occupancy-fd.html').read()
    m = re.search(r'"name":"%s","container":"[^"]*","page":(\d+),"address":(\d+)'
                  % re.escape(name), occ)
    return int(m.group(1)), int(m.group(2))


MAIN    = 'gen/stages/01/build/stage01-main.lwmap'
BSTAGE  = equ(MAIN, 'bench.stage')
TRIGGER = layout('stage.address')            # ou le loader saute pour le stage
_, ENG  = unit_base('common.engine')
WAIT    = ENG + equ('gen/common/build/engine.lwmap', 'gfxlock.bufferSwap.wait')
INV     = ENG + equ('gen/common/build/engine.lwmap', 'cheat.invincible')

out = os.path.abspath(sys.argv[2] if len(sys.argv) > 2 else 'dist/stage1.avi')
os.makedirs(os.path.dirname(out), exist_ok=True)
for stale in (out, os.path.splitext(out)[0] + '.mp4'):
    if os.path.exists(stale):
        os.remove(stale)

t = Toje()
for i in range(1, 9):
    for what in ('clear_watchpoint', 'clear_breakpoint'):
        try:
            t.call(what, {'id': i})
        except Exception:
            pass
t.boot_floppy(os.path.abspath(sys.argv[1]))
t.call('run_frames', {'n': 1200})

occ = open('dist/occupancy-fd.html').read()
m = re.search(r'"name":"title.cheat","container":"title","page":(\d+),"address":(\d+)', occ)
page, base = int(m.group(1)), int(m.group(2))
pstage = equ('gen/title/build/cheat.lwmap', 'tct.pstage')
launch = equ('gen/title/build/cheat.lwmap', 'title.cheat.launch')

t.call('set_breakpoint', {'pc': '%04X' % WAIT})
t.call('run_to_breakpoint', {'timeout_ms': 120000})
t.call('clear_breakpoint', {'id': 1})
t.call('write_memory', {'addr': 'E7E6', 'bytes': ['%02X' % (0x60 + page)]})
t.call('write_memory', {'addr': hex(base + pstage), 'bytes': ['01', '01']})   # stage 1 + invincible
t.call('set_register', {'reg': 'dp', 'value': '9F'})
t.call('set_register', {'reg': 'pc', 'value': '%04X' % (base + launch)})
print('lancement pose au point sur ($%04X)' % WAIT, flush=True)

r = t.call('arm_video_capture', {'path': out, 'start': {'pc': '%04X' % TRIGGER},
                                 'max_bytes': 4000000000})
print('capture armee sur l\'entree du stage ($%04X) :' % TRIGGER, r, flush=True)

for _ in range(30):
    t.call('run_frames', {'n': 250})
    if t.call('video_capture_status').get('state') == 'recording':
        break
else:
    raise SystemExit('le stage 1 n\'a jamais pris la main')

inv = t.read(hex(INV), 1)[0]
print('stage 1 en place — cheat.invincible = %d %s'
      % (inv, 'OK' if inv else '*** PAS INVINCIBLE ***'), flush=True)
if not inv:
    t.call('stop_video_capture')
    raise SystemExit('invincible non arme : capture abandonnee')

os.environ.pop('TOJE_FAST', None)            # le turbo est coupe de toute facon
BUDGET = int(os.environ.get('STAGE_FRAMES', '20000'))
done = 0
while done < BUDGET:
    step = min(500, BUDGET - done)
    r = t.call('run_frames', {'n': step, 'timeout_ms': 600000})
    done += r.get('frames', step) if isinstance(r, dict) else step
    st = t.read(hex(BSTAGE), 1)[0]
    vs = t.call('video_capture_status')
    print('t~%5d  stage=%d  film: %s img, %s o' % (done, st, vs.get('frames'),
                                                   vs.get('bytes')), flush=True)
    if st != 1:
        print('le stage 1 a rendu la main — 100 trames de queue', flush=True)
        t.call('run_frames', {'n': 100, 'timeout_ms': 600000})
        break

print(t.call('stop_video_capture'), flush=True)
# H.264 OBLIGATOIRE : le defaut h265 sort du hev1 que l'iPhone refuse de lire.
print(t.call('encode_capture', {'path': out, 'codec': 'h264', 'quality': 18}), flush=True)
t.close()
