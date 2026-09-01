#!/usr/bin/env python3
"""Capture video+son du stage 1 complet, en mode INVINCIBLE.

    TOJE_MCP=<toje>/scripts/toje-mcp.sh TOJE_FAST=1 \
    python3 tools/stage1_video.py dist/to8.fd [dist/stage1.avi]

Meme mode operatoire que tools/warship_video.py, dont ce script est le
decalque : le rodage (boot, title, cheat) se fait en TURBO, et le film ne
part qu'a la premiere trame du stage.

Le declencheur est l'ENTREE DE LA REGION 'stage' — l'adresse ou tout ecran
est charge, lue dans gen/layout.asm et jamais ecrite en dur. Le title y passe
aussi, mais il l'a deja franchie quand on arme : on entre par
title.cheat.launch, donc le prochain a executer cette adresse est le stage 1.
Un declencheur pc laisse le turbo disponible jusqu'a cet instant precis.
"""
import os, re, sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                '..', '..', '..', 'ci', 'toje-bench'))
from mcp import Toje

STAGE = 1


def unit_base(name):
    occ = open('dist/occupancy-fd.html').read()
    m = re.search(r'"name":"%s","container":"[^"]*","page":(\d+),"address":(\d+)'
                  % re.escape(name), occ)
    return int(m.group(1)), int(m.group(2))


def sym(mapfile, name, base):
    for l in open(mapfile):
        m = re.match(r'Symbol: %s \(.*\) = ([0-9A-Fa-f]+)' % re.escape(name), l)
        if m:
            return base + int(m.group(1), 16)
    raise SystemExit('symbole %s absent de %s' % (name, mapfile))


def equ(mapfile, name):
    for l in open(mapfile):
        m = re.match(r'Symbol: %s \(.*\) = ([0-9A-Fa-f]+)' % re.escape(name), l)
        if m:
            return int(m.group(1), 16)
    raise SystemExit('equate %s absente de %s' % (name, mapfile))


def layout(name):
    """Une equate de gen/layout.asm — le builder la deplace, pas nous."""
    for l in open('gen/layout.asm'):
        m = re.match(r'%s equ \$?([0-9A-Fa-f]+)\s*$' % re.escape(name), l.strip())
        if m:
            return int(m.group(1), 16)
    raise SystemExit('equate %s absente de gen/layout.asm' % name)


MAIN   = 'gen/stages/01/build/stage01-main.lwmap'
BENCH  = equ(MAIN, 'bench.magic')
BSTAGE = equ(MAIN, 'bench.stage')
WAIT   = 0x6100 + equ('gen/common/build/engine.lwmap', 'gfxlock.bufferSwap.wait')
ENTRY  = layout('stage.address')       # l'entree de tout ecran
_, ENGINE_BASE = unit_base('common.engine')
INV = sym('gen/common/build/engine.lwmap', 'cheat.invincible', ENGINE_BASE)


def cheat_state_addr():
    occ = open('dist/occupancy-fd.html').read()
    m = re.search(r'"name":"title.cheat","container":"title","page":(\d+),"address":(\d+)', occ)
    page, addr = int(m.group(1)), int(m.group(2))
    return page, addr + equ('gen/title/build/cheat.lwmap', 'tct.pstage')


out = os.path.abspath(sys.argv[2] if len(sys.argv) > 2 else 'dist/stage1.avi')
os.makedirs(os.path.dirname(out), exist_ok=True)
if os.path.exists(out):
    os.remove(out)

t = Toje()
# une session d'emulateur se partage : un point d'arret laisse par une sonde
# fige les run_frames suivants en silence
for i in range(1, 9):
    for what in ('clear_watchpoint', 'clear_breakpoint'):
        try:
            t.call(what, {'id': i})
        except Exception:
            pass
t.boot_floppy(os.path.abspath(sys.argv[1]))
t.call('run_frames', {'n': 1200})

# tout poke de $E7E6 passe par le point sur gfxlock.bufferSwap.wait
page, addr = cheat_state_addr()
launch = equ('gen/title/build/cheat.lwmap', 'title.cheat.launch')
base = addr - equ('gen/title/build/cheat.lwmap', 'tct.pstage')
t.call('set_breakpoint', {'pc': '%04X' % WAIT})
t.call('run_to_breakpoint', {'timeout_ms': 120000})
t.call('clear_breakpoint', {'id': 1})
t.call('write_memory', {'addr': 'E7E6', 'bytes': ['%02X' % (0x60 + page)]})
t.call('write_memory', {'addr': hex(addr), 'bytes': ['%02X' % STAGE, '01']})
t.call('set_register', {'reg': 'dp', 'value': '9F'})
t.call('set_register', {'reg': 'pc', 'value': '%04X' % (base + launch)})
print('lancement pose au point sur ($%04X)' % WAIT, flush=True)

r = t.call('arm_video_capture', {
    'path': out,
    'start': {'pc': '%04X' % ENTRY},
    'max_bytes': 4000000000,
})
print("capture armee sur l'entree du stage ($%04X) : %s" % (ENTRY, r), flush=True)

for _ in range(30):
    t.call('run_frames', {'n': 250})
    if t.call('video_capture_status').get('state') == 'recording':
        break
else:
    raise SystemExit('stage %d jamais atteint apres le lancement direct' % STAGE)

inv = t.read(hex(INV), 1)[0]
magic = t.read(hex(BENCH), 1)[0]
print('stage en place — magic=$%02X, cheat.invincible = %d %s'
      % (magic, inv, 'OK' if inv else '*** PAS INVINCIBLE ***'), flush=True)
if not inv:
    t.call('stop_video_capture')
    raise SystemExit('invincible non arme : capture abandonnee')

os.environ.pop('TOJE_FAST', None)
BUDGET = int(os.environ.get('STAGE_FRAMES', '12000'))
done = 0
while done < BUDGET:
    step = min(500, BUDGET - done)
    r = t.call('run_frames', {'n': step, 'timeout_ms': 600000})
    done += r.get('frames', step) if isinstance(r, dict) else step
    st = t.read(hex(BSTAGE), 1)[0]
    vs = t.call('video_capture_status')
    print('t~%5d  stage=%d  film: %s img, %s o'
          % (done, st, vs.get('frames'), vs.get('bytes')), flush=True)
    if st != STAGE:
        print('le stage %d a rendu la main — 100 trames de queue' % STAGE, flush=True)
        t.call('run_frames', {'n': 100, 'timeout_ms': 600000})
        break

print(t.call('stop_video_capture'), flush=True)
print('AVI :', out, os.path.getsize(out), 'octets')
