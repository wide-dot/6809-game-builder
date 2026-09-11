#!/usr/bin/env python3
"""Les deux collisions du stage 3 corrigees le 11/09/2026, verifiees sous toje.

    python3 tools/collision_stage3_probe.py      (depuis games/r-type)

A. les balles ennemies : le y le plus bas observe sur le manager de balles
   (objects.bullets.address, 24 slots de 21 octets) pendant le debut du
   stage — l'ancienne borne 160 les tuait 25 px au-dessus du sol (185) ;
   attendu > 160 (releve : 177).
B. les tirs du joueur : vaisseau pousse a gauche devant la coque, douze
   rafales ; pour chaque tir, impactX (ext+9) et sa position. Sur cette ligne
   l'avant-plan n'a pas de mur : un impactX non nul vient de la sonde du plan
   de fond, la silhouette du vaisseau (releve : 8/8, 4 a 59 px devant).
Piege : la souris occupe la manette 0 — set_pointer_device none apres le boot.
"""
#     et meurent dessus (impact avant le bord droit).
import os, re, sys, collections
os.environ['TOJE_FAST'] = '1'; sys.path.insert(0, os.path.abspath('../../ci/toje-bench'))
src = open('tools/warship_video.py').read().split('out = os.path.abspath(')[0]
exec(src)
SP = os.path.dirname(os.path.abspath(__file__))
def lwmap_sym(path, name):
    for l in open(path):
        m = re.match(r'Symbol: %s \(.*\) = ([0-9A-Fa-f]+)' % re.escape(name), l)
        if m: return int(m.group(1), 16)
    raise SystemExit(name)
BULLETS = lwmap_sym('gen/common/build/engine.lwmap', 'objects.bullets.address') if 'objects.bullets.address' in open('gen/common/build/engine.lwmap').read() else None
if BULLETS is None:
    import glob
    for f in glob.glob('gen/**/*.lwmap', recursive=True):
        if 'objects.bullets.address' in open(f).read(): BULLETS = lwmap_sym(f, 'objects.bullets.address'); break
ID_WEAPON = 5   # ObjID_Weapon
print('bullets @%04X' % BULLETS, flush=True)
t = Toje()
for i in range(1, 9):
    for what in ('clear_watchpoint', 'clear_breakpoint'):
        try: t.call(what, {'id': i})
        except Exception: pass
t.boot_floppy(os.path.abspath('dist/to8.fd'))
t.call('set_pointer_device', {'device': 'none'})   # la souris occupe la manette 0
t.call('run_frames', {'n': 1200})
page, addr = cheat_state_addr()
launch = equ('gen/title/build/cheat.lwmap', 'title.cheat.launch'); pstage = equ('gen/title/build/cheat.lwmap', 'tct.pstage'); base = addr - pstage
t.call('set_breakpoint', {'pc': '%04X' % WAIT}); t.call('run_to_breakpoint', {'timeout_ms': 120000}); t.call('clear_breakpoint', {'id': 1})
t.call('write_memory', {'addr': 'E7E6', 'bytes': ['%02X' % (0x60 + page)]})
t.call('write_memory', {'addr': hex(addr), 'bytes': ['03', '01']})
t.call('set_register', {'reg': 'dp', 'value': '9F'}); t.call('set_register', {'reg': 'pc', 'value': '%04X' % (base + launch)}); t.call('step')
for _ in range(60):
    t.call('run_frames', {'n': 250, 'timeout_ms': 600000})
    if t.read(hex(BSTAGE), 1)[0] == 3: break
print('stage 3', flush=True)
def bullets():
    raw = t.read('%04X' % BULLETS, 24 * 21)
    out = []
    for i in range(24):
        s = raw[i * 21:(i + 1) * 21]
        if s[9]:
            y = (s[14] << 8) | s[15]; y = y - 65536 if y > 32767 else y
            out.append(y)
    return out
def pool():
    raw = []
    for off in range(0, NOBJ * OSZ, 256): raw += t.read('%04X' % (POOL + off), min(256, NOBJ * OSZ - off))
    return [raw[i * OSZ:(i + 1) * OSZ] for i in range(NOBJ)]
# --- A : le y max des balles, sur 3000 trames de stage
ymax = -999; hist = collections.Counter()
for k in range(60):
    t.call('run_frames', {'n': 10, 'timeout_ms': 600000})
    for y in bullets():
        ymax = max(ymax, y); hist[y // 10 * 10] += 1
print('A. y max des balles ennemies sur 3000 trames : %d ; histogramme (dizaines) : %s' % (ymax, sorted(hist.items())), flush=True)
# --- B : des tirs vers la coque (le vaisseau est devant apres ~3000 trames)
t.call('press_joystick', {'joystick': 0, 'direction': 'left', 'hold_frames': 60})
t.call('press_joystick', {'joystick': 0, 'button_a': True, 'hold_frames': 3})   # la chauffe
t.call('run_frames', {'n': 30, 'timeout_ms': 600000})
seen = {}
for burst in range(12):
    t.call('press_joystick', {'joystick': 0, 'button_a': True, 'hold_frames': 3})
    for _ in range(8):
        t.call('run_frames', {'n': 3, 'timeout_ms': 600000, 'fast': False})
        for i, o in enumerate(pool()):
            if o[0] == ID_WEAPON:
                xp = (o[18] << 8) | o[19]; imp = (o[38 + 9] << 8) | o[38 + 10]; rt = o[34]
                key = (i, imp)
                if imp and i not in seen: seen[i] = (imp, xp, rt)
    t.call('run_frames', {'n': 40, 'timeout_ms': 600000})
print('B. tirs observes (slot -> impactX, x a la 1re lecture, routine) :', seen, flush=True)
p = os.path.join(SP, 'collision_hull.png'); t.call('screenshot', {'path': p}); print('capture', p)
t.close()
