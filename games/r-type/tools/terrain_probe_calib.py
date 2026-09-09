#!/usr/bin/env python3
"""Calibrer la geometrie de terrainCollision.do en l'appelant, point par point.

    python3 tools/terrain_probe_calib.py dist/to8.fd

Entre au stage 2, s'arrete sur le dispatch de RunObjects, puis pour 568
points (quatre rangees, x de camera+8 a camera+150) ecrit le capteur,
pousse une adresse de retour et lance terrainCollision.do (plan 1) ; le B
rendu est compare au bit du masque level2_fc.bin pour douze decalages de
colonne, col = (x - dx) div 3. Le decalage qui tombe juste sur tous les
points est la geometrie du runtime — 8 le 09/09/2026 : la cellule 0 est a
x monde = 8, le bord du champ. C'est ce qui a montre que
gen_gouger_profiles.py sondait 8 px trop a droite.
"""
import os, re, sys
__file__ = os.path.abspath(__file__)
sys.argv = ['x', sys.argv[1], '54', '1']
sys.path.insert(0, '../../ci/toje-bench')
exec(open('tools/object_cost_probe.py').read().split("for phase in PHASES:")[0])
def sym(n):
    for l in open(ENGMAP):
        m = re.match(r'Symbol: %s \(.*\) = ([0-9A-F]+)' % re.escape(n), l)
        if m: return ENG + int(m.group(1), 16)
    raise SystemExit(n)
SX = sym('terrainCollision.sensor.x'); SY = sym('terrainCollision.sensor.y')
t.call('run_frames', {'n': 300, 'fast': True, 'timeout_ms': 600000})
DISPATCH = dispatch_pc()
t.call('set_breakpoint', {'pc': '%04X' % DISPATCH}); t.call('run_to_breakpoint', {'timeout_ms': 60000}); t.call('clear_breakpoint', {'id': 1})
cam = t.read('9FE6', 2); cam = (cam[0] << 8) | cam[1]
print('camera', cam, flush=True)
mask = open('src/stages/02/terrain/level2_fc.bin', 'rb').read()
def bit(col, row): return (mask[row*48 + col//8] >> (7 - col % 8)) & 1 if 0 <= col < 384 and 0 <= row < 30 else 0
def probe(x, y):
    t.call('write_memory', {'addr': '%04X' % SX, 'bytes': ['%02X' % (x >> 8), '%02X' % (x & 255)]})
    t.call('write_memory', {'addr': '%04X' % SY, 'bytes': ['%02X' % (y >> 8), '%02X' % (y & 255)]})
    s = int(regs()['s'], 16) - 2
    t.call('write_memory', {'addr': '%04X' % s, 'bytes': ['%02X' % (DISPATCH >> 8), '%02X' % (DISPATCH & 255)]})
    t.call('set_register', {'reg': 's', 'value': '%04X' % s})
    t.call('set_register', {'reg': 'b', 'value': '01'})
    t.call('set_register', {'reg': 'pc', 'value': '%04X' % TCDO})
    r = t.call('run_until_pc', {'pc': '%04X' % DISPATCH, 'max_instructions': 2000})
    return int(regs()['b'], 16) != 0
# une rangee du plafond (y=20, rangee 1) et une du sol (y=180, rangee 28) sur 120 px
score = {dx: 0 for dx in range(0, 12)}
n = 0
for y in (20, 60, 120, 180):
    row = (y - 11) // 6
    for x in range(cam + 8, cam + 150):
        v = probe(x, y); n += 1
        for dx in score:
            if v == bool(bit((x - dx) // 3, row)): score[dx] += 1
print('points', n, 'accord par decalage dx (col = (x - dx) // 3) :', score)
t.close()
