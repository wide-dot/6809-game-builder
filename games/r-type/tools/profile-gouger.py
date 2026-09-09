#!/usr/bin/env python3
"""Profiler le stage 2 pendant que des gougers plongent.

    python3 tools/profile-gouger.py dist/to8.fd <prefixe>
    python3 tools/symbolize-profile.py <prefixe> g-attente g-plongee

Entree directe au stage 2 (le geste de stage2_video.py : tct.pstage pose et
title.cheat.launch appele au point sur), puis deux fenetres de 100 trames
rendues : une ou les gougers ATTENDENT (phase A), une ou plusieurs PLONGENT
(phase B, la boucle par trame de jeu). Le pool est lu avant et apres chaque
fenetre pour compter les gougers par phase — le profil ne vaut que si l'on
sait ce qu'il contenait.
"""
import json
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


MAIN = 'gen/stages/01/build/stage01-main.lwmap'
BSTAGE = equ(MAIN, 'bench.stage')
_, ENG = unit_base('common.engine')
WAIT = ENG + equ('gen/common/build/engine.lwmap', 'gfxlock.bufferSwap.wait')
POOL, NOBJ, OSZ, ROUTINE = 0x4000, 60, 63, 34
GOUGER_IDS = (46, 47, 48, 49)                # ObjID_gouger_tl..br (objid.const.asm)

image = os.path.abspath(sys.argv[1])
out = sys.argv[2]


def gougers(t):
    raw = []
    for off in range(0, NOBJ * OSZ, 256):
        raw += t.read('%04X' % (POOL + off), min(256, NOBJ * OSZ - off))
    phases = {}
    for i in range(NOBJ):
        o = raw[i * OSZ:(i + 1) * OSZ]
        if o[0] in GOUGER_IDS:
            phases[o[ROUTINE]] = phases.get(o[ROUTINE], 0) + 1
    return phases


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
print('stage 2 en place', flush=True)


def prof(what, frames):
    before = gougers(t)
    t.call('profile_reset')
    t.call('profile_start')
    t.call('run_frames', {'n': frames, 'fast': True, 'timeout_ms': 600000})
    t.call('profile_stop')
    after = gougers(t)
    d = {'top': t.call('profile_top', {'n': 80, 'by': 'cycles'}),
         'tree': t.call('profile_flamegraph', {'format': 'tree', 'max_depth': 6}),
         'loops': t.call('profile_loops', {}),
         'gougers_before': before, 'gougers_after': after}
    json.dump(d, open('%s-%s.json' % (out, what), 'w'), indent=1)
    print('%s : %d cycles / %d trames = %d par trame ; gougers par phase avant %s apres %s'
          % (what, d['top']['total_cycles'], frames, d['top']['total_cycles'] // frames,
             before, after), flush=True)


# Les premiers gougers (wave $00C8, $0190, $0258) attendent leur compte a
# rebours ; on profile d'abord l'attente, puis on avance jusqu'a trouver au
# moins deux gougers en phase B (routine 2) et on profile la plongee.
t.call('run_frames', {'n': 150, 'fast': True, 'timeout_ms': 600000})
prof('g-attente', 100)
for _ in range(60):
    t.call('run_frames', {'n': 25, 'fast': True, 'timeout_ms': 600000})
    if gougers(t).get(2, 0) >= 2:
        break
prof('g-plongee', 100)
t.close()
