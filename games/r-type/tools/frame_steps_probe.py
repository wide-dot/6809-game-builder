#!/usr/bin/env python3
"""Le cout de chaque grosse etape d'une boucle de jeu, mesure sous toje.

    OUT=/tmp/steps python3 tools/frame_steps_probe.py     (depuis games/r-type)

METHODE. L'anneau de trace de toje ne tient que 4 096 instructions, un
dixieme de rendu : il ne sert ici que de compteur (total_cycles). Le CPU est
conduit de frontiere en frontiere par run_until_pc — les adresses des `jsr`
de la boucle de stage-main.asm, relevees dans le listing de l'unite du stage
(stage03-main.lst, colonne des offsets, + la base de l'unite dans le rapport
d'occupation) — et l'ecart de total_cycles entre deux frontieres est le cout
de l'etape. Six boucles, moyennees. L'IRQ 50 Hz est mesuree a part : entree
de stage.userIRQ -> l'adresse de retour lue sur la pile.
run_until_pc est FIABLE apres un long run en fast, la ou un point d'arret ne
se declenche plus (vecu, 10/09/2026). Il execute instruction par instruction :
six boucles de 185 000 cycles prennent une minute.

Les offsets des frontieres sont ceux du listing du jour : a relever a nouveau
si stage-main.asm bouge (grep des `jsr` dans gen/stages/03/build/stage03-main.lst).
Resultat du 10/09/2026 : doc/profil-boucle-stage3-2026-09.md.
"""
import os, re, sys, json
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
LOOP = st(0x017D); USERIRQ = st(0x0386)
IRQ_RET = [ENG + 0x0318 + 4, ENG + 0x0347 + 4]
STEPS = [('joypad.latch.read', 0x0199), ('ScrollCols (defilement avant-plan)', 0x01A7), ('tilemap.flush', 0x01AA), ('ObjectWave', 0x01AD),
         ('Collision_Run (passe AABB + contact pod)', 0x01B2), ('fondu, joueur, pod, bits', 0x01B8), ('RunObjects (tous les objets)', 0x01EC),
         ('gfxlock.on', 0x01EF), ('mscroll.do (blast couche battleship)', 0x01FB), ('mscroll.move (feed couche)', 0x01FE),
         ('bship.patch.drain', 0x0201), ('bship.collisionFollow', 0x0209), ('stage.frameBlit (effacement)', 0x0216),
         ('BuildSprites (sprites + wsmgr)', 0x022D), ('stage.frame.tiles (decor avant-plan)', 0x0230), ('masque du champ (overlay)', 0x024F),
         ('hud.normal', 0x0257), ('gfxlock.off', 0x0267), ('stage.endTick, gfxlock.loop, retour', 0x0273)]
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
def pc(): return int(t.call('read_registers')['pc'], 16)
def until(target, maxi=600000):
    r = t.call('run_until_pc', {'pc': '%04X' % target, 'max_instructions': maxi})
    return pc() == target, r
reactors = lambda: [(i, o) for i, o in enumerate(pool()) if o[0] == REACT and (o[1] & 7) == 3 and o[ROUT] == 1]
for i in range(1200):
    run(10)
    if len(reactors()) >= 4: break
print('milieu du stage 3 : trame %d, %d reacteurs vivants, %d objets' % (fcount(), len(reactors()), sum(1 for o in pool() if o[0])), flush=True)
t.call('screenshot', {'path': os.path.join(OUT, 'scene.png')})
loops = []
for it in range(6):
    ok, r = until(LOOP)
    if not ok: print('stage.loop non atteint', r); break
    c0 = cyc(); f0 = fcount(); prev = c0; row = []
    ok, r = until(st(STEPS[0][1])); c = cyc()
    row.append(('tete de boucle (bench, etat)', c - c0)); prev = c
    for k, (name, off) in enumerate(STEPS):
        nxt = st(STEPS[k + 1][1]) if k + 1 < len(STEPS) else LOOP
        ok, r = until(nxt)
        c = cyc()
        row.append((name, c - prev if ok else None)); prev = c
        if not ok: print('  frontiere manquee apres :', name, r, flush=True); break
    loops.append((c - c0, fcount() - f0, row))
    print('boucle %d : %d cycles, %d trames' % (it + 1, c - c0, fcount() - f0), flush=True)
# l'IRQ : de l'entree du hook au retour dans le gestionnaire
irqs = []
for k in range(8):
    ok, r = until(USERIRQ)
    if not ok: break
    c0 = cyc()
    sp = int(t.call('read_registers')['s'], 16)      # l'adresse de retour du jsr, sur la pile
    b = t.read('%04X' % sp, 2); ret = (b[0] << 8) | b[1]
    ok1, _ = until(ret, 30000)
    irqs.append(cyc() - c0 if ok1 else None)
print('IRQ 50 Hz (stage.userIRQ) : %s' % irqs, flush=True)
json.dump({'loops': loops, 'irqs': irqs}, open(os.path.join(OUT, 'steps.json'), 'w'))
# la synthese
names = ['tete de boucle (bench, etat)'] + [n for n, _ in STEPS]
n = len(loops)
avg = {nm: sum((r[i][1] or 0) for _, _, r in loops) / n for i, nm in enumerate(names)}
tot = sum(c for c, _, _ in loops) / n
print('\n%-42s %9s %6s' % ('etape', 'cycles', '%'))
for nm in names: print('%-42s %9.0f %5.1f%%' % (nm, avg[nm], 100 * avg[nm] / tot))
print('%-42s %9.0f' % ('boucle entiere', tot))
ok = [v for v in irqs if v]
print('trames par boucle : %s ; IRQ 50 Hz : %s, moyenne %.0f cycles par trame' % ([f for _, f, _ in loops], irqs, sum(ok) / max(1, len(ok))))
t.close()
