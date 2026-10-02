#!/usr/bin/env python3
"""Capture video+son de la CHAINE des stages 1 -> 2 -> 3 -> 4 en INVINCIBLE,
UN FILM PAR STAGE, chacun encode en H.264 des que son stage rend la main.

    TOJE_FAST=1 python3 tools/stages_chain_video.py dist/to8.fd [dist/chain]
    -> dist/chain-stage1.mp4, chain-stage2.mp4, chain-stage3.mp4, chain-stage4.mp4

Meme rodage que stages12_video.py (purge des points d'arret, cheat pose au
point sur gfxlock.bufferSwap.wait, temoin bench.stage lu dans les .lwmap).
Le film d'un stage court de sa prise de main a celle du suivant (le fondu de
fin et le releve de score lui appartiennent) ; au basculement de bench.stage
la capture est arretee, encodee, effacee (l'AVI sans perte pese 200 Mo les
deux minutes), et REARMEE sur un declencheur pc — gfxlock.bufferSwap.wait,
qui tombe a la trame suivante — pour le stage qui commence. Le stage 4 a un
vrai boss (globals.realBoss : pas de victoire par delai) : sans tir il ne
finit jamais, son film est borne par STAGE4_FRAMES (defaut 12 000, 4 min).
Chaque MP4 pret est annonce par une ligne « MP4 : <chemin> ».
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
    raise SystemExit('equate %s absente de %s' % (name, mapfile))


def layout(name):
    for l in open('gen/layout.asm'):
        m = re.match(r'%s\s+equ\s+\$([0-9A-Fa-f]+)' % re.escape(name), l)
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
TRIGGER = layout('stage.address')
_, ENG  = unit_base('common.engine')
WAIT    = ENG + equ('gen/common/build/engine.lwmap', 'gfxlock.bufferSwap.wait')
INV     = ENG + equ('gen/common/build/engine.lwmap', 'cheat.invincible')
LAST    = 4
STAGE4_FRAMES = int(os.environ.get('STAGE4_FRAMES', '12000'))
BUDGET  = int(os.environ.get('STAGE_FRAMES', '80000'))

prefix = os.path.abspath(sys.argv[2] if len(sys.argv) > 2 else 'dist/chain')
os.makedirs(os.path.dirname(prefix), exist_ok=True)
avi = lambda s: '%s-stage%d.avi' % (prefix, s)
mp4 = lambda s: '%s-stage%d.mp4' % (prefix, s)
for s in range(1, LAST + 1):
    for stale in (avi(s), mp4(s)):
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

t.call('arm_video_capture', {'path': avi(1), 'start': {'pc': '%04X' % TRIGGER},
                             'max_bytes': 4000000000})
for _ in range(30):
    t.call('run_frames', {'n': 250})
    if t.call('video_capture_status').get('state') == 'recording':
        break
else:
    raise SystemExit('le stage 1 n\'a jamais pris la main')
inv = t.read(hex(INV), 1)[0]
print('stage 1 en place — cheat.invincible = %d %s' % (inv, 'OK' if inv else '*** PAS INVINCIBLE ***'), flush=True)
if not inv:
    t.call('stop_video_capture')
    raise SystemExit('invincible non arme : capture abandonnee')
os.environ.pop('TOJE_FAST', None)


def deliver(s):
    print(t.call('stop_video_capture'), flush=True)
    t.call('encode_capture', {'path': avi(s), 'output': mp4(s), 'codec': 'h264', 'quality': 18})
    os.remove(avi(s))
    print('MP4 : %s (%d octets)' % (mp4(s), os.path.getsize(mp4(s))), flush=True)


cur = 1
done = 0
since = 0
while done < BUDGET:
    step = 100
    r = t.call('run_frames', {'n': step, 'timeout_ms': 600000})
    n = r.get('frames', step) if isinstance(r, dict) else step
    done += n
    since += n
    st = t.read(hex(BSTAGE), 1)[0]
    if done % 1000 < step:
        vs = t.call('video_capture_status')
        print('t~%5d  stage=%d  film: %s img' % (done, st, vs.get('frames')), flush=True)
    if st != cur or (cur == LAST and since >= STAGE4_FRAMES):
        if st == cur:
            print('stage %d : budget de %d trames atteint (vrai boss, pas de fin sans tir)' % (cur, since), flush=True)
        else:
            print('stage %d rend la main a %d apres %d trames' % (cur, st, since), flush=True)
        deliver(cur)
        if st == cur or st > LAST or st < cur:
            break
        cur = st
        since = 0
        t.call('arm_video_capture', {'path': avi(cur), 'start': {'pc': '%04X' % WAIT},
                                     'max_bytes': 4000000000})
print('FIN', flush=True)
t.close()
