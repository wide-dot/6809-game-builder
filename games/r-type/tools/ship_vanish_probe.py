#!/usr/bin/env python3
"""Reproduit la disparition du vaisseau au stage 1 et remonte l'ecrasement.

    TOJE_MCP=<toje>/scripts/toje-mcp.sh TOJE_FAST=1 \
    python3 tools/ship_vanish_probe.py [--watch ADDR]

Sans argument : surveille glb_camera_y_pos ($9FE4). Le recit complet est dans
le commit qui ajoute ce fichier ; en resume, la chaine est

    un tir ennemi (common.foefire) dessine ligne 1
      -> son sprite compile ecrit a offset NEGATIF depuis U, sous $A000
      -> $9FE4 = glb_camera_y_pos, juste avant le buffer, devient $7900
      -> CheckRange borne le joueur contre la camera et lui pose y=$7910
      -> le vaisseau est dessine 30000 pixels plus bas : invisible.

UN POINT DE SURVEILLANCE NE ROMPT QUE SOUS run_to_breakpoint, jamais sous
run_frames — et l'attribut est `len`, pas `length`. Une sonde qui l'ignore
croit qu'il ne se passe rien.
"""

import os, re, sys
G = "/Users/benoitrousseau/Documents/Claude/Projects/6809-game-builder/games/r-type"
sys.path.insert(0, "/Users/benoitrousseau/Documents/Claude/Projects/6809-game-builder/ci/toje-bench")
os.chdir(G)
from mcp import Toje

def equ(mapfile, name):
    for l in open(mapfile):
        m = re.match(r'Symbol: %s \(.*\) = ([0-9A-Fa-f]+)' % re.escape(name), l)
        if m: return int(m.group(1), 16)
    raise SystemExit('equate %s absente' % name)
def layout(name):
    for l in open('gen/layout.asm'):
        m = re.match(r'%s equ \$?([0-9A-Fa-f]+)\s*$' % re.escape(name), l.strip())
        if m: return int(m.group(1), 16)
    raise SystemExit(name)

PLAYER = layout('dp.address'); YPOS = PLAYER + 21
MAIN = 'gen/stages/01/build/stage01-main.lwmap'
BSTAGE = equ(MAIN, 'bench.stage')
WAIT = 0x6100 + equ('gen/common/build/engine.lwmap', 'gfxlock.bufferSwap.wait')

t = Toje()
for i in range(1, 9):
    for w in ('clear_watchpoint', 'clear_breakpoint'):
        try: t.call(w, {'id': i})
        except Exception: pass
t.boot_floppy(os.path.abspath('dist/to8.fd'))
t.call('run_frames', {'n': 1200})
occ = open('dist/occupancy-fd.html').read()
m = re.search(r'"name":"title.cheat","container":"title","page":(\d+),"address":(\d+)', occ)
page, addr = int(m.group(1)), int(m.group(2)) + equ('gen/title/build/cheat.lwmap', 'tct.pstage')
base = addr - equ('gen/title/build/cheat.lwmap', 'tct.pstage')
t.call('set_breakpoint', {'pc': '%04X' % WAIT}); t.call('run_to_breakpoint', {'timeout_ms': 120000})
t.call('clear_breakpoint', {'id': 1})
t.call('write_memory', {'addr': 'E7E6', 'bytes': ['%02X' % (0x60 + page)]})
t.call('write_memory', {'addr': hex(addr), 'bytes': ['01', '01']})
t.call('set_register', {'reg': 'dp', 'value': '9F'})
t.call('set_register', {'reg': 'pc', 'value': '%04X' % (base + equ('gen/title/build/cheat.lwmap','title.cheat.launch'))})
for _ in range(30):
    t.call('run_frames', {'n': 250, 'fast': True})
    if t.read(hex(BSTAGE), 1)[0] == 1: break

y = lambda: (lambda b: (b[0] << 8) | b[1])(t.read('%04X' % YPOS, 2))
print("stage 1 : y=%d" % y(), flush=True)

# 1. approche grossiere puis fine
done = 0
while done < int(os.environ.get('PROBE_FRAMES', '2500')):
    t.call('run_frames', {'n': 50, 'fast': True, 'timeout_ms': 120000}); done += 50


WATCH = int(os.environ.get('PROBE_WATCH', '9FE4'), 16)
val = lambda: (lambda b: (b[0] << 8) | b[1])(t.read('%04X' % WATCH, 2))
print("t=%d  y_joueur=%d  [$%04X]=$%04X" % (done, y(), WATCH, val()), flush=True)
t.call('set_watchpoint', {'addr': '%04X' % WATCH, 'len': 2})
good = val()
for i in range(400):
    t.call('run_to_breakpoint', {'max_instructions': 8000000})
    reg = t.call('read_registers', {}); regs = reg.get('registers', reg)
    pc, v = regs.get('pc'), val()
    if v != good:
        pm = t.call('read_page_map', {})
        print("ECRIVAIN : pc=%s  $%04X : $%04X -> $%04X" % (pc, WATCH, good, v), flush=True)
        print("   pages :", {k: pm.get(k) for k in ('cart_ram_page', 'data_page')}, flush=True)
        print("   registres :", {k: regs.get(k) for k in ('a','b','x','y','u','s','dp')}, flush=True)
        for l in t.call('disassemble', {'addr': '%04X' % (int(pc, 16) - 12), 'count': 10}).get('lines', []):
            print("     %s  %-12s %s" % (l.get('addr'), ' '.join(l.get('bytes', [])), l.get('mnemonic')), flush=True)
        break
    t.call('step', {})
else:
    print("400 ecritures sans changement de valeur", flush=True)
t.close()
