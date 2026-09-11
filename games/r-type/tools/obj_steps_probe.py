#!/usr/bin/env python3
"""RunObjects et BuildSprites OBJET PAR OBJET, au milieu du stage 3.

    OUT=/tmp/steps python3 tools/obj_steps_probe.py     (depuis games/r-type)

Meme methode que frame_steps_probe.py (run_until_pc + total_cycles de
l'anneau) mais a l'interieur des deux gros postes : le CPU s'arrete au
`jsr [,x]` de RunObjects (U = l'objet) et au `jsr ,y` de BuildSprites
(l'objet dans l'operande auto-modifie qui suit), puis a l'instruction de
retour ; l'ecart est le cout de la routine de cet objet, cumule par
(identifiant, sous-type). Les adresses sont celles du listing du moteur
(gen/common/build/engine.lst) — a relever a nouveau s'il bouge.
PIEGE : les noms viennent des tables d'identifiants du STAGE et du commun
seulement ; celle du title recouvre les memes numeros.
Resultat du 10/09/2026 : doc/profil-boucle-stage3-2026-09.md.
"""
import os, re, sys, json, glob, collections
__file__ = os.path.abspath("tools/fire_burst_probe.py")
sys.path.insert(0, "../../ci/toje-bench")
sys.argv = ['x', 'dist/to8.fd']
src = open('tools/fire_burst_probe.py').read().split("def weapons():")[0]
src = src.replace("'bytes': ['02', '01']", "'bytes': ['03', '01']").replace("== 2:", "== 3:")
exec(src)
OUT = os.environ['OUT']
POOL, NOBJ, OSZ = 0x4000, 60, 63
EXT, ROUT = 38, 34
REACT = 42
FC = ENG + equ(ENGMAP, 'gfxlock.frame.count')
INV = ENG + equ(ENGMAP, 'cheat.invincible')
_, ST3 = unit_base('stage3')
def st(off): return ST3 + off
LOOP = st(0x017D); RUNOBJ_CALL = st(0x01EC); BUILD_CALL = st(0x022D)
# les deux appels, releves dans le listing du moteur DU JOUR (ils bougent
# avec tout ce qui precede dans engine.asm)
def lst_offset(src_file, src_line):
    for l in open('gen/common/build/engine.lst', errors='replace'):
        m = re.match(r'([0-9A-F]{4}) [0-9A-F ]+\((?:[^)]*/)?%s\):%05d ' % (re.escape(src_file), src_line), l)
        if m: return int(m.group(1), 16)
    raise SystemExit('appel introuvable dans engine.lst : %s:%d' % (src_file, src_line))
RO_JSR = ENG + lst_offset('RunObjects.asm', 55); RO_RET = RO_JSR + 2          # jsr [,x] / retour
BS_JSR = ENG + lst_offset('BuildSprites.asm', 347); BS_RET = BS_JSR + 2; BS_OBJ = BS_RET + 1   # jsr ,y / retour / l'objet (ldu #, operande auto-modifie)
print('RunObjects jsr %04X, BuildSprites jsr %04X' % (RO_JSR, BS_JSR), flush=True)
names = {}
for f in ('src/common/objid-common.const.asm', 'src/stages/03/objid.const.asm'):
    for l in open(f, errors='replace'):
        m = re.match(r'\s*(ObjID_\w+)\s+equ\s+(\d+)', l)
        if m: names.setdefault(int(m.group(2)), m.group(1))
t.call('write_memory', {'addr': '%04X' % INV, 'bytes': ['01']})
def fcount():
    b = t.read('%04X' % FC, 2); return (b[0] << 8) | b[1]
def pool():
    raw = []
    for off in range(0, NOBJ * OSZ, 256):
        raw += t.read('%04X' % (POOL + off), min(256, NOBJ * OSZ - off))
    return [raw[i * OSZ:(i + 1) * OSZ] for i in range(NOBJ)]
def run(n): t.call('run_frames', {'n': n, 'fast': True, 'timeout_ms': 600000})
def cyc(): return t.call('dump_trace_ring', {'count': 1})['instructions'][-1]['total_cycles']
def regs(): return t.call('read_registers')
def until(target, maxi=600000):
    t.call('run_until_pc', {'pc': '%04X' % target, 'max_instructions': maxi})
    return int(regs()['pc'], 16) == target
def objkey(addr):
    o = t.read('%04X' % addr, 2); return (o[0], o[1])
reactors = lambda: [(i, o) for i, o in enumerate(pool()) if o[0] == REACT and (o[1] & 7) == 3 and o[ROUT] == 1]
for i in range(1200):
    run(10)
    if len(reactors()) >= 4: break
print('milieu du stage 3 : trame %d, %d objets' % (fcount(), sum(1 for o in pool() if o[0])), flush=True)
runs = collections.defaultdict(lambda: [0, 0]); draws = collections.defaultdict(lambda: [0, 0])
NL = 3
for it in range(NL):
    assert until(LOOP)
    # --- RunObjects, objet par objet ---
    assert until(RUNOBJ_CALL); c_start = cyc()
    n = 0; measured = 0
    while until(RO_JSR, 400 if n else 100000):
        u = int(regs()['u'], 16); key = objkey(u); c0 = cyc()
        assert until(RO_RET); c1 = cyc()
        runs[key][0] += 1; runs[key][1] += c1 - c0; measured += c1 - c0; n += 1
    print('boucle %d : RunObjects %d objets, %d cycles dans les routines' % (it + 1, n, measured), flush=True)
    # --- BuildSprites, sprite par sprite ---
    assert until(BUILD_CALL); c_start = cyc()
    n = 0; measured = 0
    while until(BS_JSR, 3000 if n else 100000):
        key = objkey(int.from_bytes(t.read('%04X' % BS_OBJ, 2), 'big')); c0 = cyc()
        assert until(BS_RET); c1 = cyc()
        draws[key][0] += 1; draws[key][1] += c1 - c0; measured += c1 - c0; n += 1
    print('boucle %d : BuildSprites %d sprites, %d cycles dans les routines' % (it + 1, n, measured), flush=True)
def show(title, tab):
    print('\n%s (moyenne par boucle, %d boucles)' % (title, NL))
    print('%-34s %5s %9s %8s' % ('objet (id/sous-type)', 'n', 'cycles', 'chacun'))
    tot = 0
    for key, (cnt, cy) in sorted(tab.items(), key=lambda kv: -kv[1][1]):
        nm = names.get(key[0], 'id%d' % key[0])
        print('%-34s %5.1f %9.0f %8.0f' % ('%s/%d' % (nm, key[1]), cnt / NL, cy / NL, cy / cnt)); tot += cy
    print('%-34s %5s %9.0f' % ('total', '', tot / NL))
show('RunObjects', runs); show('BuildSprites', draws)
json.dump({'runs': {str(k): v for k, v in runs.items()}, 'draws': {str(k): v for k, v in draws.items()}}, open(os.path.join(OUT, 'obj_steps.json'), 'w'))
t.close()
