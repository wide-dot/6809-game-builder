#!/usr/bin/env python3
"""Le flash de coup EN REMPLACEMENT, verifie par des coups FORCES (12/09/2026).

    OUT=/tmp python3 tools/hitflash_force_probe.py     (depuis games/r-type)

Stage 3 en invincible ; pour chaque famille a pose blanche de remplacement
(reacteur arriere, capsule, detachables, reacteurs de ventre — cle = taille de
boite), on baisse d'un point le potentiel d'un objet vivant a l'ecran et on
avance TRAME PAR TRAME en relisant l'objet : la pose blanche doit apparaitre
dans image_set (sprites) ou dans un slot de wsmgr (pieces tranchees), et la
capture de cette trame la montrer (pixels blancs dans la fenetre de la boite).
Releve : reacteur de ventre trame +0 (108 px), capsule trame +0 (223 px),
petite capsule trame +8 (41 px). PIEGE : run_until_pc sur l'entree de
gfxlock.bufferSwap.wait sautait ~85 rendus d'un coup — avancer par run_frames.
"""
import os, re, sys, collections
os.environ['TOJE_FAST'] = '1'; sys.path.insert(0, os.path.abspath('../../ci/toje-bench'))
src = open('tools/warship_video.py').read().split('out = os.path.abspath(')[0]
exec(src)
SP = os.environ.get('OUT', '/tmp')   # ou vont les captures
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


GCOUNT = ENGINE_BASE + equ('gen/common/build/engine.lwmap', 'gfxlock.frame.gameCount')
def until(pc):
    # WAIT est l'ENTREE de gfxlock.bufferSwap.wait (un clr, puis la boucle
    # d'attente) : elle ne s'execute qu'une fois par boucle de jeu. Un step la
    # franchit, run_until_pc revient a la fin de la boucle suivante.
    t.call('step'); t.call('run_until_pc', {'pc': '%04X' % pc, 'max_instructions': 600000})
for k in range(60):
    t.call('run_frames', {'n': 50, 'timeout_ms': 600000})
t.call('press_joystick', {'joystick': 0, 'direction': 'left', 'hold_frames': 60})
t.call('press_joystick', {'joystick': 0, 'button_a': True, 'hold_frames': 3})   # la chauffe
t.call('run_frames', {'n': 30, 'timeout_ms': 600000})
found = []
from PIL import Image
# LES POSES BLANCHES DE REMPLACEMENT (12/09/2026) : reacteurs de ventre et
# multi par image_set dans leurs jeux _hit ; pieces wsmgr par la liste
# blanche dans un slot du manager (wsmgr.Slots : page, liste, x, y, page).
def syms(mapfile, pat):
    out = {}
    for l in open(mapfile):
        m = re.match(r'Symbol: (%s) \(.*\) = ([0-9A-Fa-f]+)' % pat, l)
        if m: out[int(m.group(2), 16)] = m.group(1)
    return out
import glob
WHITE_SETS = {}
for f in glob.glob('gen/enemies/build/stage3-cast-img*.lwmap'):
    WHITE_SETS.update(syms(f, r'set_\w+_hit_\d+'))
WHITE_LISTS = syms('gen/stages/03/build/stage03-cast.lwmap', r'react\.sl\.\w+_hit\.0')
_, WSM = unit_base('stage3.wsmgr.res')
WSLOTS = WSM + equ('gen/stages/03/build/wsmgr-res.lwmap', 'wsmgr.Slots')
WCOUNT = WSM + equ('gen/stages/03/build/wsmgr-res.lwmap', 'wsmgr.count')
print('%d jeux blancs, %d listes blanches' % (len(WHITE_SETS), len(WHITE_LISTS)), flush=True)
whites = []
def shot(tag, x, y):
    p = os.path.join(SP, 'hitflash_%s_%d.png' % (tag, len(whites) + 1)); t.call('screenshot', {'path': p})
    im = Image.open(p).convert('RGB'); px = im.load()
    n = sum(1 for yy in range(y - 12, y + 12) for xx in range(x - 12, x + 12) if 0 <= xx < 160 and 0 <= yy < 200 and px[32 + 4 * xx + 1, 112 + 2 * yy] == (251, 251, 247))
    im.crop((32 + 4 * (x - 24), 112 + 2 * (y - 24), 32 + 4 * (x + 24), 112 + 2 * (y + 24))).resize((384, 384), Image.NEAREST).save(os.path.join(SP, 'hitflash_%s_zoom_%d.png' % (tag, len(whites) + 1)))
    return p, n
# COUPS FORCES (12/09/2026) : pour chaque famille a pose blanche de remplacement,
# on baisse d'un point le potentiel de la boite d'un objet vivant a l'ecran, puis
# on avance TRAME PAR TRAME (run_until_pc sur l'entree de wait sautait ~85 rendus
# d'un coup, vecu) en relisant l'objet : la pose blanche doit apparaitre dans
# image_set (sprites) ou dans un slot de wsmgr (pieces tranchees), et la capture
# de cette trame la montrer.
REACT = 42
KEYS = {(14, 11): 'reacteur arriere (wsmgr)', (26, 10): 'capsule (wsmgr)', (6, 11): 'detachable (wsmgr)', (3, 6): 'reacteur de ventre'}
# ce que chaque famille doit montrer (les slots de wsmgr gardent les listes
# d'un flash precedent : on n'accepte que la liste DE la famille)
EXPECT = {(14, 11): ('rear_reactor_hit',), (26, 10): ('escape_capsule_hit',), (6, 11): ('small_escape_capsule_hit', 'falling_triangle_hit'), (3, 6): ('bottom_reactor',)}
seen = {}
def frame():
    t.call('step'); t.call('run_frames', {'n': 1, 'fast': False, 'timeout_ms': 600000})
for loop in range(6000):
    frame()
    objs = pool()
    for i, o in enumerate(objs):
        if o[0] != REACT or o[34] == 0: continue
        rx, ry, cx, cy, p = o[38 + 1], o[38 + 2], o[38 + 3], o[38 + 4], o[38]
        key = (rx, ry)
        if key not in KEYS or key in seen or p < 2 or p > 127 or not (16 < cx < 140 and 16 < cy < 180): continue
        addr = POOL + i * OSZ + 38
        # AVANT / APRES au meme endroit : les pixels devenus blancs sont le flash,
        # pas les blancs naturels du sprite ou des gerbes voisines
        before = os.path.join(SP, 'hitflash_before_%d.png' % (len(seen) + 1)); t.call('screenshot', {'path': before})
        t.call('write_memory', {'addr': '%04X' % addr, 'bytes': ['%02X' % (p - 1)]})
        hit = None
        for f in range(12):
            frame()
            o3 = pool()[i]
            iset = (o3[16] << 8) | o3[17]
            raw = t.read('%04X' % WSLOTS, 6 * 24)
            lists = [((raw[6 * k + 1] << 8) | raw[6 * k + 2]) for k in range(24)]
            wl = [WHITE_LISTS[l] for l in lists if l in WHITE_LISTS]
            wl = [w for w in wl if any(e in w for e in EXPECT[key])]
            ok = (iset in WHITE_SETS and any(e in WHITE_SETS[iset] for e in EXPECT[key])) or wl
            if ok:
                # la pose est posee ; son rendu peut n'etre fini qu'a la trame
                # suivante (la trame coupe la boucle) : on capture trois trames
                # et on garde celle ou le plus de pixels sont devenus blancs
                best = None
                for g in range(3):
                    if g: frame()
                    pth, n = shot('force', o3[38 + 3], o3[38 + 4])
                    a = Image.open(before).convert('RGB').load(); b = Image.open(pth).convert('RGB').load()
                    x, y = o3[38 + 3], o3[38 + 4]
                    turned = sum(1 for yy in range(y - 14, y + 14) for xx in range(x - 30, x + 30) if 0 <= xx < 160 and 0 <= yy < 200
                                 and b[32 + 4 * xx + 1, 112 + 2 * yy] == (251, 251, 247) and a[32 + 4 * xx + 1, 112 + 2 * yy] != (251, 251, 247))
                    if best is None or turned > best[0]: best = (turned, pth, g)
                turned, pth, g = best
                # la paire avant/apres, cote a cote, agrandie
                A = Image.open(before).convert('RGB').crop((32 + 4 * (x - 30), 112 + 2 * (y - 14), 32 + 4 * (x + 30), 112 + 2 * (y + 14)))
                Bm = Image.open(pth).convert('RGB').crop((32 + 4 * (x - 30), 112 + 2 * (y - 14), 32 + 4 * (x + 30), 112 + 2 * (y + 14)))
                pair = Image.new('RGB', (A.width * 2 + 8, A.height), (30, 30, 30)); pair.paste(A, (0, 0)); pair.paste(Bm, (A.width + 8, 0))
                pair = pair.resize((pair.width * 2, pair.height * 4), Image.NEAREST); pair.save(os.path.join(SP, 'hitflash_pair_%d.png' % (len(seen) + 1)))
                hit = (f + g, WHITE_SETS.get(iset), wl, turned, os.path.basename(pth))
                break
        seen[key] = hit
        print('%-26s boite (%d,%d) a (%d,%d), p %d -> %d : %s' % (KEYS[key], rx, ry, cx, cy, p, p - 1,
              ('trame +%d : image_set %s, liste wsmgr %s, %d px DEVENUS blancs dans 60x28 -> %s' % hit) if hit else 'PAS DE POSE BLANCHE EN 12 TRAMES'), flush=True)
        whites.append(1)
    if len(seen) == len(KEYS): break
print('familles vues :', seen)
t.close()
